shader_type canvas_item;

uniform float aspect_ratio : hint_range(1.0, 6.0) = 3.5;
uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform vec2 press_origin = vec2(0.5, 0.5);
uniform float hover_strength : hint_range(0.0, 1.0) = 0.0;
uniform float proximity_strength : hint_range(0.0, 1.0) = 0.0;
uniform float motion_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.0;
uniform float press_flash : hint_range(0.0, 1.5) = 0.0;
uniform float spark_strength : hint_range(0.0, 1.5) = 0.0;
uniform float disabled_factor : hint_range(0.0, 1.0) = 0.0;

uniform vec4 base_color : source_color = vec4(0.247059, 0.219608, 0.345098, 0.98);
uniform vec4 mid_color : source_color = vec4(0.298039, 0.239216, 0.380392, 0.98);
uniform vec4 glow_color : source_color = vec4(0.713725, 0.301961, 0.478431, 1.0);
uniform vec4 accent_color : source_color = vec4(0.137255, 0.411765, 0.415686, 1.0);
uniform vec4 specular_color : source_color = vec4(0.96, 0.97, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.968627, 0.941176, 1.0, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 78.233);
	return fract(p.x * p.y);
}

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2((uv.x - 0.5) * aspect_ratio, uv.y - 0.5);
	vec2 mouse_p = vec2((mouse_uv.x - 0.5) * aspect_ratio, mouse_uv.y - 0.5);
	vec2 press_p = vec2((press_origin.x - 0.5) * aspect_ratio, press_origin.y - 0.5);
	vec2 half_size = vec2(aspect_ratio * 0.5 - 0.09, 0.35);
	float radius = 0.18;
	float sdf = rounded_box_sdf(p, half_size, radius);
	float panel_mask = 1.0 - smoothstep(0.0, 0.018, sdf);
	float border = 1.0 - smoothstep(0.014, 0.04, abs(sdf));
	float inner_rim = smoothstep(-0.045, -0.012, -sdf);

	float pulse = pulse_strength * (0.5 + 0.5 * sin(TIME * 2.7));
	float glow_strength = 0.12 + proximity_strength * 0.52 + hover_strength * 0.28 + pulse * 0.18 + press_flash * 0.35;

	float sweep_pos = fract(TIME * 0.08);
	float sweep = 1.0 - smoothstep(0.0, 0.24, abs((uv.x + uv.y * 0.28) - sweep_pos));
	float scan = 0.5 + 0.5 * sin(uv.y * 140.0 + TIME * 1.8);
	float grain = hash21(uv * vec2(170.0, 96.0) + TIME * 0.03);
	float frost = mix(scan, grain, 0.35);

	vec2 glow_delta = (p - mouse_p) * vec2(0.62, 1.06);
	float mouse_glow = exp(-dot(glow_delta, glow_delta) * 4.3) * (0.18 + proximity_strength * 0.92 + hover_strength * 0.45);
	vec2 halo_delta = (p - mouse_p) * vec2(0.42, 0.76);
	float mouse_halo = exp(-dot(halo_delta, halo_delta) * 1.8) * (0.08 + proximity_strength * 0.48 + hover_strength * 0.18);
	vec2 spec_delta = (p - mouse_p) * vec2(1.45, 2.25);
	float specular = exp(-dot(spec_delta, spec_delta) * 14.0) * (0.16 + hover_strength * 0.22 + motion_strength * 0.6 + press_flash * 0.35);
	vec2 spark_delta = (p - press_p) * vec2(0.95, 1.65);
	float spark_dist = length(spark_delta);
	float spark_angle = atan(spark_delta.y, spark_delta.x);
	float spark_core = exp(-spark_dist * spark_dist * 42.0) * spark_strength;
	float spark_rays = pow(abs(cos(spark_angle * 4.0)), 18.0) * exp(-spark_dist * 14.0) * spark_strength;
	float spark_ring = exp(-pow(spark_dist - 0.12, 2.0) * 220.0) * spark_strength * 0.45;
	float top_reflection = smoothstep(0.24, -0.12, uv.y - 0.16) * panel_mask;

	vec3 base = mix(mid_color.rgb, base_color.rgb, smoothstep(0.0, 1.0, uv.y));
	base += accent_color.rgb * (0.05 + frost * 0.05);
	base += specular_color.rgb * (0.08 * top_reflection + sweep * 0.13 + specular * 0.65);
	base += glow_color.rgb * mouse_glow * 0.25;
	base += accent_color.rgb * mouse_halo * 0.18;

	vec3 border_color = mix(glow_color.rgb, accent_color.rgb, 0.5 + 0.5 * sin(TIME * 1.6 + uv.x * 6.0));
	vec3 spark_color = mix(specular_color.rgb, glow_color.rgb, 0.58 + 0.12 * sin(TIME * 20.0));
	vec3 panel_color = base;
	panel_color += border_color * border * (0.45 + glow_strength * 1.4);
	panel_color += rim_color.rgb * inner_rim * 0.06;
	panel_color += specular_color.rgb * press_flash * 0.18;
	panel_color += spark_color * (spark_core * 0.95 + spark_rays * 0.75 + spark_ring * 0.45);

	float aura = exp(-max(sdf, 0.0) * 9.0) * (0.05 + glow_strength * 0.85);
	vec3 aura_color = mix(accent_color.rgb, glow_color.rgb, 0.4 + 0.25 * sin(TIME * 2.0 + uv.y * 5.0));
	vec3 color = aura_color * aura * 0.9;
	color += aura_color * mouse_halo * 0.25;
	color += spark_color * spark_rays * 0.22;
	color = mix(color, panel_color, panel_mask);

	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma) * 0.82, disabled_factor * 0.78);

	float alpha = max(panel_mask * 0.98, max(aura * 0.34, mouse_halo * 0.16 + spark_rays * 0.12));
	alpha *= mix(1.0, 0.78, disabled_factor);

	COLOR = vec4(color, alpha);
}