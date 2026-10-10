#!/usr/bin/env bash
# Stage 04b: managed client trusts the leaf after S3 + State Manager install.
#
# Where this runs:
#   - You start this script on your laptop.
#   - curl runs on client-managed via SSM after the association installed the CA.
#   - No curl -k / --cacert — system trust store only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/_prove_lib.sh
source "$ROOT/scripts/_prove_lib.sh"

cd "$ROOT/terraform/04-trust"

prove_header "04" "Managed client (must succeed without --cacert)"
prove_info "you are on: laptop (this script)"
prove_info "curl runs on: client-managed via SSM"
prove_info "CA install path: S3 → State Manager → system trust store"

PRIVATE_URL="$(terraform output -raw private_url)"
INSTANCE_ID="$(terraform output -raw managed_client_instance_id)"
ASSOC_ID="$(terraform output -raw ssm_association_id)"
AWS_REGION="$(prove_tf_region ../terraform.tfvars)"

prove_info "instance=$INSTANCE_ID  url=$PRIVATE_URL"
prove_info "SSM association=$ASSOC_ID"

LAST_STATUS="$(aws ssm describe-association-executions \
  --region "$AWS_REGION" \
  --association-id "$ASSOC_ID" \
  --max-items 1 \
  --query 'AssociationExecutions[0].Status' \
  --output text 2>/dev/null || echo unknown)"
if [[ "$LAST_STATUS" == "Success" ]]; then
  prove_ok "[laptop] latest State Manager run: Success"
else
  prove_ok "[laptop] latest State Manager run: $LAST_STATUS (curl is the proof)"
fi

PARAMS="$(mktemp)"
trap 'rm -f "$PARAMS"' EXIT

python3 - "$PRIVATE_URL" >"$PARAMS" <<'PY'
import json, sys
url = sys.argv[1]
script = f"""set -euo pipefail
test -f /etc/pki/ca-trust/source/anchors/intranet-private-ca.pem
echo "CA anchor present (from S3 + State Manager)"
BODY=$(curl -fsS --max-time 15 '{url}/')
echo "$BODY" | head -n 3
echo "TLS OK with system trust (no -k, no --cacert)"
"""
print(json.dumps({"commands": [script]}))
PY

prove_ok "[SSM → client-managed] plain curl after CA install"
prove_ssm_run "$AWS_REGION" "$INSTANCE_ID" "$PARAMS" || prove_die "managed prove failed"

prove_pass "managed client trusts the private path — lab complete"
