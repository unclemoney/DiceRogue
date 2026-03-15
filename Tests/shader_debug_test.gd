extends Control

## shader_debug_test.gd
##
## Debug / demo scene for the neon_energy and score_panel_energy shaders.
## Run directly in the editor to visually verify shader behaviour.
## Use the on-screen buttons to cycle effect_strength and milestone_tier.

@onready var additive_rect: ColorRect = $VBoxContainer/ShaderRow/AdditivePanel/AdditiveShaderRect
@onready var multiplier_rect: ColorRect = $VBoxContainer/ShaderRow/MultiplierPanel/MultiplierShaderRect
@onready var score_panel_rect: ColorRect = $VBoxContainer/ScorePanelDemo/ScorePanelShaderRect

@onready var additive_label: Label = $VBoxContainer/ShaderRow/AdditivePanel/AdditiveLabel
@onready var multiplier_label: Label = $VBoxContainer/ShaderRow/MultiplierPanel/MultiplierLabel
@onready var score_panel_label: RichTextLabel = $VBoxContainer/ScorePanelDemo/ScorePanelLabel

@onready var strength_slider: HSlider = $VBoxContainer/Controls/StrengthRow/StrengthSlider
@onready var strength_value_label: Label = $VBoxContainer/Controls/StrengthRow/StrengthValue
@onready var intensity_slider: HSlider = $VBoxContainer/Controls/IntensityRow/IntensitySlider
@onready var intensity_value_label: Label = $VBoxContainer/Controls/IntensityRow/IntensityValue
@onready var tier_label: Label = $VBoxContainer/Controls/TierRow/TierLabel

var current_tier := 0


func _ready() -> void:
	# Make panel backgrounds semi-transparent so shader effects are visible
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.3)
	panel_style.set_corner_radius_all(4)
	panel_style.border_color = Color(0.3, 0.3, 0.5, 0.5)
	panel_style.set_border_width_all(1)
	$VBoxContainer/ShaderRow/AdditivePanel.add_theme_stylebox_override("panel", panel_style)
	$VBoxContainer/ShaderRow/MultiplierPanel.add_theme_stylebox_override("panel", panel_style.duplicate())
	$VBoxContainer/ScorePanelDemo.add_theme_stylebox_override("panel", panel_style.duplicate())

	# Set initial slider values
	strength_slider.value = 0.8
	intensity_slider.value = 0.6

	# Connect signals
	strength_slider.value_changed.connect(_on_strength_changed)
	intensity_slider.value_changed.connect(_on_intensity_changed)

	# Apply initial values
	_on_strength_changed(strength_slider.value)
	_on_intensity_changed(intensity_slider.value)
	_update_tier_display()
	print("[ShaderDebugTest] Ready — use sliders to adjust shaders")


func _on_strength_changed(value: float) -> void:
	strength_value_label.text = "%.2f" % value
	_set_all_shader_param("effect_strength", value)


func _on_intensity_changed(value: float) -> void:
	intensity_value_label.text = "%.2f" % value
	_set_all_shader_param("intensity", value)


func _on_tier_up_pressed() -> void:
	current_tier = mini(current_tier + 1, 4)
	_update_tier_display()


func _on_tier_down_pressed() -> void:
	current_tier = maxi(current_tier - 1, 0)
	_update_tier_display()


func _on_division_toggle_pressed() -> void:
	# Toggle multiplier between normal cyan and division-mode red
	if multiplier_rect and multiplier_rect.material:
		var mat = multiplier_rect.material as ShaderMaterial
		var current_color = mat.get_shader_parameter("energy_color")
		if current_color.x > 0.5:
			# Currently red-ish, switch back to cyan
			mat.set_shader_parameter("energy_color", Color(0.2, 0.8, 1.0, 1.0))
			mat.set_shader_parameter("accent_color", Color(0.1, 0.4, 1.0, 1.0))
			multiplier_label.text = "x3.5"
			multiplier_label.modulate = Color.CYAN
		else:
			# Switch to division red
			mat.set_shader_parameter("energy_color", Color(1.0, 0.1, 0.0, 1.0))
			mat.set_shader_parameter("accent_color", Color(0.8, 0.0, 0.0, 1.0))
			multiplier_label.text = "÷2.0"
			multiplier_label.modulate = Color.RED


func _update_tier_display() -> void:
	var tier_names = ["Dim White (0-99)", "Gold (100-249)", "Blue (250-499)", "Purple (500-999)", "Rainbow (1000+)"]
	tier_label.text = "Tier %d: %s" % [current_tier, tier_names[current_tier]]
	if score_panel_rect and score_panel_rect.material:
		(score_panel_rect.material as ShaderMaterial).set_shader_parameter("milestone_tier", current_tier)


func _set_all_shader_param(param_name: String, value: float) -> void:
	for rect in [additive_rect, multiplier_rect, score_panel_rect]:
		if rect and rect.material:
			(rect.material as ShaderMaterial).set_shader_parameter(param_name, value)
