#!/usr/bin/env bash
# Builds the PortMaster release: dist/Akuji (the PR folder) and dist/akuji.zip
# (the testing zip). Runs portmaster/build.sh inside the aarch64 build image,
# Ubuntu 20.04 - PortMaster's glibc floor - built from portmaster/Dockerfile
# the first time it is needed.
#
#     tools/package-portmaster.sh
#
# Only Docker's image cache is touched on the host. On an x86_64 machine the
# arm64 container runs under emulation: slower, the same output.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HERE="$REPO/portmaster"
IMAGE="${PORTMASTER_IMAGE:-portmaster-builder:aarch64}"

command -v docker >/dev/null 2>&1 || {
    echo "docker is needed: the PortMaster package builds in an Ubuntu 20.04 aarch64 container" >&2
    exit 1
}

MOUNT="$REPO"
if command -v cygpath >/dev/null 2>&1; then
    MOUNT="$(cygpath -m "$MOUNT")"
    export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "== building $IMAGE (first run, a few minutes)"
    docker build --platform linux/arm64 -t "$IMAGE" "$HERE"
fi

docker run --rm --platform linux/arm64 -v "$MOUNT:/workspace" -w /workspace \
    "$IMAGE" bash portmaster/build.sh

echo
echo "PR folder:   $REPO/dist/Akuji"
echo "testing zip: $REPO/dist/akuji.zip"
