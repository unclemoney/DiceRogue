shader_type canvas_item;

uniform sampler2D artwork_texture : source_color;
uniform bool use_artwork_texture = false;
uniform vec4 tint_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.97, 0.98, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.06;
uniform float sweep_strength : hint_range(0.0, 1.0) = 0.4;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.75;
uniform vec2 offset = vec2(0.0, 0.0);
uniform float time : hint_range(0.0, 100000.0) = 0.0;

void fragment() {
	vec2 reflected_uv = vec2(
		clamp(UV.x + offset.x * 0.018, 0.0, 1.0),
		clamp(1.0 - UV.y + offset.y * 0.012, 0.0, 1.0)
	);
	vec4 sampled_reflection = vec4(0.0);
	if (use_artwork_texture) {
		sampled_reflection = texture(artwork_texture, reflected_uv);
	}

	float fade = 1.0 - smoothstep(0.08, 1.0, UV.y);
	float sweep = 1.0 - smoothstep(0.0, 0.18, abs((UV.x + UV.y * 0.22) - fract(time * 0.06 + offset.x * 0.15 + 0.12)));
	float glint = 1.0 - smoothstep(0.0, 0.09, abs((UV.x - UV.y * 0.45) - fract(time * 0.11 + 0.35)));
	float scan = 0.5 + 0.5 * sin(UV.y * 160.0 + time * 2.4);

	vec3 procedural = sheen_color.rgb * (sweep * sweep_strength * 0.45 + glint * 0.18);
	vec3 reflected = sampled_reflection.rgb * tint_color.rgb * texture_strength;
	float reflected_alpha = sampled_reflection.a * texture_strength;
	float alpha = opacity * fade * max(reflected_alpha, sweep * sweep_strength * 0.75 + glint * 0.25);
	vec3 color = procedural + reflected * fade;
	color *= 1.0 - scan * scanline_opacity * 0.35;

	COLOR = vec4(color, alpha);
}
