shader_type canvas_item;

// Base tint coming from rarity (set from GDScript)
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Overall intensity controls
uniform float holo_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.4;
uniform float rainbow_strength : hint_range(0.0, 1.0) = 0.7;
uniform float sparkle_strength : hint_range(0.0, 1.0) = 0.35;

// Grain / noise scale
uniform float grain_scale : hint_range(10.0, 400.0) = 160.0;

// Mouse position (0–1 UV)
uniform vec2 mouse_pos = vec2(0.5, 0.5);

// Optional: use the underlying texture as a mask
uniform bool use_texture_mask = true;


// Simple hash-based noise
float hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)),
             dot(p, vec2(269.5, 183.3)));
    return fract(sin(p.x * 17.0 + p.y * 43.0) * 43758.5453);
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

// Cheap rainbow function based on angle
vec3 holo_rainbow(vec2 uv) {
    float angle = atan(uv.y - 0.5, uv.x - 0.5);
    float s = sin(angle * 3.0);
    float c = cos(angle * 2.0);

    return vec3(
        0.6 + 0.4 * s,
        0.6 + 0.4 * c,
        0.6 + 0.4 * sin(angle * 4.0 + 1.57)
    );
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    float mask = use_texture_mask ? base.a : 1.0;

    if (mask <= 0.001) {
        discard;
    }

    // Mouse direction
    vec2 dir = UV - mouse_pos;
    float dist = length(dir);

    // Grain
    float grain = noise(UV * grain_scale);

    // Rainbow shifts slightly with mouse
    vec3 rainbow = holo_rainbow(UV + dir * 0.15);

    // Gloss highlight follows mouse
    float gloss = pow(1.0 - dist, 6.0) * gloss_strength;

    // Sparkle
    float sparkle = step(0.97, noise(UV * grain_scale * 1.8)) * sparkle_strength;

    // Combine foil + tint
    vec3 holo_color = mix(tint_color.rgb, rainbow, rainbow_strength);
    holo_color += gloss;
    holo_color += sparkle;

    vec3 final_rgb = mix(base.rgb * tint_color.rgb, holo_color, holo_intensity);

    COLOR = vec4(final_rgb, mask);
}
