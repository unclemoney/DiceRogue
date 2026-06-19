shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.886275, 0.560784, 0.72549, 1.0);
uniform vec4 chase_color : source_color = vec4(0.47451, 0.886275, 0.890196, 1.0);
uniform vec4 burst_color : source_color = vec4(1.0, 0.952941, 0.784314, 1.0);
uniform float border_thickness : hint_range(0.01, 0.3) = 0.12;
uniform float edge_softness : hint_range(0.001, 0.08) = 0.018;
uniform float corner_radius : hint_range(0.02, 0.6) = 0.22;
uniform float chase_speed : hint_range(0.0, 3.0) = 0.6;
uniform float chase_width : hint_range(0.02, 0.4) = 0.12;
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform float trigger_progress : hint_range(0.0, 1.0) = 0.0;

float rounded_box_sdf(vec2 uv, float radius) {
	vec2 p = uv * 2.0 - 1.0;
	vec2 bounds = vec2(1.0 - radius);
	vec2 q = abs(p) - bounds;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

float loop_distance(float a, float b) {
	float delta = abs(a - b);
	return min(delta, 1.0 - delta);
}

void fragment() {
	float sdf = rounded_box_sdf(UV, corner_radius);
	float outer_mask = 1.0 - smoothstep(0.0, edge_softness, sdf);
	float inner_mask = 1.0 - smoothstep(-border_thickness, -border_thickness + edge_softness, sdf);
	float border_mask = clamp(outer_mask - inner_mask, 0.0, 1.0);

	vec2 centered = UV - vec2(0.5);
	float border_angle = fract((atan(centered.y, centered.x) / 6.28318530718) + 0.5);
	float chase_head = fract(TIME * chase_speed);
	float chase_tail = fract(chase_head + 0.33);
	float chase_a = smoothstep(chase_width, 0.0, loop_distance(border_angle, chase_head));
	float chase_b = smoothstep(chase_width * 1.35, 0.0, loop_distance(border_angle, chase_tail));
	float chase_mix = clamp(chase_a + chase_b * 0.55, 0.0, 1.0);

	float pulse = 0.82 + (sin(TIME * 4.0) * 0.12);
	vec3 border_color = mix(base_color.rgb, chase_color.rgb, chase_mix);
	vec3 border_glow = border_color * border_mask * glow_strength * pulse;

	float burst_ring = 0.0;
	float burst_fill = 0.0;
	float trigger_strength = sin(trigger_progress * 3.14159265359);
	if (trigger_progress > 0.0) {
		float radial_distance = length(centered * vec2(1.75, 1.0));
		float ring_radius = mix(0.06, 0.95, trigger_progress);
		burst_ring = smoothstep(0.16, 0.02, abs(radial_distance - ring_radius)) * trigger_strength;
		burst_fill = smoothstep(0.5, 0.0, radial_distance) * trigger_strength * (1.0 - trigger_progress * 0.4);
	}

	vec3 final_color = border_glow + (burst_color.rgb * (burst_ring * 1.25 + burst_fill * 0.55));
	float alpha = (border_mask * (0.45 + chase_mix * 0.7) + burst_ring * 0.95 + burst_fill * 0.35) * effect_strength;
	COLOR = vec4(final_color, clamp(alpha, 0.0, 1.0));
}