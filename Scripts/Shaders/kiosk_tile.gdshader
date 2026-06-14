shader_type canvas_item;

uniform float border_glow : hint_range(0.0, 2.0) = 0.0;
uniform vec4 neon_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform vec4 chrome_tint : source_color = vec4(0.12, 0.10, 0.14, 0.98);
uniform float reflection_amount : hint_range(0.0, 1.0) = 0.15;
uniform float corner_radius : hint_range(0.0, 64.0) = 18.0;
uniform float time : hint_range(0.0, 100000.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	vec2 size = vec2(1.0) / TEXTURE_PIXEL_SIZE;

	// Rounded rectangle signed-distance mask
	float min_side = min(size.x, size.y);
	float radius_pixels = max(corner_radius, 1.0);
	vec2 half_size = vec2(0.5);
	vec2 corner_radius_uv = vec2(radius_pixels / size.x, radius_pixels / size.y);
	vec2 d = abs(uv - half_size) - (half_size - corner_radius_uv);
	float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
	float mask = smoothstep(0.0, 0.002, dist);

	// Chrome vertical gradient across the entire tile
	float grad = mix(0.08, 0.18, uv.y);
	vec3 chrome = mix(chrome_tint.rgb, vec3(grad), 0.4);

	// Neon edge glow (stronger, visible across all rarities)
	float edge = 1.0 - smoothstep(0.0, 0.25, max(d.x, d.y) + 0.5);
	vec3 glow = neon_color.rgb * border_glow * edge * 1.5;

	// Subtle sheen overlay
	float scan = sin((uv.y + time * 0.05) * 60.0) * 0.5 + 0.5;
	float reflection = reflection_amount * scan * (1.0 - edge);

	COLOR = vec4(chrome + glow + reflection, 1.0 - mask);
}
