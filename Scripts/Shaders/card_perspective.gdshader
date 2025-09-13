shader_type canvas_item;

uniform float tilt : hint_range(-0.5, 0.5) = 0.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.4, 1.0);
uniform float x_rot : hint_range(-30.0, 30.0) = 0.0;
uniform float y_rot : hint_range(-30.0, 30.0) = 0.0;

void vertex() {
	// Get normalized UV coordinates relative to center (from -0.5 to 0.5)
	vec2 centered_uv = UV - vec2(0.5, 0.5);

	// Apply X rotation (tilt forward/backward)
	float x_rad = radians(x_rot);
	// Scale Y based on X rotation to simulate perspective
	float y_perspective = cos(x_rad);
	VERTEX.y *= y_perspective;

	// Apply Y rotation (tilt left/right)
	float y_rad = radians(y_rot);
	// Scale X based on Y rotation to simulate perspective
	float x_perspective = cos(y_rad);
	VERTEX.x *= x_perspective;

	// Apply slight skew based on rotation to enhance 3D effect
	VERTEX.x += centered_uv.y * sin(y_rad) * 10.0;
	VERTEX.y += centered_uv.x * sin(x_rad) * 10.0;

	// Apply base tilt effect
	float perspective = tilt * (UV.x - 0.5) * 2.0;
	VERTEX.y += perspective * VERTEX.x;

	// Add slight Z rotation based on tilt
	float rotation_z = tilt * 0.1;
	mat2 rot = mat2(
		vec2(cos(rotation_z), -sin(rotation_z)),
		vec2(sin(rotation_z), cos(rotation_z))
	);
	VERTEX.xy = rot * VERTEX.xy;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Add glow effect
	vec4 glow_effect = glow_color * glow_intensity * smoothstep(0.4, 0.5, distance(UV, vec2(0.5)));

	// Combine texture with glow
	COLOR = tex_color + glow_effect * tex_color.a;
}