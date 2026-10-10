#!/usr/bin/env bash
# Stage 04a: unmanaged client rejects the Private CA (no State Manager install).
#
# Where this runs:
#   - You start this script on your laptop.
#   - curl runs on client-unmanaged via SSM (laptop has no VPC route to the private URL).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/_prove_lib.sh
source "$ROOT/scripts/_prove_lib.sh"

cd "$ROOT/terraform/04-trust"

prove_header "04" "Unmanaged client (must fail TLS)"
prove_info "you are on: laptop (this script)"
prove_info "curl runs on: client-unmanaged via SSM"

PRIVATE_URL="$(terraform output -raw private_url)"
INSTANCE_ID="$(terraform output -raw unmanaged_client_instance_id)"
AWS_REGION="$(prove_tf_region ../terraform.tfvars)"

prove_info "instance=$INSTANCE_ID  url=$PRIVATE_URL"
prove_info "expect: plain curl fails (CA not in system store)"

PARAMS="$(mktemp)"
trap 'rm -f "$PARAMS"' EXIT

python3 - "$PRIVATE_URL" >"$PARAMS" <<'PY'
import json, sys
url = sys.argv[1]
script = f"""set -euo pipefail
if curl -fsS --max-time 15 '{url}/' >/tmp/body 2>/tmp/err; then
  echo "UNEXPECTED: TLS succeeded — unmanaged client should not trust this CA"
  exit 1
fi
echo "TLS rejected as expected"
sed -n '1,3p' /tmp/err || true
"""
print(json.dumps({"commands": [script]}))
PY

prove_ok "[SSM → client-unmanaged] plain curl (no -k, no --cacert)"
prove_ssm_run "$AWS_REGION" "$INSTANCE_ID" "$PARAMS" || prove_die "unmanaged prove failed"

prove_pass "unmanaged client correctly rejects the issuer — next: prove-private-managed.sh"
