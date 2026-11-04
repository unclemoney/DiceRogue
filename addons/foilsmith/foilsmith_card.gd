@tool
@icon("res://addons/foilsmith/icon.svg")
class_name FoilsmithCard
extends Control
## A holographic card drawn with foilsmith's shader, with the same controls as the web app: the
## finish (and whether the back takes it) and its eight sliders, the debug layers, depth on or off
## and pixel hue steps. It tilts toward the mouse, turns over on click and can play the preview
## loop (front, turn over, back).
##
## Build a card here in the editor: set [member source_art] and give the card a [FoilsmithFrame]
## child with components ([FrameArt], [FrameBar], [FrameText]...). The card rebuilds as you edit
## and is baked to the files the CLI writes when the scene is saved, so a game only loads PNGs.
##
## Or give it a card from the `foilsmith` CLI by pointing [member card_json] at the `<name>.json` the
## CLI writes. Its `<name>_art.png`, `_fx.png`, `_normal.png` and, for a card file, `_frame.png` and
## `_frame_foil.png` are picked up next to it. You can also set the textures yourself.

enum Finish { STANDARD, HOLO, CRACKED_ICE, GOLD, GALAXY, GLITCH, ARCANE, INVERSE, ENGRAVED, SPECTRUM }
enum Layer { SHADED, FOIL, DEPTH, POP_OUT, NORMALS }

const SHADER := preload("res://addons/foilsmith/foilsmith.gdshader")
const DEFAULT_BACK_JSON := "res://addons/foilsmith/back/default_back.json"
## The shader's finish index for each [enum Finish] (the web app's menu order differs from it).
const FINISH_INDEX := { Finish.STANDARD: 5, Finish.HOLO: 0, Finish.CRACKED_ICE: 1, Finish.GOLD: 2, Finish.GALAXY: 3, Finish.GLITCH: 4,
		Finish.ARCANE: 6, Finish.INVERSE: 7, Finish.ENGRAVED: 8, Finish.SPECTRUM: 9 }
const FINISH_NAMES := { "standard": Finish.STANDARD, "holo": Finish.HOLO, "cracked-ice": Finish.CRACKED_ICE, "gold": Finish.GOLD, "galaxy": Finish.GALAXY, "glitch": Finish.GLITCH,
		"arcane": Finish.ARCANE, "inverse": Finish.INVERSE, "engraved": Finish.ENGRAVED, "spectrum": Finish.SPECTRUM }
## Menu label and a one-line description for each [enum Finish], in the web app's words.
const FINISH_INFO := {
	Finish.STANDARD: ["Standard", "No foil: a plain printed card that still tilts, glints and catches the glare."],
	Finish.HOLO: ["Holo", "Rainbow bands that slide with the tilt, a bright spectral sweep and glitter."],
	Finish.CRACKED_ICE: ["Cracked Ice", "Shattered shards, each catching the light at its own angle."],
	Finish.GOLD: ["Gold", "A gilded frame, a soft rainbow on the art's highlights and a sweeping shine."],
	Finish.GALAXY: ["Galaxy", "A nebula and parallax starfield in the art's dark areas."],
	Finish.GLITCH: ["Glitch", "Edge glow, RGB split, scanlines and the odd glitched slice."],
	Finish.ARCANE: ["Arcane", "Fine crossed diagonal lines of rainbow sliding opposite ways with the tilt."],
	Finish.INVERSE: ["Inverse", "A pebbled rainbow sheen on the frame and panels, with a lighter touch on the art."],
	Finish.ENGRAVED: ["Engraved", "A satin silver frame with fine engraved lines that catch a pale sheen."],
	Finish.SPECTRUM: ["Spectrum", "The whole card washed in a pastel rainbow with a dense glittering grain."],
}
## What each finish slider does (the web app's subtitles), by property name.
const SLIDER_HINTS := {
	"foil": "How strongly the finish shows on the card.",
	"parallax": "How far the subject lifts off the card as it tilts.",
	"glint": "The bright highlight that slides across the surface.",
	"sparkle": "Star-shaped glitter twinkling in the foil.",
	"glare": "A soft wash of light that follows the tilt.",
	"relief": "Light and shade from the normal map, so the art looks raised.",
	"shadow": "How dark the subject's shadow falls on the card.",
	"hue_drift": "Extra rainbow cycles per loop, on top of the tilt's.",
}
## Seconds per preview loop, as in the web app.
const LOOP_SECONDS := 6.0

# --- the card ------------------------------------------------------------------------------------

@export_group("Card")
## The art to build the card from, under its [FoilsmithFrame] child.
@export var source_art: Texture2D:
	set(v):
		source_art = v
		_schedule_build()
## A depth estimate for the source art (white = nearest), for the parallax, the relief and the
## subject's shadow. Empty: a flat card. [b]Bake depth[/b] makes one with the depth model.
@export var depth_map: Texture2D:
	set(v):
		depth_map = v
		_schedule_build()
@export_tool_button("Bake depth") var bake_depth_button := bake_depth
## Where a card built here is baked: [code]<folder>/<name>.json[/code] and its PNGs (the name is the
## node's, or the scene's for a scene's root).
@export_dir var bake_folder := "res://cards"
## The `<name>.json` the CLI wrote (or the card baked here). Setting it loads the art, maps and
## frame next to it.
@export_file("*.json") var card_json := "":
	set(v):
		card_json = v
		if not _baking:
			_load_side(false)
## The back's `<name>.json` (an image run through the CLI). Empty: the Foilsmith back.
@export_file("*.json") var back_json := "":
	set(v):
		back_json = v
		_load_side(true)

@export_subgroup("Textures")
@export var art: Texture2D:
	set(v):
		art = v
		_update()
@export var fx_map: Texture2D:
	set(v):
		fx_map = v
		_update()
@export var normal_map: Texture2D:
	set(v):
		normal_map = v
		_update()
@export var frame_texture: Texture2D:
	set(v):
		frame_texture = v
		_update()
@export var frame_foil: Texture2D:
	set(v):
		frame_foil = v
		_update()
@export var back_art: Texture2D:
	set(v):
		back_art = v
		_update()
@export var back_fx_map: Texture2D:
	set(v):
		back_fx_map = v
		_update()
@export var back_normal_map: Texture2D:
	set(v):
		back_normal_map = v
		_update()
## From the front's JSON: pixel-art mode, its native pixel grid and foil hue steps.
@export var pixel_art := false:
	set(v):
		pixel_art = v
		_update()
@export var native_size := Vector2.ZERO:
	set(v):
		native_size = v
		_update()
@export var back_pixel_art := false:
	set(v):
		back_pixel_art = v
		_update()
@export var back_native_size := Vector2.ZERO:
	set(v):
		back_native_size = v
		_update()

# --- the web app's panels --------------------------------------------------------------------------

@export_group("Frame")
## Foil hue steps in pixel-art mode (the web app shows this only for pixel art).
@export_range(2, 16, 1) var pixel_hue_steps := 6:
	set(v):
		pixel_hue_steps = v
		_update()

@export_group("Depth")
## Off: the card is drawn flat, with no parallax and no subject shadow.
@export var use_depth := true:
	set(v):
		use_depth = v
		_update()

@export_group("Finish")
## The foil finish: Standard (no foil), Holo, Cracked Ice, Gold, Galaxy, Glitch, Arcane (fine crossed
## rainbow lines), Inverse (mostly the frame and panels), Engraved (satin silver with engraved lines) or
## Spectrum (pastel rainbow with glitter). See [constant FINISH_INFO].
@export var finish := Finish.HOLO:
	set(v):
		finish = v
		_update()
## The back takes the finish too (off, the default: the back is a plain standard print).
@export var back_finish := false:
	set(v):
		back_finish = v
		_update()
## How strongly the finish shows on the card.
@export_range(0.0, 2.0, 0.05) var foil := 1.0:
	set(v):
		foil = v
		_update()
## How far the subject lifts off the card as it tilts.
@export_range(0.0, 0.15, 0.005) var parallax := 0.02:
	set(v):
		parallax = v
		_update()
## The bright highlight that slides across the surface.
@export_range(0.0, 2.0, 0.05) var glint := 1.0:
	set(v):
		glint = v
		_update()
## Star-shaped glitter twinkling in the foil.
@export_range(0.0, 2.0, 0.05) var sparkle := 0.9:
	set(v):
		sparkle = v
		_update()
## A soft wash of light that follows the tilt.
@export_range(0.0, 2.0, 0.05) var glare := 0.2:
	set(v):
		glare = v
		_update()
## Light and shade from the normal map, so the art looks raised.
@export_range(0.0, 2.0, 0.05) var relief := 0.9:
	set(v):
		relief = v
		_update()
## How dark the subject's shadow falls on the card.
@export_range(0.0, 1.5, 0.05) var shadow := 0.45:
	set(v):
		shadow = v
		_update()
## Extra rainbow cycles per loop, on top of the tilt's.
@export_range(0.0, 4.0, 0.25) var hue_drift := 1.0:
	set(v):
		hue_drift = v
		_update()

@export_group("Layers")
## Show one of the generated maps on the card instead of the finished render.
@export var layer := Layer.SHADED:
	set(v):
		layer = v
		_update()

@export_group("Stage")
## Play the preview loop (as in the CLI's GIF). Also plays in the editor.
@export var play_loop := false
## Tilt toward the mouse while it is over the card.
@export var follow_mouse := true
## Turn the card over on click.
@export var click_to_flip := true
## The card's size within the node: the rest is room for the tilted corners.
@export_range(0.1, 1.0, 0.01) var card_scale := 0.86:
	set(v):
		card_scale = v
		_update()
## Varies the sparkles between cards.
@export var sparkle_seed := 0.0:
	set(v):
		sparkle_seed = v
		_update()
@export var supersample := true:
	set(v):
		supersample = v
		_update()

## The current tilt (x yaw, y pitch, radians). Past ±π/2 yaw the back shows.
var tilt := Vector2.ZERO
var flipped := false
var _target := Vector2.ZERO
var _time := 0.0
var _hue_steps := 0
var _back_hue_steps := 0
var _default_back := false
var _baking := false
var _frame: FoilsmithFrame
var _build_queued := false
var _building := false
var _build_again := false
var _built := {}
var _built_dirty := false


func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(315, 440)


## Keep scenes small: the shader material is rebuilt by the node, and textures loaded from a JSON
## are loaded from it again, so neither is saved.
func _validate_property(property: Dictionary) -> void:
	var p: String = property.name
	var from_card := (card_json != "" or get_frame() != null) and p in ["art", "fx_map", "normal_map", "frame_texture", "frame_foil", "pixel_art", "native_size"]
	var from_back := p in ["back_art", "back_fx_map", "back_normal_map", "back_pixel_art", "back_native_size"] and (back_json != "" or _default_back)
	if p == "material" or from_card or from_back:
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _ready() -> void:
	if back_json == "" and back_art == null:
		_load_side(true)
	_update()
	_watch_frame()


## Reset the look to the defaults, keeping the finish (as the web app's "Reset" does).
func reset_look() -> void:
	foil = 1.0
	parallax = 0.02
	glint = 1.0
	sparkle = 0.9
	glare = 0.2
	relief = 0.9
	shadow = 0.45
	hue_drift = 1.0


## The finish's CLI name.
func finish_name() -> String:
	return FINISH_NAMES.find_key(finish)


## Set the finish by its CLI name (standard, holo, cracked-ice, gold, galaxy, glitch, arcane, inverse, engraved, spectrum).
func set_finish_name(finish_name: String) -> void:
	finish = FINISH_NAMES.get(finish_name, Finish.HOLO)


## The CLI preview's loop at loop fraction t: inspect the front (a slow figure-of-eight), turn
## over, inspect the back, turn the rest of the way round.
static func loop_pose(t: float) -> Vector2:
	var u := t - floorf(t)
	var seg := func(a: float, b: float) -> float: return smoothstep(0.0, 1.0, clampf((u - a) / (b - a), 0.0, 1.0))
	var yaw: float = 0.3 * sin(TAU * u * 2.0) + 0.05 * sin(TAU * u * 3.0 + 1.0) + PI * (seg.call(0.42, 0.56) + seg.call(0.86, 1.0))
	var pitch := 0.15 * sin(TAU * u * 3.0 + 0.7)
	return Vector2(yaw, pitch)


func _process(delta: float) -> void:
	_time += delta
	var mat := material as ShaderMaterial
	if play_loop:
		var p := loop_pose(_time / LOOP_SECONDS)
		tilt = p
		mat.set_shader_parameter("loop_period", LOOP_SECONDS)
		mat.set_shader_parameter("clock", fmod(_time, LOOP_SECONDS))
	else:
		var goal := _target.x + (PI if flipped else 0.0)
		# unwrap so a turn takes the short way after the loop has spun the card around
		while tilt.x - goal > PI:
			tilt.x -= TAU
		while goal - tilt.x > PI:
			tilt.x += TAU
		var k := 1.0 - exp(-delta * 7.0)
		tilt.x += (goal - tilt.x) * k
		tilt.y += (_target.y - tilt.y) * k
		mat.set_shader_parameter("loop_period", 0.0)
		mat.set_shader_parameter("clock", _time)
	mat.set_shader_parameter("tilt", tilt)


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion and follow_mouse:
		var r := _card_rect()
		var x: float = (event.position.x - r.position.x) / r.size.x - 0.5
		var y: float = (event.position.y - r.position.y) / r.size.y - 0.5
		# the corner under the pointer is pressed away from the viewer
		_target = Vector2(clampf(-x * 1.1, -0.5, 0.5), clampf(y * 0.8, -0.35, 0.35))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and click_to_flip:
		flipped = not flipped
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_target = Vector2.ZERO
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_CHILD_ORDER_CHANGED:
		_watch_frame()
	elif what == NOTIFICATION_EDITOR_PRE_SAVE:
		_bake()


# --- building the card in the editor ------------------------------------------------------------

## The card's frame: its first [FoilsmithFrame] child, if it has one.
func get_frame() -> FoilsmithFrame:
	for c in get_children():
		if c is FoilsmithFrame:
			return c
	return null


## The name the card is baked under: the node's, or the scene's for a scene's root.
func bake_stem() -> String:
	var n := String(name)
	if owner == null and scene_file_path != "":
		n = scene_file_path.get_file().get_basename()
	return n.to_snake_case()


func _watch_frame() -> void:
	var f := get_frame()
	if f == _frame:
		return
	if _frame and _frame.frame_changed.is_connected(_schedule_build):
		_frame.frame_changed.disconnect(_schedule_build)
	_frame = f
	if _frame:
		_frame.frame_changed.connect(_schedule_build)
		_schedule_build()


## Rebuild the card soon (edits that come together build once).
func _schedule_build() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _build_queued:
		return
	if source_art == null or get_frame() == null or not ClassDB.class_exists("FoilsmithNative"):
		return
	_build_queued = true
	get_tree().create_timer(0.15).timeout.connect(_start_build)


func _start_build() -> void:
	_build_queued = false
	if _building:
		_build_again = true
		return
	var f := get_frame()
	if f == null or source_art == null:
		return
	_building = true
	var art_img := source_art.get_image()
	var depth_img: Image = depth_map.get_image() if depth_map else null
	var json := JSON.stringify(f.to_spec())
	var fonts := f.fonts()
	var steps := pixel_hue_steps
	# the build takes a few tenths of a second: off the main thread, so the editor stays smooth
	WorkerThreadPool.add_task(func() -> void:
		var r: Dictionary = ClassDB.class_call_static("FoilsmithNative", "build", art_img, depth_img, json, fonts, -1, steps)
		_build_done.call_deferred(r))


func _build_done(r: Dictionary) -> void:
	_building = false
	if r.has("error"):
		push_warning("Foilsmith: %s: %s" % [name, r.error])
	else:
		_built = r
		_built_dirty = true
		art = ImageTexture.create_from_image(r.art)
		fx_map = ImageTexture.create_from_image(r.fx)
		normal_map = ImageTexture.create_from_image(r.normal) if r.has("normal") else null
		frame_texture = ImageTexture.create_from_image(r.frame)
		frame_foil = ImageTexture.create_from_image(r.frame_foil)
		var info: Dictionary = JSON.parse_string(r.info)
		pixel_art = info.get("pixel_art", false)
		var ns: Array = info.get("native_size", [0, 0])
		native_size = Vector2(ns[0], ns[1])
		_hue_steps = int(info.get("hue_steps", 0))
		_update()
	if _build_again:
		_build_again = false
		_schedule_build()


## Write the built card where the CLI would: `<name>.json` and its PNGs, which a game loads.
func _bake() -> void:
	if _built.is_empty() or get_frame() == null:
		return
	if owner == null and scene_file_path == "":
		return   # a new scene's root: its name comes with the scene's file, at the next save
	var path := "%s/%s.json" % [bake_folder.trim_suffix("/"), bake_stem()]
	var base := path.get_basename()
	if _built_dirty or not FileAccess.file_exists(path):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var pngs: Array[String] = []
		for key in ["art", "fx", "normal", "frame", "frame_foil"]:
			if _built.has(key):
				var p := "%s_%s.png" % [base, key]
				(_built[key] as Image).save_png(p)
				pngs.append(p)
		# the CLI's JSON, with the card's finish (as the CLI writes a card file's)
		var info: String = _built.info.strip_edges().trim_suffix("}").strip_edges()
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string('%s,\n  "finish": "%s"\n}\n' % [info, finish_name()])
		f.close()
		_built_dirty = false
		_import_baked.call_deferred(pngs)
	if card_json != path:
		_baking = true
		card_json = path
		_baking = false


func _import_baked(pngs: Array[String]) -> void:
	_import_new(pngs, func() -> void: _fix_imports(pngs))


## Let the editor import files just written (a scan picks them up), then call `then`.
func _import_new(paths: Array[String], then: Callable) -> void:
	var editor := Engine.get_singleton("EditorInterface")
	if editor == null or not is_inside_tree():
		return
	var fs: EditorFileSystem = editor.get_resource_filesystem()
	fs.scan()
	for _i in 120:   # up to 30 s
		await get_tree().create_timer(0.25).timeout
		var importing: bool = fs.has_method("is_importing") and fs.call("is_importing")
		if not fs.is_scanning() and not importing and paths.all(func(p): return FileAccess.file_exists(p + ".import") and ResourceLoader.exists(p)):
			await get_tree().process_frame   # out of the import's own callbacks
			then.call()
			return
	push_warning("Foilsmith: %s weren't imported" % [paths])


## Bake the source art's depth with the depth model (Depth Anything V2 Small, on the GPU), save
## it next to the baked card and use it.
func bake_depth() -> void:
	if source_art == null:
		push_warning("Foilsmith: set the Source Art first")
		return
	if not FoilsmithDepth.estimate_async(source_art.get_image(), _depth_done):
		push_warning("Foilsmith: the depth model is busy")
		return
	print("Foilsmith: estimating depth for %s…" % name)


func _depth_done(d: Image) -> void:
	if d == null:
		push_warning("Foilsmith: the depth model needs the Forward+ or Mobile renderer. Set a Depth Map by hand instead.")
		return
	var path := "%s/%s_depth.png" % [bake_folder.trim_suffix("/"), bake_stem()]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	d.save_png(path)
	print("Foilsmith: depth saved to ", path)
	# use it now, and the imported file (which the scene saves by path) once the editor has it
	depth_map = ImageTexture.create_from_image(d)
	_import_new([path], func() -> void: depth_map = load(path))


func _draw() -> void:
	if art:
		draw_texture_rect(art, _card_rect(), false)


## The largest rect with the card's proportions, centred in the node.
func _card_rect() -> Rect2:
	var aspect := 630.0 / 880.0
	if art:
		aspect = float(art.get_width()) / art.get_height()
	var s := size
	var h := s.y
	var w := h * aspect
	if w > s.x:
		w = s.x
		h = w / aspect
	return Rect2((s - Vector2(w, h)) * 0.5, Vector2(w, h))


func _update() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("fx_map", fx_map)
	mat.set_shader_parameter("normal_map", normal_map)
	mat.set_shader_parameter("has_frame", frame_texture != null)
	mat.set_shader_parameter("frame_tex", frame_texture)
	mat.set_shader_parameter("frame_foil", frame_foil)
	mat.set_shader_parameter("back_tex", back_art)
	mat.set_shader_parameter("back_fx_map", back_fx_map)
	mat.set_shader_parameter("back_normal_map", back_normal_map)
	mat.set_shader_parameter("pixel_art", pixel_art)
	mat.set_shader_parameter("native_size", native_size)
	mat.set_shader_parameter("hue_steps", pixel_hue_steps if pixel_art else _hue_steps)
	mat.set_shader_parameter("back_pixel_art", back_pixel_art)
	mat.set_shader_parameter("back_native_size", back_native_size)
	mat.set_shader_parameter("back_hue_steps", _back_hue_steps)
	mat.set_shader_parameter("finish", FINISH_INDEX[finish])
	mat.set_shader_parameter("back_finish", back_finish)
	mat.set_shader_parameter("debug_view", int(layer))
	mat.set_shader_parameter("foil", foil)
	mat.set_shader_parameter("depth_scale", parallax if use_depth else 0.0)
	mat.set_shader_parameter("glint", glint)
	mat.set_shader_parameter("sparkle", sparkle)
	mat.set_shader_parameter("glare", glare)
	mat.set_shader_parameter("relief", relief)
	mat.set_shader_parameter("shadow", shadow if use_depth else 0.0)
	mat.set_shader_parameter("hue_cycles", hue_drift)
	mat.set_shader_parameter("card_scale", card_scale)
	mat.set_shader_parameter("aspect", 0.0)
	mat.set_shader_parameter("seed", sparkle_seed)
	mat.set_shader_parameter("supersample", supersample)
	queue_redraw()


## Load a side's art and maps from the CLI's `<name>.json` and the files next to it.
func _load_side(back: bool) -> void:
	var json := back_json if back else card_json
	if back:
		_default_back = json == ""
	if back and json == "":
		json = DEFAULT_BACK_JSON
	if json == "":
		return
	var base := json.get_basename()
	var sibling := func(suffix: String) -> String: return base + suffix + ".png"
	var paths: Array[String] = []
	for suffix in ["_art", "_fx", "_normal", "_frame", "_frame_foil"]:
		if ResourceLoader.exists(sibling.call(suffix)):
			paths.append(sibling.call(suffix))
	if Engine.is_editor_hint():
		_fix_imports(paths)
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(json)) if FileAccess.file_exists(json) else null
	var tex := func(suffix: String) -> Texture2D:
		var p: String = sibling.call(suffix)
		return load(p) if ResourceLoader.exists(p) else null
	if back:
		back_art = tex.call("_art")
		back_fx_map = tex.call("_fx")
		back_normal_map = tex.call("_normal")
	else:
		art = tex.call("_art")
		fx_map = tex.call("_fx")
		normal_map = tex.call("_normal")
		frame_texture = tex.call("_frame")
		frame_foil = tex.call("_frame_foil")
	if info is Dictionary:
		var px: bool = info.get("pixel_art", false)
		var ns: Array = info.get("native_size", [0, 0])
		var steps := int(info.get("hue_steps", 0))
		if back:
			back_pixel_art = px
			back_native_size = Vector2(ns[0], ns[1])
			_back_hue_steps = steps
		else:
			pixel_art = px
			native_size = Vector2(ns[0], ns[1])
			_hue_steps = steps
			if px and steps > 0:
				pixel_hue_steps = steps
			# the card's own finish, when its card file names one
			if info.has("finish"):
				set_finish_name(info["finish"])
	_update()


## The maps are data, not pictures: the FX map's alpha is the pop-out mask (no alpha-border fix,
## no premultiply) and the normal map must not be re-encoded as one. Fix the import settings of any
## that Godot imported as pictures, and reimport them.
static func _fix_imports(paths: Array[String]) -> void:
	var editor := Engine.get_singleton("EditorInterface")
	if editor == null:
		return
	var redo: PackedStringArray = []
	for p in paths:
		var cfg := ConfigFile.new()
		if cfg.load(p + ".import") != OK:
			continue
		var want := {
			"compress/mode": 0,
			"mipmaps/generate": false,
			"process/premult_alpha": false,
		}
		if p.ends_with("_fx.png"):
			want["process/fix_alpha_border"] = false
		if p.ends_with("_normal.png"):
			want["compress/normal_map"] = 2
		var changed := false
		for key in want:
			if cfg.get_value("params", key, null) != want[key]:
				cfg.set_value("params", key, want[key])
				changed = true
		if changed:
			cfg.save(p + ".import")
			redo.append(p)
	if not redo.is_empty():
		editor.get_resource_filesystem().reimport_files(redo)
