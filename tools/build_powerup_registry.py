# tools/build_powerup_registry.py
# Run from anywhere: py build_powerup_registry.py
import csv, re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
POWERUP_DIR = REPO_ROOT / "Scripts" / "PowerUps"
OUT = REPO_ROOT / "Data" / "powerup_registry.csv"

# Keys that might hold the display name, in order of preference
NAME_KEYS = ["power_name", "display_name", "title", "name", "label"]
DESC_KEYS = ["description", "tooltip", "flavor_text", "desc"]

RARITIES = ["common", "uncommon", "rare", "epic", "legendary"]

def parse_tres(text: str):
    fields = dict(re.findall(r'^(\w+)\s*=\s*"(.*)"', text, re.M))
    name = next((fields[k] for k in NAME_KEYS if k in fields), "")
    desc = next((fields[k] for k in DESC_KEYS if k in fields), "")
    rarity = fields.get("rarity", "")
    rating = fields.get("rating", "")
    return name, desc, rarity, rating

def main():
    if not POWERUP_DIR.is_dir():
        raise SystemExit(f"PowerUp folder not found: {POWERUP_DIR}")

    existing = {}
    if OUT.exists():
        for row in csv.DictReader(OUT.open(encoding="utf-8")):
            existing[row["file"]] = row

    rows = []
    for f in sorted(POWERUP_DIR.glob("*.tres")):
        name, desc, rarity, rating = parse_tres(f.read_text(encoding="utf-8"))
        old = existing.get(f.name, {})

        rarity = rarity or old.get("rarity", "")
        rating = rating or old.get("rating", "")

        if rarity and rarity not in RARITIES:
            print(f"WARN {f.name}: unknown rarity '{rarity}'")

        rows.append({
            "file": f.name,
            "current_name": name or old.get("current_name", ""),
            "suggested_name": old.get("suggested_name", ""),
            "rarity": rarity,
            "rating": rating,
            "description": desc,
            "icon_concept": old.get("icon_concept", ""),
            "status": old.get("status", "pending"),
        })

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {len(rows)} rows to {OUT}")

if __name__ == "__main__":
    main()