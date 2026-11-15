#!/usr/bin/env bash
# Install only on macOS iOS export jobs, never in generic Linux/Web exports.
# Pinned public release + GitHub-published SHA-256; no unreviewed latest zip.
set -euo pipefail
source_url="https://github.com/keremvatandas/godot-ios-gamecenter/releases/download/v1.0.1/gamecenter-addon.zip"
digest="b27db4e3192d6fa07ec33b6af8d109d6ee4dab5a0b4b0895d23dd5f26e50b92f"
cache="${RUNNER_TEMP:-/tmp}/starrun-gamecenter"
mkdir -p "$cache"
archive="$cache/gamecenter-addon-v1.0.1.zip"
if [[ ! -s "$archive" ]]; then
  curl --fail --location --retry 3 "$source_url" -o "$archive"
fi
printf '%s  %s\n' "$digest" "$archive" | shasum -a 256 -c -
python3 - "$archive" <<'PY'
import pathlib, sys, zipfile
zip_path = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(zip_path) as archive:
    for member in archive.namelist():
        normalized = pathlib.PurePosixPath(member)
        if normalized.is_absolute() or '..' in normalized.parts:
            raise SystemExit(f"Unsafe path in pinned GameCenterKit archive: {member}")
        if not member.startswith("addons/gamecenter/"):
            raise SystemExit(f"Unexpected GameCenterKit package path: {member}")
    archive.extractall(".")
assert pathlib.Path("addons/gamecenter/plugin.cfg").is_file()
assert pathlib.Path("addons/gamecenter/gamecenter.gdextension").is_file()
assert pathlib.Path("addons/gamecenter/bin/libgamecenter.ios.xcframework").is_dir()
PY
# This change is only in the CI checkout. Linux/Windows/Web never load a
# macOS/iOS GDExtension because the addon is absent on those builders.
python3 - <<'PY'
from pathlib import Path
project = Path("project.godot")
s = project.read_text()
section = '[editor_plugins]\n\nenabled=PackedStringArray("res://addons/gamecenter/plugin.cfg")\n'
if "[editor_plugins]" in s:
    raise SystemExit("Game Center install expected no pre-existing editor_plugins section")
project.write_text(s.rstrip() + "\n\n" + section)
PY
echo "Pinned GameCenterKit v1.0.1 installed for iOS export only"
