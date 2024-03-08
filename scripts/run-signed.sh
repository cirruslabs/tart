#!/bin/sh

# helper script to build and run a signed tart binary
# usage: ./scripts/run-signed.sh run sonoma-base

set -e

swift build --product tart
codesign --sign - --entitlements Resources/tart-dev.entitlements --force .build/debug/tart

rm -Rf .build/Tart.app/
mkdir -p .build/Tart.app/Contents/MacOS .build/Tart.app/Contents/Resources
cp -c .build/debug/tart .build/Tart.app/Contents/MacOS/tart
cp -c Resources/embedded.provisionprofile .build/Tart.app/Contents/embedded.provisionprofile
cp -c Resources/Info.plist .build/Tart.app/Contents/Info.plist
cp -c Resources/AppIcon.png .build/Tart.app/Contents/Resources

.build/Tart.app/Contents/MacOS/tart "$@"
