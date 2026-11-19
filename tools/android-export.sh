#!/usr/bin/env bash
# Generate a signed, Google Play-compatible Android App Bundle from the exact Godot 4.6.3 source.
# Keystores are supplied through environment variables and never committed.
set -euo pipefail
version=4.6.3
template_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version.stable"
work="${RUNNER_TEMP:-/tmp}/starrun-android-export"
mkdir -p "$template_dir" "$work"
base="https://github.com/godotengine/godot/releases/download/$version-stable"

if [[ ! -s "$template_dir/android_source.zip" || ! -s "$template_dir/android_release.apk" || ! -s "$template_dir/android_debug.apk" ]]; then
  curl --fail --location --retry 3 "$base/Godot_v$version-stable_export_templates.tpz" -o "$work/templates.tpz"
  unzip -oqj "$work/templates.tpz" \
    'templates/android_source.zip' 'templates/android_release.apk' 'templates/android_debug.apk' \
    -d "$template_dir"
fi
for artifact in android_source.zip android_release.apk android_debug.apk; do
  test -s "$template_dir/$artifact"
done

: "${JAVA_HOME:?OpenJDK 17 is required}"
: "${ANDROID_HOME:?Android SDK installation is required}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?Release keystore is required}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?Release key alias is required}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?Release key password is required}"
test -f "$ANDROID_HOME/platforms/android-36/android.jar"
test -s "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
test -s assets/icon.svg
grep -Fq 'gradle_build/target_sdk="36"' export_presets.cfg
grep -Fq 'package/unique_name="com.rsm.starrun"' export_presets.cfg
grep -Fq 'gradle_build/export_format=1' export_presets.cfg

# Version overrides apply only to this build's disposable checkout.
if [[ -n "${STARRUN_ANDROID_VERSION_CODE:-}" || -n "${STARRUN_ANDROID_VERSION_NAME:-}" ]]; then
  python3 - <<'PY'
import os
import re
from pathlib import Path

code = os.environ.get("STARRUN_ANDROID_VERSION_CODE", "")
name = os.environ.get("STARRUN_ANDROID_VERSION_NAME", "")
if not code.isdecimal() or not 1 <= int(code) <= 2100000000:
    raise SystemExit("Android release versionCode must be a positive Play-safe integer")
if not re.fullmatch(r"[0-9][A-Za-z0-9.+_-]{0,31}", name):
    raise SystemExit("Android release versionName contains unsupported characters")
path = Path("export_presets.cfg")
head, marker, android = path.read_text().partition("[preset.4.options]")
if not marker:
    raise SystemExit("Android preset is missing")
android, num_codes = re.subn(r"(?m)^version/code=[0-9]+$", f"version/code={code}", android, count=1)
android, num_names = re.subn(r'(?m)^version/name="[^"]*"$', f'version/name="{name}"', android, count=1)
if (num_codes, num_names) != (1, 1):
    raise SystemExit("Android version fields are missing from export preset")
path.write_text(head + marker + android)
print(f"Android versionName={name}, versionCode={code}")
PY
fi

godot --headless --path . --script tools/generate-android-icon.gd
test -s assets/android-icon.png
godot --headless --path . --editor --import --quit 2>&1 | tee "$work/import.log"
godot --headless --path . --quit-after 10 2>&1 | tee "$work/startup.log"
if grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load script' "$work/import.log" "$work/startup.log"; then
  echo "::error::Godot scripts failed to parse; Android export stopped"
  exit 1
fi

mkdir -p build/android
godot --headless --path . --install-android-build-template --export-release Android \
  build/android/StarRun.aab 2>&1 | tee "$work/export.log"
test -s build/android/StarRun.aab
unzip -tq build/android/StarRun.aab
unzip -Z -1 build/android/StarRun.aab | grep -Fqx 'base/manifest/AndroidManifest.xml'
jarsigner -verify build/android/StarRun.aab
echo "Built signed Star/Run Android App Bundle for com.rsm.starrun"
