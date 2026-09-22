#!/usr/bin/env python3
"""Composite the mall store pictograms into the wayfinding atlas.

Input:  tools/_mall_icon_work/cells.json  — {"<cell>": {"url": "<png url>", "name": "<label>"}, ...}
        Downloaded PNGs are cached as tools/_mall_icon_work/cell_XX.png so
        reruns don't re-fetch; delete a cached cell to replace its art.
Output: Resources/Art/UI/mall_store_icons.png — 256x96, 8x4 grid of 32x24
        cells. Each source pictogram is 24x24 and is pasted centered in its
        cell (4px horizontal inset). Cells 0-23 are stores, 24 is the generic
        storefront fallback, 25-31 stay empty.

Cell map (must match MallStoreIcons.STORE_ICONS):
  0 Deb's Department Store (tote bag)   1 Shears (scissors)
  2 Radio Hut Electronics (radio)       3 Tilt! Arcade (joystick)
  4 Pay-less Shoes (shoe)               5 BK Toyz (blocks)
  6 The Intelligent Pet Store (paw)     7 Photo Hut (camera)
  8 Four-Starr Sports Outlet (ball)     9 Hobby Haven (puzzle piece)
  10 Walden Pond Books (book)           11 Roasters Coffee (mug)
  12 Bed Bath and Bodyworks (towel)     13 J-Mart (cart)
  14 Macies Department (paper bag)      15 Downtown Video Rentals (film reel)
  16 Food Court (fork)                  17 Comics-n-more (speech bubble)
  18 Reed's Music Emporium (note)       19 Candy's Confection Store (sweet)
  20 The Hot Topic (flame)              21 KY Jewelry (gem)
  22 Whiteside Cinema (clapper)         23 Furniture Castle Liquidator (armchair)
  24 fallback storefront
"""

import json
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "tools" / "_mall_icon_work"
OUT = ROOT / "Resources" / "Art" / "UI" / "mall_store_icons.png"
GRID = (8, 4)
CELL = (32, 24)
ICON = (24, 24)


def fetch(cell: int, url: str) -> Image.Image:
    cache = WORK / f"cell_{cell:02d}.png"
    if not cache.exists():
        urllib.request.urlretrieve(url, cache)
    img = Image.open(cache).convert("RGBA")
    if img.size != ICON:
        raise SystemExit(f"cell {cell}: expected {ICON}, got {img.size} — fix {cache} by hand")
    return img


def main() -> int:
    cells = json.loads((WORK / "cells.json").read_text())
    atlas = Image.new("RGBA", (GRID[0] * CELL[0], GRID[1] * CELL[1]), (0, 0, 0, 0))
    for key, entry in sorted(cells.items(), key=lambda kv: int(kv[0])):
        cell = int(key)
        img = fetch(cell, entry["url"])
        x = (cell % GRID[0]) * CELL[0] + (CELL[0] - ICON[0]) // 2
        y = (cell // GRID[0]) * CELL[1] + (CELL[1] - ICON[1]) // 2
        atlas.paste(img, (x, y))
        print(f"cell {cell:02d}: {entry.get('name', '?')}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUT)
    print(f"wrote {OUT} ({atlas.size[0]}x{atlas.size[1]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
