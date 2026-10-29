#!/usr/bin/env bash
# Print the path of a Free Pascal 3.2 compiler, fetching one if there is none.
#
#     tools/find-fpc.sh
#
# In order: $FPC if set; the copy tools/fetch-fpc.sh put in .toolchain/; fpc
# on PATH; the Free Pascal inside a Windows Lazarus install. A compiler that is
# not 3.2.x is passed over - Ubuntu 20.04's is 3.0.4 - rather than trusted. On
# Linux, if nothing suitable is found, tools/fetch-fpc.sh is run.
#
# Also prints, on a second line, the PPC_CONFIG_PATH the compiler needs, or
# nothing if it finds its own configuration. Messages go to stderr.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

version_ok() {
    local v
    if [ -n "${2:-}" ]; then
        v="$(PPC_CONFIG_PATH="$2" "$1" -iV 2>/dev/null || true)"
    else
        v="$("$1" -iV 2>/dev/null || true)"
    fi
    case "$v" in 3.2.*) return 0 ;; *) return 1 ;; esac
}

emit() {
    echo "$1"
    echo "${2:-}"
    exit 0
}

if [ -n "${FPC:-}" ]; then
    if version_ok "$FPC" "${PPC_CONFIG_PATH:-}"; then
        emit "$FPC" "${PPC_CONFIG_PATH:-}"
    fi
    echo "find-fpc: \$FPC=$FPC is not a Free Pascal 3.2 compiler" >&2
    exit 2
fi

for fetched in "$REPO"/.toolchain/fpc-3.2.*-*/bin/fpc; do
    [ -x "$fetched" ] || continue
    cfg="$(dirname "$(dirname "$fetched")")/etc"
    if version_ok "$fetched" "$cfg"; then
        # The configuration names the checkout path it was unpacked under, and
        # a compiler with a stale one cannot find its own run time. fetch-fpc.sh
        # rewrites it when that path has changed - a moved checkout, a new
        # clone, or the PortMaster container mounting the repo somewhere else.
        "$REPO/tools/fetch-fpc.sh" >/dev/null
        emit "$fetched" "$cfg"
    fi
done

if command -v fpc >/dev/null 2>&1 && version_ok "$(command -v fpc)"; then
    emit "$(command -v fpc)"
fi

for candidate in /e/lazarus/fpc/*/bin/*/fpc.exe /c/lazarus/fpc/*/bin/*/fpc.exe \
                 "/c/Program Files/Lazarus/fpc/"*/bin/*/fpc.exe; do
    [ -x "$candidate" ] && version_ok "$candidate" && emit "$candidate"
done

if [ "$(uname -s)" = "Linux" ]; then
    echo "find-fpc: no Free Pascal 3.2 here - fetching one into .toolchain/" >&2
    fetched="$("$REPO/tools/fetch-fpc.sh")"
    emit "$fetched" "$(dirname "$(dirname "$fetched")")/etc"
fi

echo "find-fpc: no Free Pascal 3.2 compiler found. Install Lazarus, or set FPC." >&2
exit 2
