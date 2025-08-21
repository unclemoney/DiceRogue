shader_type canvas_item;

// the rendered screen
uniform sampler2D screen_texture : hint_screen_texture;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;

// bar controls
uniform float bar_thickness   : hint_range(1.0, 20.0) = 6.0;
uniform float roll_speed      : hint_range(0.0, 2.0)  = 0.9;
uniform float bar_darkness    : hint_range(0.0, 1.0)  = 0.1;

// glitch controls
uniform float glitch_chance   : hint_range(0.0, 1.0)  = 0.05;
uniform float glitch_offset   : hint_range(0.0, 0.1)  = 0.02;
uniform float glitch_width    : hint_range(0.0, 0.2)  = 0.08;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv       = SCREEN_UV;
    vec2 px       = SCREEN_PIXEL_SIZE;
    vec2 texSize  = vec2(textureSize(screen_texture, 0));

    // base color
    vec3 original = texture(screen_texture, uv).rgb;
    vec3 col = original;

    // 1) Rolling horizontal bars
    float pos = uv.y * texSize.y + TIME * roll_speed * bar_thickness;
    float band = mod(pos, bar_thickness * 2.0);
    float darkness = step(bar_thickness, band) * bar_darkness;
    col *= (1.0 - darkness);

    // 2) Occasional glitch slices
    float bandIndex = floor(uv.y * texSize.y / bar_thickness);
    float chance = rand(vec2(bandIndex, floor(TIME)));
    if (chance < glitch_chance) {
        float shift = (rand(vec2(bandIndex, TIME)) - 0.5) * glitch_offset;
        float sliceWidth = glitch_width + rand(vec2(TIME, bandIndex)) * glitch_width;
        if (fract(uv.x / sliceWidth) < sliceWidth) {
            col = texture(screen_texture, uv + vec2(shift, 0.0)).rgb;
        }
    }

    // Blend processed color with original based on effect_strength
    col = mix(original, col, effect_strength);

    COLOR = vec4(col, 1.0);
}