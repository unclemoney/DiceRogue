shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ring_width : hint_range(0.01, 0.2) = 0.08;
uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 0.8, 0.6);
uniform float max_radius : hint_range(0.1, 1.0) = 0.5;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);

	// Current ring radius based on progress
	float current_radius = progress * max_radius;

	// Ring band with soft edges
	float inner = current_radius - ring_width * 0.5;
	float outer = current_radius + ring_width * 0.5;

	float ring = smoothstep(inner - 0.02, inner, dist) * (1.0 - smoothstep(outer, outer + 0.02, dist));

	// Fade out as progress increases
	float fade = 1.0 - progress * progress;

	COLOR = vec4(ring_color.rgb, ring * ring_color.a * fade);
}
