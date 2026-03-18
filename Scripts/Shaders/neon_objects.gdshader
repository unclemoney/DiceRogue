shader_type canvas_item;
// Neon Objects - Floating 3D geometric shapes on a dark grid
// Created for DiceRogue (Guhtzee)
// Inspired by late 80s Trapper Keeper art: neon cubes, spheres, prisms floating in space
// Features 2D-projected 3D shapes with lighting, neon edge glow, chrome sheen, depth fog

// Background colors
uniform vec4 colour_1 : source_color = vec4(0.04, 0.02, 0.12, 1.0);  // Deep dark void
uniform vec4 colour_2 : source_color = vec4(0.0, 0.7, 0.75, 1.0);    // Teal grid lines
uniform vec4 colour_3 : source_color = vec4(0.65, 0.0, 0.9, 1.0);    // Purple accents

// Shape colors
uniform vec4 shape_color_1 : source_color = vec4(0.1, 0.5, 0.95, 1.0); // Blue shapes
uniform vec4 shape_color_2 : source_color = vec4(0.9, 0.1, 0.5, 1.0);  // Pink shapes
uniform vec4 shape_color_3 : source_color = vec4(0.0, 0.85, 0.7, 1.0); // Cyan shapes

// Controls
uniform float shape_density : hint_range(2.0, 10.0) = 5.0;
uniform float float_speed : hint_range(0.0, 1.0) = 0.15;
uniform float rotation_speed : hint_range(0.0, 1.0) = 0.25;
uniform float grid_opacity : hint_range(0.0, 1.0) = 0.35;
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float chrome_sheen : hint_range(0.0, 1.0) = 0.4;
uniform float pixel_filter : hint_range(200.0, 1000.0) = 500.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;

// Hash functions
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

// Rotate 2D
vec2 rotate2d(vec2 p, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// Perspective grid background (simplified from neon_grid)
vec3 render_grid(vec2 uv, float t) {
	vec2 grid_uv = uv;
	// Mild perspective warp
	grid_uv.y = pow(grid_uv.y, 1.3);
	grid_uv.y += t * float_speed * 0.3;
	grid_uv.x += t * float_speed * 0.1;

	vec2 grid_pos = grid_uv * 16.0;
	vec2 gf = fract(grid_pos);

	float h_line = smoothstep(0.95, 1.0, gf.y) + smoothstep(0.05, 0.0, gf.y);
	float v_line = smoothstep(0.95, 1.0, gf.x) + smoothstep(0.05, 0.0, gf.x);
	float grid = max(h_line, v_line) * 0.5;

	vec3 grid_col = mix(colour_2.rgb, colour_3.rgb, uv.y);
	return grid_col * grid * grid_opacity;
}

// SDF: Sphere (shaded circle with specular)
// Returns vec4: rgb = lit color, a = coverage
vec4 render_sphere(vec2 p, float radius, vec3 base_col, float seed, float t) {
	float dist = length(p);
	if (dist > radius * 1.5) return vec4(0.0);

	float body = smoothstep(radius, radius - 0.008, dist);
	if (body < 0.001) return vec4(0.0);

	// Normal approximation for lighting
	float nd = dist / radius;
	vec2 normal_xy = p / radius;
	float nz = sqrt(max(0.0, 1.0 - nd * nd));

	// Directional light from upper-left
	vec3 light_dir = normalize(vec3(-0.5, -0.6, 0.6));
	vec3 normal = normalize(vec3(normal_xy, nz));
	float diffuse = max(dot(normal, -light_dir), 0.0);
	diffuse = diffuse * 0.7 + 0.3; // Ambient

	// Specular highlight
	vec3 view_dir = vec3(0.0, 0.0, 1.0);
	vec3 reflect_dir = reflect(light_dir, normal);
	float spec = pow(max(dot(reflect_dir, view_dir), 0.0), 32.0);

	// Chrome rainbow reflection
	float chrome_angle = atan(p.y, p.x);
	vec3 chrome_col = vec3(
		sin(chrome_angle * 2.0 + t + seed * 6.0) * 0.5 + 0.5,
		sin(chrome_angle * 2.0 + t + seed * 6.0 + 2.094) * 0.5 + 0.5,
		sin(chrome_angle * 2.0 + t + seed * 6.0 + 4.189) * 0.5 + 0.5
	);

	vec3 col = base_col * diffuse;
	col += vec3(1.0) * spec * 0.8;
	col = mix(col, chrome_col * diffuse, chrome_sheen * 0.5);

	// Edge glow
	float edge = smoothstep(0.6, 1.0, nd) * (1.0 - smoothstep(0.95, 1.0, nd));
	col += base_col * edge * glow_intensity * 0.5;

	return vec4(col, body);
}

// SDF: Cube (isometric projection)
vec4 render_cube(vec2 p, float size, vec3 base_col, float angle, float seed, float t) {
	// Rotate the point
	vec2 rp = rotate2d(p, angle * 0.3);

	// Isometric cube: three visible faces (top, left, right)
	float s = size;

	// Top face (parallelogram)
	vec2 top_p = rp - vec2(0.0, -s * 0.5);
	// Transform to isometric: skew
	vec2 iso_top = vec2(top_p.x - top_p.y * 0.5, top_p.y * 0.866 + top_p.x * 0.0);

	// Simplified cube as diamond + extensions
	// Diamond shape for top face
	float top_d = abs(rp.x) * 0.866 + abs(rp.y + s * 0.25) * 0.5;
	float top_face = smoothstep(s * 0.55, s * 0.52, top_d) * step(rp.y, s * 0.0);

	// Left face
	float left_face = 0.0;
	if (rp.x < 0.0) {
		float lf = step(-s * 0.5, rp.x) * step(rp.y, s * 0.25);
		float ld = abs(rp.x + s * 0.25);
		left_face = smoothstep(s * 0.52, s * 0.48, ld) * step(0.0, rp.y + s * 0.25) * step(rp.y, rp.x * 0.577 + s * 0.55);
	}

	// Right face
	float right_face = 0.0;
	if (rp.x >= 0.0) {
		float rd = abs(rp.x - s * 0.25);
		right_face = smoothstep(s * 0.52, s * 0.48, rd) * step(0.0, rp.y + s * 0.25) * step(rp.y, -rp.x * 0.577 + s * 0.55);
	}

	// Overall cube body approximation (hexagonal shape)
	float hex_d = max(abs(rp.x) * 0.866 + abs(rp.y) * 0.5, abs(rp.y));
	float body = smoothstep(s * 0.62, s * 0.58, hex_d);

	if (body < 0.001) return vec4(0.0);

	// Face lighting
	vec3 col = base_col;
	float face_y = rp.y / s;
	if (face_y < -0.05) {
		col = base_col * 1.1; // Top face (bright)
	} else if (rp.x < 0.0) {
		col = base_col * 0.65; // Left face (dark)
	} else {
		col = base_col * 0.85; // Right face (medium)
	}

	// Chrome reflection
	float chrome_v = sin(rp.x * 15.0 + rp.y * 10.0 + t + seed * 5.0) * 0.5 + 0.5;
	vec3 chrome = vec3(chrome_v, chrome_v * 0.8, 1.0 - chrome_v);
	col = mix(col, chrome, chrome_sheen * 0.3);

	// Neon edge glow (outline)
	float edge = smoothstep(s * 0.58, s * 0.54, hex_d) * (1.0 - smoothstep(s * 0.54, s * 0.50, hex_d));
	float edge_glow = smoothstep(s * 0.62, s * 0.54, hex_d) * (1.0 - body);
	col += base_col * glow_intensity * 0.4 * edge;

	return vec4(col, body);
}

// SDF: Wireframe pyramid / triangular prism
vec4 render_pyramid(vec2 p, float size, vec3 base_col, float angle, float seed, float t) {
	vec2 rp = rotate2d(p, angle * 0.2);
	float s = size;

	// Triangle body
	float tri_y = rp.y + s * 0.3;
	float tri_w = s * (1.0 - (tri_y / (s * 1.2)));
	if (tri_y < 0.0 || tri_y > s * 1.2) return vec4(0.0);
	if (abs(rp.x) > tri_w * 0.55) return vec4(0.0);

	float body_d = max(abs(rp.x) / tri_w - 0.5, 0.0);
	float body = smoothstep(0.05, 0.0, body_d) * step(0.0, tri_y) * step(tri_y, s * 1.15);

	if (body < 0.001) return vec4(0.0);

	// Wireframe: draw edges only
	float edge_width = 0.012;
	// Left edge
	float left_slope = rp.x + tri_w * 0.5;
	float left_line = smoothstep(edge_width, edge_width * 0.3, abs(left_slope));
	// Right edge
	float right_slope = rp.x - tri_w * 0.5;
	float right_line = smoothstep(edge_width, edge_width * 0.3, abs(right_slope));
	// Bottom edge
	float bot_line = smoothstep(edge_width, edge_width * 0.3, abs(tri_y));
	// Internal cross line
	float mid_line = smoothstep(edge_width * 0.7, edge_width * 0.2, abs(rp.x));

	float wireframe = max(max(left_line, right_line), max(bot_line, mid_line * 0.5));
	wireframe *= body;

	// Fill with dim interior + bright wireframe
	vec3 fill_col = base_col * 0.15;
	vec3 wire_col = base_col * (1.0 + glow_intensity * 0.5);

	// Animated pulse on wireframe
	float pulse = sin(t * 2.0 + seed * 6.283) * 0.3 + 0.7;
	wire_col *= pulse;

	vec3 col = mix(fill_col, wire_col, wireframe);

	// Outer glow
	float glow_body = smoothstep(s * 0.7, s * 0.3, length(p)) * 0.15 * glow_intensity;
	col += base_col * glow_body;

	return vec4(col, body * 0.85);
}

// SDF: Diamond / octahedron cross-section
vec4 render_diamond(vec2 p, float size, vec3 base_col, float angle, float seed, float t) {
	vec2 rp = rotate2d(p, angle * 0.4);
	float s = size;

	// Diamond = rotated square SDF
	float d = (abs(rp.x) + abs(rp.y)) / s;
	float body = smoothstep(0.72, 0.68, d);

	if (body < 0.001) return vec4(0.0);

	// Face lighting based on quadrant
	vec3 col = base_col;
	if (rp.y < 0.0) {
		col *= 1.1; // Top bright
	} else {
		col *= 0.7; // Bottom dark
	}
	if (rp.x < 0.0) {
		col *= 0.85;
	}

	// Facet lines (internal edges of gem cut)
	float facet1 = smoothstep(0.008, 0.003, abs(rp.x));
	float facet2 = smoothstep(0.008, 0.003, abs(rp.y));
	float facet3 = smoothstep(0.008, 0.003, abs(rp.x - rp.y));
	float facet4 = smoothstep(0.008, 0.003, abs(rp.x + rp.y));
	float facets = max(max(facet1, facet2), max(facet3, facet4)) * 0.6;
	col = mix(col, base_col * 1.5 + vec3(0.3), facets);

	// Chrome sheen
	float sheen = sin(rp.x * 20.0 + rp.y * 15.0 + t * 1.5 + seed * 4.0) * 0.5 + 0.5;
	col = mix(col, vec3(sheen, 0.8, 1.0 - sheen * 0.5) * 0.8, chrome_sheen * 0.35);

	// Edge neon glow
	float edge = smoothstep(0.68, 0.64, d) * (1.0 - smoothstep(0.64, 0.58, d));
	col += base_col * edge * glow_intensity * 0.6;

	return vec4(col, body);
}

void fragment() {
	// Pixelation
	vec2 screen_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float pixel_size = length(screen_size) / pixel_filter;
	vec2 uv = floor(UV * screen_size / pixel_size) * pixel_size / screen_size;

	float t = TIME;

	// Dark background
	vec3 col = colour_1.rgb;

	// Add subtle radial gradient
	float center_d = length(uv - 0.5);
	col += colour_1.rgb * 0.4 * (1.0 - center_d);

	// Perspective grid
	col += render_grid(uv, t);

	// === Floating objects ===
	vec2 scroll = vec2(t * float_speed * 0.2, t * float_speed * 0.15);
	vec2 grid_uv = (uv + scroll) * shape_density;
	vec2 cell_id = floor(grid_uv);
	vec2 cell_fract = fract(grid_uv) - 0.5;

	for (int dx = -1; dx <= 1; dx++) {
		for (int dy = -1; dy <= 1; dy++) {
			vec2 neighbor = vec2(float(dx), float(dy));
			vec2 id = cell_id + neighbor;

			// Skip some cells
			float presence = hash21(id + 7.0);
			if (presence > 0.6) continue;

			// Position jitter
			vec2 pos_rand = hash22(id + 50.0) * 0.6 - 0.3;
			vec2 p = cell_fract - neighbor - pos_rand;

			// Scale to world coords
			p /= shape_density;

			// Depth (for fog and draw order hint)
			float depth = hash21(id + 30.0);
			float depth_fade = 0.5 + depth * 0.5;

			// Object size
			float obj_size = 0.03 + hash21(id + 3.0) * 0.03;

			// Rotation angle (animated)
			float rot = hash21(id + 11.0) * 6.283 + t * rotation_speed * (0.5 + depth);

			// Choose shape type
			float shape_type = hash21(id + 5.0);

			// Choose color
			float color_pick = hash21(id + 9.0);
			vec3 shape_col = shape_color_1.rgb;
			if (color_pick < 0.33) {
				shape_col = shape_color_1.rgb;
			} else if (color_pick < 0.66) {
				shape_col = shape_color_2.rgb;
			} else {
				shape_col = shape_color_3.rgb;
			}

			// Apply depth fog
			shape_col *= depth_fade;

			// Render appropriate shape
			vec4 shape_result = vec4(0.0);
			float seed = hash21(id + 17.0);

			if (shape_type < 0.3) {
				shape_result = render_sphere(p, obj_size, shape_col, seed, t);
			} else if (shape_type < 0.55) {
				shape_result = render_cube(p, obj_size, shape_col, rot, seed, t);
			} else if (shape_type < 0.75) {
				shape_result = render_pyramid(p, obj_size, shape_col, rot, seed, t);
			} else {
				shape_result = render_diamond(p, obj_size, shape_col, rot, seed, t);
			}

			if (shape_result.a > 0.001) {
				// Additive glow halo behind object
				float halo_dist = length(p) / (obj_size * 2.5);
				float halo = exp(-halo_dist * halo_dist * 3.0) * glow_intensity * 0.15;
				col += shape_col * halo;

				// Composite object
				col = mix(col, shape_result.rgb, shape_result.a);
			}
		}
	}

	// Subtle scanlines
	float scanline = sin(uv.y * screen_size.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scanline * 0.3;

	// Vignette
	col *= 1.0 - center_d * 0.4;

	COLOR = vec4(col, 1.0);
}
