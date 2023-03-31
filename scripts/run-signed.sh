#!/bin/sh

# helper script to build and run a signed tart binary
# usage: ./scripts/run-signed.sh run ventura-base

set -e

swift build --product tart
codesign --sign - --entitlements Resources/tart-dev.entitlements --force .build/debug/tart

.build/debug/tart "$@"
