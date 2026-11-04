@tool
class_name FoilsmithAttack
extends Resource
## One attack of a [FrameAttacks] component: its cost, name, damage and text.

## Cost symbols (grass, fire, colorless...).
@export var cost := PackedStringArray():
	set(v):
		cost = v
		emit_changed()
@export var name := "":
	set(v):
		name = v
		emit_changed()
@export var damage := "":
	set(v):
		damage = v
		emit_changed()
@export_multiline var text := "":
	set(v):
		text = v
		emit_changed()


func to_spec() -> Dictionary:
	return { "cost": Array(cost), "name": name, "damage": damage, "text": text }


static func from_spec(d: Dictionary) -> FoilsmithAttack:
	var a := FoilsmithAttack.new()
	a.cost = PackedStringArray(d.get("cost", []))
	a.name = str(d.get("name", ""))
	a.damage = str(d.get("damage", ""))
	a.text = str(d.get("text", ""))
	return a
