#!/usr/bin/env bash
# Stage 02: public ACM path — HTTPS works with default browser/OS trust.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/_prove_lib.sh
source "$ROOT/scripts/_prove_lib.sh"

cd "$ROOT/terraform/02-public"

prove_header "02" "Public ACM path"

PUBLIC_URL="$(terraform output -raw public_url)"
HOST="${PUBLIC_URL#https://}"

HTTP_CODE="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 20 "$PUBLIC_URL/" || true)"
prove_eq "HTTPS response" "$HTTP_CODE" "200" || prove_die "could not reach $PUBLIC_URL (got HTTP ${HTTP_CODE:-none})"
prove_info "$PUBLIC_URL"

CERT_TXT="$(echo | openssl s_client -servername "$HOST" -connect "${HOST}:443" 2>/dev/null \
  | openssl x509 -noout -issuer -subject 2>/dev/null || true)"
[[ -n "$CERT_TXT" ]] || prove_die "could not read TLS certificate from $HOST"

prove_contains "Certificate issued by Amazon" "$CERT_TXT" "O = Amazon" \
  || prove_die "issuer is not Amazon — is ACM attached?"
prove_contains "Certificate name is $HOST" "$CERT_TXT" "CN = $HOST" \
  || prove_die "subject CN mismatch"
prove_info "$(echo "$CERT_TXT" | tr '\n' ' ' | sed 's/  */ /g')"

prove_pass "public path works with default trust — continue to stage 03"
