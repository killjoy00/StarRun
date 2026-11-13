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
"$godot" --headless --path . --editor --import --quit 2>&1 | tee "$root/import.log"
"$godot" --headless --path . --quit-after 10 2>&1 | tee "$root/startup.log"
if grep -Eq "SCRIPT ERROR:|ERROR: Failed to load script" "$root/import.log" "$root/startup.log"; then
  echo "::error::Godot scripts failed to parse; refusing a broken iPhone export"
  exit 1
fi
"$godot" --headless --path . --export-release iOS build/ios/StarRun.zip
# Godot's iOS "project only" mode creates sibling directories rather than a ZIP.
# Keep the Xcode project and payload together, and archive them for CI artifacts.
test -d build/ios/StarRun.xcodeproj
test -d build/ios/StarRun
mkdir -p build/ios/xcode
# Xcode references all generated XCFrameworks relative to the project root.
# Moving only StarRun.xcodeproj and StarRun/ breaks MoltenVK and engine paths.
for generated in build/ios/*; do
  [[ "$generated" == "build/ios/xcode" ]] && continue
  mv "$generated" build/ios/xcode/
done
test -d build/ios/xcode/StarRun.xcodeproj
test -d build/ios/xcode/StarRun
(cd build/ios/xcode && zip -qry ../StarRun.zip .)
test -s build/ios/StarRun.zip
unzip -tq build/ios/StarRun.zip
project=$(find build/ios/xcode -name '*.xcodeproj' -type d -print -quit)
if [[ -z "$project" ]]; then
  echo "::error::Godot iOS export did not contain an Xcode project"
  find build/ios/xcode -maxdepth 3 -print | head -60
  exit 1
fi
echo "Exported Xcode project: $project"
xcodebuild -list -project "$project"
