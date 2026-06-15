shader_type canvas_item;

uniform sampler2D artwork_texture : source_color;
uniform float opacity : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.06;
uniform vec2 offset = vec2(0.0, 0.0);

void fragment() {
	vec2 uv = UV;
	// Flip vertically to create a reflection
	uv.y = 1.0 - uv.y;
	// Apply parallax / hover offset
	uv += offset * 0.01;

	vec4 tex = texture(artwork_texture, uv);

	// Vertical fade-out from bottom (reflection source) to top
	float fade = smoothstep(0.0, 1.0, UV.y);
	tex.a *= opacity * (1.0 - fade);

	// Subtle CRT scanlines
	float scan = sin(UV.y * 120.0 * 3.14159265359) * 0.5 + 0.5;
	tex.rgb *= 1.0 - (scan * scanline_opacity);

	COLOR = tex;
}
