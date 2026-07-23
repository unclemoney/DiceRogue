shader_type canvas_item;

uniform float glow_strength = 0.0;
uniform float lock_overlay_strength = 0.0;
uniform bool disabled = false;
uniform vec4 disabled_color : source_color = vec4(0.8, 0.0, 0.0, 0.5);
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

// Perspective tilt uniforms (mouse-reactive hover)
uniform float x_rot : hint_range(-15.0, 15.0) = 0.0;
uniform float y_rot : hint_range(-15.0, 15.0) = 0.0;

// Dice color uniforms
uniform float green_color_strength = 0.0;
uniform float red_color_strength = 0.0;
uniform float purple_color_strength = 0.0;
uniform float blue_color_strength = 0.0;
uniform float yellow_color_strength = 0.0;

void vertex() {
	// Perspective tilt based on mouse position
	vec2 centered_uv = UV - vec2(0.5, 0.5);

	// Apply X rotation (tilt forward/backward)
	float x_rad = radians(x_rot);
	VERTEX.y *= cos(x_rad);

	// Apply Y rotation (tilt left/right)
	float y_rad = radians(y_rot);
	VERTEX.x *= cos(y_rad);

	// Apply slight skew to enhance 3D perspective
	VERTEX.x += centered_uv.y * sin(y_rad) * 8.0;
	VERTEX.y += centered_uv.x * sin(x_rad) * 8.0;
}

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec4 result = original;

    // Apply glow
    if (glow_strength > 0.0) {
        result = mix(result, vec4(1.0, 1.0, 0.8, result.a), glow_strength);
    }

    // Apply dice color effects (radiate from edges)
    if (green_color_strength > 0.0 || red_color_strength > 0.0 || purple_color_strength > 0.0 || blue_color_strength > 0.0 || yellow_color_strength > 0.0) {
        // Calculate distance from edge
        float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
        float edge_effect = 1.0 - smoothstep(0.0, 0.3, edge_dist);

        // Apply green color effect
        if (green_color_strength > 0.0) {
            vec4 green_color = vec4(0.0, 1.0, 0.0, 1.0);
            float green_pulse = 0.8 + 0.2 * sin(TIME * 4.0);
            result = mix(result, green_color, green_color_strength * edge_effect * green_pulse * 0.6);
        }

        // Apply red color effect
        if (red_color_strength > 0.0) {
            vec4 red_color = vec4(1.0, 0.0, 0.0, 1.0);
            float red_pulse = 0.8 + 0.2 * sin(TIME * 5.0);
            result = mix(result, red_color, red_color_strength * edge_effect * red_pulse * 0.6);
        }

        // Apply purple color effect
        if (purple_color_strength > 0.0) {
            vec4 purple_color = vec4(0.8, 0.0, 1.0, 1.0);
            float purple_pulse = 0.8 + 0.2 * sin(TIME * 3.5);
            result = mix(result, purple_color, purple_color_strength * edge_effect * purple_pulse * 0.6);
        }

        // Apply blue color effect
        if (blue_color_strength > 0.0) {
            vec4 blue_color = vec4(0.0, 0.5, 1.0, 1.0);
            float blue_pulse = 0.8 + 0.2 * sin(TIME * 6.0);
            result = mix(result, blue_color, blue_color_strength * edge_effect * blue_pulse * 0.6);
        }

        // Apply yellow color effect
        if (yellow_color_strength > 0.0) {
            vec4 yellow_color = vec4(1.0, 0.9, 0.0, 1.0);
            float yellow_pulse = 0.8 + 0.2 * sin(TIME * 4.5);
            result = mix(result, yellow_color, yellow_color_strength * edge_effect * yellow_pulse * 0.6);
        }
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

    // Apply critical flash (white flash overlay)
    if (flash_strength > 0.0) {
        result = mix(result, vec4(1.0, 1.0, 1.0, result.a), flash_strength);
    }

    COLOR = result;
}