shader_type canvas_item;

// Screen sampling
uniform sampler2D screen_texture : hint_screen_texture;

// Curvature
uniform float curvature        : hint_range(0.0, 0.5) = 0.0;

// Chromatic aberration / CRT
uniform float chroma_offset    : hint_range(0.0, 5.0)   = 2.0;
uniform float effect_strength  : hint_range(0.0, 1.0)   = 1.0;

// VHS bars
uniform float bar_thickness    : hint_range(1.0, 20.0)  = 7.0;
uniform float roll_speed       : hint_range(0.0, 2.0)   = 0.08;
uniform float bar_darkness     : hint_range(0.0, 1.0)   = 0.3;

// VHS glitches
uniform float glitch_chance    : hint_range(0.0, 1.0)   = 0.05;
uniform float glitch_offset    : hint_range(0.0, 0.1)   = 0.02;
uniform float glitch_width     : hint_range(0.0, 0.2)   = 0.08;

// CRT scanlines & noise
uniform float scanline_strength: hint_range(0.0, 1.0)   = 0.04;
uniform float noise_strength   : hint_range(0.0, 0.2)   = 0.01;

// pseudo-random generator
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    // Sample the untouched screen once up-front
    vec3 original = texture(screen_texture, SCREEN_UV).rgb;

    // 1) Barrel distortion remap
    vec2 uv = SCREEN_UV * 2.0 - 1.0;
    float r2 = dot(uv, uv);
    uv *= 1.0 + curvature * r2;
    uv = uv * 0.5 + 0.5;

    // 2) Flag outside region and clamp
    bool outside = (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0);
    uv = clamp(uv, vec2(0.0), vec2(1.0));

    // 3) Prep for effects
    vec2 px      = SCREEN_PIXEL_SIZE;
    vec2 texSize = vec2(textureSize(screen_texture, 0));

    // 4) Chromatic aberration sampling
    float o = chroma_offset * px.x;
    float cr = texture(screen_texture, uv + vec2( o, 0.0)).r;
    float cg = texture(screen_texture, uv               ).g;
    float cb = texture(screen_texture, uv - vec2( o, 0.0)).b;
    vec3 col = vec3(cr, cg, cb);

    // 5) Rolling VHS bars
    float pos  = uv.y * texSize.y + TIME * roll_speed * bar_thickness;
    float band = mod(pos, bar_thickness * 2.0);
    float shade = step(bar_thickness, band) * bar_darkness;
    col *= (1.0 - shade);

    // 6) VHS glitch slices
    float bandIdx = floor(uv.y * texSize.y / bar_thickness);
    if (rand(vec2(bandIdx, floor(TIME))) < glitch_chance) {
        float shift  = (rand(vec2(bandIdx, TIME)) - 0.5) * glitch_offset;
        float sliceW = glitch_width + rand(vec2(TIME, bandIdx)) * glitch_width;
        if (fract(uv.x / sliceW) < sliceW) {
            col = texture(screen_texture, uv + vec2(shift, 0.0)).rgb;
        }
    }

    // 7) CRT scanlines
    float scan = sin(uv.y * texSize.y * PI) * 0.5 + 0.5;
    col *= mix(1.0, scan, scanline_strength);

    // 8) Noise flicker
    float noise = (rand(uv * TIME) - 0.5) * noise_strength;
    col += noise;

    // 9) Mix with original based on effect_strength
    vec3 processed = outside ? vec3(0.0) : col;
    vec3 final     = mix(original, processed, effect_strength);

    COLOR = vec4(final, 1.0);
}