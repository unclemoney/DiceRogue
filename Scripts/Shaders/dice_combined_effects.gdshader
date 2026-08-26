shader_type canvas_item;

uniform float glow_strength = 0.0;
uniform float lock_overlay_strength = 0.0;
uniform bool disabled = false;
uniform float debuff_disabled_strength : hint_range(0.0, 1.0) = 0.0;
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
    float base_alpha = original.a;
    float face_mask = smoothstep(0.02, 0.18, base_alpha);

    vec2 px = TEXTURE_PIXEL_SIZE * 1.5;
    float alpha_left = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
    float alpha_right = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
    float alpha_up = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
    float alpha_down = texture(TEXTURE, UV + vec2(0.0, px.y)).a;

    float neighbor_min = min(min(alpha_left, alpha_right), min(alpha_up, alpha_down));
    float neighbor_max = max(max(alpha_left, alpha_right), max(alpha_up, alpha_down));
    float silhouette_rim = face_mask * smoothstep(0.02, 0.30, base_alpha - neighbor_min);
    float silhouette_soft = face_mask * smoothstep(0.06, 0.40, neighbor_max - neighbor_min);
    float color_rim = clamp(silhouette_rim * 1.15 + silhouette_soft * 0.25, 0.0, 1.0);
    float interior_pulse = face_mask * (0.10 + 0.04 * sin(TIME * 2.0 + UV.y * 12.0));

    // Apply glow
    if (glow_strength > 0.0) {
        float glow_mix = glow_strength * clamp(color_rim * 0.85 + silhouette_soft * 0.30 + face_mask * 0.10, 0.0, 1.0);
        result.rgb = mix(result.rgb, vec3(1.0, 1.0, 0.8), glow_mix);
    }

    // Apply dice color effects, bound to the dice silhouette instead of the UV rectangle.
    if (green_color_strength > 0.0 || red_color_strength > 0.0 || purple_color_strength > 0.0 || blue_color_strength > 0.0 || yellow_color_strength > 0.0) {
        // Apply green color effect
        if (green_color_strength > 0.0) {
            vec3 green_color = vec3(0.0, 1.0, 0.0);
            float green_pulse = 0.8 + 0.2 * sin(TIME * 4.0);
            float green_mix = green_color_strength * (color_rim * green_pulse * 0.75 + interior_pulse);
            result.rgb = mix(result.rgb, green_color, green_mix);
        }

        // Apply red color effect
        if (red_color_strength > 0.0) {
            vec3 red_color = vec3(1.0, 0.0, 0.0);
            float red_pulse = 0.8 + 0.2 * sin(TIME * 5.0);
            float red_mix = red_color_strength * (color_rim * red_pulse * 0.75 + interior_pulse);
            result.rgb = mix(result.rgb, red_color, red_mix);
        }

        // Apply purple color effect
        if (purple_color_strength > 0.0) {
            vec3 purple_color = vec3(0.8, 0.0, 1.0);
            float purple_pulse = 0.8 + 0.2 * sin(TIME * 3.5);
            float purple_mix = purple_color_strength * (color_rim * purple_pulse * 0.75 + interior_pulse);
            result.rgb = mix(result.rgb, purple_color, purple_mix);
        }

        // Apply blue color effect
        if (blue_color_strength > 0.0) {
            vec3 blue_color = vec3(0.0, 0.5, 1.0);
            float blue_pulse = 0.8 + 0.2 * sin(TIME * 6.0);
            float blue_mix = blue_color_strength * (color_rim * blue_pulse * 0.75 + interior_pulse);
            result.rgb = mix(result.rgb, blue_color, blue_mix);
        }

        // Apply yellow color effect
        if (yellow_color_strength > 0.0) {
            vec3 yellow_color = vec3(1.0, 0.9, 0.0);
            float yellow_pulse = 0.8 + 0.2 * sin(TIME * 4.5);
            float yellow_mix = yellow_color_strength * (color_rim * yellow_pulse * 0.75 + interior_pulse);
            result.rgb = mix(result.rgb, yellow_color, yellow_mix);
        }
    }

    // Apply lock overlay
    if (lock_overlay_strength > 0.0) {
        // Create a pattern for lock overlay
        float pattern = sin(UV.x * 30.0) * sin(UV.y * 30.0) * 0.5 + 0.5;
        float lock_mix = lock_overlay_strength * pattern * face_mask * 0.30;
        result.rgb = mix(result.rgb, vec3(0.0, 0.0, 0.0), lock_mix);
    }

    // Apply debuff-specific face marker without reusing the full disabled state.
    if (debuff_disabled_strength > 0.0) {
        float slash_a = 1.0 - smoothstep(0.05, 0.10, abs(UV.x - UV.y));
        float slash_b = 1.0 - smoothstep(0.05, 0.10, abs(UV.x - (1.0 - UV.y)));
        float slash_mark = max(slash_a, slash_b);
        float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
        float debuff_mix = debuff_disabled_strength * slash_mark * pulse * face_mask * 0.55;
        result.rgb = mix(result.rgb, vec3(0.95, 0.2, 0.15), debuff_mix);
    }

    // Apply disabled effect
    if (disabled) {
        // Mix with red color and add pulsing effect
        float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
        float disabled_mix = disabled_color.a * pulse * face_mask;
        result.rgb = mix(result.rgb, disabled_color.rgb, disabled_mix);
    }

    // Apply critical flash (white flash overlay)
    if (flash_strength > 0.0) {
        result.rgb = mix(result.rgb, vec3(1.0, 1.0, 1.0), flash_strength * face_mask);
    }

    COLOR = vec4(result.rgb, base_alpha);
}