import re

with open(r'c:\Users\danie\Documents\dicerogue\DiceRogue\Tests\DebuffTest.tscn', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip_depth = 0

for line in lines:
    stripped = line.strip()
    if stripped.startswith('[node '):
        match = re.search(r'name="([^"]+)".*?parent="([^"]*)"', stripped)
        if match:
            name = match.group(1)
            parent = match.group(2)
            # Remove orphaned DiceAreaVisual under CRTTV/DiceHand
            if name == "DiceAreaVisual" and parent == "CRTTV/DiceHand":
                skip_depth = 1
                continue
    if skip_depth > 0:
        if stripped.startswith('[node ') or stripped.startswith('[connection ') or stripped.startswith('[ext_resource ') or stripped.startswith('[sub_resource '):
            skip_depth = 0
        else:
            continue
    new_lines.append(line)

content = ''.join(new_lines)

# Update RoundManager dice_hand_path override
content = content.replace(
    'dice_hand_path = NodePath("../../CRTTV/DiceHand")',
    'dice_hand_path = NodePath("../../GameUI/MarginContainer/MainVBox/MiddleSection/CenterColumn/DiceAreaContainer/DiceHand")'
)

# Update RoundManager scorecard_path override (ScoreCard is at root)
# content = content.replace(...) # ScoreCard is still at root, so path is fine

with open(r'c:\Users\danie\Documents\dicerogue\DiceRogue\Tests\DebuffTest.tscn', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')
