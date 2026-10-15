#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
dart run build_runner build
flutter build macos --release
mkdir -p build/distribution
ditto -c -k --sequesterRsrc --keepParent build/macos/Build/Products/Release/dukan_app.app build/distribution/dukan-macos-development.zip
