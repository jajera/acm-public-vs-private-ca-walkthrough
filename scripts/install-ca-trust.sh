#!/usr/bin/env bash
# Idempotent install of a Private CA PEM into the Amazon Linux / RHEL system trust store.
# Usage: install-ca-trust.sh s3://bucket/trust/ca.pem
set -euo pipefail

SRC="${1:?s3 URI or local PEM path required}"
ANCHOR_DIR="/etc/pki/ca-trust/source/anchors"
ANCHOR_FILE="${ANCHOR_DIR}/intranet-private-ca.pem"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if [[ "$SRC" == s3://* ]]; then
  aws s3 cp "$SRC" "$TMP"
else
  cp "$SRC" "$TMP"
fi

# Basic PEM sanity
grep -q "BEGIN CERTIFICATE" "$TMP"

NEW_SUM="$(sha256sum "$TMP" | awk '{print $1}')"
if [[ -f "$ANCHOR_FILE" ]]; then
  OLD_SUM="$(sha256sum "$ANCHOR_FILE" | awk '{print $1}')"
  if [[ "$NEW_SUM" == "$OLD_SUM" ]]; then
    echo "CA trust already current ($NEW_SUM)"
    exit 0
  fi
fi

install -d -m 0755 "$ANCHOR_DIR"
install -m 0644 "$TMP" "$ANCHOR_FILE"
update-ca-trust extract
echo "Installed CA trust anchor $ANCHOR_FILE ($NEW_SUM)"
