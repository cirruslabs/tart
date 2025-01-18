source = [ "dist/tart_darwin_all/tart.app/Contents/MacOS/tart" ]
bundle_id = "com.github.cirruslabs.tart"

apple_id {
  username = "hello@cirruslabs.org"
  password = "@env:AC_PASSWORD"
}

sign {
  application_identity = "Developer ID Application: Cirrus Labs, Inc."
  entitlements_file = "Resources/tart-prod.entitlements"
}
