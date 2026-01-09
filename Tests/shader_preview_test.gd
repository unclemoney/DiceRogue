extends Control

## ShaderPreviewTest
##
## Test scene to preview and compare the three new arcade background shaders.
## Press number keys 1-4 to switch between shaders.

var background: ColorRect
var label: Label
var current_shader_index: int = 0

var shader_configs = [
	{
		"name": "Original Swirl",
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
	},
	{
		"name": "Neon Grid (Tron)",
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
		"name": "VHS Static Wave",
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
		"name": "Arcade Starfield",
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
	}
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Create background
	background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color.WHITE
	add_child(background)
	
	# Create instruction label
	label = Label.new()
	label.name = "Instructions"
	label.position = Vector2(20, 20)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	
	# Apply first shader
	_apply_shader(0)
	
	print("[ShaderPreviewTest] Ready! Press 1-4 to switch shaders, ESC to exit")


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
			KEY_ESCAPE:
				get_tree().quit()


func _apply_shader(index: int) -> void:
	if index < 0 or index >= shader_configs.size():
		return
	
	current_shader_index = index
	var config = shader_configs[index]
	
	print("[ShaderPreviewTest] Loading shader: ", config["name"])
	
	var shader = load(config["path"])
	if not shader:
		print("[ShaderPreviewTest] ERROR: Could not load shader: ", config["path"])
		return
	
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	
	# Apply all parameters
	for param_name in config["params"]:
		shader_mat.set_shader_parameter(param_name, config["params"][param_name])
	
	background.material = shader_mat
	
	# Update label
	var instructions = "Press 1-4 to switch shaders | ESC to quit\n\n"
	instructions += "Current: [%d] %s\n\n" % [index + 1, config["name"]]
	instructions += "1 - Original Swirl (Balatro)\n"
	instructions += "2 - Neon Grid (Tron)\n"
	instructions += "3 - VHS Static Wave\n"
	instructions += "4 - Arcade Starfield"
	
	label.text = instructions
	
	print("[ShaderPreviewTest] Applied shader: ", config["name"])
