#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: dwork-create <container-name> <work-dir>"
}

die() {
  echo "dwork-create: $*" >&2
  exit 1
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker is required"
}

if [ $# -ne 2 ]; then
  usage
  exit 1
fi

require_docker

CONTAINER_NAME="$1"
WORK_DIR="$2"

[[ -d "$WORK_DIR" ]] || die "work dir does not exist: $WORK_DIR"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"


if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  die "Container $CONTAINER_NAME already exists"
fi


# Image is tagged with host uid/gid so files in the mounted work dir are owned
# by the same user inside the container as on the host.
UID_NUM="$(id -u)"
GID_NUM="$(id -g)"
IMAGE_NAME="dwork:${UID_NUM}-${GID_NUM}"

echo "Building image $IMAGE_NAME, creating container $CONTAINER_NAME"

docker build \
  --build-arg UID="$UID_NUM" \
  --build-arg GID="$GID_NUM" \
  -t "$IMAGE_NAME" \
  "$SCRIPT_DIR"

docker create \
  --init \
  --name "$CONTAINER_NAME" \
  -v "$WORK_DIR:/work" \
  -w /work \
  "$IMAGE_NAME" \
  sleep infinity
  
echo "Container $CONTAINER_NAME created"
