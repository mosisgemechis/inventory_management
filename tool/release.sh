#!/usr/bin/env bash
# Bump the app version, commit it, and push the release tag.
#
#   tool/release.sh 1.1.0
#
# Afterwards build the artifacts and publish the matching GitHub Release
# (see RELEASING.md). The in-app updater reads that release.
set -euo pipefail

usage() {
  echo "Usage: tool/release.sh <version>   e.g. tool/release.sh 1.1.0" >&2
  exit 1
}

[ $# -eq 1 ] || usage
VERSION="${1#v}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must look like 1.2.3 (got '$1')" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is not clean. Commit or stash your changes first." >&2
  git status --short >&2
  exit 1
fi

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Tag v$VERSION already exists." >&2
  exit 1
fi

CURRENT="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
BUILD="$(printf '%s' "$CURRENT" | sed -E 's/.*\+([0-9]+).*/\1/')"
[ -n "$BUILD" ] || BUILD=0
NEXT_BUILD=$((BUILD + 1))
NEXT="$VERSION+$NEXT_BUILD"

python - "$NEXT" <<'PY'
import io, re, sys
new = sys.argv[1]
path = "pubspec.yaml"
text = io.open(path, encoding="utf-8", newline="").read()
text, n = re.subn(r"(?m)^version: .*$", "version: " + new, text, count=1)
if n != 1:
    raise SystemExit("Could not update the version line in pubspec.yaml")
io.open(path, "w", encoding="utf-8", newline="").write(text)
PY

echo "pubspec.yaml: $CURRENT -> $NEXT"

git add pubspec.yaml
git commit -m "chore(release): v$VERSION"
git tag -a "v$VERSION" -m "GM Inventory Everywhere v$VERSION"
git push origin HEAD
git push origin "v$VERSION"

cat <<EOF

Tagged v$VERSION and pushed.

Next steps:
  1. flutter build apk --release
     flutter build windows --release
  2. Publish the GitHub Release for tag v$VERSION with the built files attached
     and user-facing notes in the description. Installed apps will offer the
     update on their next launch.
EOF
