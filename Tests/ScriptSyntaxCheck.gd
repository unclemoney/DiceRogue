extends SceneTree

func _init():
	var scripts = [
		"res://Scripts/Shaders/tv_power_on.gdshader",
		"res://Scripts/Effects/tv_power_controller.gd",
		"res://Scripts/Effects/CRTManager.gd",
		"res://Scripts/UI/new_round_panel.gd",
		"res://Scripts/UI/score_card_ui.gd",
		"res://Scripts/UI/game_button_ui.gd",
		"res://Scripts/Core/game_controller.gd",
		"res://Scripts/UI/debug_panel.gd",
	]
	var ok = true
	for path in scripts:
		if path.ends_with(".gdshader"):
			var res = load(path)
			if res:
				print("OK: " + path)
			else:
				print("FAIL: " + path)
				ok = false
		else:
			var res = load(path)
			if res:
				print("OK: " + path)
			else:
				print("FAIL: " + path)
				ok = false
	if ok:
		print("ALL SCRIPTS LOADED SUCCESSFULLY")
	else:
		print("SOME SCRIPTS FAILED TO LOAD")
	quit()
