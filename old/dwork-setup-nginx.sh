#!/bin/bash

set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dwork"
NGINX_DIR="$STATE_DIR/nginx"
NETWORK_NAME="dwork-web"
PROXY_NAME="dwork-nginx"
HTTPS_PORT="${DWORK_HTTPS_PORT:-4443}"

usage() {
  echo "Usage: dwork-setup-nginx <opencode-container-name>"
}

die() {
  echo "dwork-setup-nginx: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

connect_to_network() {
  local container_name="$1"
  local attached

  attached="$(docker inspect \
    -f '{{with index .NetworkSettings.Networks "dwork-web"}}yes{{end}}' \
    "$container_name")"
  if [ "$attached" != "yes" ]; then
    docker network connect "$NETWORK_NAME" "$container_name"
  fi
}

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

require_command docker
require_command openssl

CONTAINER_NAME="$1"
DOMAIN="${CONTAINER_NAME}.localhost"

[[ "$CONTAINER_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
  die "container name must contain only lowercase letters, digits, and hyphens"
[[ "$HTTPS_PORT" =~ ^[0-9]+$ ]] &&
  (( HTTPS_PORT >= 1 && HTTPS_PORT <= 65535 )) ||
  die "DWORK_HTTPS_PORT must be a number between 1 and 65535"

docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1 ||
  die "container $CONTAINER_NAME does not exist"

install -d -m 700 "$NGINX_DIR/certs"
install -d -m 755 "$NGINX_DIR/conf.d"

PORT_FILE="$NGINX_DIR/https-port"
if [ -f "$PORT_FILE" ]; then
  CONFIGURED_PORT="$(<"$PORT_FILE")"
  [ "$CONFIGURED_PORT" = "$HTTPS_PORT" ] ||
    die "shared proxy already uses port $CONFIGURED_PORT; set DWORK_HTTPS_PORT=$CONFIGURED_PORT"
else
  printf '%s\n' "$HTTPS_PORT" > "$PORT_FILE"
fi

CERT_FILE="$NGINX_DIR/certs/${CONTAINER_NAME}.crt"
KEY_FILE="$NGINX_DIR/certs/${CONTAINER_NAME}.key"
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN" \
    >/dev/null 2>&1
  chmod 600 "$KEY_FILE"
fi

if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  docker network create "$NETWORK_NAME" >/dev/null
fi
connect_to_network "$CONTAINER_NAME"

if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" != "true" ]; then
  docker start "$CONTAINER_NAME" >/dev/null
fi

cat > "$NGINX_DIR/conf.d/${CONTAINER_NAME}.conf" <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/nginx/certs/${CONTAINER_NAME}.crt;
    ssl_certificate_key /etc/nginx/certs/${CONTAINER_NAME}.key;

    location / {
        proxy_pass http://${CONTAINER_NAME}:4096;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
        proxy_read_timeout 3600s;
    }
}
EOF

if docker container inspect "$PROXY_NAME" >/dev/null 2>&1; then
  connect_to_network "$PROXY_NAME"
  if [ "$(docker inspect -f '{{.State.Running}}' "$PROXY_NAME")" != "true" ]; then
    docker start "$PROXY_NAME" >/dev/null
  fi
  docker exec "$PROXY_NAME" nginx -t
  docker exec "$PROXY_NAME" nginx -s reload
else
  echo "Creating shared Nginx proxy"
  docker create \
    --name "$PROXY_NAME" \
    --restart unless-stopped \
    --network "$NETWORK_NAME" \
    --label dwork.kind=proxy \
    -p "127.0.0.1:${HTTPS_PORT}:443" \
    -v "$NGINX_DIR/conf.d:/etc/nginx/conf.d:ro" \
    -v "$NGINX_DIR/certs:/etc/nginx/certs:ro" \
    nginx:stable-bookworm \
    >/dev/null
  docker start "$PROXY_NAME" >/dev/null
fi

echo
echo "OpenCode is running at https://${DOMAIN}:${HTTPS_PORT}"
echo "Certificate: $CERT_FILE (self-signed; trust it locally to remove browser warnings)"
