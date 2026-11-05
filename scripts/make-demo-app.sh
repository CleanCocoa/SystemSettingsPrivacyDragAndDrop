#!/bin/sh
# Builds build/PrivacyDragAndDropDemo.app, ad-hoc signed with only the App Sandbox entitlement.
set -eu
cd "$(dirname "$0")/.."
swift build -c release --product PrivacyDragAndDropDemo
app=build/PrivacyDragAndDropDemo.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp Demo/Info.plist "$app/Contents/Info.plist"
cp "$(swift build -c release --show-bin-path)/PrivacyDragAndDropDemo" "$app/Contents/MacOS/"
codesign --force --sign - --entitlements Demo/Sandbox.entitlements "$app"
codesign --display --entitlements - "$app" 2>/dev/null | grep -q app-sandbox
echo "$app"
