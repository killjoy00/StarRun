#!/usr/bin/env bash
# iOS-only outgoing share sheet for Godot 4.6.3. Never loaded by Web/desktop.
# The archive is pinned to the Godot 4.6-compatible Share Plugin v5.2.
set -euo pipefail

cache="${RUNNER_TEMP:-/tmp}/starrun-ios-share"
mkdir -p "$cache"
# The archive hash comes from the publisher's v5.2 release metadata and is
# pinned here. Do not call the unauthenticated GitHub releases API on every CI
# run: shared hosted runners can hit a 403 rate limit before export starts.
python3 - "$cache" <<'PY'
import pathlib
import sys
import urllib.request
import hashlib
import zipfile
import stat

name = "SharePlugin-iOS-v5.2.zip"
url = "https://github.com/godot-mobile-plugins/godot-share/releases/download/v5.2/" + name
expected = "3bcc46dd250532067345812bc03d3e43d4013f3ffe08354217225b0affedb77f"
path = pathlib.Path(sys.argv[1]) / name
if not path.is_file():
    req = urllib.request.Request(url, headers={"User-Agent": "StarRun-iOS-CI"})
    with urllib.request.urlopen(req, timeout=90) as source:
        path.write_bytes(source.read())
actual = hashlib.sha256(path.read_bytes()).hexdigest()
assert actual == expected, "iOS share plugin SHA-256 mismatch"

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
