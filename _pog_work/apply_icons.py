"""Apply pog atlas icons to all PowerUp .tres files.

For each powerup in assignment.json: rewrite the Texture2D ext_resource
(uid + path -> assigned sheet) and the AtlasTexture region (from
grid_cells.json 'tight' rects). ThePiggyBank also gets rating E -> G.
"""
import json
import re
import sys

UIDS = {
    "mom_approved_pog_grid_5x5_revised.png": "uid://c65f3br6a5kwf",
    "parental_guidance_pg_pog_grid_5x5.png": "uid://bybdxd404djbf",
    "questionable_pog_grid_5x5.png": "uid://dqct3k5i3x45l",
    "grounded_pog_grid_5x5.png": "uid://c0y4n53xm2pgx",
    "experimental_pog_grid_5x5.png": "uid://du5rije0h63iw",
    "banned_pog_grid_5x5.png": "uid://dg5pg547mqu30",
}
ART = "res://Resources/Art/Powerups/"

powerups = json.load(open("_pog_work/powerups.json"))
assignment = json.load(open("_pog_work/assignment.json"))
assignment.pop("_comment", None)
grids = json.load(open("_pog_work/grid_cells.json"))

# sanity: every powerup assigned, no sheet+cell reuse
assert set(assignment) == set(powerups), (
    "unassigned: %s, unknown: %s"
    % (set(powerups) - set(assignment), set(assignment) - set(powerups)))
seen = set()
for pid, (sheet, idx) in assignment.items():
    key = (sheet, idx)
    assert key not in seen, f"duplicate use of {key}"
    seen.add(key)
    assert grids[sheet]["tight"][idx] is not None, f"{pid}: empty cell {key}"

changed = 0
for pid, d in powerups.items():
    sheet, idx = assignment[pid]
    x, y, w, h = grids[sheet]["tight"][idx]
    path = d["file"]
    txt = open(path, encoding="utf-8").read()
    orig = txt

    tex_lines = re.findall(r'^\[ext_resource type="Texture2D".*\]$', txt, re.M)
    assert len(tex_lines) == 1, f"{path}: {len(tex_lines)} Texture2D ext_resources"
    new_line = ('[ext_resource type="Texture2D" uid="%s" path="%s%s" %s]'
                % (UIDS[sheet], ART, sheet,
                   re.search(r'id="[^"]*"', tex_lines[0]).group(0)))
    txt = txt.replace(tex_lines[0], new_line)

    new_region = "region = Rect2(%d, %d, %d, %d)" % (x, y, w, h)
    txt, n = re.subn(r"^region = Rect2\(.*\)$", new_region, txt, count=1, flags=re.M)
    assert n == 1, f"{path}: no region line"

    if pid == "the_piggy_bank":
        txt, n = re.subn(r'^rating = "E"$', 'rating = "G"', txt, count=1, flags=re.M)
        assert n == 1, f"{path}: rating E not found"

    if txt != orig:
        open(path, "w", encoding="utf-8", newline="\n").write(txt)
        changed += 1
        print(f"updated {path}: {sheet}[{idx}] -> Rect2({x},{y},{w},{h})")

print(f"\n{changed}/{len(powerups)} files updated")
