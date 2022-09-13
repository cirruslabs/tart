source = [".build/arm64-apple-macosx/debug/tart"]
bundle_id = "com.github.cirruslabs.tart"

apple_id {
  username = "hello@cirruslabs.org"
  password = "@env:AC_PASSWORD"
}

sign {
  application_identity = "Developer ID Application: Cirrus Labs, Inc."
  entitlements_file = "Resources/tart.entitlements"
}
