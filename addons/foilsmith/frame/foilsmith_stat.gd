@tool
class_name FoilsmithStat
extends Resource
## One column of a [FrameStats] component: a label over a value, or over a row of symbols.

@export var label := "":
	set(v):
		label = v
		emit_changed()
@export var value := "":
	set(v):
		value = v
		emit_changed()
## A symbol (fire, star...) drawn [member count] times.
@export var symbol := "":
	set(v):
		symbol = v
		emit_changed()
@export_range(0, 6) var count := 1:
	set(v):
		count = v
		emit_changed()


func to_spec() -> Dictionary:
	return { "label": label, "symbol": symbol, "count": count, "value": value }


static func from_spec(d: Dictionary) -> FoilsmithStat:
	var s := FoilsmithStat.new()
	s.label = str(d.get("label", ""))
	s.symbol = str(d.get("symbol", ""))
	s.count = int(d.get("count", 1))
	s.value = str(d.get("value", ""))
	return s
