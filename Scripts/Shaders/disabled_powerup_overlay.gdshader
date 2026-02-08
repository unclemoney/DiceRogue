shader_type canvas_item;

uniform bool disabled = false;
uniform vec4 disabled_color : source_color = vec4(0.8, 0.0, 0.0, 0.6);
uniform float line_width : hint_range(0.01, 0.1) = 0.04;
uniform float grayscale_amount : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec4 current_color = texture(TEXTURE, UV);

	if (disabled) {
		// Convert to grayscale
		float gray = dot(current_color.rgb, vec3(0.299, 0.587, 0.114));
		vec3 gray_color = vec3(gray);
		vec3 desaturated = mix(current_color.rgb, gray_color, grayscale_amount);

		// Draw diagonal X lines (top-left to bottom-right and top-right to bottom-left)
		float line1 = abs(UV.x - UV.y);
		float line2 = abs(UV.x - (1.0 - UV.y));

		// Check if pixel is on either diagonal line
		bool on_line = line1 < line_width || line2 < line_width;

		if (on_line) {
			// Red X overlay with subtle pulse
			float pulse = 0.85 + 0.15 * sin(TIME * 2.5);
			COLOR = vec4(disabled_color.rgb, current_color.a * pulse);
		} else {
			// Desaturated base with slight red tint
			COLOR = vec4(desaturated * 0.7, current_color.a * 0.85);
		}
	} else {
		COLOR = current_color;
	}
}
