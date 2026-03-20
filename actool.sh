#!/usr/bin/env bash

# Set shell options to enable fail-fast behavior
#
# * -e: fail the script when an error occurs or command fails
# * -u: fail the script when attempting to reference unset parameters
# * -o pipefail: by default an exit status of a pipeline is that of its
#                last command, this fails the pipe early if an error in
#                any of its commands occurs
#
set -euo pipefail

OUTPUT_PATH="Resources/actool"
PLIST_PATH="$OUTPUT_PATH/Info.plist"

rm -rf "${OUTPUT_PATH}"
mkdir -p "${OUTPUT_PATH}"

actool "Resources/UPW Tart.icon" \
  --compile "${OUTPUT_PATH}" \
  --output-format human-readable-text \
  --notices \
  --warnings \
  --errors \
  --app-icon "UPW Tart" \
  --output-partial-info-plist $PLIST_PATH \
  --include-all-app-icons \
  --target-device mac \
  --minimum-deployment-target 13.0 \
  --platform macosx
