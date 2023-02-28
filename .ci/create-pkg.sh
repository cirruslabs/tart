#!/bin/sh

set -e

export VERSION="${CIRRUS_TAG:-0}"

mkdir -p .ci/pkg/Tart.app/Contents/MacOS
cp .build/arm64-apple-macosx/debug/tart .ci/pkg/Tart.app/Contents/MacOS/Tart
cp Resources/embedded.provisionprofile .ci/pkg/Tart.app/Contents/embedded.provisionprofile
pkgbuild --root .ci/pkg/Tart.app --identifier com.github.cirruslabs.tart --version $VERSION \
  --scripts .ci/pkg/scripts \
  --install-location "/Library/Application Support/Tart/Tart.app" \
  --sign "Developer ID Installer: Cirrus Labs, Inc. (9M2P8L4D89)" \
  "./dist/Tart-$VERSION.pkg"
xcrun notarytool submit "./dist/Tart-$VERSION.pkg" --keychain-profile "notarytool" --wait
xcrun stapler staple "./dist/Tart-$VERSION.pkg"
