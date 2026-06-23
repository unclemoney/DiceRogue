shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float glow_strength : hint_range(0.0, 4.0) = 1.45;
uniform float threshold : hint_range(0.0, 1.5) = 0.42;
uniform float saturation_threshold : hint_range(0.0, 1.0) = 0.10;
uniform int radius_steps : hint_range(1, 16) = 9;
uniform float spread : hint_range(0.0, 32.0) = 10.5;
uniform float lod_bias_scale : hint_range(0.0, 1.5) = 0.26;
uniform float source_boost : hint_range(0.0, 3.0) = 1.22;
uniform float alpha_strength : hint_range(0.0, 2.5) = 1.08;

const int MAX_STEPS = 16;
const int DIR_COUNT = 8;
const float TAU_F = 6.28318530718;

vec4 glow_source(vec2 uv, float lod_bias) {
	vec4 sample_color = textureLod(screen_texture, uv, lod_bias);
	float max_channel = max(sample_color.r, max(sample_color.g, sample_color.b));
	float min_channel = min(sample_color.r, min(sample_color.g, sample_color.b));
	float saturation = max_channel - min_channel;
	float brightness_mask = smoothstep(threshold, threshold + 0.20, max_channel);
	float saturation_mask = smoothstep(saturation_threshold, saturation_threshold + 0.18, saturation);
	float mask = brightness_mask * saturation_mask;
	return vec4(sample_color.rgb * mask * source_boost, mask);
}

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));
	vec4 glow = glow_source(SCREEN_UV, 0.0) * 0.35;
	float total_weight = 0.35;

	for (int step = 1; step <= MAX_STEPS; step++) {
		if (step > radius_steps) {
			break;
		}

		float t = float(step) / float(max(radius_steps, 1));
		float weight = pow(1.0 - t, 2.2);
		float lod_bias = t * float(radius_steps) * lod_bias_scale;
		float distance = spread * float(step);

		for (int dir = 0; dir < DIR_COUNT; dir++) {
			float angle = TAU_F * float(dir) / float(DIR_COUNT);
			vec2 direction = vec2(cos(angle), sin(angle));
			vec2 sample_uv = clamp(SCREEN_UV + direction * pixel_size * distance, vec2(0.0), vec2(1.0));
			glow += glow_source(sample_uv, lod_bias) * weight;
		}

		total_weight += weight * float(DIR_COUNT);
	}

	glow /= max(total_weight, 0.0001);
	float alpha = clamp(max(glow.r, max(glow.g, glow.b)) * alpha_strength, 0.0, 1.0);
	COLOR = vec4(glow.rgb * glow_strength, alpha);
}