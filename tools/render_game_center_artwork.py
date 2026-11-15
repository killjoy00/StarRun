#!/usr/bin/env python3
"""Render deterministic, Apple-compliant 1024×1024 RGB achievement artwork.

Assets stay generated in CI for App Store Connect; no font or binary committed.
"""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
SPEC=json.loads((ROOT/"data/game_center.json").read_text())
DEST=ROOT/"build/game-center-artwork"
DEST.mkdir(parents=True,exist_ok=True)
COLORS={
  "flight":(102,245,223),"boss":(255,192,120),"mastery":(218,149,255),
  "fleet":(100,170,255),"fusion":(255,140,185),"prototype":(175,250,170),
  "tactics":(255,160,125),"daily":(111,211,255),"endless":(190,180,255)
}
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def font(size):
    try: return ImageFont.truetype(FONT,size)
    except OSError: return ImageFont.load_default()
def centered(draw,y,txt,f,color,width=1024):
    bb=draw.textbbox((0,0),txt,font=f)
    draw.text(((width-(bb[2]-bb[0]))/2,y),txt,font=f,fill=color)

for item in SPEC["achievements"]:
    color=COLORS.get(item["icon"],(102,245,223))
    im=Image.new("RGB",(1024,1024),(7,12,25))
    d=ImageDraw.Draw(im)
    d.rounded_rectangle((60,60,964,964),radius=180,outline=color,width=22,fill=(13,29,43))
    d.ellipse((230,150,794,714),outline=(36,69,80),width=5)
    for i in range(12):
        angle=i*math.pi/6
        x=512+340*math.cos(angle);y=447+340*math.sin(angle)
        d.ellipse((x-5,y-5,x+5,y+5),fill=(58,104,124))
    # A stylized ascending starship and amber slash reflect the Star/Run logo.
    d.polygon(((512,214),(702,638),(512,561),(322,638)),fill=(19,73,87))
    d.line([(512,214),(702,638),(512,561),(322,638),(512,214)],fill=color,width=20,joint="curve")
    d.line([(512,317),(512,544)],fill=(235,247,255),width=13)
    d.line([(654,315),(403,690)],fill=(255,192,120),width=30)
    d.ellipse((387,674,419,706),fill=(255,192,120))
    d.ellipse((638,299,670,331),fill=(255,192,120))
    initials="".join(word[0].upper() for word in item["name"].split() if word[0].isalpha())[:3]
    centered(d,674,initials,font(86),color)
    # Two-line-friendly title for 1024px preview cards.
    name=item["name"]
    if len(name)>19:
        words=name.split()
        left=""; right=""
        for word in words:
            if len(left)+len(word)+1 <= 17: left=(left+" "+word).strip()
            else: right=(right+" "+word).strip()
        centered(d,790,left,font(50),(240,246,252))
        centered(d,857,right,font(45),(240,246,252))
    else:
        centered(d,806,name,font(49),(240,246,252))
    centered(d,915,"STAR/RUN · "+str(item["points"])+" PTS",font(24),(154,176,190))
    out=DEST/(item["id"]+".png")
    im.save(out,"PNG",dpi=(72,72),optimize=True)
    assert Image.open(out).size==(1024,1024) and Image.open(out).mode=="RGB"
print(f"GAME CENTER ARTWORK: {len(SPEC['achievements'])} RGB 1024px PNGs in {DEST}")
