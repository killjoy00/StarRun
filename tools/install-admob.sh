#!/usr/bin/env bash
# Install pinned Poing Studios Godot AdMob v5.1.0 for iOS export only.
# Do not install the SDK on Web/Windows/Linux or use real ads before approval.
set -euo pipefail
test_mode="${STARRUN_ADMOB_TEST_MODE:-0}"
config=data/admob.json
test -f "$config"
ids_output="$(python3 - "$config" "$test_mode" <<'PY'
import json, re, sys
c=json.load(open(sys.argv[1]))
if sys.argv[2] == "1" or (c.get("enabled", False) and c.get("test_mode", False)):
    print("ca-app-pub-3940256099942544~1458002511")
    print("ca-app-pub-3940256099942544/2934735716")
    print("test")
    raise SystemExit
if not c.get("enabled",False):
    print("disabled")
    raise SystemExit
app=c.get("app_id","")
banner=c.get("banner_unit_id","")
if not re.fullmatch(r"ca-app-pub-[0-9]{16}~[0-9]{10}",app):
    raise SystemExit("Invalid AdMob iOS App ID. Expected ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX")
if not re.fullmatch(r"ca-app-pub-[0-9]{16}/[0-9]{10}",banner):
    raise SystemExit("Invalid AdMob iOS banner unit ID. Expected ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX")
if app.startswith("ca-app-pub-3940256099942544") or banner.startswith("ca-app-pub-3940256099942544"):
    raise SystemExit("Google sample IDs must not be present in an enabled production configuration")
print(app); print(banner); print("live")
PY
)"
if [[ "$ids_output" == "disabled" ]]; then
  echo "AdMob disabled; exporting unchanged iOS app with no ad SDK."
  exit 0
fi
mode="$(printf '%s\n' "$ids_output" | sed -n '3p')"
if [[ "$mode" != "test" && "$mode" != "live" ]]; then
  echo "Unexpected AdMob config mode" >&2
  exit 1
fi
app_id="$(printf '%s\n' "$ids_output" | sed -n '1p')"
banner_id="$(printf '%s\n' "$ids_output" | sed -n '2p')"
echo "Preparing pinned Godot AdMob SDK for iOS ($mode configuration)."
asset_version=v5.1.0
base="https://github.com/poingstudios/godot-admob-plugin/releases/download/$asset_version"
cache="${RUNNER_TEMP:-/tmp}/starrun-admob-$asset_version"
mkdir -p "$cache"
download_verified() {
  local name="$1" hash="$2"
  if [[ ! -s "$cache/$name" ]]; then
    curl --fail --location --retry 3 "$base/$name" -o "$cache/$name"
  fi
  echo "$hash  $cache/$name" | shasum -a 256 -c -
}
download_verified poing-godot-admob-v5.1.0.zip 8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f
download_verified ios-template-v4.6.3.zip 1943a989353a2a3c609adc7cba47a939e3f6b619f805becd9b5e49eb0d4cc7df
python3 - "$cache" "$app_id" "$banner_id" "$test_mode" <<'PY'
import json, pathlib, sys, zipfile
cache=pathlib.Path(sys.argv[1])
app_id=sys.argv[2]
banner_id=sys.argv[3]
test=sys.argv[4]=="1"
root=pathlib.Path(".")
addon=root/"addons/admob"

def safe_files(archive):
    with zipfile.ZipFile(cache/archive) as z:
        names=[name for name in z.namelist() if not name.endswith("/")]
        print(archive, "files:", len(names), "first:", names[:4])
        for entry in z.infolist():
            parts=pathlib.PurePosixPath(entry.filename).parts
            if (not parts or entry.is_dir()):
                continue
            if ".." in parts or entry.filename.startswith("/") or "\\" in entry.filename:
                raise SystemExit("Unsafe AdMob archive path")
            yield parts, z.read(entry)

addon_entries=0
for parts, content in safe_files("poing-godot-admob-v5.1.0.zip"):
    if "addons" not in parts:
        continue
    idx=parts.index("addons")
    rel=pathlib.Path(*parts[idx:])
    dest=root/rel
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(content)
    addon_entries+=1
if addon_entries < 30 or not (addon/"plugin.cfg").is_file():
    raise SystemExit("AdMob v5.1.0 editor addon missing after extraction")

# Poing v5.1.0 assumes the new Godot SPM method is fully operational.
# Godot 4.6.3 exposes it but does not link GoogleMobileAds/UMP for this
# export. Force the plugin's documented local-Swift-package fallback and
# patch the generated pbxproj synchronously (deferred calls are dropped by
# headless CI at editor shutdown).
exporter = addon/"internal/exporters/ios/export_plugin.gd"
source = exporter.read_text()
conditional = 'if has_method("add_apple_embedded_platform_spm_package"):'
deferred = '_defer_pbxproj_patch.call_deferred(export_dir, path)'
if source.count(conditional)!=1 or source.count(deferred)!=1:
    raise SystemExit("Unexpected Poing v5.1.0 export plugin source; refusing unverified patch")
source = source.replace(conditional, 'if Engine.get_version_info().minor >= 8 and has_method("add_apple_embedded_platform_spm_package"):')
source = source.replace(deferred, '_patch_xcodeproj(export_dir, path)')
exporter.write_text(source)

bin_root=addon/"ios/bin"
native_entries=0
for parts, content in safe_files("ios-template-v4.6.3.zip"):
    # v5.1 native archive has ads/, core/, ump/ plus optional mediation.
    # It is NOT a legacy res://ios/plugins/*.gdip archive.
    rel=pathlib.Path(*parts)
    dest=bin_root/rel
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_bytes(content)
    native_entries+=1
if native_entries < 20 or not (bin_root/"ads").is_dir():
    raise SystemExit("AdMob iOS native ads library missing after extraction")
(bin_root/"package.gd").write_text('const VERSION := "v5.1.0"\n')

project=root/"project.godot"
text=project.read_text()
if '[editor_plugins]' in text:
    # Retain the existing editor plugins (Game Center/Share).
    tag = 'res://addons/admob/plugin.cfg'
    root_index = text.index('[editor_plugins]')
    before, section = text[:root_index], text[root_index:]
    marker = 'enabled=PackedStringArray('
    opening = section.index(marker) + len(marker)
    closing = section.index(')', opening)
    current = section[opening:closing].strip()
    if tag not in current:
        updated = current + (', ' if current else '') + '"' + tag + '"'
        section = section[:opening] + updated + section[closing:]
    text = before + section
else:
    text += '\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/admob/plugin.cfg")\n'
text += '\n[admob]\n\ngeneral/ios/enabled=true\ngeneral/ios/app_id="%s"\n' % app_id
project.write_text(text)

native_source=root/"scripts/admob_native_runtime.gd.txt"
if not native_source.is_file():
    raise SystemExit("Missing reviewed native Star/Run banner runtime template")
(root/"scripts/admob_native_runtime.gd").write_text(native_source.read_text())

if test:
    path=root/"data/admob.json"
    config=json.loads(path.read_text())
    config.update({"enabled":True,"app_id":app_id,"banner_unit_id":banner_id,"test_mode":True})
    path.write_text(json.dumps(config,indent=2)+"\n")
print("Native AdMob iOS v5.1.0 installed:", addon_entries, "addon files,",native_entries,"native files;",
      "using",("Google test IDs" if test else "configured live IDs"),"with consent gate.")
PY
