shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float line_thickness : hint_range(0.0, 0.1) = 0.02;
uniform vec4 beam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_size : hint_range(0.0, 0.05) = 0.015;

void fragment() {
	vec2 uv = UV - vec2(0.5);

	float half_w;
	float half_h;

	if (progress < 0.5) {
		float t = progress / 0.5;
		half_w = mix(0.0, 0.5, t);
		half_h = mix(0.0, line_thickness * 0.5, t);
	} else {
		float t = (progress - 0.5) / 0.5;
		half_w = 0.5;
		half_h = mix(line_thickness * 0.5, 0.5, t);
	}

	float dist_x = abs(uv.x) - half_w;
	float dist_y = abs(uv.y) - half_h;
	float dist = max(dist_x, dist_y);

	float mask = 1.0 - step(0.0, dist);
	float glow = 1.0 - smoothstep(0.0, glow_size, dist);

	vec4 screen_col = texture(screen_texture, SCREEN_UV);

	vec4 col = mix(vec4(0.0, 0.0, 0.0, 1.0), screen_col, mask);
	col = mix(col, beam_color, glow * (1.0 - mask));

	COLOR = col;
}
