# Glass Button Shader Standard

This document defines the standard pattern for creating shader-backed glass buttons in DiceRogue. It uses the glass action button implementation as the reference pattern and is intended to be reused for future buttons that need a luminous, glassy neon appearance.

## Goal

The goal is to keep button creation consistent across the project:

- a single root `Control` owns the visuals
- a `ColorRect` provides the shader surface
- a transparent `Button` provides the click target
- text sits on top of the shader without losing readability
- colors are driven by a palette dictionary so different buttons can share the same shader while varying their look

This pattern is implemented in:

- `Scripts/UI/glass_action_button.gd`
- `Scripts/Shaders/shop_reroll_button_glass.gdshader`

The same pattern is also used by the main roll button in:

- `Scripts/UI/roll_button_ui.gd`
- `Scripts/Shaders/roll_button_glass.gdshader`

---

## Standard structure

A reusable shader button should be built in this order:

1. Create a root `Control` or `Node` to hold the UI.
2. Add a full-size `ColorRect` named `ShaderRect`.
3. Load the desired shader and create a `ShaderMaterial`.
4. Assign the material to the `ColorRect`.
5. Add a `MarginContainer` to hold the text.
6. Add a centered label or content layout.
7. Add a transparent `Button` with `flat = true` and empty styleboxes over the full area.
8. Connect hover, press, and disable states to the material parameters.
9. Use a palette dictionary to vary the color set per button class or use case.

### Core creation pattern

```gdscript
func _build_ui() -> void:
	shader_rect = ColorRect.new()
	shader_rect.name = "ShaderRect"
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_rect.color = Color.WHITE
	add_child(shader_rect)

	var shader = load(SHADER_PATH) as Shader
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		shader_material.set_shader_parameter("hover_strength", 0.0)
		shader_material.set_shader_parameter("pulse_strength", 0.0)
		shader_material.set_shader_parameter("press_flash", 0.0)
		shader_material.set_shader_parameter("disabled_factor", 0.0)
		shader_rect.material = shader_material

	content_margin = MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(content_margin)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content_margin.add_child(title_label)

	overlay_button = Button.new()
	overlay_button.name = "OverlayButton"
	overlay_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_button.flat = true
	add_child(overlay_button)
```

This is the reusable structure to follow for all future glass buttons.

---

## Shader application pattern

The shader is applied to the `ColorRect`, not directly to the `Button`.

That is intentional:

- the `Button` is the interaction target
- the `ColorRect` is the visible surface
- the text sits on top of the visible surface
- the shader can animate hover, pulse, flash, and disabled-state visuals without affecting button logic

### Important setup details

In `GlassActionButton._build_ui()`, the shader is loaded and assigned like this:

```gdscript
var shader = load(SHADER_PATH) as Shader
if shader:
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("hover_strength", 0.0)
	shader_material.set_shader_parameter("pulse_strength", 0.0)
	shader_material.set_shader_parameter("press_flash", 0.0)
	shader_material.set_shader_parameter("disabled_factor", 0.0)
	shader_rect.material = shader_material
```

This makes the shader material the actual visual layer, while the button remains a separate click region.

---

## Palette-driven color system

The key to making this pattern reusable is the palette dictionary. Different button styles can keep the same base shader and only change the color uniforms.

### Default palette contract

The shared shader uses these uniforms:

- `base_color`
- `mid_color`
- `glow_color`
- `accent_color`
- `rim_color`
- `specular_color`

These are set through the `set_palette()` method:

```gdscript
func set_palette(palette: Dictionary) -> void:
	if shader_material == null:
		return

	_apply_shader_color("accent_color", palette, Color(0.47451, 0.886275, 0.890196, 1.0))
	_apply_shader_color("glow_color", palette, Color(0.968627, 0.941176, 1.0, 1.0))
	_apply_shader_color("base_color", palette, Color(0.137255, 0.411765, 0.415686, 0.92))
	_apply_shader_color("mid_color", palette, Color(0.2, 0.56, 0.56, 0.96))
	_apply_shader_color("rim_color", palette, Color(0.968627, 0.941176, 1.0, 1.0))
	_apply_shader_color("specular_color", palette, Color(0.917647, 1.0, 0.984314, 1.0))

	_font_color = palette.get("font_color", DEFAULT_FONT_COLOR)
	var font_outline: Color = palette.get("font_outline_color", DEFAULT_FONT_OUTLINE)
	if title_label:
		title_label.add_theme_color_override("font_color", _font_color)
		title_label.add_theme_color_override("font_outline_color", font_outline)
		if palette.has("outline_size"):
			title_label.add_theme_constant_override("outline_size", palette.get("outline_size", 1))
```

This means a button can be re-skinned without rewriting the shader logic.

---

## How colors vary between buttons

Each button type uses a different palette, while sharing the same glass shader. The shader is not hard-coded to one color theme; the values are tuned per use case.

### Example: green glass action button

This palette creates a cool green/teal glass feel:

```gdscript
var palette = {
	"accent_color": Color(0.16, 0.82, 0.48, 1.0),
	"glow_color": Color(0.95, 0.88, 0.34, 1.0),
	"base_color": Color(0.10, 0.22, 0.18, 0.98),
	"mid_color": Color(0.16, 0.32, 0.26, 0.98),
	"rim_color": Color(0.96, 0.97, 0.88, 1.0),
	"font_color": Color(0.9686, 0.9412, 1.0, 1.0),
	"font_outline_color": Color(0.1294, 0.1216, 0.2, 1.0),
	"outline_size": 1
}
```

This style is used for the reroll/shop-style action glass buttons and gives the button a vivid green energy with gold glow highlights.

### Design intent behind the color mapping

- `base_color`: the dark underlying fill of the glass panel
- `mid_color`: the mid-tone gradient beneath the highlight
- `accent_color`: the main saturated accent, often pushing the CTA energy
- `glow_color`: the luminous bloom or light edge around the button
- `rim_color`: the bright rim or edge light
- `specular_color`: the reflective sheen and glass highlights

This creates a layered glass treatment: dark body + accent energy + bright reflection + soft glow.

---

## Button state behavior

The shader is animated by parameters that represent the button's state:

- `hover_strength`: strengthens the glow on mouseover
- `pulse_strength`: keeps an idle or selected pulse alive
- `press_flash`: flashes during click input
- `disabled_factor`: darkens or desaturates when disabled

### Toggle and selected state

A useful pattern for future buttons is the toggle behavior defined in `GlassActionButton`:

```gdscript
func _apply_selected_visual() -> void:
	if shader_material == null:
		return
	if _is_toggled:
		shader_material.set_shader_parameter("pulse_strength", SELECTED_PULSE_STRENGTH)
		shader_material.set_shader_parameter("hover_strength", SELECTED_HOVER_STRENGTH)
	else:
		shader_material.set_shader_parameter("pulse_strength", 0.0)
		shader_material.set_shader_parameter("hover_strength", 0.0)
```

This allows buttons to maintain a subtle selected glow while still using the same shader.

---

## Recommended future-button standard

When adding a new glass button, follow this checklist:

1. Reuse the `GlassActionButton` pattern or a small variant of it.
2. Keep the shader on a `ColorRect`, not on the clickable `Button`.
3. Use a single `ShaderMaterial` per button.
4. Expose a `palette` dictionary for easy per-button color variation.
5. Keep the text as a separate label on top of the shader surface.
6. Use the same parameter names and animate them consistently:
   - `hover_strength`
   - `pulse_strength`
   - `press_flash`
   - `disabled_factor`
7. Use palette values to set mood and emphasis instead of editing the shader itself for each button.

---

## Practical rule of thumb

Use this rule when deciding whether a new button should use the standard:

- If it is a clickable UI control with a glass neon look, use the standard glass shader pattern.
- If it needs a different behavior but still a glass treatment, keep the same structure and only change the palette and shader parameters.
- If it needs a completely different effect, create a new shader, but still preserve the same stable UI layering pattern: `ColorRect` visual + `Button` input + label overlay.

---

## Summary

The glass button standard is:

- consistent layout
- shader-backed visual layer
- transparent click surface
- labeled content overlay
- palette-driven color variation

This preserves a uniform UI language while allowing each button to feel distinct. The design system is intentionally modular: the shader stays mostly constant, and the colors and motion intensity change based on button role.
