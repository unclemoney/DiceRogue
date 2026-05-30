with open(r'c:\Users\danie\Documents\dicerogue\DiceRogue\Tests\DebuffTest.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('[ext_resource type="PackedScene" uid="uid://crkb0ardui001" path="res://Scenes/UI/CorkboardUI.tscn" id="98_ocuqv"]\n', '')

with open(r'c:\Users\danie\Documents\dicerogue\DiceRogue\Tests\DebuffTest.tscn', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done')
