shader_type canvas_item;

uniform float glow_strength = 0.0;
uniform float lock_overlay_strength = 0.0;
uniform bool disabled = false;
uniform vec4 disabled_color : source_color = vec4(0.8, 0.0, 0.0, 0.5);

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec4 result = original;

    // Apply glow
    if (glow_strength > 0.0) {
        result = mix(result, vec4(1.0, 1.0, 0.8, result.a), glow_strength);
    }

    // Apply lock overlay
    if (lock_overlay_strength > 0.0) {
        // Create a pattern for lock overlay
        float pattern = sin(UV.x * 30.0) * sin(UV.y * 30.0) * 0.5 + 0.5;
        vec4 lock_color = vec4(0.0, 0.0, 0.0, lock_overlay_strength * pattern);
        result = mix(result, lock_color, lock_overlay_strength * 0.3);
    }

    // Apply disabled effect
    if (disabled) {
        // Mix with red color and add pulsing effect
        float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
        result = mix(result, disabled_color, 0.5 * pulse);
    }

    COLOR = result;
}