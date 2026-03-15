shader_type canvas_item;
// Score Panel Energy - Animated background for Total Score panel
// Created for DiceRogue (Guhtzee)
// Subdued energy field that intensifies with score, with milestone color tiers

uniform float intensity : hint_range(0.0, 2.0) = 0.3;
uniform float energy_speed : hint_range(0.0, 3.0) = 0.8;
uniform int milestone_tier : hint_range(0, 4) = 0;
// Tier 0 (0-99): Dim warm white
// Tier 1 (100-249): Soft gold
// Tier 2 (250-499): Electric blue
// Tier 3 (500-999): Purple/magenta
// Tier 4 (1000+): Rainbow/prismatic cycling

uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;
uniform float edge_arc_strength : hint_range(0.0, 1.0) = 0.3;

// Hash for noise
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		value += amp * noise(p);
		amp *= 0.5;
		p = p * 2.1 + vec2(1.7, 9.2);
	}
	return value;
}

// HSV to RGB conversion for rainbow mode
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Get tier color based on milestone_tier
vec3 get_tier_color(int tier, float time_val, vec2 uv) {
	if (tier <= 0) {
		// Dim warm white
		return vec3(0.9, 0.85, 0.7);
	} else if (tier == 1) {
		// Soft gold
		return vec3(1.0, 0.84, 0.3);
	} else if (tier == 2) {
		// Electric blue
		return vec3(0.2, 0.6, 1.0);
	} else if (tier == 3) {
		// Purple / magenta
		return vec3(0.7, 0.2, 1.0);
	} else {
		// Rainbow / prismatic cycling
		float hue = fract(time_val * 0.15 + uv.x * 0.3 + uv.y * 0.2);
		return hsv2rgb(vec3(hue, 0.8, 1.0));
	}
}

void fragment() {
	if (effect_strength <= 0.001) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);  // white instead of transparent
	} else {
		vec2 uv = UV;
		float t = TIME * energy_speed;
		
		// Get base color from tier
		vec3 tier_color = get_tier_color(milestone_tier, TIME, uv);
		
		// === SLOW MOVING ENERGY FIELD ===
		vec2 flow = vec2(t * 0.4, t * 0.2);
		float field1 = fbm(uv * 3.0 + flow);
		float field2 = fbm(uv * 2.0 - flow * 0.6 + vec2(4.0, 2.0));
		float energy_field = (field1 + field2) * 0.5;
		
		// Soft pulsing
		float pulse = 0.85 + 0.15 * sin(TIME * 0.8);
		energy_field *= pulse;
		
		// === EDGE LIGHTNING ARCS ===
		float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
		float edge_mask = smoothstep(0.15, 0.0, edge_dist);
		
		// Animate arcs along edges
		float edge_arc1 = sin(uv.y * 20.0 - t * 4.0) * 0.5 + 0.5;
		float edge_arc2 = sin(uv.x * 16.0 + t * 3.5) * 0.5 + 0.5;
		float edge_arcs = edge_mask * max(edge_arc1, edge_arc2);
		edge_arcs = pow(edge_arcs, 2.0) * edge_arc_strength * intensity;
		
		// === COMBINE ===
		float field_alpha = energy_field * intensity * 0.3;
		float arc_alpha = edge_arcs * 0.5;
		float total_alpha = (field_alpha + arc_alpha) * effect_strength;
		
		vec3 field_color = tier_color * energy_field * intensity * 0.6;
		vec3 arc_color = mix(tier_color, vec3(1.0), 0.3) * edge_arcs;
		vec3 final_color = field_color + arc_color;
		
		total_alpha = clamp(total_alpha, 0.0, 0.7);  // Never fully opaque - text must remain readable
		
		COLOR = vec4(final_color, total_alpha);
	}
}
