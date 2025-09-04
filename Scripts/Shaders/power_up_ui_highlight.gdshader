shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);

void fragment() {
    vec4 current_color = texture(TEXTURE, UV);
    vec4 glow = glow_color * glow_intensity;

    // Add glow while preserving alpha
    COLOR = vec4(
        mix(current_color.rgb, glow.rgb, glow_intensity),
        current_color.a
    );
}