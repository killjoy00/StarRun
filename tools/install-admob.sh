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
if sys.argv[2] == "1":
    print("ca-app-pub-3940256099942544~1458002511")
    print("ca-app-pub-3940256099942544/2934735716")
    print("test")
    raise SystemExit
if not c.get("enabled",False):
    print("")
    print("")
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
mode="$(printf '%s\n' "$ids_output" | sed -n '3p')"
if [[ "$mode" == "disabled" ]]; then
  echo "AdMob disabled; exporting unchanged iOS app with no ad SDK."
  exit 0
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
import configparser, json, pathlib, re, sys, zipfile
cache=pathlib.Path(sys.argv[1]); app_id=sys.argv[2]; banner_id=sys.argv[3]; test=sys.argv[4]=="1"
root=pathlib.Path(".")
def unpack(archive, target, prefix=None):
    with zipfile.ZipFile(cache/archive) as z:
        contents=[n for n in z.namelist() if not n.endswith("/")]
        print(archive, "entries:", len(contents), "sample:", contents[:8])
        for info in z.infolist():
            parts=pathlib.PurePosixPath(info.filename).parts
            if not parts or info.is_dir() or ".." in parts or info.filename.startswith("/") or "\\" in info.filename:
                if ".." in parts or info.filename.startswith("/") or "\\" in info.filename:
                    raise SystemExit("Unsafe AdMob SDK zip entry: " + info.filename)
                continue
            rel=pathlib.Path(*parts)
            if prefix and rel.parts[0]==prefix:
                rel=pathlib.Path(*rel.parts[1:])
            if not rel.parts: continue
            destination=target/rel
            destination.parent.mkdir(parents=True,exist_ok=True)
            destination.write_bytes(z.read(info))
unpack("poing-godot-admob-v5.1.0.zip",root)
unpack("ios-template-v4.6.3.zip",root/"ios/plugins")
gdips=list((root/"ios/plugins").rglob("*.gdip"))
if not gdips:
    raise SystemExit("Poing iOS template did not contain a .gdip (check release asset layout)")
print("AdMob GDIP:",[str(x) for x in gdips])
admob=[p for p in gdips if "admob" in p.name.lower() and "ads" in p.name.lower()]
if not admob:
    raise SystemExit("No AdMob ads .gdip found")
gdip=admob[0]
text=gdip.read_text()
sample=re.findall(r"ca-app-pub-[0-9]{16}~[0-9]{10}",text)
if not sample:
    raise SystemExit("AdMob .gdip missing Google AdMob App ID slot; refusing to export unconfigured SDK")
text=re.sub(r"ca-app-pub-[0-9]{16}~[0-9]{10}",app_id,text)
gdip.write_text(text)
config=configparser.ConfigParser(interpolation=None)
config.read_string(text)
plugin_name=config.get("config","name",fallback="")
if not plugin_name:
    raise SystemExit("AdMob .gdip missing plugin name")
preset=root/"export_presets.cfg"
source=preset.read_text()
if "[preset.3.options]" not in source:
    raise SystemExit("Missing iOS export preset")
key="plugins/"+plugin_name+"="
if key in source:
    source=re.sub(r"(?m)^"+re.escape(key)+r".*$",key+"true",source)
else:
    source=source.rstrip()+"\n"+key+"true\n"
preset.write_text(source)
if test:
    path=root/"data/admob.json"
    c=json.loads(path.read_text())
    c.update({"enabled":True,"app_id":app_id,"banner_unit_id":banner_id,"test_mode":True})
    path.write_text(json.dumps(c,indent=2)+"\n")
print("Enabled signed iOS export plugin",plugin_name,"with",("test" if test else "live"),"configuration")
PY
