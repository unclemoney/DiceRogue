extends Control

## ChannelBackgroundTest
##
## Test scene to preview all 20 channel background shaders.
## Loads ChannelDifficultyData resources and applies their background_shader
## to a full-screen ColorRect, simulating what GameController does at runtime.
##
## Controls:
## - Left/Right arrows or A/D: Navigate channels
## - 1-9, 0: Jump to channel 1-10
## - Shift+1-0: Jump to channel 11-20
## - Space: Toggle auto-cycle (3s per channel)
## - ESC: Quit
##
## Side-effects: None. Standalone test scene with no external dependencies.

var background: ColorRect
var label: RichTextLabel
var current_channel: int = 1
var auto_cycle: bool = false
var auto_timer: float = 0.0
const AUTO_CYCLE_INTERVAL: float = 3.0
const TOTAL_CHANNELS: int = 20
var channel_configs: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Pre-load all channel configs
	for i in range(1, TOTAL_CHANNELS + 1):
		var padded = "%02d" % i
		var path = "res://Resources/Data/Channels/channel_%s.tres" % padded
		var config = load(path)
		if config:
			channel_configs.append(config)
		else:
			channel_configs.append(null)
			print("[ChannelBGTest] WARNING: Could not load %s" % path)

	# Background ColorRect
	background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color.WHITE
	add_child(background)

	# Info label
	var panel = Panel.new()
	panel.name = "LabelBG"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)
	panel.size = Vector2(520, 320)
	panel.modulate = Color(1, 1, 1, 0.7)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	label = RichTextLabel.new()
	label.name = "InfoLabel"
	label.bbcode_enabled = true
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.position = Vector2(16, 16)
	label.size = Vector2(512, 312)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 16)
	label.add_theme_color_override("default_color", Color.WHITE)
	add_child(label)

	# Apply first channel
	_apply_channel(1)
	print("[ChannelBGTest] Ready! Left/Right to navigate, Space for auto-cycle, ESC to quit")


func _process(delta: float) -> void:
	if auto_cycle:
		auto_timer += delta
		if auto_timer >= AUTO_CYCLE_INTERVAL:
			auto_timer = 0.0
			var next_ch = current_channel + 1
			if next_ch > TOTAL_CHANNELS:
				next_ch = 1
			_apply_channel(next_ch)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_RIGHT, KEY_D:
				var next_ch = current_channel + 1
				if next_ch > TOTAL_CHANNELS:
					next_ch = 1
				_apply_channel(next_ch)
			KEY_LEFT, KEY_A:
				var prev_ch = current_channel - 1
				if prev_ch < 1:
					prev_ch = TOTAL_CHANNELS
				_apply_channel(prev_ch)
			KEY_SPACE:
				auto_cycle = !auto_cycle
				auto_timer = 0.0
				_update_label()
			KEY_1:
				if event.shift_pressed:
					_apply_channel(11)
				else:
					_apply_channel(1)
			KEY_2:
				if event.shift_pressed:
					_apply_channel(12)
				else:
					_apply_channel(2)
			KEY_3:
				if event.shift_pressed:
					_apply_channel(13)
				else:
					_apply_channel(3)
			KEY_4:
				if event.shift_pressed:
					_apply_channel(14)
				else:
					_apply_channel(4)
			KEY_5:
				if event.shift_pressed:
					_apply_channel(15)
				else:
					_apply_channel(5)
			KEY_6:
				if event.shift_pressed:
					_apply_channel(16)
				else:
					_apply_channel(6)
			KEY_7:
				if event.shift_pressed:
					_apply_channel(17)
				else:
					_apply_channel(7)
			KEY_8:
				if event.shift_pressed:
					_apply_channel(18)
				else:
					_apply_channel(8)
			KEY_9:
				if event.shift_pressed:
					_apply_channel(19)
				else:
					_apply_channel(9)
			KEY_0:
				if event.shift_pressed:
					_apply_channel(20)
				else:
					_apply_channel(10)
			KEY_ESCAPE:
				get_tree().quit()


## _apply_channel(channel: int) -> void
##
## Loads and applies the background shader from the specified channel config.
## Falls back to a gray background if no shader is configured.
func _apply_channel(channel: int) -> void:
	current_channel = channel
	var idx = channel - 1

	if idx < 0 or idx >= channel_configs.size():
		print("[ChannelBGTest] Invalid channel: %d" % channel)
		return

	var config = channel_configs[idx]
	if config == null:
		background.material = null
		background.color = Color(0.2, 0.2, 0.2, 1.0)
		_update_label()
		return

	if config.background_shader != null:
		config.apply_background(background)
	else:
		background.material = null
		background.color = Color(0.1, 0.05, 0.15, 1.0)

	_update_label()
	print("[ChannelBGTest] Channel %d: %s" % [channel, config.display_name])


## _update_label() -> void
##
## Rebuilds the info overlay with current channel details.
func _update_label() -> void:
	var config = channel_configs[current_channel - 1] if (current_channel - 1) < channel_configs.size() else null

	var text = "[b]CHANNEL BACKGROUND TEST[/b]\n\n"
	text += "[color=cyan]Channel %d / %d[/color]\n" % [current_channel, TOTAL_CHANNELS]

	if config:
		text += "[color=yellow]%s[/color]\n" % config.display_name
		text += "[i]%s[/i]\n\n" % config.description

		if config.background_shader:
			var shader_name = config.background_shader.resource_path.get_file()
			text += "[color=green]Shader:[/color] %s\n" % shader_name
			text += "[color=green]Params:[/color] %d overrides\n" % config.background_shader_params.size()

			# Show color params as swatches
			for key in config.background_shader_params:
				var val = config.background_shader_params[key]
				if val is Color:
					text += "  %s: [color=#%s]████[/color]\n" % [key, val.to_html(false)]
				else:
					text += "  %s: %s\n" % [key, str(val)]
		else:
			text += "[color=red]No background shader configured[/color]\n"
	else:
		text += "[color=red]Config not loaded[/color]\n"

	text += "\n[color=gray]── Controls ──[/color]\n"
	text += "Left/Right or A/D: Navigate\n"
	text += "1-9, 0: Channels 1-10\n"
	text += "Shift+1-0: Channels 11-20\n"

	var cycle_status = "[color=green]ON[/color]" if auto_cycle else "[color=red]OFF[/color]"
	text += "Space: Auto-cycle (%s)\n" % cycle_status
	text += "ESC: Quit\n"

	label.text = text
