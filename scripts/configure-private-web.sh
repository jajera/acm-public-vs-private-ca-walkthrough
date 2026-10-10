#!/usr/bin/env bash
# Idempotent: install nginx and load Private CA leaf material from Secrets Manager.
# Invoked by SSM State Manager on private-web (not via EC2 user data).
#
# Required env:
#   SECRET_ID          Secrets Manager secret id/arn (JSON: certificate, chain, private_key)
#   AWS_DEFAULT_REGION Region for GetSecretValue
#   PRIVATE_HOSTNAME   Hostname shown on the demo page
set -euo pipefail

: "${SECRET_ID:?SECRET_ID required}"
: "${AWS_DEFAULT_REGION:?AWS_DEFAULT_REGION required}"
: "${PRIVATE_HOSTNAME:?PRIVATE_HOSTNAME required}"

retry() {
  local n=0
  local max=12
  local delay=10
  until "$@"; do
    n=$((n + 1))
    if [[ "$n" -ge "$max" ]]; then
      echo "FAILED after $max attempts: $*" >&2
      return 1
    fi
    echo "retry $n/$max: $*" >&2
    sleep "$delay"
  done
}

retry dnf install -y nginx jq awscli

mkdir -p /etc/nginx/ssl
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

retry aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --region "$AWS_DEFAULT_REGION" \
  --query SecretString \
  --output text \
  >"$TMP"

jq -r '.certificate' "$TMP" >/etc/nginx/ssl/server.crt
jq -r '.chain // empty' "$TMP" >>/etc/nginx/ssl/server.crt
jq -r '.private_key' "$TMP" >/etc/nginx/ssl/server.key
chmod 600 /etc/nginx/ssl/server.key

cat >/usr/share/nginx/html/index.html <<HTML
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Private CA path</title></head>
<body>
  <h1>Private CA path</h1>
  <p>TLS terminated on nginx with a Private CA leaf from Secrets Manager.</p>
  <p>Host: ${PRIVATE_HOSTNAME}</p>
  <p>Configured by SSM State Manager (not EC2 user data).</p>
</body>
</html>
HTML

cat >/etc/nginx/conf.d/tls.conf <<'NGINX'
server {
  listen 443 ssl;
  server_name _;
  ssl_certificate     /etc/nginx/ssl/server.crt;
  ssl_certificate_key /etc/nginx/ssl/server.key;
  root /usr/share/nginx/html;
  index index.html;
}
NGINX

rm -f /etc/nginx/conf.d/default.conf
systemctl enable nginx
systemctl restart nginx
echo "private-web configured from Secrets Manager secret $SECRET_ID"
