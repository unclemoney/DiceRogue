extends Control

## ShaderGallery
##
## Interactive test scene to preview, compare, and tune all background shaders.
## Includes the 4 original shaders plus 3 new creative background shaders.
##
## Controls:
## - Keys 1-7: Switch between shaders
## - C: Toggle comparison mode (side-by-side)
## - Left/Right arrows: Change comparison shader in comparison mode
## - ESC: Quit
##
## Side-effects: None. Standalone test scene with no external dependencies.

var background: ColorRect
var compare_bg_left: ColorRect
var compare_bg_right: ColorRect
var label: RichTextLabel
var comparison_mode: bool = false
var current_shader_index: int = 0
var compare_shader_index: int = 1
var compare_container: HBoxContainer

var shader_configs: Array = [
	{
		"name": "1. Plasma Screen",
		"description": "Classic demoscene organic plasma (Amiga/C64 era)",
		"path": "res://Scripts/Shaders/plasma_screen.gdshader",
		"params": {
			"colour_1": Color(0.08, 0.04, 0.15, 1.0),
			"colour_2": Color(0.6, 0.0, 0.9, 1.0),
			"colour_3": Color(0.0, 0.75, 0.8, 1.0),
			"plasma_speed": 0.4,
			"pixel_filter": 500.0,
			"plasma_scale": 1.5,
			"color_cycle_speed": 0.8,
			"contrast": 1.2,
			"warp_intensity": 0.3,
			"scanline_strength": 0.15
		}
	},
	{
		"name": "2. Arcade Carpet - Diamonds",
		"description": "90s mall carpet geometric patterns (Diamond style)",
		"path": "res://Scripts/Shaders/arcade_carpet.gdshader",
		"params": {
			"colour_1": Color(0.06, 0.02, 0.12, 1.0),
			"colour_2": Color(0.5, 0.0, 0.8, 1.0),
			"colour_3": Color(0.0, 0.75, 0.75, 1.0),
			"colour_4": Color(1.0, 0.2, 0.5, 1.0),
			"colour_5": Color(0.0, 0.9, 0.4, 1.0),
			"scroll_speed": 0.15,
			"pixel_filter": 450.0,
			"tile_size": 12.0,
			"pattern_style": 0,
			"fabric_texture": 0.25,
			"glow_amount": 0.4
		}
	},
	{
		"name": "3. Arcade Carpet - Starbursts",
		"description": "Bowling alley carpet with starbursts & rings",
		"path": "res://Scripts/Shaders/arcade_carpet.gdshader",
		"params": {
			"colour_1": Color(0.06, 0.02, 0.12, 1.0),
			"colour_2": Color(0.5, 0.0, 0.8, 1.0),
			"colour_3": Color(0.0, 0.75, 0.75, 1.0),
			"colour_4": Color(1.0, 0.2, 0.5, 1.0),
			"colour_5": Color(0.0, 0.9, 0.4, 1.0),
			"scroll_speed": 0.12,
			"pixel_filter": 450.0,
			"tile_size": 10.0,
			"pattern_style": 1,
			"fabric_texture": 0.3,
			"glow_amount": 0.35
		}
	},
	{
		"name": "4. Arcade Carpet - Memphis",
		"description": "Memphis design squiggles & triangles",
		"path": "res://Scripts/Shaders/arcade_carpet.gdshader",
		"params": {
			"colour_1": Color(0.06, 0.02, 0.12, 1.0),
			"colour_2": Color(0.5, 0.0, 0.8, 1.0),
			"colour_3": Color(0.0, 0.75, 0.75, 1.0),
			"colour_4": Color(1.0, 0.2, 0.5, 1.0),
			"colour_5": Color(0.0, 0.9, 0.4, 1.0),
			"scroll_speed": 0.1,
			"pixel_filter": 450.0,
			"tile_size": 14.0,
			"pattern_style": 2,
			"fabric_texture": 0.2,
			"glow_amount": 0.5
		}
	},
	{
		"name": "5. Marquee Lights",
		"description": "Theater/casino chasing bulb borders",
		"path": "res://Scripts/Shaders/marquee_lights.gdshader",
		"params": {
			"colour_1": Color(0.05, 0.02, 0.1, 1.0),
			"colour_2": Color(1.0, 0.85, 0.2, 1.0),
			"colour_3": Color(0.15, 0.08, 0.05, 1.0),
			"bulb_alt_1": Color(0.0, 0.9, 0.8, 1.0),
			"bulb_alt_2": Color(0.8, 0.0, 1.0, 1.0),
			"chase_speed": 1.0,
			"pixel_filter": 500.0,
			"bulb_size": 0.035,
			"bulb_spacing": 0.07,
			"glow_radius": 1.8,
			"frame_count": 3,
			"inner_pattern": 0.5
		}
	},
	{
		"name": "6. Neon Grid (original)",
		"description": "Tron-inspired perspective grid",
		"path": "res://Scripts/Shaders/neon_grid.gdshader",
		"params": {
			"colour_1": Color(0.15, 0.08, 0.25, 1.0),
			"colour_2": Color(0.0, 0.8, 0.8, 1.0),
			"colour_3": Color(0.8, 0.0, 1.0, 1.0),
			"grid_speed": 0.3,
			"pixel_filter": 500.0,
			"grid_density": 20.0,
			"perspective_strength": 1.0,
			"glow_intensity": 1.2,
			"scanline_strength": 0.3
		}
	},
	{
		"name": "7. VHS Static Wave (original)",
		"description": "Analog TV interference with chromatic drift",
		"path": "res://Scripts/Shaders/vhs_wave.gdshader",
		"params": {
			"colour_1": Color(0.08, 0.04, 0.15, 1.0),
			"colour_2": Color(0.25, 0.12, 0.35, 1.0),
			"colour_3": Color(0.0, 0.6, 0.7, 1.0),
			"wave_speed": 0.5,
			"pixel_filter": 500.0,
			"wave_density": 8.0,
			"wave_amplitude": 0.05,
			"chromatic_drift": 0.02,
			"noise_strength": 0.15,
			"scanline_intensity": 0.4
		}
	},
	{
		"name": "8. Arcade Starfield (original)",
		"description": "Multi-layer parallax stars with 80s color cycling",
		"path": "res://Scripts/Shaders/arcade_starfield.gdshader",
		"params": {
			"colour_1": Color(0.08, 0.04, 0.15, 1.0),
			"colour_2": Color(0.8, 0.0, 1.0, 1.0),
			"colour_3": Color(0.0, 0.8, 0.8, 1.0),
			"star_speed": 0.2,
			"pixel_filter": 500.0,
			"star_density": 200.0,
			"twinkle_speed": 2.0,
			"comet_trails": 0.3,
			"color_cycle_speed": 1.0
		}
	},
	{
		"name": "9. Original Swirl (Balatro)",
		"description": "Paint swirl effect (legacy reference)",
		"path": "res://Scripts/Shaders/backgground_swirl.gdshader",
		"params": {
			"colour_1": Color(0.15, 0.08, 0.25, 1.0),
			"colour_2": Color(0.25, 0.12, 0.35, 1.0),
			"colour_3": Color(0.08, 0.04, 0.15, 1.0),
			"spin_speed": 0.5,
			"contrast": 1.5,
			"spin_amount": 0.3,
			"lighting": 0.5,
			"pixel_filter": 500.0
		}
	}
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# === Single shader view ===
	background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color.WHITE
	add_child(background)

	# === Comparison mode container (hidden initially) ===
	compare_container = HBoxContainer.new()
	compare_container.name = "CompareContainer"
	compare_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	compare_container.visible = false
	compare_container.add_theme_constant_override("separation", 4)
	add_child(compare_container)

	compare_bg_left = ColorRect.new()
	compare_bg_left.name = "CompareLeft"
	compare_bg_left.color = Color.WHITE
	compare_bg_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare_container.add_child(compare_bg_left)

	compare_bg_right = ColorRect.new()
	compare_bg_right.name = "CompareRight"
	compare_bg_right.color = Color.WHITE
	compare_bg_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare_container.add_child(compare_bg_right)

	# === Info label overlay ===
	label = RichTextLabel.new()
	label.name = "InfoLabel"
	label.bbcode_enabled = true
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.position = Vector2(16, 16)
	label.size = Vector2(500, 400)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_color_override("default_color", Color.WHITE)
	add_child(label)

	# Add a dark panel behind the label for readability
	var panel = Panel.new()
	panel.name = "LabelBG"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(508, 408)
	panel.modulate = Color(1, 1, 1, 0.6)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	move_child(panel, get_child_count() - 2) # Behind label

	# Apply first shader
	_apply_shader(0)

	print("[ShaderGallery] Ready! Keys 1-9 to switch, C for compare, ESC to quit")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_apply_shader(0)
			KEY_2:
				_apply_shader(1)
			KEY_3:
				_apply_shader(2)
			KEY_4:
				_apply_shader(3)
			KEY_5:
				_apply_shader(4)
			KEY_6:
				_apply_shader(5)
			KEY_7:
				_apply_shader(6)
			KEY_8:
				_apply_shader(7)
			KEY_9:
				_apply_shader(8)
			KEY_C:
				_toggle_comparison()
			KEY_LEFT:
				if comparison_mode:
					compare_shader_index = wrapi(compare_shader_index - 1, 0, shader_configs.size())
					_update_comparison()
			KEY_RIGHT:
				if comparison_mode:
					compare_shader_index = wrapi(compare_shader_index + 1, 0, shader_configs.size())
					_update_comparison()
			KEY_ESCAPE:
				get_tree().quit()


## _apply_shader(index)
##
## Loads a shader configuration by index and applies it to the background.
## Updates the info label with shader details and controls.
func _apply_shader(index: int) -> void:
	if index < 0 or index >= shader_configs.size():
		return

	current_shader_index = index

	if comparison_mode:
		_update_comparison()
	else:
		var config = shader_configs[index]
		_apply_shader_to_rect(background, config)
		_update_label()

	print("[ShaderGallery] Applied: ", shader_configs[index]["name"])


## _apply_shader_to_rect(rect, config)
##
## Applies a shader configuration dictionary to a given ColorRect node.
func _apply_shader_to_rect(rect: ColorRect, config: Dictionary) -> void:
	var shader = load(config["path"])
	if not shader:
		print("[ShaderGallery] ERROR: Could not load: ", config["path"])
		return

	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader

	for param_name in config["params"]:
		shader_mat.set_shader_parameter(param_name, config["params"][param_name])

	rect.material = shader_mat


## _toggle_comparison()
##
## Switches between single shader view and side-by-side comparison mode.
func _toggle_comparison() -> void:
	comparison_mode = !comparison_mode

	background.visible = !comparison_mode
	compare_container.visible = comparison_mode

	if comparison_mode:
		# Set compare index to next shader
		compare_shader_index = wrapi(current_shader_index + 1, 0, shader_configs.size())
		_update_comparison()
	else:
		_apply_shader(current_shader_index)


## _update_comparison()
##
## Updates both side-by-side panels in comparison mode.
func _update_comparison() -> void:
	_apply_shader_to_rect(compare_bg_left, shader_configs[current_shader_index])
	_apply_shader_to_rect(compare_bg_right, shader_configs[compare_shader_index])
	_update_label()


## _update_label()
##
## Rebuilds the info label text based on current mode and shader selection.
func _update_label() -> void:
	var text = "[b]SHADER GALLERY[/b]\n"

	if comparison_mode:
		text += "[color=yellow]COMPARISON MODE[/color]\n"
		text += "Left: [color=cyan]%s[/color]\n" % shader_configs[current_shader_index]["name"]
		text += "Right: [color=cyan]%s[/color]\n" % shader_configs[compare_shader_index]["name"]
		text += "[i]%s[/i]\n\n" % shader_configs[compare_shader_index]["description"]
		text += "Left/Right arrows: change right shader\n"
		text += "1-9: change left shader\n"
	else:
		var config = shader_configs[current_shader_index]
		text += "\n[color=cyan]%s[/color]\n" % config["name"]
		text += "[i]%s[/i]\n\n" % config["description"]
		text += "[color=gray]Parameters:[/color]\n"
		for param_name in config["params"]:
			var val = config["params"][param_name]
			if val is Color:
				text += "  %s: [color=#%s]████[/color]\n" % [param_name, val.to_html(false)]
			else:
				text += "  %s: %s\n" % [param_name, str(val)]

	text += "\n[color=gray]── Controls ──[/color]\n"
	text += "1-9: Switch shaders\n"
	text += "C: Toggle comparison\n"
	text += "ESC: Quit\n"

	text += "\n[color=gray]── Shader List ──[/color]\n"
	for i in range(shader_configs.size()):
		var marker = " ◄" if i == current_shader_index else ""
		text += "%s%s\n" % [shader_configs[i]["name"], marker]

	label.text = text
