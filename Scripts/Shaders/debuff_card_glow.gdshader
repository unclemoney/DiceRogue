shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(0.9, 0.35, 0.6, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.5) = 0.3;
uniform float proximity_strength : hint_range(0.0, 1.0) = 0.0;
uniform float active_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_strength : hint_range(0.0, 1.5) = 0.0;
uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform vec2 rect_size = vec2(220.0, 280.0);
uniform float corner_radius : hint_range(0.0, 64.0) = 26.0;
uniform float spread : hint_range(0.0, 80.0) = 34.0;
uniform float rim_width : hint_range(1.0, 20.0) = 8.0;
uniform float outer_halo_scale : hint_range(0.0, 2.0) = 0.92;
uniform float rim_halo_scale : hint_range(0.0, 2.0) = 0.54;
uniform float pointer_scale : hint_range(0.0, 1.0) = 0.34;
uniform float pulse_speed : hint_range(0.0, 20.0) = 4.8;
uniform float pulse_wobble : hint_range(0.0, 0.3) = 0.09;

float sd_rounded_rect(vec2 p, vec2 half_size, float radius) {
	vec2 d = abs(p - half_size) - max(half_size - vec2(radius), vec2(0.0));
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

void fragment() {
	vec2 size = max(rect_size, vec2(1.0));
	vec2 half_size = size * 0.5;
	vec2 pixel_pos = UV * size;

	float dist = sd_rounded_rect(pixel_pos, half_size, max(corner_radius, 0.0));
	float outer_halo = 1.0 - smoothstep(0.0, spread, max(dist, 0.0));
	float rim = 1.0 - smoothstep(0.0, rim_width, abs(dist));
	vec2 pointer_delta = UV - mouse_uv;
	float pointer_focus = exp(-dot(pointer_delta, pointer_delta) * 8.0) * proximity_strength;
	float pulse_wave = 1.0 + sin(TIME * pulse_speed + UV.y * 10.0) * pulse_wobble * (active_strength + pulse_strength);

	float glow_drive = glow_intensity + active_strength * 0.42 + proximity_strength * 0.22 + pulse_strength * 0.74;
	float alpha = (outer_halo * outer_halo_scale + rim * rim_halo_scale + pointer_focus * pointer_scale) * glow_color.a * glow_drive * pulse_wave;

	COLOR = vec4(glow_color.rgb * alpha, alpha);
}