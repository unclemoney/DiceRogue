shader_type canvas_item;

uniform vec4 accent_tint : source_color = vec4(0.62, 0.64, 0.67, 1.0);

uniform float foil_intensity : hint_range(0.0, 1.5) = 0.24;
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.18;
uniform float iridescence_strength : hint_range(0.0, 1.0) = 0.16;
uniform float rainbow_strength : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.08;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;
uniform float layer_alpha : hint_range(0.0, 1.0) = 0.54;
uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform float corner_radius : hint_range(0.01, 0.49) = 0.17;
uniform float edge_softness : hint_range(0.001, 0.05) = 0.018;


float hash(vec2 p) {
    p = vec2(
        dot(p, vec2(127.1, 311.7)),
        dot(p, vec2(269.5, 183.3))
    );
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}


float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) +
        (c - a) * u.y * (1.0 - u.x) +
        (d - b) * u.x * u.y;
}


vec3 rainbow_band(vec2 uv, vec2 pointer_dir) {
    float angle = atan(pointer_dir.y, pointer_dir.x);
    float sweep = dot(uv - vec2(0.5), normalize(pointer_dir + vec2(0.001, 0.0))) * 7.0;
    float phase = angle * 1.35 + sweep;
    return vec3(
        0.60 + 0.22 * sin(phase + 0.0),
        0.62 + 0.20 * sin(phase + 2.09),
        0.66 + 0.22 * sin(phase + 4.18)
    );
}


float rounded_rect_mask(vec2 uv, float radius, float softness) {
	vec2 q = abs(uv - vec2(0.5)) - vec2(0.5 - radius);
	float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	return 1.0 - smoothstep(0.0, softness, dist);
}


void fragment() {
    float mask_alpha = rounded_rect_mask(UV, corner_radius, edge_softness);

    vec2 local_uv = UV - vec2(0.5);
    vec2 pointer_delta = mouse_uv - UV;
    float pointer_distance = length(pointer_delta);
    vec2 pointer_dir = normalize(pointer_delta + vec2(0.0001, 0.0001));
    vec2 sweep_dir = normalize(vec2(0.88, -0.48));

    float grain = (noise(UV * 120.0) - 0.5) * grain_strength;
    float brushed = sin((UV.y + UV.x * 0.17) * 130.0) * 0.015;
    float rim = pow(clamp(1.0 - length(local_uv) * 1.72, 0.0, 1.0), 0.65);
    float highlight = pow(clamp(1.0 - pointer_distance * 1.15, 0.0, 1.0), 3.2);
    float specular = pow(clamp(dot(normalize(vec2(0.55, -0.85)), pointer_dir) * 0.5 + 0.5, 0.0, 1.0), 3.0);
    float sweep_center = dot(mouse_uv - vec2(0.5), sweep_dir);
    float sweep_value = dot(UV - vec2(0.5), sweep_dir);
    float sheen_band = exp(-abs(sweep_value - sweep_center) * 14.0);
    float motion_sheen = sheen_band * (0.18 + gloss_strength * 0.82);

    vec3 pearl_base = vec3(0.83, 0.83, 0.84);
    vec3 silver_shadow = vec3(0.64, 0.65, 0.67);
    vec3 foil_base = mix(silver_shadow, pearl_base, rim * 0.65 + 0.2);

    vec3 accent_mix = mix(foil_base, accent_tint.rgb, 0.22);
    vec3 iridescent = rainbow_band(UV, pointer_dir);
    vec3 foil_color = mix(accent_mix, iridescent, rainbow_strength);
    foil_color = mix(foil_color, mix(foil_base, iridescent, 0.35), iridescence_strength * 0.55);

    float gloss = highlight * gloss_strength;
    float rim_glow = rim * rim_strength * 0.32;
    float foil_mix = clamp(foil_intensity + gloss * 0.55 + rim_glow + motion_sheen * 0.35, 0.0, 1.0);

    vec3 final_rgb = foil_base;
    final_rgb = mix(final_rgb, foil_color, foil_mix);
    final_rgb += vec3(grain + brushed);
    final_rgb += vec3(gloss * 0.30 + motion_sheen * 0.22 + specular * gloss_strength * 0.08);
    final_rgb = clamp(final_rgb, 0.0, 1.0);

    COLOR = vec4(final_rgb, mask_alpha * layer_alpha);
}
