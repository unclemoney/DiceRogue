@tool
@icon("res://addons/foilsmith/frame/component.svg")
class_name FoilsmithComponent
extends Node
## One component of a frame (a child of a [FoilsmithFrame], or of a [FrameRow]): the frame stacks
## its components top to bottom in the order they are in the scene tree. Its fields are the web
## app's for that kind of component, under the same names (see [FoilsmithFields]).

var _v := {}        # property -> value
var _start := {}    # property -> what a new node starts with (and what it reverts to)
var _fields := []   # this kind's fields, the position first


## The component's kind in the JSON (`art`, `bar`, `text`...).
func kind() -> String:
	return ""


func _init() -> void:
	_fields = FoilsmithFields.fields_of(kind())
	var start: Dictionary = FoilsmithFields.KINDS[kind()].start
	for f in _fields:
		if f.t == "fill":
			for p in FoilsmithFields.fill_props(f):
				_start[p] = Color(0, 0, 0, 0)
		else:
			_start[f.p] = FoilsmithFields.to_inspector(f, start.get(f.k, f.d))
	_start["role"] = ""
	for p in _start:
		_v[p] = _copy(_start[p])
	_watch_items()


func _get_property_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({ name = "Position", type = TYPE_NIL, usage = PROPERTY_USAGE_GROUP })
	var label: String = FoilsmithFields.KINDS[kind()].label
	for i in _fields.size():
		var f: Dictionary = _fields[i]
		if i == FoilsmithFields.PLACE.size():
			out.append({ name = label, type = TYPE_NIL, usage = PROPERTY_USAGE_GROUP })
		if f.t == "fill":
			for p in FoilsmithFields.fill_props(f):
				out.append({ name = p, type = TYPE_COLOR, usage = PROPERTY_USAGE_DEFAULT })
		else:
			out.append(FoilsmithFields.property(f))
	# what the component holds (name, rules...): editors carry text between frames by it
	out.append({ name = "role", type = TYPE_STRING, usage = PROPERTY_USAGE_STORAGE })
	return out


func _get(property: StringName) -> Variant:
	return _v.get(property)


func _set(property: StringName, value: Variant) -> bool:
	if not _v.has(property):
		return false
	_v[property] = value
	if property in ["attacks", "columns"]:
		_watch_items()
	changed()
	return true


func _property_can_revert(property: StringName) -> bool:
	return _start.has(property)


func _property_get_revert(property: StringName) -> Variant:
	return _copy(_start.get(property))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_EXIT_TREE, NOTIFICATION_CHILD_ORDER_CHANGED:
			changed()


## Tell the frame something changed (it rebuilds the card).
func changed() -> void:
	var f := frame()
	if f:
		f.mark_changed()


## The frame this component is in.
func frame() -> FoilsmithFrame:
	var n := get_parent()
	while n and not n is FoilsmithFrame:
		n = n.get_parent()
	return n as FoilsmithFrame


## The component as the web app and the CLI write it.
func to_spec() -> Dictionary:
	var d := { "type": kind() }
	for f in _fields:
		if f.t == "fill":
			var ps := FoilsmithFields.fill_props(f)
			var a: Color = _v[ps[0]]
			var b: Color = _v[ps[1]]
			if a.a > 0 and b.a > 0:
				d[f.k] = [FoilsmithFields.hex(a), FoilsmithFields.hex(b)]
		else:
			var j: Variant = FoilsmithFields.to_json(f, _v[f.p])
			if j != null:
				d[f.k] = j
	if _v.role != "":
		d.role = _v.role
	if kind() == "row":
		d.children = get_children().filter(func(c): return c is FoilsmithComponent).map(func(c): return c.to_spec())
	return d


## Set the fields from the JSON (a missing key gets the spec's default, as foilsmith reads it).
func apply_spec(d: Dictionary) -> void:
	for f in _fields:
		if f.t == "fill":
			var ps := FoilsmithFields.fill_props(f)
			var v: Variant = d.get(f.k)
			_v[ps[0]] = Color.html(v[0]) if v is Array and v.size() == 2 else Color(0, 0, 0, 0)
			_v[ps[1]] = Color.html(v[1]) if v is Array and v.size() == 2 else Color(0, 0, 0, 0)
		else:
			_v[f.p] = FoilsmithFields.to_inspector(f, d.get(f.k))
	_v.role = str(d.get("role", ""))
	_watch_items()
	notify_property_list_changed()
	changed()


## A component node for a JSON component (rows with their children).
static func create(d: Dictionary) -> FoilsmithComponent:
	var c: FoilsmithComponent
	match str(d.get("type", "")):
		"art": c = FrameArt.new()
		"bar": c = FrameBar.new()
		"text": c = FrameText.new()
		"symbols": c = FrameSymbols.new()
		"attacks": c = FrameAttacks.new()
		"stats": c = FrameStats.new()
		"spacer": c = FrameSpacer.new()
		"row": c = FrameRow.new()
		_: return null
	c.apply_spec(d)
	var role: String = c._v.role
	c.name = role.capitalize().replace(" ", "") if role != "" else FoilsmithFields.KINDS[c.kind()].label.capitalize().replace(" ", "")
	if c is FrameRow:
		for child in d.get("children", []):
			var n := create(child)
			if n:
				c.add_child(n, true)
	return c


# attacks and stat columns are resources: an edit in one of them changes the card too
func _watch_items() -> void:
	for p in ["attacks", "columns"]:
		if not _v.has(p):
			continue
		for item in _v[p]:
			if item and not item.changed.is_connected(changed):
				item.changed.connect(changed)


static func _copy(v: Variant) -> Variant:
	if v is Array:
		var a: Array = v.duplicate()
		for i in a.size():
			if a[i] is Resource:
				a[i] = a[i].duplicate()
		return a
	if v is PackedStringArray:
		return v.duplicate()
	return v
