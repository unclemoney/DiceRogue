shader_type canvas_item;

uniform float glow_strength = 0.0;
uniform float x_rot : hint_range(-15.0, 15.0) = 0.0;
uniform float y_rot : hint_range(-15.0, 15.0) = 0.0;
uniform float flash_strength = 0.0;
uniform float color_cycle_speed = 0.3;

void vertex() {
	vec2 centered_uv = UV - vec2(0.5, 0.5);
	float x_rad = radians(x_rot);
	VERTEX.y *= cos(x_rad);
	float y_rad = radians(y_rot);
	VERTEX.x *= cos(y_rad);
	VERTEX.x += centered_uv.y * sin(y_rad) * 8.0;
	VERTEX.y += centered_uv.x * sin(x_rad) * 8.0;
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec4 result = original;

	// Color cycling
	float cycle = TIME * color_cycle_speed;
	vec3 gold = vec3(1.0, 0.85, 0.3);
	vec3 teal = vec3(0.0, 0.8, 0.8);
	vec3 purple = vec3(0.8, 0.0, 1.0);

	float t = fract(cycle / 3.0);
	vec3 cycle_color;
	if (t < 0.33) {
		cycle_color = mix(gold, teal, t / 0.33);
	} else if (t < 0.66) {
		cycle_color = mix(teal, purple, (t - 0.33) / 0.33);
	} else {
		cycle_color = mix(purple, gold, (t - 0.66) / 0.34);
	}

	// Subtle edge color cycling (always visible)
	float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge_effect = 1.0 - smoothstep(0.0, 0.25, edge_dist);
	result = mix(result, vec4(cycle_color, result.a), edge_effect * 0.15);

	// Glow effect on hover - stronger color mix
	if (glow_strength > 0.0) {
		result = mix(result, vec4(cycle_color, result.a), glow_strength * 0.6);
	}

	// Click flash
	if (flash_strength > 0.0) {
		result = mix(result, vec4(1.0, 1.0, 1.0, result.a), flash_strength);
	}

	COLOR = result;
}
