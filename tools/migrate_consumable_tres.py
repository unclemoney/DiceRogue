"""One-off migration: ConsumableData required/excluded_dice_sides -> allowed_dice_sets,
plus usage_window / usage_conditions assignment per the approved refactor plan."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIR = ROOT / "Scripts" / "Consumable"

# id -> allowed_dice_sets list (only non-default)
ALLOWED = {
    "evens_upgrade": [4],
    "odds_upgrade": [4],
    "even_odd_full_house_upgrade": [4],
    "fives_upgrade": [6],
    "sixes_upgrade": [6],
    "large_straight_upgrade": [6],
}

# id -> usage_window int (ANY_TIME=0 default omitted, BEFORE_ROLL_INITIATED=1,
# DURING_ACTIVE_ROUND=2, AFTER_SCORING=3)
WINDOW = {
    "go_broke_or_go_home": 1,
    "paint_job": 2,
    "mulligan": 2,
    "loaded_dice": 2,
    "any_score": 2,
    "empty_shelves": 2,
    "green_envy": 2,
    "score_reroll": 2,
    "visit_the_shop": 3,
}

# id -> usage_conditions (only non-empty)
CONDITIONS = {
    "go_broke_or_go_home": ["open_lower_category"],
    "one_free_mod": ["mod_slot_free"],
    "antidote": ["has_active_debuff"],
    "spite": ["has_active_debuff"],
    "scratch_ticket": ["last_score_zero"],
    "mulligan": ["dice_rolled", "has_placed_score"],
    "loaded_dice": ["dice_rolled"],
    "score_reroll": ["dice_rolled", "has_placed_score"],
    "double_existing": ["has_placed_score"],
    "any_score": ["dice_rolled", "open_category"],
    "double_or_nothing": ["rolls_at_turn_start"],
    "paint_job": ["dice_rolled"],
    "empty_shelves": ["dice_rolled"],
    "green_envy": ["dice_rolled"],
    "the_pawn_shop": ["has_powerups"],
    "random_power_up_uncommon": ["powerup_slot_free"],
}

DROP_RE = re.compile(r"^(required_dice_sides|excluded_dice_sides) = .*$")

def migrate(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8")
    m = re.search(r'^id = "([^"]+)"', text, re.M)
    if not m:
        return "SKIP (no id)"
    cid = m.group(1)
    lines = text.splitlines()
    out = []
    dropped = 0
    for line in lines:
        if DROP_RE.match(line.strip()):
            dropped += 1
            continue
        out.append(line)
        if line.startswith("price = "):
            if cid in ALLOWED:
                out.append("allowed_dice_sets = Array[int](%s)" % str(ALLOWED[cid]))
            if cid in WINDOW:
                out.append("usage_window = %d" % WINDOW[cid])
            if cid in CONDITIONS:
                conds = ", ".join('"%s"' % c for c in CONDITIONS[cid])
                out.append("usage_conditions = Array[StringName]([%s])" % conds)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    return "id=%s dropped=%d window=%s conditions=%s allowed=%s" % (
        cid, dropped, WINDOW.get(cid, "-"), CONDITIONS.get(cid, "-"), ALLOWED.get(cid, "-"))

def main() -> int:
    files = sorted(DIR.glob("*.tres"))
    print("Migrating %d .tres files" % len(files))
    for f in files:
        print("%s: %s" % (f.name, migrate(f)))
    return 0

if __name__ == "__main__":
    sys.exit(main())
