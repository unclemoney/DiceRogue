@tool
@icon("res://addons/foilsmith/frame/frame.svg")
class_name FoilsmithFrame
extends Node
## A card's frame, made of nodes: put it under a [FoilsmithCard] and give it components
## ([FrameArt], [FrameBar], [FrameText]...), stacked top to bottom in scene-tree order. The card
## rebuilds itself as you edit, and bakes the maps when the scene is saved.
##
## The card base, the colours and the components are the web app's, and the frame reads and
## writes the same JSON as the web app and the CLI: load a frame, template or card file from either,
## or save one for them.
##
## To use one frame for several cards, save the card as a scene and instance it once per card:
## turn on Editable Children on an instance to give it its own text, while the layout and the
## colours stay the template's.

signal frame_changed

@export_tool_button("Start from preset…", "Load") var start_from_preset := _pick_preset
@export_tool_button("Load frame, template or card file…", "Load") var load_file_button := _pick_load
@export_tool_button("Save frame template…", "Save") var save_template_button := _pick_save.bind(true)
@export_tool_button("Save card file…", "Save") var save_card_button := _pick_save.bind(false)

const FACES := ["title", "body", "sans", "sans-text"]

var _v := {}
var _start := {}
var _pending := false
static var _themes := {}


func _init() -> void:
	for f in FoilsmithFields.BASE + FoilsmithFields.BODY:
		_start[f.p] = FoilsmithFields.to_inspector(f, null)
	_start["painted_body"] = false
	_set_theme_values(_start, FoilsmithFields.DEFAULT_THEME)
	for face in FACES:
		_start[_font_prop(face)] = null
	for p in _start:
		_v[p] = _start[p]


func _get_property_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({ name = "Card base", type = TYPE_NIL, usage = PROPERTY_USAGE_GROUP })
	for f in FoilsmithFields.BASE:
		out.append(FoilsmithFields.property(f))
	out.append({ name = "painted_body", type = TYPE_BOOL, usage = PROPERTY_USAGE_DEFAULT })
	if _v.painted_body:
		for f in FoilsmithFields.BODY:
			out.append(FoilsmithFields.property(f))
	out.append({ name = "Colours", type = TYPE_NIL, usage = PROPERTY_USAGE_GROUP })
	out.append({ name = "palette", type = TYPE_STRING, usage = PROPERTY_USAGE_EDITOR, hint = PROPERTY_HINT_ENUM,
		hint_string = ",".join(["custom colours"] + themes().keys()) })
	for r in FoilsmithFields.THEME:
		for p in _theme_props(r):
			out.append({ name = p, type = TYPE_COLOR, usage = PROPERTY_USAGE_DEFAULT, hint = PROPERTY_HINT_COLOR_NO_ALPHA })
	out.append({ name = "Fonts", type = TYPE_NIL, usage = PROPERTY_USAGE_GROUP })
	for face in FACES:
		out.append({ name = _font_prop(face), type = TYPE_OBJECT, usage = PROPERTY_USAGE_DEFAULT,
			hint = PROPERTY_HINT_RESOURCE_TYPE, hint_string = "FontFile" })
	return out


func _get(property: StringName) -> Variant:
	if property == "palette":
		return _palette_name()
	return _v.get(property)


func _set(property: StringName, value: Variant) -> bool:
	if property == "palette":
		if themes().has(value):
			_set_theme_values(_v, themes()[value])
			notify_property_list_changed()
			mark_changed()
		return true
	if not _v.has(property):
		return false
	_v[property] = value
	if property == "painted_body":
		notify_property_list_changed()
	mark_changed()
	return true


func _property_can_revert(property: StringName) -> bool:
	return _start.has(property)


func _property_get_revert(property: StringName) -> Variant:
	return _start.get(property)


func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		mark_changed()


## Something in the frame changed: the card rebuilds (once, however many changes come together).
func mark_changed() -> void:
	if _pending or not is_inside_tree():
		return
	_pending = true
	_emit_changed.call_deferred()


func _emit_changed() -> void:
	_pending = false
	frame_changed.emit()


# --- the JSON ------------------------------------------------------------------------------------

## The frame as the web app and the CLI write it. A template keeps the layout only: no theme, no
## colour overrides and no text (as the web app's "Save frame template").
func to_spec(template := false) -> Dictionary:
	var base := {}
	for f in FoilsmithFields.BASE:
		base[f.k] = FoilsmithFields.to_json(f, _v[f.p])
	if _v.painted_body:
		var body := {}
		for f in FoilsmithFields.BODY:
			body[f.k] = FoilsmithFields.to_json(f, _v[f.p])
		base.body = body
	var spec := { "base": base, "components": components().map(func(c): return c.to_spec()) }
	if template:
		spec.components = spec.components.map(_template_component)
	else:
		spec.theme = _theme_spec()
	return spec


## The frame's component nodes, in order.
func components() -> Array:
	return get_children().filter(func(c): return c is FoilsmithComponent)


## Set the frame from the JSON of a frame, a template or a card file. A card file brings all its
## text and colours; a template or a bare frame only a layout, which keeps this frame's colours and
## the text of components with the same role (as the web app loads them).
func load_spec(d: Dictionary) -> void:
	var card: bool = d.has("frame") and d.frame is Dictionary and d.frame.get("components") is Array
	var next: Dictionary = d.frame if card else d
	if not next.get("components") is Array:
		push_error("Foilsmith: not a frame, template or card file")
		return
	if card:
		_apply(next, next.get("theme", FoilsmithFields.DEFAULT_THEME), false)
	else:
		_apply(next, _theme_spec(), true)


## Start from a preset (its colours too; text with a matching role is kept).
func apply_preset(preset_name: String) -> void:
	var presets: Dictionary = JSON.parse_string(ClassDB.class_call_static("FoilsmithNative", "presets"))
	if not presets.has(preset_name):
		return
	var p: Dictionary = presets[preset_name]
	_apply(p, p.get("theme", _theme_spec()), true)


func _apply(next: Dictionary, theme: Dictionary, carry_text: bool) -> void:
	var b: Dictionary = next.get("base", {})
	for f in FoilsmithFields.BASE:
		_v[f.p] = FoilsmithFields.to_inspector(f, b.get(f.k))
	var body: Variant = b.get("body")
	_v.painted_body = body is Dictionary
	for f in FoilsmithFields.BODY:
		_v[f.p] = FoilsmithFields.to_inspector(f, body.get(f.k) if body is Dictionary else null)
	_set_theme_values(_v, theme)
	var comps: Array = next.components
	if carry_text:
		comps = _carry_text(to_spec().components, comps)
	for c in components():
		remove_child(c)
		c.queue_free()
	var root := _scene_root()
	for d in comps:
		var n := FoilsmithComponent.create(d)
		if n:
			add_child(n, true)
			_own(n, root)
	notify_property_list_changed()
	mark_changed()


# --- colours ---------------------------------------------------------------------------------------

## The named palettes (from the frames crate).
static func themes() -> Dictionary:
	if _themes.is_empty() and ClassDB.class_exists("FoilsmithNative"):
		_themes = JSON.parse_string(ClassDB.class_call_static("FoilsmithNative", "themes"))
	return _themes


func _theme_spec() -> Dictionary:
	var t := {}
	for r in FoilsmithFields.THEME:
		var ps := _theme_props(r)
		t[r.k] = [FoilsmithFields.hex(_v[ps[0]]), FoilsmithFields.hex(_v[ps[1]])] if r.pair else FoilsmithFields.hex(_v[ps[0]])
	return t


func _palette_name() -> String:
	var t := _theme_spec()
	for n in themes():
		var other: Dictionary = FoilsmithFields.DEFAULT_THEME.merged(themes()[n], true)
		if JSON.stringify(_normalize(other)) == JSON.stringify(_normalize(t)):
			return n
	return "custom colours"


static func _normalize(t: Dictionary) -> Dictionary:
	var out := {}
	for r in FoilsmithFields.THEME:
		var v: Variant = t.get(r.k)
		if v is Array:
			out[r.k] = v.map(func(x): return Color.html(x).to_html(false))
		elif v != null:
			out[r.k] = Color.html(v).to_html(false)
	return out


static func _theme_props(r: Dictionary) -> Array:
	return [r.p + "_top", r.p + "_bottom"] if r.pair else [r.p]


static func _set_theme_values(into: Dictionary, theme: Dictionary) -> void:
	var t: Dictionary = FoilsmithFields.DEFAULT_THEME.merged(theme, true)
	for r in FoilsmithFields.THEME:
		var ps := _theme_props(r)
		var v: Variant = t[r.k]
		if r.pair:
			into[ps[0]] = Color.html(v[0])
			into[ps[1]] = Color.html(v[1])
		else:
			into[ps[0]] = Color.html(v)


# --- fonts -------------------------------------------------------------------------------------------

static func _font_prop(face: String) -> String:
	return face.replace("-", "_") + "_font"


## The fonts the card is drawn with: face -> TTF/OTF bytes (only the ones set).
func fonts() -> Dictionary:
	var out := {}
	for face in FACES:
		var f: FontFile = _v[_font_prop(face)]
		if f and not f.data.is_empty():
			out[face] = f.data
	return out


# --- templates (the web app's toTemplate and carryText) ---------------------------------------------

static func _template_component(c: Dictionary) -> Dictionary:
	var o := c.duplicate(true)
	o.erase("fill")
	o.erase("ink")
	for k in FoilsmithFields.TEXT_KEYS.get(o.type, []):
		if o.has(k):
			o[k] = ""
	if o.type == "attacks":
		o.items = o.get("items", []).map(func(a): return a.merged({ "name": "", "damage": "", "text": "" }, true))
	if o.type == "stats":
		o.items = o.get("items", []).map(func(s): return s.merged({ "value": "" }, true))
	if o.type == "row":
		o.children = o.get("children", []).map(_template_component)
	return o


static func _leaves(comps: Array) -> Array:
	var out := []
	for c in comps:
		out.append(c)
		if c.get("type") == "row":
			out.append_array(_leaves(c.get("children", [])))
	return out


static func _carry_text(from: Array, to: Array) -> Array:
	var src := {}
	for c in _leaves(from):
		var role: String = c.get("role", "")
		if role != "" and not src.has(role):
			src[role] = c
	var carry := func(c: Dictionary, me: Callable) -> Dictionary:
		var o := c.duplicate(true)
		var s: Variant = src.get(o.get("role", ""))
		if s is Dictionary:
			if o.type == "bar" and s.type == "bar" and str(s.get("text", "")) != "":
				o.text = s.text
			if o.type == "text" and s.type == "text":
				if str(s.get("body", "")) != "":
					o.body = s.body
				if str(s.get("secondary", "")) != "":
					o.secondary = s.secondary
		if o.type == "row":
			o.children = o.get("children", []).map(func(x): return me.call(x, me))
		return o
	return to.map(func(c): return carry.call(c, carry))


# --- the buttons -------------------------------------------------------------------------------------

func _scene_root() -> Node:
	if Engine.is_editor_hint():
		var r: Node = Engine.get_singleton("EditorInterface").get_edited_scene_root()
		if r and (r == self or r.is_ancestor_of(self)):
			return r
	return owner if owner else self


static func _own(n: Node, root: Node) -> void:
	if n != root:
		n.owner = root
	for c in n.get_children():
		_own(c, root)


func _pick_preset() -> void:
	var presets: Dictionary = JSON.parse_string(ClassDB.class_call_static("FoilsmithNative", "presets"))
	var menu := PopupMenu.new()
	for n in presets:
		menu.add_item(n)
	menu.index_pressed.connect(func(i: int) -> void: apply_preset(menu.get_item_text(i)))
	menu.popup_hide.connect(menu.queue_free)
	Engine.get_singleton("EditorInterface").get_base_control().add_child(menu)
	menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ZERO))


func _dialog(mode: EditorFileDialog.FileMode, title: String, done: Callable, file := "") -> void:
	var d := EditorFileDialog.new()
	d.file_mode = mode
	d.access = EditorFileDialog.ACCESS_FILESYSTEM
	d.title = title
	d.add_filter("*.json", "Frame, template or card file")
	if file != "":
		d.current_file = file
	d.file_selected.connect(done)
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	Engine.get_singleton("EditorInterface").get_base_control().add_child(d)
	d.popup_file_dialog()


func _pick_load() -> void:
	_dialog(EditorFileDialog.FILE_MODE_OPEN_FILE, "Load a frame, template or card file", func(path: String) -> void:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary:
			load_spec(d)
		else:
			push_error("Foilsmith: %s isn't JSON" % path))


func _pick_save(template: bool) -> void:
	var card := get_parent() as FoilsmithCard
	var stem := "frame-template" if template else (card.bake_stem() if card else "card")
	_dialog(EditorFileDialog.FILE_MODE_SAVE_FILE, "Save frame template" if template else "Save card file", func(path: String) -> void:
		var out: Dictionary
		if template:
			out = to_spec(true)
		else:
			out = { "frame": to_spec() }
			if card and card.source_art:
				var art := ProjectSettings.globalize_path(card.source_art.resource_path)
				out.art = _relative(art, path.get_base_dir())
			if card and card.depth_map:
				out.depth = _relative(ProjectSettings.globalize_path(card.depth_map.resource_path), path.get_base_dir())
			if card:
				out.finish = card.finish_name()
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  ", false) + "\n"), stem + ".json")


static func _relative(target: String, from_dir: String) -> String:
	var a := target.simplify_path().split("/")
	var b := from_dir.simplify_path().split("/")
	var i := 0
	while i < min(a.size(), b.size()) and a[i] == b[i]:
		i += 1
	var parts: Array[String] = []
	for _j in range(i, b.size()):
		parts.append("..")
	for j in range(i, a.size()):
		parts.append(a[j])
	return "/".join(parts)
