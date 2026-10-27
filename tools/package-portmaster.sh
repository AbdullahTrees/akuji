#!/usr/bin/env bash
# Builds the PortMaster release: dist/Akuji (the PR folder) and dist/akuji.zip
# (the testing zip). Runs portmaster/build.sh inside the aarch64 build image.
#
#     tools/package-portmaster.sh
#
# The image is portmaster-builder:aarch64, built from the repository one level
# up (docker compose build aarch64). Nothing here is installed on the host.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$(dirname "$REPO")"
IMAGE="portmaster-builder:aarch64"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "missing image $IMAGE - build it in $(dirname "$WORKSPACE") first" >&2
    exit 1
fi

if command -v cygpath >/dev/null 2>&1; then
    WORKSPACE="$(cygpath -m "$WORKSPACE")"
    export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
fi

docker run --rm --platform linux/arm64 -v "$WORKSPACE:/workspace" \
    -w /workspace/akuji "$IMAGE" bash /workspace/akuji/portmaster/build.sh

echo
echo "PR folder:   $REPO/dist/Akuji"
echo "testing zip: $REPO/dist/akuji.zip"
