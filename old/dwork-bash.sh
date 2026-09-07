#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: dwork-bash <container-name>"
}

die() {
    echo "dwork-bash: $*" >&2
    exit 1
}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi

CONTAINER_NAME="$1"


if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Container $CONTAINER_NAME exists"
else
  die "Container $CONTAINER_NAME does not exist, run dwork-create first"
fi

if [ "$(docker container inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" = "true" ]; then
  echo "Container $CONTAINER_NAME is running"
else
  # start container if not running
  echo "Starting container $CONTAINER_NAME"
  docker start "$CONTAINER_NAME"
fi

docker exec -it "$CONTAINER_NAME" bash
