shader_type canvas_item;

// mall_floor_tiles.gdshader
//
// Procedural dark grey tiled corridor floor: two-tone checker tiles, grout
// lines, and a subtle per-tile tint from a cell hash. No textures.
// Position comes through a varying (canvas_item fragment has no VERTEX), so
// the grid is continuous across every polygon sharing the same parent space.

uniform float tile_size_px = 16.0;
uniform float grout_width = 2.0;
uniform vec4 color_a : source_color = vec4(0.28, 0.28, 0.30, 1.0);
uniform vec4 color_b : source_color = vec4(0.34, 0.34, 0.36, 1.0);
uniform vec4 grout_color : source_color = vec4(0.16, 0.16, 0.18, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.08;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 cell = floor(local_pos / tile_size_px);
	vec2 cell_uv = fract(local_pos / tile_size_px);

	float checker = mod(cell.x + cell.y, 2.0);
	vec3 tile_color = mix(color_a.rgb, color_b.rgb, checker);

	float hash = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	tile_color *= 1.0 + (hash - 0.5) * 2.0 * tint_strength;

	float grout = step(cell_uv.x, grout_width / tile_size_px) + step(cell_uv.y, grout_width / tile_size_px);
	vec3 color = mix(tile_color, grout_color.rgb, clamp(grout, 0.0, 1.0));

	COLOR = vec4(color, color_a.a);
}
