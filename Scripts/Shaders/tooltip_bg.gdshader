shader_type canvas_item;

// Tooltip background: subtle animated shimmer over a near-black fill.
// Shimmer bands and vignette are PIXEL-based (rect_size), so small tooltips
// still show a visible band and large ones show several.
// `fade` is driven by tooltip.gd's show/hide tweens; `rect_size` is fed
// on resize (canvas_item has no built-in SIZE).

uniform vec4 base_color : source_color = vec4(0.12, 0.10, 0.14, 0.98);
uniform float shimmer_strength : hint_range(0.0, 0.12) = 0.06;
uniform float shimmer_wavelength_px = 110.0;
uniform float vignette_margin_px = 26.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale = 0.35;
uniform vec2 rect_size = vec2(260.0, 120.0);
uniform float corner_radius = 8.0;

void fragment() {
	vec2 px = (UV - 0.5) * rect_size; // centered pixel coords
	float band = sin((px.x + px.y) * TAU / shimmer_wavelength_px + TIME * time_scale) * shimmer_strength;
	float edge_dist = min(
		min(px.x + rect_size.x * 0.5, rect_size.x * 0.5 - px.x),
		min(px.y + rect_size.y * 0.5, rect_size.y * 0.5 - px.y));
	float vig = 1.0 - 0.08 * smoothstep(vignette_margin_px, 0.0, edge_dist);
	vec3 col = base_color.rgb * (1.0 + band) * vig;
	// Rounded-rect SDF (same math as tooltip_border.gdshader): fade alpha out
	// over ~1.5px past the corner arc instead of painting opaque square corners.
	// A smoothstep blend (not discard) keeps the edge anti-aliased — a hard cut
	// aliases visibly during the scale-pop show animation.
	vec2 q = abs(px) - (rect_size * 0.5 - vec2(corner_radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float corner_alpha = 1.0 - smoothstep(-0.75, 0.75, d);
	COLOR = vec4(col, base_color.a * fade * corner_alpha);
}
