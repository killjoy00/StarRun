#!/usr/bin/env bash
# iOS-only outgoing share sheet for Godot 4.6.3. Never loaded by Web/desktop.
# The archive is pinned to the Godot 4.6-compatible Share Plugin v5.2.
set -euo pipefail

cache="${RUNNER_TEMP:-/tmp}/starrun-ios-share"
mkdir -p "$cache"
release_api="https://api.github.com/repos/godot-mobile-plugins/godot-share/releases/tags/v5.2"
curl --fail --location --retry 3 -H 'Accept: application/vnd.github+json' \
  "$release_api" -o "$cache/release.json"

python3 - "$cache/release.json" "$cache" <<'PY'
import json
import pathlib
import sys
import urllib.request
import hashlib
import zipfile
import stat

release = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert release.get("tag_name") == "v5.2", "Unexpected share-plugin release"
name = "SharePlugin-iOS-v5.2.zip"
assets = [a for a in release.get("assets", []) if a.get("name") == name]
assert len(assets) == 1, "Missing pinned iOS share archive"
asset = assets[0]
url = asset.get("browser_download_url", "")
assert url == "https://github.com/godot-mobile-plugins/godot-share/releases/download/v5.2/" + name, "Unexpected share archive URL"
expected = asset.get("digest", "")
assert expected.startswith("sha256:") and len(expected) == 71, "Release asset SHA-256 digest not published"
path = pathlib.Path(sys.argv[2]) / name
if not path.is_file():
    req = urllib.request.Request(url, headers={"User-Agent": "StarRun-iOS-CI"})
    with urllib.request.urlopen(req, timeout=90) as source:
        path.write_bytes(source.read())
actual = hashlib.sha256(path.read_bytes()).hexdigest()
assert actual == expected.removeprefix("sha256:"), "iOS share plugin SHA-256 mismatch"

with zipfile.ZipFile(path) as archive:
    names = archive.namelist()
    for info in archive.infolist():
        entry = pathlib.PurePosixPath(info.filename)
        assert not entry.is_absolute() and ".." not in entry.parts and "\\" not in info.filename, "Unsafe share archive entry"
        assert info.filename.startswith(("ios/", "addons/")), f"Unexpected share archive path: {info.filename}"
        assert not stat.S_ISLNK(info.external_attr >> 16), "Symlink forbidden in share archive"
    assert "ios/plugins/SharePlugin.gdip" in names, "Missing native plugin descriptor"
    assert any(p.startswith("ios/plugins/SharePlugin.release.xcframework/") for p in names), "Missing native release library"
    # Extract the iOS-specific binaries only; no Android/editor addon required.
    archive.extractall(".", members=[i for i in archive.infolist() if i.filename.startswith("ios/")])
assert pathlib.Path("ios/plugins/SharePlugin.gdip").is_file()
assert pathlib.Path("ios/plugins/SharePlugin.release.xcframework").is_dir()
print(f"Verified {name} (SHA-256 {actual}) and installed native iOS share sheet")
PY
