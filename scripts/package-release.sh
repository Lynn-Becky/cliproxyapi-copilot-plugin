#!/bin/sh
set -eu

VERSION=${1:-}
GOOS=${2:-linux}
if [ "$#" -ge 2 ]; then
  shift 2
elif [ "$#" -ge 1 ]; then
  shift
fi
if [ "$#" -gt 0 ]; then
  ARCHES="$*"
else
  ARCHES="amd64 arm64"
fi

PLUGIN_ID="cliproxyapi-copilot"

case "$VERSION" in
  "" | *[!0-9.]* | .* | *. | *..*)
    printf 'error: version must be dotted numeric without a leading v\n' >&2
    exit 1
    ;;
esac
case "$VERSION" in
  *.*) ;;
  *)
    printf 'error: version must contain at least two numeric components\n' >&2
    exit 1
    ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DIST_DIR="$REPO_DIR/dist"
command -v python3 >/dev/null 2>&1 || {
  printf 'error: python3 is required\n' >&2
  exit 1
}
command -v sha256sum >/dev/null 2>&1 || {
  printf 'error: sha256sum is required\n' >&2
  exit 1
}

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/checksums.txt"

for GOARCH in $ARCHES; do
  case "$GOARCH" in
    *[!a-z0-9_]* | "")
      printf 'error: invalid GOARCH value: %s\n' "$GOARCH" >&2
      exit 1
      ;;
  esac

  PLUGIN="$REPO_DIR/build/plugins/$GOOS/$GOARCH/$PLUGIN_ID.so"
  ARCHIVE="$PLUGIN_ID"_"$VERSION"_"$GOOS"_"$GOARCH".zip

  [ -f "$PLUGIN" ] || {
    printf 'error: plugin artifact is missing for %s/%s; run make build first\n' "$GOOS" "$GOARCH" >&2
    exit 1
  }

  rm -f "$DIST_DIR/$ARCHIVE"
  python3 - "$PLUGIN" "$DIST_DIR/$ARCHIVE" <<'PY'
import pathlib
import sys
import zipfile

plugin = pathlib.Path(sys.argv[1])
archive = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as output:
    output.write(plugin, plugin.name)
PY
  (
    cd "$DIST_DIR"
    sha256sum "$ARCHIVE" >>checksums.txt
  )
done

printf 'Created precompiled archives in %s and checksums.txt\n' "$DIST_DIR"
