shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.0, 0.5); // yellow glow

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = mix(tex_color, glow_color, glow_strength);
}