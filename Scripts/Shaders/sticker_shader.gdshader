shader_type canvas_item;

uniform float gloss_strength : hint_range(0.0, 1.0) = 0.6;
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 tint_color : source_color = vec4(1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    
    // Gloss highlight
    float gloss = pow(abs(sin(UV.y * 8.0 + TIME * 1.5)), 4.0) * gloss_strength;

    // Sparkle
    float sparkle = fract(sin(dot(UV * 200.0, vec2(12.9898,78.233))) * 43758.5453);
    sparkle = step(1.0 - sparkle_amount, sparkle);

    COLOR = tex * tint_color;
    COLOR.rgb += gloss * 0.4;
    COLOR.rgb += sparkle * 0.2;
}
