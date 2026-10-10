#!/usr/bin/env bash
# Optional: download the published CA PEM for inspection (not required for managed prove).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/terraform/04-trust"

URI="$(terraform output -raw ca_s3_uri)"
OUT="${1:-./ca.pem}"

aws s3 cp "$URI" "$OUT"
echo "Wrote $OUT"
openssl x509 -in "$OUT" -noout -subject -issuer
