#!/usr/bin/env bash
# Native iOS StoreKit 2; never imported on Web/Windows/Linux builds.
# MIT-licensed OpenIAP Godot v4.4.0, exact release SHA-256 from GitHub.
set -euo pipefail
version="4.4.0"
asset="godot-iap-$version.zip"
url="https://github.com/hyodotdev/openiap/releases/download/godot-iap-$version/$asset"
sha="72b8af205cf394aaf8c96bcdb5160b4a0eff722a50bb532dcd68f26691738c58"
folder="$RUNNER_TEMP/starrun-openiap-$version"
mkdir -p "$folder"
if [[ ! -s "$folder/$asset" ]]; then
  curl --fail --location --retry 3 "$url" -o "$folder/$asset"
fi
printf '%s  %s\n' "$sha" "$folder/$asset" | shasum -a 256 -c -
python3 - "$folder/$asset" <<'PY'
import pathlib, sys, zipfile
archive=pathlib.Path(sys.argv[1])
target=pathlib.Path("addons/godot-iap")
with zipfile.ZipFile(archive) as z:
    found=0
    for item in z.infolist():
        parts=pathlib.PurePosixPath(item.filename).parts
        if item.is_dir(): continue
        if not parts or '..' in parts or item.filename.startswith('/') or '\\' in item.filename:
            raise SystemExit('Unsafe OpenIAP archive entry')
        if 'addons' not in parts: continue
        at=parts.index('addons')
        if len(parts)<at+3 or parts[at+1]!='godot-iap': continue
        relative=pathlib.Path(*parts[at+2:])
        dest=target/relative
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(z.read(item))
        found+=1
if found < 15 or not (target/"plugin.cfg").is_file() or not (target/"bin/godot_iap.gdextension").is_file():
    raise SystemExit('Pinned GodotIap plugin package incomplete')
for name in ["GodotIap","SwiftGodotRuntime"]:
    if not (target/"bin/ios"/(name+".framework")/"Info.plist").exists():
        raise SystemExit('Missing signed iOS framework: '+name)
print('Pinned OpenIAP StoreKit 2 installed:',found,'files')
project=pathlib.Path("project.godot")
s=project.read_text()
tag='"res://addons/godot-iap/plugin.cfg"'
start=s.find("enabled=PackedStringArray(",s.find("[editor_plugins]"))
if start < 0: raise SystemExit("Existing Game Center and Share editor plugin section missing")
left=start+len("enabled=PackedStringArray(")
right=s.find(")",left)
if right < 0: raise SystemExit("Bad Godot editor plugin config")
if tag not in s[left:right]:
    current=s[left:right].strip()
    s=s[:left]+current+(", " if current else "")+tag+s[right:]
project.write_text(s)
PY
