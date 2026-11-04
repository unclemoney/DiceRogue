@tool
extends RefCounted
class_name PowerUpFoilBaker

const POWERUP_DATA_DIR := "res://Scripts/PowerUps"
const OUTPUT_DIR := "res://Resources/Art/Powerups/Foilsmith"
const ART_SIZE := 64
const HUE_STEPS := 6


func bake_all() -> void:
	print("Foilsmith PowerUp bake started")
	var success_count := 0
	if not ClassDB.class_exists("FoilsmithNative"):
		push_error("Foilsmith bake failed: FoilsmithNative is unavailable. Enable the Foilsmith plugin.")
		_quit_if_requested(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var data_paths := _find_powerup_data()
	var baked_ids := {}
	var imported_paths: Array[String] = []
	var failures: Array[String] = []
	for data_path in data_paths:
		var data := ResourceLoader.load(data_path) as PowerUpData
		if not _validate_data(data, data_path, failures):
			continue
		if baked_ids.has(data.id):
			failures.append("%s: duplicate PowerUp ID '%s' (first defined by %s)" % [data_path, data.id, baked_ids[data.id]])
			continue
		baked_ids[data.id] = data_path
		var result := await _bake_powerup(data, imported_paths)
		if result.is_empty():
			failures.append("%s (%s): bake failed" % [data.id, data_path])
			continue
		data.foilsmith_card_json = "%s/%s.json" % [OUTPUT_DIR, data.id]
		var error := _save_data_path(data, data_path)
		if error != OK:
			failures.append("%s: could not save %s (error %d)" % [data.id, data_path, error])
			continue
		success_count += 1
		print("Foilsmith PowerUp baked: ", data.id)
	_write_import_settings(imported_paths)
	if not imported_paths.is_empty():
		await _import_outputs(imported_paths)
	print("Foilsmith PowerUp bake complete: %d succeeded, %d failed/skipped" % [success_count, failures.size()])
	for failure in failures:
		push_warning("Foilsmith PowerUp: " + failure)
	_quit_if_requested(0 if failures.is_empty() else 1)


func _quit_if_requested(exit_code: int) -> void:
	if OS.get_cmdline_user_args().has("--quit-after-bake"):
		var tree := Engine.get_main_loop() as SceneTree
		tree.quit(exit_code)


func _find_powerup_data() -> Array[String]:
	var paths: Array[String] = []
	for file in DirAccess.get_files_at(POWERUP_DATA_DIR):
		if file.ends_with(".tres"):
			paths.append(POWERUP_DATA_DIR.path_join(file))
	paths.sort()
	return paths


func _validate_data(data: PowerUpData, path: String, failures: Array[String]) -> bool:
	if not data:
		return false
	if data.id.is_empty():
		failures.append(path + ": empty PowerUp ID")
		return false
	if not data.icon:
		failures.append("%s (%s): missing icon" % [data.id, path])
		return false
	return true


func _bake_powerup(data: PowerUpData, imported_paths: Array[String]) -> Dictionary:
	var base_path := OUTPUT_DIR.path_join(data.id)
	var source := _normalized_source(data.icon)
	if source == null:
		return {}
	if source.save_png(base_path + "_source.png") != OK:
		return {}
	var depth := _load_image(base_path + "_depth.png")
	if depth == null:
		depth = await _estimate_depth(source)
		if depth == null:
			push_error("Foilsmith depth needs the Forward+ or Mobile renderer: " + data.id)
			return {}
		if depth.save_png(base_path + "_depth.png") != OK:
			return {}
	var spec := _custom_frame_spec()
	var result: Dictionary = ClassDB.class_call_static(
		"FoilsmithNative",
		"build",
		source,
		depth,
		JSON.stringify(spec),
		{},
		-1,
		HUE_STEPS
	)
	if result.has("error"):
		push_error("Foilsmith build for %s: %s" % [data.id, result.error])
		return {}
	for key in ["art", "fx", "normal"]:
		if not result.has(key):
			push_error("Foilsmith build for %s omitted %s" % [data.id, key])
			return {}
		var output_path := "%s_%s.png" % [base_path, key]
		if (result[key] as Image).save_png(output_path) != OK:
			return {}
		imported_paths.append(output_path)
	for key in ["frame", "frame_foil"]:
		if result.has(key):
			var output_path := "%s_%s.png" % [base_path, key]
			(result[key] as Image).save_png(output_path)
			imported_paths.append(output_path)
	var info: Variant = JSON.parse_string(result.get("info", "{}"))
	if not info is Dictionary:
		return {}
	info["finish"] = "holo"
	info["pixel_art"] = true
	info["native_size"] = [ART_SIZE, ART_SIZE]
	info["hue_steps"] = HUE_STEPS
	var json_file := FileAccess.open(base_path + ".json", FileAccess.WRITE)
	if json_file == null:
		return {}
	json_file.store_string(JSON.stringify(info, "  ", false) + "\n")
	json_file.close()
	imported_paths.append(base_path + "_source.png")
	imported_paths.append(base_path + "_depth.png")
	return result


func _normalized_source(texture: Texture2D) -> Image:
	var original := texture.get_image()
	if original == null or original.is_empty():
		return null
	if original.is_compressed():
		original.decompress()
	original.convert(Image.FORMAT_RGBA8)
	var scale_factor := minf(float(ART_SIZE) / original.get_width(), float(ART_SIZE) / original.get_height())
	var resized_size := Vector2i(
		maxi(1, roundi(original.get_width() * scale_factor)),
		maxi(1, roundi(original.get_height() * scale_factor))
	)
	if resized_size != original.get_size():
		original.resize(resized_size.x, resized_size.y, Image.INTERPOLATE_NEAREST)
	var output := Image.create(ART_SIZE, ART_SIZE, false, Image.FORMAT_RGBA8)
	output.fill(Color(0.0, 0.0, 0.0, 0.0))
	var offset := (Vector2i(ART_SIZE, ART_SIZE) - resized_size) / 2
	output.blit_rect(original, Rect2i(Vector2i.ZERO, resized_size), offset)
	return output


func _custom_frame_spec() -> Dictionary:
	var frame := FoilsmithFrame.new()
	frame.corner_radius = 0.0
	frame.border_width = 0.0
	frame.padding = 0.0
	frame.dark_rim = 0.0
	frame.painted_body = false
	var art := FrameArt.new()
	frame.add_child(art)
	art.height = 100.0
	art.corner_radius = 0.0
	art.trim = "none"
	art.foil = "full"
	var spec := frame.to_spec()
	art.free()
	frame.free()
	return spec


func _estimate_depth(source: Image) -> Image:
	if not Engine.is_editor_hint() or OS.get_cmdline_user_args().has("--sync-depth"):
		return FoilsmithDepth.estimate(source)
	var result: Image = null
	var completed := false
	var started := FoilsmithDepth.estimate_async(source, func(depth: Image) -> void:
		result = depth
		completed = true
	)
	if not started:
		return null
	var tree := Engine.get_main_loop() as SceneTree
	while not completed:
		await tree.process_frame
	return result


func _load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return image


func _import_outputs(paths: Array[String]) -> void:
	if not Engine.is_editor_hint():
		return
	var editor := Engine.get_singleton("EditorInterface")
	var filesystem: EditorFileSystem = editor.get_resource_filesystem()
	filesystem.scan()
	var tree := Engine.get_main_loop() as SceneTree
	while filesystem.is_scanning():
		await tree.process_frame
	FoilsmithCard._fix_imports(paths)
	for _attempt in range(120):
		var importing: bool = filesystem.has_method("is_importing") and filesystem.call("is_importing")
		if not filesystem.is_scanning() and not importing:
			break
		await tree.create_timer(0.25).timeout


func _write_import_settings(paths: Array[String]) -> void:
	for path in paths:
		var config := ConfigFile.new()
		config.load(path + ".import")
		config.set_value("params", "compress/mode", 0)
		config.set_value("params", "mipmaps/generate", false)
		config.set_value("params", "process/premult_alpha", false)
		if path.ends_with("_fx.png"):
			config.set_value("params", "process/fix_alpha_border", false)
		if path.ends_with("_normal.png"):
			config.set_value("params", "compress/normal_map", 2)
		config.save(path + ".import")


func _save_data_path(data: PowerUpData, data_path: String) -> Error:
	var text := FileAccess.get_file_as_string(data_path)
	var property_line := "foilsmith_card_json = \"%s\"" % data.foilsmith_card_json
	var existing := RegEx.new()
	existing.compile("(?m)^foilsmith_card_json = \".*\"$")
	if existing.search(text):
		text = existing.sub(text, property_line, true)
	else:
		var icon_property := RegEx.new()
		icon_property.compile("(?m)^icon = .+$")
		var icon_match := icon_property.search(text)
		if icon_match == null:
			return ERR_INVALID_DATA
		var newline := "\r\n" if text.contains("\r\n") else "\n"
		var insert_at := icon_match.get_end()
		text = text.substr(0, insert_at) + newline + property_line + text.substr(insert_at)
	var file := FileAccess.open(data_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK
