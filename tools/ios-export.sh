#!/usr/bin/env bash
# Repeatable macOS-only Godot 4.6.3 iOS/Xcode source export.
# No Apple API key is needed to produce and build an unsigned iPhone app.
set -euo pipefail
version=4.6.3
root="${RUNNER_TEMP:-/tmp}/starrun-ios-godot-$version"
mkdir -p "$root"
base="https://github.com/godotengine/godot/releases/download/$version-stable"
if [[ ! -f "$root/Godot.app/Contents/MacOS/Godot" ]]; then
  curl --fail --location --retry 3 "$base/Godot_v$version-stable_macos.universal.zip" -o "$root/engine.zip"
  unzip -oq "$root/engine.zip" -d "$root"
fi
godot="$root/Godot.app/Contents/MacOS/Godot"
test -f "$godot"
chmod +x "$godot"
template_dir="$HOME/Library/Application Support/Godot/export_templates/$version.stable"
mkdir -p "$template_dir"
if [[ ! -s "$template_dir/ios.zip" ]]; then
  curl --fail --location --retry 3 "$base/Godot_v$version-stable_export_templates.tpz" -o "$root/templates.tpz"
  unzip -oqj "$root/templates.tpz" 'templates/ios.zip' -d "$template_dir"
fi
test -s "$template_dir/ios.zip"
"$godot" --version
swift tools/generate-ios-icon.swift assets/ios-icon.png
test -s assets/ios-icon.png
mkdir -p build/ios
"$godot" --headless --path . --editor --import --quit
"$godot" --headless --path . --export-release iOS build/ios/StarRun.zip
test -s build/ios/StarRun.zip
unzip -tq build/ios/StarRun.zip
mkdir -p build/ios/xcode
unzip -oq build/ios/StarRun.zip -d build/ios/xcode
project=$(find build/ios/xcode -name '*.xcodeproj' -type d -print -quit)
if [[ -z "$project" ]]; then
  echo "::error::Godot iOS export did not contain an Xcode project"
  find build/ios/xcode -maxdepth 3 -print | head -60
  exit 1
fi
echo "Exported Xcode project: $project"
xcodebuild -list -project "$project"
