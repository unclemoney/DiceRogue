shader_type canvas_item;

// Tooltip border: rarity-tinted rounded-rect border with a one-shot
// welding-torch trace on show. `trace` sweeps 0->1 around the ROUNDED
// perimeter at constant speed (arc-length parameterized: 4 straights +
// 4 quarter arcs); the hot spot parks as trace approaches 1.
// canvas_item has no built-in SIZE — tooltip.gd feeds `rect_size` on resize.

uniform vec4 border_color : source_color = vec4(0.95, 0.86, 0.42, 1.0);
uniform float border_width = 3.0;
uniform float trace : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform float glow_size = 6.0;
uniform float trail = 0.12;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(260.0, 120.0);
uniform float corner_radius = 8.0;

void fragment() {
	vec2 px = (UV - 0.5) * rect_size; // centered pixel coords, y down
	vec2 half_s = rect_size * 0.5;
	float r = corner_radius;
	float sw = rect_size.x - 2.0 * r;  // horizontal straight length
	float sh = rect_size.y - 2.0 * r;  // vertical straight length
	float arc = PI * r * 0.5;          // quarter-arc length
	float perimeter = 2.0 * (rect_size.x + rect_size.y) - 8.0 * r + 2.0 * PI * r;

	// Rounded-rect SDF (negative inside).
	vec2 q = abs(px) - (half_s - vec2(r));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;

	// Arc-length parameter of the nearest outline point,
	// clockwise from top-left: top straight, TR arc, right straight,
	// BR arc, bottom straight (R->L), BL arc, left straight (B->T), TL arc.
	vec2 inner = half_s - vec2(r);
	vec2 apx = abs(px);
	float along;
	if (apx.x > inner.x && apx.y > inner.y) {
		// Corner zone: quarter arc around the corner center.
		vec2 cc = vec2(sign(px.x) * inner.x, sign(px.y) * inner.y);
		float ang = atan(px.y - cc.y, px.x - cc.x);
		if (px.x > 0.0 && px.y < 0.0) {
			// top-right: -90..0 degrees
			along = sw + (ang + PI * 0.5) / (PI * 0.5) * arc;
		} else if (px.x > 0.0) {
			// bottom-right: 0..90 degrees
			along = sw + arc + sh + ang / (PI * 0.5) * arc;
		} else if (px.y > 0.0) {
			// bottom-left: 90..180 degrees
			along = sw + arc + sh + arc + sw + (ang - PI * 0.5) / (PI * 0.5) * arc;
		} else {
			// top-left: 180..270 degrees (atan returns -180..-90 here)
			along = sw + arc + sh + arc + sw + arc + sh + (ang + PI) / (PI * 0.5) * arc;
		}
	} else {
		float dist_top = px.y + half_s.y;
		float dist_right = half_s.x - px.x;
		float dist_bottom = half_s.y - px.y;
		float dist_left = px.x + half_s.x;
		float dmin = min(min(dist_top, dist_right), min(dist_bottom, dist_left));
		if (dmin == dist_top) {
			along = px.x + half_s.x - r;
		} else if (dmin == dist_right) {
			along = sw + arc + (px.y + half_s.y - r);
		} else if (dmin == dist_bottom) {
			along = sw + arc + sh + arc + (half_s.x - r - px.x);
		} else {
			along = sw + arc + sh + arc + sw + arc + (half_s.y - r - px.y);
		}
	}
	float t = clamp(along / perimeter, 0.0, 1.0);

	// Hot spot: wrapped distance from the trace head along the perimeter.
	float delta = abs(t - trace);
	delta = min(delta, 1.0 - delta);
	float hot = smoothstep(trail, 0.0, delta);
	// Park the hot spot as the trace completes: full border lit, no traveler.
	hot *= 1.0 - smoothstep(0.9, 1.0, trace);

	float on_line = 1.0 - smoothstep(border_width * 0.5 - 0.75, border_width * 0.5 + 0.75, abs(d));
	float halo = (1.0 - on_line) * smoothstep(glow_size + border_width * 0.5, border_width * 0.5, abs(d)) * hot;

	vec3 line_col = mix(border_color.rgb, glow_color.rgb, hot) * (1.0 + 2.2 * hot);
	vec3 col = line_col * on_line + glow_color.rgb * halo;
	float a = max(on_line * border_color.a, halo * glow_color.a);
	COLOR = vec4(col, a * fade);
}
