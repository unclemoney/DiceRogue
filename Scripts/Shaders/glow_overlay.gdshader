shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.0, 0.5); // yellow glow

uniform float lock_overlay_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 lock_color : source_color = vec4(0.0, 0.0, 0.0, 0.5); // semi-transparent black

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 glow = mix(tex_color, glow_color, glow_strength);
    vec4 locked = mix(glow, lock_color, lock_overlay_strength);
    COLOR = locked;
}