#!/bin/bash

set -euo pipefail

die() {
  echo "dwork-status: $*" >&2
  exit 1
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker is required"
}

if [ $# -ne 0 ]; then
  echo "Usage: dwork-status"
  exit 1
fi

require_docker

echo "Images"
echo "------"
images="$(docker images --filter 'reference=dwork*' --format '{{.Repository}}:{{.Tag}}\t{{.Size}}')"
if [ -z "$images" ]; then
  echo "  (none)"
else
  while IFS=$'\t' read -r image size; do
    printf '  %s  (%s)\n' "$image" "$size"
  done <<< "$images"
fi

echo
echo "Containers"
echo "----------"
container_ids=($(docker ps -aq))
found=0
if [ ${#container_ids[@]} -gt 0 ]; then
  while IFS=$'\t' read -r name image status work; do
    name="${name#/}"
    case "$image" in
      dwork:*|dwork-opencode:*)
        found=1
        printf '  %-16s %-10s %-20s %s\n' "$name" "$status" "$image" "$work"
        ;;
    esac
  done < <(docker inspect --format '{{.Name}}{{"\t"}}{{.Config.Image}}{{"\t"}}{{.State.Status}}{{"\t"}}{{range .Mounts}}{{if or (eq .Destination "/work") (eq .Destination "/home/hostuser")}}{{.Source}}{{end}}{{end}}' "${container_ids[@]}")
fi
if [ "$found" -eq 0 ]; then
  echo "  (none)"
fi

echo
echo "Tips"
echo "----"
echo "  docker stop NAME      stop a running container"
echo "  docker kill NAME      force-stop (SIGKILL)"
echo "  docker start NAME     start a stopped container"
echo "  docker rm NAME        delete a stopped container"
echo "  docker rm -f NAME     stop and delete"
echo "  docker rmi IMAGE      delete image (after its containers are gone)"
