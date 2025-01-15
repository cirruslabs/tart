#!/bin/sh

# helper script to build a signed tart binary
CURDIR=$1

set -e

PKGDIR=${CURDIR}/dist/Tart.app

swift build --product tart
codesign --sign - --entitlements Resources/tart-dev.entitlements --force .build/debug/tart

rm -Rf ${PKGDIR}
mkdir -p ${PKGDIR}/Contents/MacOS ${PKGDIR}/Contents/Resources
cp -c .build/debug/tart ${PKGDIR}/Contents/MacOS/tart
cp -c Resources/embedded.provisionprofile ${PKGDIR}/Contents/embedded.provisionprofile
cp -c Resources/Info.plist ${PKGDIR}/Contents/Info.plist
cp -c Resources/AppIcon.png ${PKGDIR}/Contents/Resources
