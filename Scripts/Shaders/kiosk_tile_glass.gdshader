shader_type canvas_item;

uniform vec2 rect_size = vec2(186.0, 286.0);
uniform float corner_radius : hint_range(0.0, 64.0) = 16.0;
uniform vec2 mouse_uv = vec2(0.5, 0.35);
uniform vec2 parallax_offset = vec2(0.0, 0.0);
uniform float hover_strength : hint_range(0.0, 1.0) = 0.18;
uniform float motion_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.72;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.06;
uniform float time : hint_range(0.0, 100000.0) = 0.0;

uniform vec4 base_color : source_color = vec4(0.082353, 0.129412, 0.188235, 0.98);
uniform vec4 mid_color : source_color = vec4(0.145098, 0.203922, 0.274510, 0.98);
uniform vec4 accent_color : source_color = vec4(0.125490, 0.376471, 0.431373, 0.9);
uniform vec4 neon_color : source_color = vec4(0.713725, 0.301961, 0.478431, 1.0);
uniform vec4 specular_color : source_color = vec4(0.960784, 0.976471, 1.0, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 34.45);
	return fract(p.x * p.y);
}

float sd_rounded_rect(vec2 p, vec2 half_size, float radius) {
	vec2 d = abs(p - half_size) - max(half_size - vec2(radius), vec2(0.0));
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 size = max(rect_size, vec2(1.0));
	vec2 half_size = size * 0.5;
	vec2 pixel_pos = UV * size;
	float dist = sd_rounded_rect(pixel_pos, half_size, corner_radius);
	float fill = 1.0 - smoothstep(0.0, 1.6, dist);
	float rim = (1.0 - smoothstep(0.0, 3.2, abs(dist))) * rim_strength;

	float vertical_grad = smoothstep(0.0, 1.0, UV.y);
	vec3 color = mix(mid_color.rgb, base_color.rgb, vertical_grad);

	float top_gloss = 1.0 - smoothstep(0.03, 0.48, UV.y);
	float sweep = 1.0 - smoothstep(0.0, 0.18, abs((UV.x + UV.y * 0.18) - fract(time * 0.05 + parallax_offset.x * 0.2 + 0.14)));
	vec2 glow_delta = (UV - mouse_uv) * vec2(0.8, 1.18);
	float mouse_glow = exp(-dot(glow_delta, glow_delta) * 8.0) * (0.08 + hover_strength * 0.55 + motion_strength * 0.28);
	vec2 spec_delta = (UV - mouse_uv) * vec2(1.8, 2.5);
	float specular = exp(-dot(spec_delta, spec_delta) * 18.0) * (0.10 + hover_strength * 0.35 + motion_strength * 0.4);
	float grain = hash21(UV * vec2(160.0, 92.0) + time * 0.03 + parallax_offset * 12.0) - 0.5;
	float pulse = 0.5 + 0.5 * sin(time * 3.2);
	float scan = 0.5 + 0.5 * sin(UV.y * 120.0 + time * 1.2);

	color += accent_color.rgb * (0.05 + grain * grain_strength);
	color += specular_color.rgb * (top_gloss * (0.18 + hover_strength * 0.1));
	color += specular_color.rgb * sweep * (0.08 + hover_strength * 0.12 + motion_strength * 0.05);
	color += specular_color.rgb * specular * 0.72;
	color += neon_color.rgb * mouse_glow * 0.22;
	color += neon_color.rgb * pulse_strength * pulse * rim * 0.12;
	color += specular_color.rgb * rim * 0.16;
	color -= vec3(0.03, 0.035, 0.05) * smoothstep(0.62, 1.0, UV.y);
	color *= 1.0 - scan * 0.018;

	COLOR = vec4(color, fill);
}