"""Derive a regular 5x5 cell grid per sheet from eroded alpha components.

1. alpha mask (alpha > 128), erode N passes to separate touching pogs
2. label components, keep area >= MIN_AREA, compute centroids
3. cluster centroid xs into 5 columns, ys into 5 rows
4. cell boundaries = midpoints between adjacent cluster means
   (outer bounds 0 / 1024)
5. record which cells actually contain a pog (some sheets have blanks)

Output JSON: {sheet: {"cells": [[x,y,w,h] x25 row-major],
                      "occupied": [bool x25]}}
"""
import json
import os
from PIL import Image

SHEETS = [
    "mom_approved_pog_grid_5x5_revised.png",
    "parental_guidance_pg_pog_grid_5x5.png",
    "questionable_pog_grid_5x5.png",
    "grounded_pog_grid_5x5.png",
    "experimental_pog_grid_5x5.png",
    "banned_pog_grid_5x5.png",
]
ART_DIR = r"C:/Users/danie/Documents/dicerogue/DiceRogue/Resources/Art/Powerups"
OUT = r"C:/Users/danie/Documents/dicerogue/DiceRogue/_pog_work/grid_cells.json"

MIN_AREA = 6000
ERODE_PASSES = 7


def erode(mask, w, h):
    out = bytearray(w * h)
    for y in range(1, h - 1):
        base = y * w
        for x in range(1, w - 1):
            i = base + x
            if mask[i] and mask[i - 1] and mask[i + 1] and mask[i - w] and mask[i + w]:
                out[i] = 1
    return out


def components(eroded, w, h):
    comps = []
    visited = bytearray(w * h)
    for start in range(w * h):
        if not eroded[start] or visited[start]:
            continue
        stack = [start]
        visited[start] = 1
        sx = sy = 0
        n = 0
        while stack:
            i = stack.pop()
            y, x = divmod(i, w)
            sx += x; sy += y; n += 1
            if x > 0:
                j = i - 1
                if eroded[j] and not visited[j]:
                    visited[j] = 1; stack.append(j)
            if x < w - 1:
                j = i + 1
                if eroded[j] and not visited[j]:
                    visited[j] = 1; stack.append(j)
            if y > 0:
                j = i - w
                if eroded[j] and not visited[j]:
                    visited[j] = 1; stack.append(j)
            if y < h - 1:
                j = i + w
                if eroded[j] and not visited[j]:
                    visited[j] = 1; stack.append(j)
        if n >= MIN_AREA:
            comps.append((sx / n, sy / n, n))
    return comps


def cluster(values, k, gap):
    """Sort values, split into k groups at the k-1 largest gaps."""
    vs = sorted(values)
    gaps = sorted(((vs[i + 1] - vs[i], i) for i in range(len(vs) - 1)), reverse=True)
    splits = sorted(i for g, i in gaps[:k - 1] if g > gap)
    assert len(splits) == k - 1, f"could not split into {k} clusters (gaps: {gaps[:k]})"
    groups = []
    prev = 0
    for s in splits:
        groups.append(vs[prev:s + 1])
        prev = s + 1
    groups.append(vs[prev:])
    return groups


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    result = {}
    for name in SHEETS:
        img = Image.open(os.path.join(ART_DIR, name))
        w, h = img.size
        alpha = img.getchannel("A").tobytes()
        mask = bytearray(w * h)
        for i, v in enumerate(alpha):
            if v > 128:
                mask[i] = 1
        eroded = mask
        for _ in range(ERODE_PASSES):
            eroded = erode(eroded, w, h)
        comps = components(eroded, w, h)

        xs = [c[0] for c in comps]
        ys = [c[1] for c in comps]
        col_groups = cluster(xs, 5, 40)
        row_groups = cluster(ys, 5, 40)
        col_means = [sum(g) / len(g) for g in col_groups]
        row_means = [sum(g) / len(g) for g in row_groups]

        xb = [0] + [int((col_means[i] + col_means[i + 1]) / 2) for i in range(4)] + [w]
        yb = [0] + [int((row_means[i] + row_means[i + 1]) / 2) for i in range(4)] + [h]

        cells = []
        occupied = []
        for r in range(5):
            for c in range(5):
                cells.append([xb[c], yb[r], xb[c + 1] - xb[c], yb[r + 1] - yb[r]])
                cx = (xb[c] + xb[c + 1]) / 2
                cy = (yb[r] + yb[r + 1]) / 2
                hit = any(abs(px - cx) < 90 and abs(py - cy) < 90 for px, py, _ in comps)
                occupied.append(hit)

        print(f"{name}: {len(comps)} pogs")
        print(f"  col_means {[int(m) for m in col_means]} xb={xb}")
        print(f"  row_means {[int(m) for m in row_means]} yb={yb}")
        empties = [i for i, o in enumerate(occupied) if not o]
        if empties:
            print(f"  empty cells (row-major idx): {empties}")
        result[name] = {"cells": cells, "occupied": occupied}
    with open(OUT, "w") as f:
        json.dump(result, f, indent=2)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
