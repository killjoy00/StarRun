#!/usr/bin/env bash
set -euo pipefail
# A single pinned engine/template pair for local development and CI.
version=4.6.3
engine_dir="${RUNNER_TEMP:-/tmp}/starrun-godot-$version"
mkdir -p "$engine_dir"
base="https://github.com/godotengine/godot/releases/download/$version-stable"
curl --fail --location --retry 3 "$base/Godot_v$version-stable_linux.x86_64.zip" -o "$engine_dir/engine.zip"
unzip -oq "$engine_dir/engine.zip" -d "$engine_dir"
chmod +x "$engine_dir/Godot_v$version-stable_linux.x86_64"
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$engine_dir" >> "$GITHUB_PATH"
fi
ln -sf "$engine_dir/Godot_v$version-stable_linux.x86_64" "$engine_dir/godot"
if [[ "${1:-}" == "--templates" ]]; then
  curl --fail --location --retry 3 "$base/Godot_v$version-stable_export_templates.tpz" -o "$engine_dir/templates.tpz"
  template_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version.stable"
  mkdir -p "$template_dir"
  unzip -oqj "$engine_dir/templates.tpz" 'templates/web_nothreads_release.zip' 'templates/web_nothreads_debug.zip' 'templates/linux_release.x86_64' 'templates/windows_release_x86_64.exe' -d "$template_dir"
  chmod +x "$template_dir/linux_release.x86_64"
fi
"$engine_dir/godot" --version
