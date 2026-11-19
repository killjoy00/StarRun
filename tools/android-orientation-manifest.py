#!/usr/bin/env python3
"""Make portrait an optional Android hardware feature without changing game rotation.

Godot's portrait activity orientation otherwise implicitly filters out devices
whose screen hardware cannot rotate to portrait. Android recommends an explicit
<uses-feature ... android:required="false" /> for nonessential orientations.

Usage:
  python3 tools/android-orientation-manifest.py patch android/build/src/main/AndroidManifest.xml
  python3 tools/android-orientation-manifest.py verify /path/to/bundletool-dumped-AndroidManifest.xml
"""
from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID = "{http://schemas.android.com/apk/res/android}"
NAME = "android.hardware.screen.portrait"
OPTIONAL_DECLARATION = '<uses-feature android:name="android.hardware.screen.portrait" android:required="false" />'


def manifest_root(text: str) -> ET.Element:
    root = ET.fromstring(text)
    if root.tag != "manifest":
        raise ValueError("Expected Android manifest document")
    return root


def portrait_features(root: ET.Element) -> list[ET.Element]:
    return [
        element for element in root.findall("uses-feature")
        if element.get(ANDROID + "name") == NAME
    ]


def verify(text: str, *, check_package: bool) -> None:
    root = manifest_root(text)
    items = portrait_features(root)
    if len(items) != 1 or items[0].get(ANDROID + "required") != "false":
        raise ValueError(
            "Manifest must contain exactly one portrait hardware feature, "
            "explicitly marked android:required=\"false\""
        )
    if check_package:
        if root.get("package") != "com.rsm.starrun":
            raise ValueError(f"Unexpected Android package: {root.get('package')!r}")
        # Godot may set the requested orientation at runtime, so the compiled
        # AndroidManifest is not a reliable source for the in-game orientation.
        # Confirm the Godot project setting itself has not changed instead.
        settings = Path("project.godot").read_text(encoding="utf-8")
        if "window/handheld/orientation=1" not in settings:
            raise ValueError("Star/Run's Godot portrait layout setting changed")
        orientations = [
            activity.get(ANDROID + "screenOrientation")
            for activity in root.findall("./application/activity")
        ]
        print(f"Compiled Android activity orientation attributes: {orientations!r}")
        print("PASS: compiled Star/Run AAB makes portrait hardware optional; "
              "Godot project still requests portrait display")
    else:
        print("PASS: Godot Android source template declares portrait feature optional")


def patch(text: str) -> str:
    root = manifest_root(text)
    if portrait_features(root):
        raise ValueError("Unexpected portrait feature in pristine Godot template; review manually")
    if len(root.findall("application")) != 1:
        raise ValueError("Expected exactly one Android application entry")
    # Edit the human-readable Gradle template without rewriting other Godot
    # placeholders, Android/tools XML namespaces or formatting.
    match = re.search(r"(?m)^(?P<indent>[ \t]*)<application\b", text)
    if match is None:
        raise ValueError("Could not locate Android application in template")
    indentation = match.group("indent")
    updated = (
        text[:match.start()]
        + indentation + OPTIONAL_DECLARATION + "\n\n"
        + text[match.start():]
    )
    verify(updated, check_package=False)
    return updated


def main() -> None:
    if len(sys.argv) != 3 or sys.argv[1] not in {"patch", "verify"}:
        raise SystemExit("Usage: android-orientation-manifest.py patch|verify manifest.xml")
    mode, path = sys.argv[1], Path(sys.argv[2])
    if not path.is_file():
        raise SystemExit(f"Missing Android manifest: {path}")
    content = path.read_text(encoding="utf-8")
    if mode == "patch":
        path.write_text(patch(content), encoding="utf-8")
    else:
        verify(content, check_package=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, ET.ParseError) as error:
        raise SystemExit(f"Android orientation feature validation failed: {error}")
