shader_type canvas_item;

// mall_lightbox.gdshader
//
// Lightbox backdrop for the mall map: light grey/white base, a soft radial
// sheen from top-center, a gentle vignette at the visible panel edges, and
// one faint diagonal specular band. Static. No textures.
// Position comes through a varying (canvas_item fragment has no VERTEX);
// view_size is the visible viewport rect, not the full board polygon.

uniform vec4 base_color : source_color = vec4(0.93, 0.94, 0.96, 1.0);
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.18;
uniform float band_strength : hint_range(0.0, 1.0) = 0.10;
uniform vec2 view_size = vec2(900.0, 360.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = local_pos / view_size;

	// Radial sheen from top-center.
	float sheen_dist = distance(uv * vec2(view_size.x / view_size.y, 1.0), vec2(0.5 * view_size.x / view_size.y, 0.0));
	float sheen = 1.0 - smoothstep(0.0, 0.9, sheen_dist);

	// Gentle vignette at the panel edges.
	float edge = min(min(uv.x, 1.0 - uv.x) * view_size.x, min(uv.y, 1.0 - uv.y) * view_size.y);
	float vignette = smoothstep(0.0, 90.0, edge);

	// Faint diagonal specular band.
	float band_coord = dot(uv, normalize(vec2(1.0, 0.6)));
	float band = smoothstep(0.02, 0.0, abs(band_coord - 0.62) - 0.10);

	vec3 color = base_color.rgb;
	color += vec3(1.0) * sheen * sheen_strength * 0.25;
	color *= mix(1.0 - vignette_strength, 1.0, vignette);
	color += vec3(1.0) * band * band_strength;

	COLOR = vec4(color, base_color.a);
}
