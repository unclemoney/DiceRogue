"""Apply coupon atlas icons to all Consumable .tres files.

For each consumable in assignment.json:
  - rewrite the Texture2D ext_resource (uid + path -> assigned sheet, keep id)
  - bump load_steps by 1
  - insert an AtlasTexture sub_resource with the cell region from regions.json
  - point `icon` at the sub-resource

Run from the project root:  python _coupon_work/apply_coupon_icons.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(ROOT)
CONS_DIR = os.path.join(PROJ, "Scripts", "Consumable")

UIDS = {
    "Sunday_Coupon_Sheet_5x5_Generic.png": "uid://dg6pm7i6if501",
    "Sunday_Coupon_Sheet_5x5_Hardware.png": "uid://dwlo8ieu7vgo0",
}
ART = "res://Resources/Art/Consumables/"

assignment = json.load(open(os.path.join(ROOT, "assignment.json"), encoding="utf-8"))
assignment.pop("_comment", None)
regions = json.load(open(os.path.join(ROOT, "regions.json"), encoding="utf-8"))

# sanity: no sheet+cell reuse, all regions present
seen = set()
for cid, (sheet, idx) in assignment.items():
    key = (sheet, idx)
    assert key not in seen, "duplicate use of %s" % (key,)
    seen.add(key)
    assert regions[sheet]["regions"][idx], "%s: empty region %s" % (cid, key)

files = [f for f in os.listdir(CONS_DIR) if f.endswith(".tres")]
assert files, "no .tres files found in %s" % CONS_DIR

changed = 0
covered = set()
for fname in sorted(files):
    path = os.path.join(CONS_DIR, fname)
    txt = open(path, encoding="utf-8").read()
    orig = txt

    m = re.search(r'^id = "([^"]+)"$', txt, re.M)
    assert m, "%s: no resource id" % fname
    cid = m.group(1)
    if cid not in assignment:
        print("SKIP %s (id %s not in assignment)" % (fname, cid))
        continue
    covered.add(cid)
    sheet, idx = assignment[cid]
    x, y, w, h = regions[sheet]["regions"][idx]

    tex_lines = re.findall(r'^\[ext_resource type="Texture2D".*\]$', txt, re.M)
    assert len(tex_lines) == 1, "%s: %d Texture2D ext_resources" % (fname, len(tex_lines))
    tex_id = re.findall(r'\bid="([^"]*)"', tex_lines[0])[-1]
    new_line = '[ext_resource type="Texture2D" uid="%s" path="%s%s" id="%s"]' % (
        UIDS[sheet], ART, sheet, tex_id)
    txt = txt.replace(tex_lines[0], new_line)

    sub_id = "AtlasTexture_c%02d" % idx if sheet.endswith("Generic.png") else "AtlasTexture_h%02d" % idx
    if "[sub_resource" in txt:
        # already converted: update the region in place, nothing else
        txt, n = re.subn(r"^region = Rect2\(.*\)$",
                         "region = Rect2(%d, %d, %d, %d)" % (x, y, w, h),
                         txt, count=1, flags=re.M)
        assert n == 1, "%s: no region line" % fname
    else:
        # bump load_steps
        def bump(match):
            return "load_steps=%d" % (int(match.group(1)) + 1)
        txt, n = re.subn(r"load_steps=(\d+)", bump, txt, count=1)
        assert n == 1, "%s: no load_steps" % fname

        # insert AtlasTexture sub_resource before [resource]
        sub_block = ('[sub_resource type="AtlasTexture" id="%s"]\n'
                     'atlas = ExtResource("%s")\n'
                     'region = Rect2(%d, %d, %d, %d)\n\n' % (sub_id, tex_id, x, y, w, h))
        txt = txt.replace("[resource]", sub_block + "[resource]", 1)

        # repoint icon
        txt, n = re.subn(r'^icon = ExtResource\("[^"]*"\)$',
                         'icon = SubResource("%s")' % sub_id, txt, count=1, flags=re.M)
        assert n == 1, "%s: no icon line" % fname

    if txt != orig:
        open(path, "w", encoding="utf-8", newline="\n").write(txt)
        changed += 1
        print("updated %s: %s -> %s[%d] Rect2(%d,%d,%d,%d)" % (fname, cid, sheet, idx, x, y, w, h))

missing = set(assignment) - covered
assert not missing, "assignment ids with no tres file: %s" % missing
print("\n%d/%d files updated" % (changed, len(files)))
