#!/bin/sh

set -e

export VERSION="${CIRRUS_TAG:-0}"

mkdir -p .ci/pkg/
cp .build/arm64-apple-macosx/debug/tart .ci/pkg/
pkgbuild --root .ci/pkg --version $VERSION --install-location /usr/local/bin/ --identifier com.github.cirruslabs.tart --sign "Developer ID Installer: Fedor Korotkov (9M2P8L4D89)" "./dist/Tart-$VERSION.pkg"
xcrun notarytool submit "./dist/Tart-$VERSION.pkg" --keychain-profile "notarytool" --wait
xcrun stapler staple "./dist/Tart-$VERSION.pkg"
