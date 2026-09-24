#!/usr/bin/env bash
# Bump the version in src/Version.pas and print the new one.
#
#     tools/bump-version.sh patch    +0.0.1 - every commit
#     tools/bump-version.sh minor    +0.1.0 - a milestone; patch returns to 0
#     tools/bump-version.sh          prints the current version, changes nothing
#
# The only thing that should ever change APP_VERSION. It refuses a file whose
# version is not three plain numbers rather than guessing what was meant.

set -eu

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$REPO/src/Version.pas"

current="$(sed -n "s/^  APP_VERSION = '\([0-9]*\.[0-9]*\.[0-9]*\)';.*/\1/p" "$FILE")"
if [ -z "$current" ]; then
    echo "bump-version: no MAJOR.MINOR.PATCH APP_VERSION in $FILE" >&2
    exit 1
fi

IFS=. read -r major minor patch <<< "$current"

case "${1:-}" in
    "")     echo "$current"; exit 0 ;;
    patch)  patch=$((patch + 1)) ;;
    minor)  minor=$((minor + 1)); patch=0 ;;
    *)      echo "usage: tools/bump-version.sh [patch|minor]" >&2; exit 2 ;;
esac

next="$major.$minor.$patch"
# Rewrite only that one line, keeping the file's own line endings.
sed -i "s/^  APP_VERSION = '$current';/  APP_VERSION = '$next';/" "$FILE"
grep -q "^  APP_VERSION = '$next';" "$FILE" || {
    echo "bump-version: the rewrite did not take" >&2
    exit 1
}
echo "$next"
