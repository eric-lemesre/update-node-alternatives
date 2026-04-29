#!/bin/sh
# debian/vendor-nvm.sh - refresh vendor/nvm/ from upstream nvm-sh/nvm
#
# Run from the repository root:
#   debian/vendor-nvm.sh X.Y.Z
#
# Updates:
#   - vendor/nvm/{nvm.sh,nvm-exec,bash_completion,LICENSE.md,README.md}
#   - vendor/nvm/VERSION
#   - debian/control (Provides: bundled-nvm-X.Y.Z)
#
# Then the maintainer should run dch(1) to add a changelog entry and
# commit vendor/nvm/, debian/control, debian/changelog together.
#
# Copyright (C) 2026 Eric Lemesre <eric.lemesre@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

set -eu

REPO="nvm-sh/nvm"
VENDOR_DIR="vendor/nvm"
FILES="nvm.sh nvm-exec bash_completion LICENSE.md README.md"

if [ ! -f debian/control ] || [ ! -d "$VENDOR_DIR" ]; then
    echo >&2 "$0: must be run from the repository root"
    exit 1
fi

VER=${1:-}
if [ -z "$VER" ]; then
    echo >&2 "Usage: $0 X.Y.Z"
    echo >&2 "Hint: 'make check-upstream' shows the latest available version."
    exit 1
fi

echo ":: Vendoring nvm $VER from github.com/$REPO"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/$REPO/archive/refs/tags/v$VER.tar.gz"
echo ":: Downloading $URL"
curl -fsSL "$URL" -o "$TMP/nvm.tar.gz"

echo ":: Extracting"
tar -xzf "$TMP/nvm.tar.gz" -C "$TMP"
SRC="$TMP/nvm-$VER"
if [ ! -d "$SRC" ]; then
    echo >&2 "Unexpected archive layout: $SRC missing"
    exit 1
fi

for f in $FILES; do
    if [ ! -f "$SRC/$f" ]; then
        echo >&2 "Missing in upstream tarball: $f"
        exit 1
    fi
done

echo ":: Updating $VENDOR_DIR/"
for f in $FILES; do
    cp -p "$SRC/$f" "$VENDOR_DIR/$f"
done
echo "$VER" > "$VENDOR_DIR/VERSION"

echo ":: Updating debian/control (Provides: bundled-nvm-...)"
sed -i "s/^Provides: bundled-nvm-.*/Provides: bundled-nvm-$VER/" debian/control

echo
echo "Done. Bundled nvm is now $VER."
echo
echo "Next steps:"
echo "  dch --increment \"Update bundled nvm to $VER.\""
echo "  git add vendor/nvm debian/control debian/changelog"
echo "  git commit -m \"vendor: bump nvm to $VER\""
echo "  make deb"
