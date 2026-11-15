#!/usr/bin/env python3
"""Idempotent Star/Run Game Center setup using existing EZTrivia ASC credentials.

No secrets live in this repository. Run only on the shared credential runner.
Resources are created but NOT submitted for Apple review automatically.
"""
from __future__ import annotations
import datetime as dt
import json
import os
import pathlib
import sys
import time
from urllib.parse import urlparse

import jwt
import requests

BASE = "https://api.appstoreconnect.apple.com/v1"
ROOT = pathlib.Path(__file__).resolve().parents[1]
META = json.loads((ROOT / "data/game_center.json").read_text())

def token():
    key = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    p = pathlib.Path(os.environ["ASC_KEY_PATH"]).expanduser()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"},
        p.read_text(), algorithm="ES256", headers={"kid": key}
    )

class API:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {token()}",
            "Content-Type": "application/json",
        })
    def request(self, method, path, **kwargs):
        response = self.session.request(method, BASE + path, timeout=45, **kwargs)
        if response.status_code >= 300:
            raise RuntimeError(f"{method} {path} HTTP {response.status_code}: {response.text[:1200]}")
        return response.json() if response.content else {}
    def get_all(self,path,**params):
        collected = []
        url = BASE+path
        while url:
            response = self.session.get(url,params=params,timeout=45)
            if response.status_code >= 300:
                raise RuntimeError(f"GET {path} HTTP {response.status_code}: {response.text[:1200]}")
            data = response.json()
            collected.extend(data.get("data",[]))
            url = data.get("links",{}).get("next")
            params = {}
        return collected

def link(t,id):
    return {"data":{"type":t,"id":id}}

def ensure_detail(api, app):
    appid = app["id"]
    detail = api.request("GET",f"/apps/{appid}/gameCenterDetail").get("data")
    if detail:
        print("Game Center detail already enabled")
        return detail["id"]
    body = {"data":{"type":"gameCenterDetails",
                    "relationships":{"app":link("apps",appid)}}}
    detail = api.request("POST","/gameCenterDetails",json=body)["data"]
    print("Enabled App Store Connect Game Center detail")
    return detail["id"]

def ensure_board(api, detail):
    spec = META["leaderboard"]
    existing = api.get_all(f"/gameCenterDetails/{detail}/gameCenterLeaderboards")
    found = next((x for x in existing if x["attributes"].get("vendorIdentifier") == spec["id"]),None)
    if found:
        attrs = found["attributes"]
        if attrs.get("recurrenceRule") != spec["recurrence"] or attrs.get("recurrenceDuration") != spec["duration"]:
            raise RuntimeError("Daily Game Center board exists with non-daily reset rules; refusing incompatible reuse")
        print("Recurring UTC Daily leaderboard exists:",spec["id"])
    else:
        # Apple's recurring periods cannot begin in the past. Start at the
        # next midnight UTC; this matches the client's UTC seed boundaries.
        future = dt.datetime.now(dt.timezone.utc).date() + dt.timedelta(days=1)
        first = f"{future.isoformat()}T00:00:00Z"
        attrs = {
            "referenceName":spec["name"],"vendorIdentifier":spec["id"],
            "defaultFormatter":"INTEGER",
            "submissionType":"BEST_SCORE","scoreSortType":"DESC",
            "scoreRangeStart":"0","scoreRangeEnd":str(spec["score_max"]),
            "recurrenceStartDate":first,
            "recurrenceDuration":spec["duration"],"recurrenceRule":spec["recurrence"]
        }
        body={"data":{"type":"gameCenterLeaderboards","attributes":attrs,
                      "relationships":{"gameCenterDetail":link("gameCenterDetails",detail)}}}
        found=api.request("POST","/gameCenterLeaderboards",json=body)["data"]
        print("Created recurring UTC leaderboard:",spec["id"],"starting",first)
    loc = api.get_all(f"/gameCenterLeaderboards/{found['id']}/localizations")
    if not any(x["attributes"].get("locale")=="en-US" for x in loc):
        payload={"data":{"type":"gameCenterLeaderboardLocalizations",
                         "attributes":{"locale":"en-US","name":spec["name"],
                                       "description":"Today's shared UTC run. Highest score wins."},
                         "relationships":{"gameCenterLeaderboard":link("gameCenterLeaderboards",found["id"])}}}
        api.request("POST","/gameCenterLeaderboardLocalizations",json=payload)
        print("Created Daily en-US localization")
    return found["id"]


def ensure_badge_image(api, localization_id, achievement_id):
    """Reserve, upload, and commit the localized Apple Game Center PNG."""
    image_path = ROOT / "build/game-center-artwork" / (achievement_id + ".png")
    if not image_path.is_file():
        raise RuntimeError(f"Required Apple achievement artwork missing: {image_path}")
    data = image_path.read_bytes()
    related = f"/gameCenterAchievementLocalizations/{localization_id}/gameCenterAchievementImage"
    response = api.session.get(BASE + related, timeout=45)
    if response.status_code == 200:
        existing = response.json().get("data")
    elif response.status_code == 404:
        existing = None
    else:
        raise RuntimeError(f"Read localized Game Center badge failed: HTTP {response.status_code}: {response.text[:500]}")
    if existing:
        state = existing.get("attributes",{}).get("assetDeliveryState",{})
        status = state.get("state","unknown") if isinstance(state,dict) else str(state)
        print(f"Achievement image already registered for {achievement_id}: {status}")
        return
    payload = {
        "data":{
            "type":"gameCenterAchievementImages",
            "attributes":{"fileSize":len(data),"fileName":image_path.name},
            "relationships":{"gameCenterAchievementLocalization":link("gameCenterAchievementLocalizations",localization_id)}
        }
    }
    item = api.request("POST","/gameCenterAchievementImages",json=payload)["data"]
    operations = item.get("attributes",{}).get("uploadOperations",[])
    if not operations:
        item = api.request("GET",f"/gameCenterAchievementImages/{item['id']}")["data"]
        operations = item.get("attributes",{}).get("uploadOperations",[])
    if not operations:
        raise RuntimeError(f"Apple did not return upload operations for achievement badge {achievement_id}")
    for operation in operations:
        url = operation.get("url","")
        parsed = urlparse(url)
        # URLs are minted by Apple, but must never include a plain HTTP URL
        # or an attacker-controlled inline credential before uploading bytes.
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
            raise RuntimeError("Unsafe Apple asset upload URL")
        offset = int(operation.get("offset",0))
        length = int(operation.get("length",len(data)-offset))
        if offset < 0 or length <= 0 or offset + length > len(data):
            raise RuntimeError(f"Invalid asset chunk for badge {achievement_id}")
        headers = {h["name"]:h["value"] for h in operation.get("requestHeaders",[])}
        upload = requests.request(operation.get("method","PUT"),url,
                                  data=data[offset:offset+length],headers=headers,timeout=75)
        if upload.status_code >= 300:
            raise RuntimeError(f"Apple image upload failed for {achievement_id}: HTTP {upload.status_code}: {upload.text[:500]}")
    api.request("PATCH",f"/gameCenterAchievementImages/{item['id']}",json={
        "data":{"type":"gameCenterAchievementImages","id":item["id"],"attributes":{"uploaded":True}}
    })
    print(f"Uploaded Apple-compliant 1024px RGB achievement image: {achievement_id}")

def ensure_achievements(api, detail):
    configured = api.get_all(f"/gameCenterDetails/{detail}/gameCenterAchievements")
    lookup = {x["attributes"].get("vendorIdentifier"):x for x in configured}
    for spec in META["achievements"]:
        vendor = "com.rsm.starrun."+spec["id"]
        entry = lookup.get(vendor)
        if entry is None:
            payload = {"data":{"type":"gameCenterAchievements",
                               "attributes":{"referenceName":spec["name"],"vendorIdentifier":vendor,
                                             "points":int(spec["points"]),"repeatable":False,
                                             "showBeforeEarned":True},
                               "relationships":{"gameCenterDetail":link("gameCenterDetails",detail)}}}
            entry=api.request("POST","/gameCenterAchievements",json=payload)["data"]
            print("Created Apple achievement:",vendor)
        else:
            if int(entry["attributes"].get("points",-1)) != int(spec["points"]):
                raise RuntimeError("Existing Apple achievement has mismatched permanent points: "+vendor)
            print("Apple achievement already exists:",vendor)
        loc = api.get_all(f"/gameCenterAchievements/{entry['id']}/localizations")
        localization = next((x for x in loc if x["attributes"].get("locale")=="en-US"),None)
        if localization is None:
            body={"data":{"type":"gameCenterAchievementLocalizations",
                          "attributes":{"locale":"en-US","name":spec["name"],
                                        "beforeEarnedDescription":spec["description"],
                                        "afterEarnedDescription":"Completed: "+spec["description"]},
                          "relationships":{"gameCenterAchievement":link("gameCenterAchievements",entry["id"])}}}
            localization = api.request("POST","/gameCenterAchievementLocalizations",json=body)["data"]
            print("  Added en-US achievement localization")
        ensure_badge_image(api,localization["id"],spec["id"])
    return len(META["achievements"])

def main():
    entries=META["achievements"]
    assert len(entries)==17 and len({x["id"] for x in entries})==17
    assert max(x["points"] for x in entries)<=100 and sum(x["points"] for x in entries)<=1000
    api=API()
    apps=api.get_all("/apps",**{"filter[bundleId]":META["app_bundle"]})
    if len(apps)!=1:
        raise RuntimeError(f"Expected exactly one App Store Connect app for {META['app_bundle']}; found {len(apps)}")
    detail=ensure_detail(api,apps[0])
    ensure_board(api,detail)
    count=ensure_achievements(api,detail)
    print(f"Configured {count} Apple achievement definitions, one recurring UTC Daily board.")
    print("NEXT: Apple metadata review/publication and physical-device Game Center testing remain separate gates.")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Game Center provisioning halted: {exc}",file=sys.stderr)
        sys.exit(1)
