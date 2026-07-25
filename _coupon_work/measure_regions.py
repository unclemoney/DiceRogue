"""Measure per-cell coupon bounding boxes in the two 5x5 coupon sheets.

Structure discovered by profiling (both 2048x2048 sheets):
  - Coupons are NOT centered on a 409.6px grid: column pitch ~385px,
    per-cell measurement is required.
  - Dashed borders are thin (2-3px) lines; product art forms wide runs.
  - Blank band under the top border contains only the vertical borders.
  - Horizontal cut lines (with scissors) can out-peak the coupon's own
    top border, so the top border is picked by expected distance from
    the (reliably detected) bottom border.

Output:
  _coupon_work/regions.json  {sheet: {"regions": [[x,y,w,h] x25 row-major],
                                      "bands":  [[0, frac] x25]}}
  _coupon_work/preview_<sheet>  1024px preview, red=region, blue=title band
"""
import json
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(ROOT)
ART = os.path.join(PROJ, "Resources", "Art", "Consumables")
SHEETS = [
    "Sunday_Coupon_Sheet_5x5_Generic.png",
    "Sunday_Coupon_Sheet_5x5_Hardware.png",
]
DARK = 110          # luminance threshold for "dark" pixels
CELL = 2048 / 5.0   # 409.6 nominal pitch
EXPECTED_H = 345    # expected coupon height (px)
MARGIN_SIDE = 8     # px of paper kept around the dashed border (left/right)
MARGIN_TOP = 12     # extra at top so the scissors aren't clipped
MARGIN_BOTTOM = 8


def load_mask(path):
    img = Image.open(path).convert("L")
    w, h = img.size
    px = img.load()
    mask = bytearray(w * h)
    for y in range(h):
        base = y * w
        for x in range(w):
            if px[x, y] < DARK:
                mask[base + x] = 1
    return mask, w, h


def col_count(mask, w, x, y0, y1):
    c = 0
    for y in range(y0, y1):
        c += mask[y * w + x]
    return c


def row_count(mask, w, y, x0, x1):
    base = y * w
    c = 0
    for x in range(x0, x1):
        c += mask[base + x]
    return c


def thin_runs(mask, w, x0, x1, y0, y1, min_count, max_width=5):
    """Runs of columns each with >= min_count dark pixels; keep runs whose
    total width <= max_width (borders are thin; art is wide)."""
    runs = []
    run_start = None
    run_max = 0
    for x in range(x0, x1):
        c = col_count(mask, w, x, y0, y1)
        if c >= min_count:
            if run_start is None:
                run_start = x
                run_max = c
            else:
                run_max = max(run_max, c)
        else:
            if run_start is not None:
                runs.append((run_start, x - 1, run_max))
                run_start = None
    if run_start is not None:
        runs.append((run_start, x1 - 1, run_max))
    return [(a, b, c) for a, b, c in runs if b - a + 1 <= max_width]


def measure_cell_edges(mask, w, h):
    """Returns (tops, bottoms, lefts, rights): per-row/col border coords.
    tops/bottoms are per-cell (5x5); lefts/rights are per-column (5)."""
    cw = int(round(CELL))
    tops = [[None] * 5 for _ in range(5)]
    bottoms = [[None] * 5 for _ in range(5)]
    left_votes = [[] for _ in range(5)]
    right_votes = [[] for _ in range(5)]

    for row in range(5):
        for col in range(5):
            cx0 = int(round(col * CELL))
            cy0 = int(round(row * CELL))
            hx0 = cx0 + int(cw * 0.15)
            hx1 = cx0 + int(cw * 0.90)

            best, bottom = -1, None
            for y in range(cy0 + int(cw * 0.80), min(cy0 + int(cw * 1.02), h)):
                c = row_count(mask, w, y, hx0, hx1)
                if c > best:
                    best, bottom = c, y
            cands = []
            thresh = int((hx1 - hx0) * 0.30)
            for y in range(max(bottom - 430, 0), bottom - 260):
                if row_count(mask, w, y, hx0, hx1) >= thresh:
                    cands.append(y)
            if not cands:
                raise RuntimeError("cell (%d,%d): no top candidates" % (col, row))
            top = min(cands, key=lambda y: abs((bottom - y) - EXPECTED_H))
            tops[row][col] = top
            bottoms[row][col] = bottom

            sy0 = top + max(6, int((bottom - top) * 0.05))
            sy1 = sy0 + int((bottom - top) * 0.16)
            min_count = max(5, int((sy1 - sy0) * 0.20))

            for a, b, _c in thin_runs(mask, w, max(cx0 - 70, 0), min(cx0 + 160, w),
                                      sy0, sy1, min_count):
                left_votes[col].append((a + b) // 2)
            for a, b, _c in thin_runs(mask, w, cx0 + int(cw * 0.70),
                                      min(cx0 + int(cw * 1.25), w),
                                      sy0, sy1, min_count):
                right_votes[col].append((a + b) // 2)

    def consensus(votes, expected):
        # cluster votes within +-4px; return center of biggest cluster
        clusters = []
        for v in sorted(votes):
            if clusters and v - clusters[-1][-1] <= 8:
                clusters[-1].append(v)
            else:
                clusters.append([v])
        clusters.sort(key=len, reverse=True)
        best_cluster = clusters[0]
        return sum(best_cluster) // len(best_cluster)

    rights = [consensus(right_votes[c], 0) for c in range(5)]
    # own left border always sits a few px right of the previous coupon's
    # right border — filter those votes out before taking consensus
    lefts = []
    for c in range(5):
        votes = left_votes[c]
        if c > 0:
            votes = [v for v in votes if v > rights[c - 1] + 8]
        lefts.append(consensus(votes, 0))

    # Pass C: re-detect top/bottom per cell by tracing the vertical dashed
    # borders (which span the full coupon height). The nominal-grid heuristic
    # above drifts on the bottom row, latching onto the inner title separator
    # and the sheet's paper edge; the vertical dashes don't lie.
    for row in range(5):
        for col in range(5):
            new_top, new_bottom = vertical_edges(mask, w, h, col, row,
                                                 lefts[col], rights[col])
            old_top, old_bottom = tops[row][col], bottoms[row][col]
            if new_top is not None and new_bottom is not None \
                    and 290 <= new_bottom - new_top <= 430:
                tops[row][col] = new_top
                bottoms[row][col] = new_bottom
            else:
                print("  warn cell(%d,%d): vertical trace failed (%s,%s), keeping (%d,%d)"
                      % (col, row, new_top, new_bottom, old_top, old_bottom))
    return tops, bottoms, lefts, rights


def _col_any(mask, w, x, y):
    base = y * w + x
    return (mask[base - 3] or mask[base - 2] or mask[base - 1] or mask[base]
            or mask[base + 1] or mask[base + 2] or mask[base + 3])


def vertical_edges(mask, w, h, col, row, left, right):
    """Trace the left/right dashed borders to find the coupon's vertical
    extent, then snap to the nearest strong horizontal border rows."""
    cw = int(round(CELL))
    cx0 = int(round(col * CELL))
    cy0 = int(round(row * CELL))
    hx0 = cx0 + int(cw * 0.15)
    hx1 = cx0 + int(cw * 0.90)
    y0 = max(cy0 - int(cw * 0.30), 0)
    y1 = min(cy0 + int(cw * 1.10), h)

    # top: first dark at the left border column after a >=25px empty gap
    # (vertical dashes have small gaps; the paper between coupons is wide)
    top_est = None
    empty = 0
    for y in range(y0, y1):
        if _col_any(mask, w, left, y):
            if empty >= 25:
                top_est = y
                break
            empty = 0
        else:
            empty += 1
    # bottom: same scanning upward from the sheet bottom area
    bottom_est = None
    empty = 0
    for y in range(y1 - 1, y0, -1):
        if _col_any(mask, w, right, y):
            if empty >= 25:
                bottom_est = y
                break
            empty = 0
        else:
            empty += 1
    if top_est is None or bottom_est is None:
        return None, None

    # snap to the nearest strong horizontal dashed border (+-14px)
    def snap(y_est):
        best, best_y = -1, None
        for yy in range(max(y_est - 14, 0), min(y_est + 15, h)):
            c = row_count(mask, w, yy, hx0, hx1)
            if c > best:
                best, best_y = c, yy
        return best_y

    return snap(top_est), snap(bottom_est)


def measure_band(mask, w, hx0, hx1, top, bottom):
    """First content row below the top border -> title band bottom."""
    band_bottom = None
    bthresh = max(6, int((hx1 - hx0) * 0.06))
    run = 0
    for y in range(top + 6, bottom - 4):
        c = row_count(mask, w, y, hx0, hx1)
        if c > bthresh:
            run += 1
            if run >= 3:
                band_bottom = y - 2
                break
        else:
            run = 0
    if band_bottom is None:
        band_bottom = top + int((bottom - top) * 0.25)
    return band_bottom


def main():
    out = {}
    for sheet in SHEETS:
        path = os.path.join(ART, sheet)
        mask, w, h = load_mask(path)
        cw = int(round(CELL))
        tops, bottoms, lefts, rights = measure_cell_edges(mask, w, h)
        print(sheet)
        print("  lefts :", lefts)
        print("  rights:", rights)
        regions, bands = [], []
        for row in range(5):
            for col in range(5):
                top = tops[row][col]
                bottom = bottoms[row][col]
                left = lefts[col]
                right = rights[col]
                hx0 = int(round(col * CELL)) + int(cw * 0.15)
                hx1 = int(round(col * CELL)) + int(cw * 0.90)
                bb = measure_band(mask, w, hx0, hx1, top, bottom)
                bands.append([0.0, (bb - top) / float(bottom - top + 1)])
                # margin around the dashed border: keeps the scissors at the
                # top and gives the border breathing room (clamped to sheet)
                rx = max(left - MARGIN_SIDE, 0)
                ry = max(top - MARGIN_TOP, 0)
                rr = min(right + MARGIN_SIDE, w - 1)
                rb = min(bottom + MARGIN_BOTTOM, h - 1)
                regions.append([rx, ry, rr - rx + 1, rb - ry + 1])
        out[sheet] = {"regions": regions, "bands": bands}

        img = Image.open(path).convert("RGB")
        small = img.resize((1024, 1024))
        draw = ImageDraw.Draw(small)
        s = 1024 / 2048.0
        for reg, band in zip(regions, bands):
            x, y, rw, rh = [v * s for v in reg]
            draw.rectangle([x, y, x + rw, y + rh], outline=(255, 0, 0), width=2)
            bh = rh * band[1]
            draw.rectangle([x, y, x + rw, y + bh], outline=(0, 80, 255), width=2)
        prev = os.path.join(ROOT, "preview_" + sheet)
        small.save(prev)
        print("wrote", prev)

    with open(os.path.join(ROOT, "regions.json"), "w") as f:
        json.dump(out, f, indent=1)
    for sheet in SHEETS:
        regs = out[sheet]["regions"]
        ws = [r[2] for r in regs]
        hs = [r[3] for r in regs]
        bts = [b[1] for b in out[sheet]["bands"]]
        print(sheet)
        print("  w range %d-%d  h range %d-%d" % (min(ws), max(ws), min(hs), max(hs)))
        print("  band-bottom frac min %.2f max %.2f avg %.2f"
              % (min(bts), max(bts), sum(bts) / len(bts)))


if __name__ == "__main__":
    main()
