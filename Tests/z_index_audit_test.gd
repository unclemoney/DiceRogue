extends Control

## z_index_audit_test.gd
##
## Audits the RenderLayers tier registry (Scripts/Core/render_layers.gd):
##   1. Z_DEBUG_ROOT sits strictly above every other Z_* constant and the
##      LAYER_* overlay chain is ordered.
##   2. The fan/modal z_index band is strictly increasing.
##   3. DebugPanel.tscn / StatisticsPanel.tscn root z_index values.
##   4. Source scan of res://Scripts/ for bare numeric z_index / layer literals.
## Also builds a labeled stacking demo and saves a screenshot.
## Run windowed (NOT headless):
##   godot --path . Tests/z_index_audit_test.tscn

var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

const REGISTRY_PATH := "res://Scripts/Core/render_layers.gd"
const DEBUG_PANEL_PATH := "res://Scenes/UI/DebugPanel.tscn"
const STATISTICS_PANEL_PATH := "res://Scenes/UI/StatisticsPanel.tscn"
const SHOT_PATH := "res://Tests/_layout_shots/z_index_audit.png"

var _pass_count := 0
var _fail_count := 0
var _skip_count := 0


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = RenderLayers.Z_SHADOW - 1
	add_child(bg)

	call_deferred("_run")


func _run() -> void:
	print("\n=== Z-INDEX AUDIT TEST ===")
	_build_stacking_demo()
	_test_debug_root_top()
	_test_fan_band_order()
	_test_scene_root_z_indices()
	_test_source_scan()

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://Tests/_layout_shots")
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(SHOT_PATH)
	print("[ZIndexAuditTest] saved %s (err=%d)" % [SHOT_PATH, err])

	print("=== SUMMARY: %d PASS, %d FAIL, %d SKIP ===" % [_pass_count, _fail_count, _skip_count])
	if _fail_count == 0:
		print("=== OVERALL: PASS ===")
	else:
		print("=== OVERALL: FAIL ===")

	if OS.has_feature("editor"):
		print("[ZIndexAuditTest] Running from editor; leaving scene up for inspection.")
	else:
		get_tree().quit(0 if _fail_count == 0 else 1)


# ─── REPORTING ──────────────────────────────────────────────────────────────

func _report(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass_count += 1
		print("PASS: %s%s" % [label, (" — " + detail) if detail != "" else ""])
	else:
		_fail_count += 1
		print("FAIL: %s%s" % [label, (" — " + detail) if detail != "" else ""])


func _report_skip(label: String, detail: String = "") -> void:
	_skip_count += 1
	print("SKIP: %s%s" % [label, (" — " + detail) if detail != "" else ""])


# ─── TEST 1: DEBUG ROOT ON TOP ──────────────────────────────────────────────

func _parse_registry_constants() -> Dictionary:
	var constants := {}
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return constants
	var regex := RegEx.new()
	regex.compile("^const (Z_[A-Z_0-9]+|LAYER_[A-Z_0-9]+): int += (-?[0-9]+)")
	while not file.eof_reached():
		var line := file.get_line()
		var m := regex.search(line)
		if m:
			constants[m.get_string(1)] = m.get_string(2).to_int()
	return constants


func _test_debug_root_top() -> void:
	print("\n-- Test 1: registry ordering --")
	var constants := _parse_registry_constants()
	if constants.is_empty():
		_report(false, "registry parse", "could not read %s" % REGISTRY_PATH)
		return
	_report(constants.get("Z_DEBUG_ROOT", -1) == RenderLayers.Z_DEBUG_ROOT,
		"registry file agrees with RenderLayers.Z_DEBUG_ROOT",
		"file=%d class=%d" % [constants.get("Z_DEBUG_ROOT", -1), RenderLayers.Z_DEBUG_ROOT])
	var higher: Array[String] = []
	for const_name: String in constants:
		if not const_name.begins_with("Z_") or const_name.begins_with("Z_DEBUG"):
			continue
		if constants[const_name] >= RenderLayers.Z_DEBUG_ROOT:
			higher.append("%s=%d" % [const_name, constants[const_name]])
	_report(higher.is_empty(), "Z_DEBUG_ROOT (%d) strictly above every other Z_* constant" % RenderLayers.Z_DEBUG_ROOT,
		"" if higher.is_empty() else "violations: %s" % ", ".join(higher))
	_report(RenderLayers.LAYER_SCENE_TRANSITION > RenderLayers.LAYER_TOOLTIP,
		"LAYER_SCENE_TRANSITION (%d) > LAYER_TOOLTIP (%d)" % [RenderLayers.LAYER_SCENE_TRANSITION, RenderLayers.LAYER_TOOLTIP])
	_report(RenderLayers.LAYER_TOOLTIP > RenderLayers.LAYER_FAN_OVERLAY,
		"LAYER_TOOLTIP (%d) > LAYER_FAN_OVERLAY (%d)" % [RenderLayers.LAYER_TOOLTIP, RenderLayers.LAYER_FAN_OVERLAY])
	# Overlay ladder: round transition < chore popup < pause menu < debug panel
	var layer_chain: Array = [
		["LAYER_ROUND_TRANSITION", RenderLayers.LAYER_ROUND_TRANSITION],
		["LAYER_CHORE_POPUP", RenderLayers.LAYER_CHORE_POPUP],
		["LAYER_PAUSE_MENU", RenderLayers.LAYER_PAUSE_MENU],
		["LAYER_DEBUG_PANEL", RenderLayers.LAYER_DEBUG_PANEL],
		["LAYER_TOOLTIP", RenderLayers.LAYER_TOOLTIP],
		["LAYER_SCENE_TRANSITION", RenderLayers.LAYER_SCENE_TRANSITION],
	]
	for i in range(1, layer_chain.size()):
		var lower: Array = layer_chain[i - 1]
		var upper: Array = layer_chain[i]
		_report(upper[1] > lower[1], "%s (%d) > %s (%d)" % [upper[0], upper[1], lower[0], lower[1]])


# ─── TEST 2: FAN BAND STRICTLY INCREASING ───────────────────────────────────

func _test_fan_band_order() -> void:
	print("\n-- Test 2: fan band strictly increasing --")
	var chain: Array = [
		["Z_FAN_BG", RenderLayers.Z_FAN_BG],
		["Z_FAN_BG_ALT", RenderLayers.Z_FAN_BG_ALT],
		["Z_FAN_CARD_BASE", RenderLayers.Z_FAN_CARD_BASE],
		["Z_FAN_HOVER", RenderLayers.Z_FAN_HOVER],
		["Z_FAN_TOOLTIP", RenderLayers.Z_FAN_TOOLTIP],
		["Z_FAN_OVERFLOW", RenderLayers.Z_FAN_OVERFLOW],
		["Z_BANNER", RenderLayers.Z_BANNER],
		["Z_SETTINGS", RenderLayers.Z_SETTINGS],
		["Z_SCREEN_FX_LOW", RenderLayers.Z_SCREEN_FX_LOW],
		["Z_SCREEN_FX", RenderLayers.Z_SCREEN_FX],
		["Z_POWERUP_FX", RenderLayers.Z_POWERUP_FX],
		["Z_MOD_SELL", RenderLayers.Z_MOD_SELL],
		["Z_TOOLTIP", RenderLayers.Z_TOOLTIP],
		["Z_DEBUG_ROOT", RenderLayers.Z_DEBUG_ROOT],
	]
	for i in range(1, chain.size()):
		var lower: Array = chain[i - 1]
		var upper: Array = chain[i]
		_report(upper[1] > lower[1], "%s (%d) > %s (%d)" % [upper[0], upper[1], lower[0], lower[1]])


# ─── TEST 3: PANEL ROOT Z_INDICES ───────────────────────────────────────────

func _check_scene_root_z(scene_path: String, expected: int, label: String) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		_report_skip(label, "failed to load %s (missing autoloads or parse error)" % scene_path)
		return
	var inst := packed.instantiate()
	if inst == null:
		_report_skip(label, "failed to instantiate %s (missing autoloads)" % scene_path)
		return
	if inst is CanvasItem:
		var actual: int = (inst as CanvasItem).z_index
		_report(actual == expected, label, "expected root z_index %d, got %d" % [expected, actual])
	else:
		_report(false, label, "root of %s is not a CanvasItem" % scene_path)
	inst.free()


func _test_scene_root_z_indices() -> void:
	print("\n-- Test 3: panel scene root z_index --")
	_check_scene_root_z(DEBUG_PANEL_PATH, RenderLayers.Z_DEBUG_ROOT, "DebugPanel.tscn root z_index == Z_DEBUG_ROOT")
	_check_scene_root_z(STATISTICS_PANEL_PATH, RenderLayers.Z_MODAL, "StatisticsPanel.tscn root z_index == Z_MODAL")


# ─── TEST 4: SOURCE SCAN ────────────────────────────────────────────────────

func _test_source_scan() -> void:
	print("\n-- Test 4: source scan of res://Scripts/ --")
	var z_regex := RegEx.new()
	z_regex.compile("z_index = -?[0-9]")
	var layer_regex := RegEx.new()
	layer_regex.compile("\\blayer = [0-9]")
	var z_offenders: Array[String] = []
	var layer_offenders: Array[String] = []
	_scan_dir("res://Scripts", z_regex, layer_regex, z_offenders, layer_offenders)
	for offender in z_offenders:
		print("  OFFENDER (z_index): %s" % offender)
	_report(z_offenders.is_empty(), "no bare numeric z_index assignments in res://Scripts/",
		"%d offender(s)" % z_offenders.size())
	for offender in layer_offenders:
		print("  OFFENDER (layer): %s" % offender)
	_report(layer_offenders.is_empty(), "no bare numeric layer assignments on CanvasLayers in res://Scripts/",
		"%d offender(s)" % layer_offenders.size())


func _scan_dir(path: String, z_regex: RegEx, layer_regex: RegEx, z_offenders: Array[String], layer_offenders: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_dir(path.path_join(file_name), z_regex, layer_regex, z_offenders, layer_offenders)
		elif file_name.ends_with(".gd"):
			_scan_file(path.path_join(file_name), z_regex, layer_regex, z_offenders, layer_offenders)
		file_name = dir.get_next()
	dir.list_dir_end()


func _scan_file(path: String, z_regex: RegEx, layer_regex: RegEx, z_offenders: Array[String], layer_offenders: Array[String]) -> void:
	if path == REGISTRY_PATH:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var mentions_canvas_layer := text.contains("CanvasLayer")
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i]
		if line.strip_edges().begins_with("#"):
			continue
		if z_regex.search(line):
			z_offenders.append("%s:%d: %s" % [path, i + 1, line.strip_edges()])
		elif mentions_canvas_layer and layer_regex.search(line):
			layer_offenders.append("%s:%d: %s" % [path, i + 1, line.strip_edges()])


# ─── VISUAL STACKING DEMO ───────────────────────────────────────────────────

func _build_stacking_demo() -> void:
	var title := Label.new()
	title.text = "RenderLayers STACKING DEMO — higher tiers overlap lower ones"
	title.position = Vector2(40, 24)
	if vcr_font:
		title.add_theme_font_override("font", vcr_font)
		title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.32, 1.0))
	add_child(title)

	var tiers: Array = [
		["Z_SHADOW", RenderLayers.Z_SHADOW, Color(0.35, 0.35, 0.40)],
		["Z_MODAL", RenderLayers.Z_MODAL, Color(0.25, 0.45, 0.70)],
		["Z_FAN_CARD_BASE", RenderLayers.Z_FAN_CARD_BASE, Color(0.30, 0.60, 0.40)],
		["Z_BANNER", RenderLayers.Z_BANNER, Color(0.75, 0.55, 0.20)],
		["Z_SETTINGS", RenderLayers.Z_SETTINGS, Color(0.60, 0.35, 0.65)],
		["Z_POWERUP_FX", RenderLayers.Z_POWERUP_FX, Color(0.80, 0.30, 0.30)],
		["Z_DEBUG_ROOT", RenderLayers.Z_DEBUG_ROOT, Color(0.90, 0.80, 0.25)],
	]
	for i in tiers.size():
		var entry: Array = tiers[i]
		var tier_name: String = entry[0]
		var tier_value: int = entry[1]
		var panel := Panel.new()
		panel.name = "Demo_%s" % tier_name
		panel.z_index = tier_value
		panel.position = Vector2(40 + i * 165, 110 + i * 70)
		panel.size = Vector2(240, 150)
		var style := StyleBoxFlat.new()
		style.bg_color = entry[2]
		style.border_color = Color(0.05, 0.05, 0.05, 1.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", style)
		add_child(panel)

		var label := Label.new()
		label.text = "%s\n= %d" % [tier_name, tier_value]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_CENTER)
		if vcr_font:
			label.add_theme_font_override("font", vcr_font)
			label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
		panel.add_child(label)
