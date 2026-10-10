#!/usr/bin/env bash
# Stage 03: Private CA is ACTIVE and the private leaf is served.
#
# Modes (terraform output private_tls_mode):
#   alb_acm      — ACM private cert on internal ALB; HTTP backend on private-web
#   nginx_export — Secrets Manager → State Manager → nginx :443 on private-web
#
# Where this runs:
#   - You start this script on your laptop (repo root).
#   - CA / ACM checks: laptop → AWS API.
#   - Leaf inspect: laptop → SSM Run Command → runs on private-web EC2.
#   - Laptop does NOT curl the private URL (no VPC route/DNS).
#
# Trusted HTTPS is stage 04 (S3 + State Manager → system store → plain curl).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/_prove_lib.sh
source "$ROOT/scripts/_prove_lib.sh"

cd "$ROOT/terraform/03-private"

MODE="$(terraform output -raw private_tls_mode)"
PRIVATE_URL="$(terraform output -raw private_url)"
HOST="${PRIVATE_URL#https://}"
INSTANCE_ID="$(terraform output -raw private_web_instance_id)"
PRIVATE_IP="$(terraform output -raw private_web_private_ip)"
CA_ARN="$(terraform output -raw private_ca_arn)"
AWS_REGION="$(prove_tf_region ../terraform.tfvars)"

prove_header "03" "Private CA + leaf ($MODE)"
prove_info "you are on: laptop (this script)"
prove_info "private_tls_mode=$MODE"
prove_info "leaf inspect runs on: private-web via SSM"

prove_ok "[laptop] reading terraform outputs + AWS API"
CA_STATUS="$(aws acm-pca describe-certificate-authority \
  --region "$AWS_REGION" \
  --certificate-authority-arn "$CA_ARN" \
  --query 'CertificateAuthority.Status' \
  --output text)"
prove_eq "Private CA status" "$CA_STATUS" "ACTIVE" || prove_die "Private CA is not ACTIVE"
prove_info "private-web=$INSTANCE_ID  ip=$PRIVATE_IP"
prove_info "private URL $PRIVATE_URL is VPC-only (laptop does not curl it)"

PARAMS="$(mktemp)"
trap 'rm -f "$PARAMS"' EXIT

if [[ "$MODE" == "alb_acm" ]]; then
  ACM_ARN="$(terraform output -raw acm_private_certificate_arn)"
  ALB_DNS="$(terraform output -raw internal_alb_dns_name)"
  prove_info "ACM private cert=$ACM_ARN"
  prove_info "internal ALB=$ALB_DNS"

  ACM_STATUS="$(aws acm describe-certificate \
    --region "$AWS_REGION" \
    --certificate-arn "$ACM_ARN" \
    --query 'Certificate.Status' \
    --output text)"
  prove_eq "ACM private cert status" "$ACM_STATUS" "ISSUED" || prove_die "ACM private cert is not ISSUED"

  python3 - "$HOST" >"$PARAMS" <<'PY'
import json, sys
host = sys.argv[1]
script = f"""set -euo pipefail
# Resolve private hostname inside the VPC (alias → internal ALB).
CERT=$(echo | openssl s_client -servername "{host}" -connect "{host}:443" 2>/dev/null \\
  | openssl x509 -noout -subject -issuer)
echo "$CERT"
echo "$CERT" | grep -E -q "CN = {host}|CN={host}"
echo "$CERT" | grep -qi "Lab Root CA"
if echo "$CERT" | grep -q "O = Amazon"; then
  echo "issuer looks like Amazon public CA — wrong path"
  exit 1
fi
curl -fsS --max-time 10 "http://127.0.0.1/" | grep -qi "Private CA path"
echo "HTTP backend on private-web OK (TLS is on the internal ALB)"
"""
print(json.dumps({"commands": [script]}))
PY

  prove_ok "[SSM → private-web] inspect ALB leaf + HTTP backend"
  prove_ssm_run "$AWS_REGION" "$INSTANCE_ID" "$PARAMS" || prove_die "leaf inspect failed"
  prove_ok "Leaf served by internal ALB (ACM private cert)"
  prove_pass "ACM private cert on internal ALB — run stage 04 for trusted client curl"

elif [[ "$MODE" == "nginx_export" ]]; then
  ASSOC_ID="$(terraform output -raw ssm_configure_association_id)"
  prove_info "SSM association=$ASSOC_ID"
  prove_info "leaf install path: Secrets Manager → State Manager → private-web"

  LAST_STATUS="$(aws ssm describe-association-executions \
    --region "$AWS_REGION" \
    --association-id "$ASSOC_ID" \
    --max-items 1 \
    --query 'AssociationExecutions[0].Status' \
    --output text 2>/dev/null || echo unknown)"
  if [[ "$LAST_STATUS" == "Success" ]]; then
    prove_ok "[laptop] latest State Manager run: Success"
  else
    prove_info "[laptop] latest State Manager run: $LAST_STATUS (leaf inspect is the proof)"
  fi

  python3 - "$HOST" "$PRIVATE_IP" >"$PARAMS" <<'PY'
import json, sys
host, ip = sys.argv[1], sys.argv[2]
script = f"""set -euo pipefail
CERT=$(echo | openssl s_client -servername "{host}" -connect "{ip}:443" 2>/dev/null \\
  | openssl x509 -noout -subject -issuer)
echo "$CERT"
echo "$CERT" | grep -E -q "CN = {host}|CN={host}"
echo "$CERT" | grep -qi "Lab Root CA"
if echo "$CERT" | grep -q "O = Amazon"; then
  echo "issuer looks like Amazon public CA — wrong path"
  exit 1
fi
test -f /etc/nginx/ssl/server.crt
test -f /etc/nginx/ssl/server.key
echo "nginx leaf material present under /etc/nginx/ssl"
"""
print(json.dumps({"commands": [script]}))
PY

  prove_ok "[SSM → private-web] inspect leaf (openssl + /etc/nginx/ssl)"
  prove_ssm_run "$AWS_REGION" "$INSTANCE_ID" "$PARAMS" || prove_die "leaf inspect failed"
  prove_ok "Leaf served by nginx"
  prove_pass "leaf is on nginx — run stage 04 for trusted client curl"

else
  prove_die "unknown private_tls_mode=$MODE (expected alb_acm or nginx_export)"
fi
