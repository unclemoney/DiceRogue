import re

with open(r'c:\Users\danie\Documents\dicerogue\DiceRogue\Tests\DebuffTest.tscn', 'r', encoding='utf-8') as f:
    lines = f.readlines()

nodes_to_remove = {
    'HutchBackground': '.',
    'TVFrame': '.',
    'ChallengeContainer': '.',
    'PowerUpContainer': '.',
    'ScoreCardUI': 'CRTTV',
    'DiceHand': 'CRTTV',
    'CorkboardUI': '.',
    'PowerUpUI': '.',
    'ConsumableUI': '.',
    'ChallengeUI': '.',
    'DebuffUI': '.',
    'GameButtonUI': '.',
    'GamingConsoleUI': '.',
    'VCRTurnTrackerUI': '.',
}

new_lines = []
skip_depth = 0

for line in lines:
    stripped = line.strip()
    if stripped.startswith('[node '):
        match = re.search(r'name="([^"]+)".*?parent="([^"]*)"', stripped)
        if match:
            name = match.group(1)
            parent = match.group(2)
            if name in nodes_to_remove and parent == nodes_to_remove[name]:
                skip_depth = 1
                continue
    if skip_depth > 0:
        if stripped.startswith('[node ') or stripped.startswith('[connection ') or stripped.startswith('[ext_resource ') or stripped.startswith('[sub_resource '):
            skip_depth = 0
        else:
            continue
    new_lines.append(line)

content = ''.join(new_lines)

# Add GameUI ext_resource before ShopUI ext_resource if not present
if 'res://Scenes/UI/GameUI.tscn' not in content:
    content = content.replace(
        '[ext_resource type="PackedScene" uid="uid://dbqwnxq8iy66l" path="res://Scenes/UI/shop_ui.tscn" id="32_oy5od"]',
        '[ext_resource type="PackedScene" uid="uid://dbqwnxq8iy66l" path="res://Scenes/UI/shop_ui.tscn" id="32_oy5od"]\n[ext_resource type="PackedScene" path="res://Scenes/UI/GameUI.tscn" id="gameui"]'
    )

# Add GameUI node before ShopUI node
if '[node name="GameUI"' not in content:
    content = content.replace(
        '[node name="ShopUI" parent="." instance=ExtResource("32_oy5od")]',
        '[node name="GameUI" parent="." instance=ExtResource("gameui")]\n\n[node name="ShopUI" parent="." instance=ExtResource("32_oy5od")]'
    )

with open(r'c:\Users\danie\Documents\dicerogue\DiceRogue\Tests\DebuffTest.tscn', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')
