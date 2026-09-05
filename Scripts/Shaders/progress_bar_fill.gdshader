shader_type canvas_item;

// progress_bar_fill.gdshader
//
// Fill-only shine for GameProgressBar, derived from the roll_button_glass
// family (diagonal sweep band idiom). The track stays matte — this shader
// never touches it. Sheen motion is driven from GDScript via sheen_phase /
// sheen_strength so it can freeze ~2s after a value change instead of
// shimmering forever. heat = 1 is the overflow variant: hotter base, and
// GDScript runs the phase tween ~1.5x faster.

uniform vec4 base_color : source_color = vec4(0.549020, 0.729412, 0.662745, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
// Band center in UV space; driven from GDScript (pausable). Band crosses the
// bar over roughly -0.2 .. 1.5.
uniform float sheen_phase = -0.2;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.0;
// 0 = normal fill, 1 = overflow hot variant (brighter base, punchier sheen)
uniform float heat : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Vertical glass gradient: darker bottom edge, brighter top edge
	float grad = mix(0.75, 1.1, 1.0 - UV.y);
	vec3 color = base_color.rgb * mix(grad, grad * 1.3, heat);

	// One diagonal sheen band (sweep idiom from roll_button_glass)
	float band = 1.0 - smoothstep(0.0, 0.18, abs((UV.x + UV.y * 0.28) - sheen_phase));
	color += sheen_color.rgb * band * 0.45 * sheen_strength * (1.0 + heat * 0.5);

	COLOR = vec4(color, base_color.a);
}
