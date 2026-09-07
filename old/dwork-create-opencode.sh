#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dwork"
SECRETS_DIR="$STATE_DIR/secrets"

usage() {
  echo "Usage: dwork-create-opencode <container-name> <work-dir>"
}

die() {
  echo "dwork-create-opencode: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

if [ $# -ne 2 ]; then
  usage
  exit 1
fi

require_command docker

CONTAINER_NAME="$1"
WORK_DIR="$2"

[[ "$CONTAINER_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
  die "container name must contain only lowercase letters, digits, and hyphens"
[[ -d "$WORK_DIR" ]] || die "work dir does not exist: $WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  die "Container $CONTAINER_NAME already exists"
fi

install -d -m 700 "$SECRETS_DIR"

read -r -p "Localhost port [4096]: " OPENCODE_PORT
OPENCODE_PORT="${OPENCODE_PORT:-4096}"
[[ "$OPENCODE_PORT" =~ ^[0-9]+$ ]] &&
  (( OPENCODE_PORT >= 1 && OPENCODE_PORT <= 65535 )) ||
  die "port must be a number between 1 and 65535"

SECRET_FILE="$SECRETS_DIR/${CONTAINER_NAME}.env"
read -r -p "OpenCode username [opencode]: " USERNAME
USERNAME="${USERNAME:-opencode}"

while true; do
  read -r -s -p "OpenCode password: " PASSWORD
  echo
  [ -n "$PASSWORD" ] || {
    echo "Password cannot be empty" >&2
    continue
  }

  read -r -s -p "Confirm password: " PASSWORD_CONFIRM
  echo
  [ "$PASSWORD" = "$PASSWORD_CONFIRM" ] && break
  echo "Passwords do not match" >&2
done

{
  echo "OPENCODE_SERVER_USERNAME=$USERNAME"
  echo "OPENCODE_SERVER_PASSWORD=$PASSWORD"
} > "$SECRET_FILE"
chmod 600 "$SECRET_FILE"
unset PASSWORD PASSWORD_CONFIRM

UID_NUM="$(id -u)"
GID_NUM="$(id -g)"
BASE_IMAGE="dwork:${UID_NUM}-${GID_NUM}"
IMAGE_NAME="dwork-opencode:${UID_NUM}-${GID_NUM}"

echo "Building $BASE_IMAGE"
docker build \
  --build-arg UID="$UID_NUM" \
  --build-arg GID="$GID_NUM" \
  -t "$BASE_IMAGE" \
  "$SCRIPT_DIR"

echo "Building $IMAGE_NAME"
docker build \
  -f "$SCRIPT_DIR/Dockerfile.opencode" \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  -t "$IMAGE_NAME" \
  "$SCRIPT_DIR"

echo "Creating and starting $CONTAINER_NAME"
docker create \
  --init \
  --restart unless-stopped \
  --name "$CONTAINER_NAME" \
  --label dwork.kind=opencode \
  --env-file "$SECRET_FILE" \
  -p "127.0.0.1:${OPENCODE_PORT}:4096" \
  -v "$WORK_DIR:/home/hostuser" \
  -w /home/hostuser \
  "$IMAGE_NAME" \
  >/dev/null
docker start "$CONTAINER_NAME" >/dev/null

echo
echo "OpenCode is running at http://localhost:${OPENCODE_PORT}"
echo "Credentials: $SECRET_FILE"
echo
echo "To add the shared Nginx HTTPS proxy later, run:"
printf '  %q %q\n' "$SCRIPT_DIR/dwork-setup-nginx.sh" "$CONTAINER_NAME"
