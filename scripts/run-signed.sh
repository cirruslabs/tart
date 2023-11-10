#!/bin/sh

# helper script to build and run a signed tart binary
# usage: ./scripts/run-signed.sh run sonoma-base

set -e

swift build --product tart
codesign --sign - --entitlements Resources/tart-dev.entitlements --force .build/debug/tart

mkdir -p .build/tart.app/Contents/MacOS
cp -c .build/debug/tart .build/tart.app/Contents/MacOS/tart
cp -c Resources/embedded.provisionprofile .build/tart.app/Contents/embedded.provisionprofile

.build/tart.app/Contents/MacOS/tart "$@"
