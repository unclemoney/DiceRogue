shader_type canvas_item;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float spread : hint_range(0.0, 1.0) = 0.5;
uniform float fade_speed : hint_range(0.1, 5.0) = 1.0;

void fragment() {
    // Create circular particle with soft edges
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    float circle = smoothstep(0.5, 0.3, dist);  // Adjusted for softer edges
    
    // Add some variation
    float noise = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);
    
    // Slower fade
    float fade = 1.0 - (TIME * fade_speed * 0.5);  // Slowed down fade
    
    // Combine for final color with increased brightness
    COLOR = color * 1.5;  // Increased brightness
    COLOR.a *= circle * fade * (0.8 + (noise * 0.2));  // More consistent alpha
}