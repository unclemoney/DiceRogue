shader_type canvas_item;

uniform bool disabled = false;
uniform vec4 disabled_color : source_color = vec4(0.8, 0.0, 0.0, 0.5);

void fragment() {
    vec4 current_color = texture(TEXTURE, UV);
    
    if (disabled) {
        // Mix the original color with the disabled color
        COLOR = mix(current_color, disabled_color, 0.5);
        // Add a slight pulsing effect
        COLOR.a *= 0.8 + 0.2 * sin(TIME * 3.0);
    } else {
        COLOR = current_color;
    }
}