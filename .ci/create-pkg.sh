#!/bin/sh

set -e

mkdir -p .ci/pkg/
cp .build/arm64-apple-macosx/debug/tart .ci/pkg/
pkgbuild --root .ci/pkg --version "${CIRRUS_TAG:-0}" --install-location /usr/local/bin/ --identifier com.github.cirruslabs.tart --sign "Developer ID Installer: Fedor Korotkov (9M2P8L4D89)" ./dist/Tart.pkg
xcrun notarytool submit ./dist/Tart.pkg --keychain-profile "notarytool" --wait
xcrun stapler staple ./dist/Tart.pkg
