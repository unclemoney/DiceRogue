extends SceneTree

## Headless smoke test: verify all PowerUp .tres files load with valid
## AtlasTexture icons, and that the edited UI script parses.

func _init() -> void:
	var failures := 0

	var script_res = load("res://Scripts/UI/power_up_ui.gd")
	if script_res == null:
		printerr("FAIL: power_up_ui.gd failed to parse")
		failures += 1
	else:
		print("OK: power_up_ui.gd parsed")

	var dir := DirAccess.open("res://Scripts/PowerUps")
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var path := "res://Scripts/PowerUps/" + f
		var r = ResourceLoader.load(path)
		if r == null:
			printerr("FAIL load: ", f)
			failures += 1
			continue
		var icon = r.get("icon")
		if icon == null or not icon is AtlasTexture:
			printerr("FAIL icon: ", f)
			failures += 1
			continue
		var atlas = (icon as AtlasTexture).atlas
		if atlas == null:
			printerr("FAIL atlas: ", f)
			failures += 1
			continue
		var region: Rect2 = (icon as AtlasTexture).region
		if region.size.x < 100 or region.size.y < 100:
			printerr("FAIL region too small: ", f, " ", region)
			failures += 1
			continue
		print("OK ", f, " id=", r.get("id"), " rating=", r.get("rating"),
			" sheet=", atlas.resource_path.get_file(), " region=", region)

	print("failures: ", failures)
	quit(failures)
