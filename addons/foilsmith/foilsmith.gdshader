shader_type canvas_item;
render_mode blend_premul_alpha;
// Draws a card (the node's TEXTURE is the front art) with foilsmith's finish: fake 3D tilt, parallax
// over the depth map, relief lighting from the normal map, the subject's pop-out shadow and rim, a foil
// finish (holo, cracked ice, gold, galaxy, glitch, arcane, inverse, engraved, spectrum or standard: see
// apply_finish), a flat frame laid over the art, a specular glint, glare and edge shading. Turned
// away, it shows the back: an image with its own maps, shaded exactly like the front.
// A port of crates/preview/src/shade.rs (and foilsmith.frag is the same again in GLSL ES): keep them in
// step. Same constants, hash and hsv, so a frame here matches the CPU preview.
//
// The node: a Sprite2D or TextureRect showing the art, so the rect has the card's proportions. The card
// is drawn card_scale of the rect, centred: leave room for tilted corners (~0.92). Outside the card
// it's transparent. Use the node's texture filter Linear (or Nearest for pixel art: that path fetches
// texels itself). The art is straight alpha (Godot's default import; keep "Fix Alpha Border" on).
//
// Maps (from the `foilsmith` CLI: <name>_fx.png, <name>_normal.png, <name>.json):
//   fx_map: R foil, G depth, B art window, A pop-out mask. A is data, not coverage: import it with
//     "Fix Alpha Border" and "Premultiply Alpha" OFF, compression Lossless, mipmaps off.
//   normal_map: tangent space, OpenGL (+Y up). Import with "Normal Map: Disabled", Lossless, mipmaps off.
//     (If it was imported as an RG normal map anyway, Z is rebuilt from X and Y.) Optional: flat if unset.
//   back_tex, back_fx_map, back_normal_map: the back's art and maps, the same kinds and import
//     settings as the front's (back_tex like the art). The back is drawn the right way round (sampled
//     at (1 - u, v)); its own alpha is its silhouette. Unset: nothing shows when the card faces away.
//   frame_tex, frame_foil (has_frame on): a flat frame drawn over the front's art (<name>_frame.png,
//     straight alpha, and <name>_frame_foil.png, its metal in R), any size with the card's proportions.
//     It sits on the card plane (no parallax), widens the silhouette to its own alpha, and takes the
//     finish on its metal. Import both without premultiply, Lossless, mipmaps off. The back has none.
// Every map is sampled bilinearly (filter_linear); where the CPU preview samples nearest (pixel-art
// mode) this shader fetches the texel itself, so no filter_nearest hint is needed.
//
// Output is premultiplied (blend_premul_alpha). The CPU preview's backdrop, aura and drop shadow are
// scene dressing and aren't drawn here.

uniform vec2 tilt = vec2(0.0);          // radians: x = yaw, y = pitch. |yaw| past pi/2 shows the back
uniform float card_scale : hint_range(0.1, 1.0) = 1.0;   // the card's size in the rect, so tilted corners fit
uniform float aspect = 0.0;             // card width / height (0: from the art's size)
uniform float loop_period = 0.0;        // seconds; > 0 snaps every oscillator to whole cycles per loop
uniform float seed = 0.0;               // varies the sparkles between cards
uniform float clock = -1.0;             // seconds; < 0 runs on TIME. Set it to render a given preview frame
uniform int finish : hint_enum("Holo", "Cracked ice", "Gold", "Galaxy", "Glitch", "Standard", "Arcane", "Inverse", "Engraved", "Spectrum") = 0;
uniform bool back_finish = false;       // the back takes the finish too (false: the back is standard)
uniform int debug_view : hint_enum("Shaded", "Foil", "Depth", "Pop", "Normal") = 0;   // the raw maps on the card

uniform sampler2D fx_map : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_linear, repeat_disable;
uniform sampler2D back_tex : hint_default_transparent, filter_linear, repeat_disable;
uniform sampler2D back_fx_map : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D back_normal_map : hint_normal, filter_linear, repeat_disable;
uniform bool has_frame = false;         // draw the frame layer over the front
uniform sampler2D frame_tex : hint_default_transparent, filter_linear, repeat_disable;
uniform sampler2D frame_foil : hint_default_black, filter_linear, repeat_disable;

group_uniforms look;
uniform float foil : hint_range(0.0, 2.0) = 1.0;            // foil strength
uniform float depth_scale : hint_range(0.0, 0.2) = 0.02;    // how far the subject rises, in card heights (parallax)
uniform float glint : hint_range(0.0, 2.0) = 1.0;           // specular glint
uniform float sparkle : hint_range(0.0, 2.0) = 0.9;         // glitter in the foil
uniform float glare : hint_range(0.0, 2.0) = 0.2;           // soft glare that follows the tilt
uniform float relief : hint_range(0.0, 2.0) = 0.9;          // normal-map relief lighting
uniform float shadow : hint_range(0.0, 1.0) = 0.45;         // the subject's shadow on the card
uniform float hue_cycles = 1.0;         // full rainbow cycles per loop (or per ~33 s) on top of the tilt
uniform bool supersample = true;        // 4x rotated-grid supersampling, as the CPU preview does

group_uniforms pixel_art;
// from <name>.json: pixel_art, native_size, hue_steps (the back's from its own JSON)
uniform bool pixel_art = false;         // every effect works on whole art pixels
uniform vec2 native_size = vec2(0.0);   // the art's native pixel grid (0: the texture's size)
uniform int hue_steps = 0;              // foil hue steps (0: continuous rainbow)
uniform bool back_pixel_art = false;
uniform vec2 back_native_size = vec2(0.0);
uniform int back_hue_steps = 0;
group_uniforms;

varying vec4 v_modulate;  // node modulate/self_modulate, captured before we overwrite COLOR

const float CAMERA_D = 2.4;

// the art at a uv, premultiplied by coverage like the CPU's art texture: zero outside the card. Nearest
// fetches the texel; bilinear fades to zero over the outer half texel, as the CPU's zero border does.
// A macro, as Godot can't pass TEXTURE to a function: it needs `art_size` in scope.
#define ART_AT(uv, nearest) ((nearest) ? art_texel(uv, art_size) : textureLod(TEXTURE, uv, 0.0) * art_fade(uv, art_size))
// the side's art (front or back)
#define SIDE_AT(uv, nearest, back) ((back) ? back_at(uv, nearest) : ART_AT(uv, nearest))
#define art_texel(uv, size) (texel_in(uv, size) ? texelFetch(TEXTURE, ivec2(floor((uv) * (size))), 0) : vec4(0.0))

void vertex() {
	v_modulate = COLOR;
}

bool texel_in(vec2 uv, vec2 size) {
	vec2 x = uv * size;
	return x.x >= 0.0 && x.y >= 0.0 && x.x < size.x && x.y < size.y;
}
// bilinear with a zero border: the fade over the outer half texel
float edge_fade(vec2 uv, vec2 size) {
	vec2 x = uv * size;
	vec2 k = clamp(min(x + 0.5, size + 0.5 - x), 0.0, 1.0);
	return k.x * k.y;
}
// straight-alpha art: only the alpha fades
vec4 art_fade(vec2 uv, vec2 size) {
	return vec4(1.0, 1.0, 1.0, edge_fade(uv, size));
}
ivec2 texel_of(vec2 uv, ivec2 sz) {
	return clamp(ivec2(floor(uv * vec2(sz))), ivec2(0), sz - 1);
}
// the back's art, like the front's (zero outside the card)
vec4 back_at(vec2 uv, bool nearest) {
	vec2 size = vec2(textureSize(back_tex, 0));
	if (nearest) { return texel_in(uv, size) ? texelFetch(back_tex, ivec2(floor(uv * size)), 0) : vec4(0.0); }
	return textureLod(back_tex, uv, 0.0) * art_fade(uv, size);
}
// the frame (zero outside it, like the art) and its foil mask: always bilinear
vec4 frame_at(vec2 uv) {
	vec2 size = vec2(textureSize(frame_tex, 0));
	return textureLod(frame_tex, uv, 0.0) * art_fade(uv, size);
}
float frame_foil_at(vec2 uv) {
	vec2 size = vec2(textureSize(frame_foil, 0));
	return textureLod(frame_foil, uv, 0.0).r * edge_fade(uv, size);
}
// the front's or the back's FX map
vec4 fx_at(vec2 uv, bool nearest, bool back) {
	if (back) {
		if (nearest) { return texelFetch(back_fx_map, texel_of(uv, textureSize(back_fx_map, 0)), 0); }
		return textureLod(back_fx_map, uv, 0.0);
	}
	if (nearest) { return texelFetch(fx_map, texel_of(uv, textureSize(fx_map, 0)), 0); }
	return textureLod(fx_map, uv, 0.0);
}
vec3 normal_at(vec2 uv, bool nearest, bool back) {
	vec3 nm;
	if (back) {
		nm = nearest ? texelFetch(back_normal_map, texel_of(uv, textureSize(back_normal_map, 0)), 0).rgb : textureLod(back_normal_map, uv, 0.0).rgb;
	} else {
		nm = nearest ? texelFetch(normal_map, texel_of(uv, textureSize(normal_map, 0)), 0).rgb : textureLod(normal_map, uv, 0.0).rgb;
	}
	// an RG-only normal map (B reads 0, never < 0.25 in a real tangent-space map): rebuild Z
	if (nm.b < 0.25) {
		vec2 xy = nm.rg * 2.0 - 1.0;
		nm.b = sqrt(max(1.0 - dot(xy, xy), 0.0)) * 0.5 + 0.5;
	}
	return nm;
}

vec3 hsv(float h, float s, float v) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}
// sin-free hash (Dave Hoskins): GPU sin() is imprecise at large inputs
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx + seed * 13.7) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash2(vec2 p) { return vec2(hash(p), hash(p + 17.31)); }
vec3 screen_blend(vec3 a, vec3 b) { return 1.0 - (1.0 - a) * (1.0 - b); }
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
// value noise and fractal noise over it
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
// the art's colour from a sample (straight alpha already: Godot's import)
vec3 color_of(vec4 t) { return t.a > 1e-4 ? t.rgb : vec3(0.0); }
vec3 nrm(vec3 a) { return a / max(length(a), 1e-8); }
// round half away from zero, like Rust's f32::round (GLSL's round() may round half to even)
float rnd(float x) { return sign(x) * floor(abs(x) + 0.5); }

// the yaw of whichever face is towards the camera, in -pi/2..pi/2: lighting and glare follow the
// visible face through a spin
float facing_yaw(float yaw) {
	float y = atan(sin(yaw), cos(yaw));
	if (y > PI * 0.5) { return y - PI; }
	if (y < -PI * 0.5) { return y + PI; }
	return y;
}
// loop-safe oscillator rate: with a loop period the rate snaps to whole cycles per loop
float rate(float r) {
	if (loop_period > 0.0) { return max(rnd(r * loop_period / TAU), 1.0) * TAU / loop_period; }
	return r;
}

// what's fixed for the whole card, and the side being shaded (front or back)
struct Card {
	float aspect;
	vec2 face;     // the card in "face pixels" (700 tall), the unit effect sizes are tuned in
	float t;       // seconds
	bool pixel;    // pixel art: every effect works on whole art pixels
	vec2 native;   // pixel grid
	vec2 px;       // one art pixel in face pixels
	int hue_steps; // foil hue steps (0: continuous)
	vec2 art_px;   // one texel of the side's art, in UV
};

// rotation of the card (yaw then pitch)
mat3 pose(vec2 tl) {
	float cx = cos(tl.y), sx = sin(tl.y), cy = cos(tl.x), sy = sin(tl.x);
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cx, sx), vec3(0.0, -sx, cx));
	mat3 ry = mat3(vec3(cy, 0.0, -sy), vec3(0.0, 1.0, 0.0), vec3(sy, 0.0, cy));
	return ry * rx;
}

// where the view ray through p (card heights from the card's centre, y down) meets the card. The
// back is shaded in a mirrored card space (x and z flipped), where it's a face like the front
struct Geo {
	vec3 o;       // the camera, card space (mirrored for the back)
	vec3 d;       // the ray, card space (mirrored for the back)
	vec2 uv;      // card-plane hit, on the side seen ((1 - u, v) of the front's for the back)
	vec2 uv_e;    // the point seen there after parallax (snapped to art pixels in pixel-art mode)
	float h_d;    // its height
	vec2 cn;      // the side's normal in view space, xy (for edge shading)
	bool hit;     // near the card at all
	bool back;    // the camera is behind the card
};

Geo cast_ray(mat3 R, vec2 p, Card c) {
	Geo g = Geo(vec3(0.0), vec3(0.0), vec2(0.0), vec2(0.0), 0.0, vec2(0.0), false, false);
	g.o = transpose(R) * vec3(0.0, 0.0, -CAMERA_D);
	g.d = transpose(R) * vec3(p, CAMERA_D);
	vec3 hit = g.o + g.d * (-g.o.z / g.d.z);
	g.uv = vec2(hit.x / c.aspect + 0.5, hit.y + 0.5);
	g.hit = g.uv.x >= -0.01 && g.uv.x <= 1.01 && g.uv.y >= -0.01 && g.uv.y <= 1.01;
	g.back = g.o.z > 0.0;
	g.cn = R[2].xy;
	if (g.back) {
		g.o *= vec3(-1.0, 1.0, -1.0);
		g.d *= vec3(-1.0, 1.0, -1.0);
		g.uv.x = 1.0 - g.uv.x;
		g.cn.x = -g.cn.x;
	}
	g.uv_e = g.uv;
	if (!g.hit) { return g; }
	// parallax occlusion: march from depth_scale in front of the card down to it, take the first
	// point under the height field
	vec3 o = g.o, d = g.d;
	vec2 uv_d = g.uv;
	float ds = depth_scale;
	if (ds > 0.0) {
		float s0 = (-ds - o.z) / d.z, s1 = -o.z / d.z;
		vec2 prev_uv = g.uv;
		float prev_gap = -1.0;
		for (int i = 0; i <= 32; i++) {
			float s = mix(s0, s1, float(i) / 32.0);
			float pz = o.z + d.z * s;
			vec2 puv = vec2((o.x + d.x * s) / c.aspect + 0.5, o.y + d.y * s + 0.5);
			float h = fx_at(puv, c.pixel, g.back).g;
			float gap = pz + h * ds;   // >= 0: the ray is at or under the surface
			if (gap >= 0.0) {
				float k = i == 0 ? 1.0 : prev_gap / (prev_gap - gap);
				uv_d = mix(prev_uv, puv, k);
				g.h_d = h;
				break;
			}
			prev_uv = puv;
			prev_gap = gap;
		}
	}
	// pixel art: every effect works on whole art pixels
	g.uv_e = c.pixel ? (floor(uv_d * c.native) + 0.5) / c.native : uv_d;
	return g;
}

// four-point star glints (face pixels), each on its own twinkle
float sparkles(vec2 uv, float view, Card c) {
	vec2 fp = uv * c.face;
	if (c.pixel) { fp = (floor(fp / c.px) + 0.5) * c.px; }
	float cs = 26.0;
	vec2 ci = floor(fp / cs);
	float total = 0.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 cell = ci + vec2(float(x), float(y));
		float h = hash(cell * 1.37 + 3.1);
		if (h < 0.8) { continue; }
		vec2 o = hash2(cell + 9.2);
		vec2 d = fp - (cell + o) * cs;
		float s = max(sin(c.t * rate(1.2 + h * 2.0) + h * 60.0 + view * 14.0), 0.0);
		float tw = s * s * s * s;
		float len = (5.0 + 8.0 * hash(cell + 4.4)) * (0.4 + 0.6 * tw);
		if (c.pixel) {
			// a plus of whole art pixels
			vec2 ctr = floor((cell + o) * cs / c.px);
			vec2 q = floor(fp / c.px) - ctr;
			float arm = max(rnd(len / c.px.x * 0.5), 1.0);
			bool on = (q.x == 0.0 && abs(q.y) <= arm) || (q.y == 0.0 && abs(q.x) <= arm);
			if (on) { total += tw * ((q.x == 0.0 && q.y == 0.0) ? 1.5 : 0.8); }
			continue;
		}
		vec2 a = abs(d);
		vec2 r = abs(vec2(d.x + d.y, d.x - d.y)) * 0.7071;
		float rays = max(0.0, 1.0 - a.x / len) * exp(-a.y * a.y * 1.4)
			+ max(0.0, 1.0 - a.y / len) * exp(-a.x * a.x * 1.4)
			+ 0.45 * (max(0.0, 1.0 - r.x / (len * 0.45)) * exp(-r.y * r.y * 2.0)
				+ max(0.0, 1.0 - r.y / (len * 0.45)) * exp(-r.x * r.x * 2.0));
		float core = exp(-dot(d, d) * 0.35);
		total += (rays + core) * tw;
	}
	return min(total, 1.5);
}

// a fine grain of glinting flecks: each cell (`cell` face pixels, or one art pixel in pixel-art
// mode) flashes at its own viewing angle (finish.rs grain)
float grain(vec2 uv, float view, Card c, float cell) {
	vec2 cs = c.pixel ? c.px : vec2(cell);
	vec2 g = floor(uv * c.face / cs);
	float h = hash(g + 50.69);
	float s = max(sin(h * 50.0 + view * 15.0), 0.0);
	s *= s;
	s *= s;
	return s * s;
}

// step a hue for pixel art
float steps(float h, int n) { return n > 0 ? floor(h * float(n)) / float(n) : h; }
// smoothstep with its edges reversed (e0 > e1), well defined
float smoothstep_down(float e0, float e1, float x) { return 1.0 - smoothstep(e1, e0, x); }

// the art around the point seen, for finishes that look at it (glitch): the caller samples them, as
// Godot can't pass TEXTURE to a function. glitch_uv gives tap k's uv
struct Taps {
	vec3 r;    // the RGB split: red, green and blue taps
	vec3 g;
	vec3 b;
	vec3 xp;   // two art pixels right, left, down, up
	vec3 xm;
	vec3 yp;
	vec3 ym;
};
vec2 glitch_uv(vec2 uv, Card c, int k) {
	float view = facing_yaw(tilt.x) * 1.6 - tilt.y * 1.1;
	float burst = step(0.7, hash(vec2(floor(c.t * 0.5), 11.0)));
	float slice = burst * (hash(vec2(floor(uv.y * 30.0), floor(c.t * 2.0))) >= 0.96 ? 1.0 : 0.0);
	vec2 guv = vec2(uv.x + slice * 0.015 * sin(c.t * 50.0), uv.y);
	float split = 0.004 + abs(view) * 0.006;
	vec2 px = c.art_px;
	if (k == 0) { return guv + vec2(split, 0.0); }
	if (k == 1) { return guv; }
	if (k == 2) { return guv - vec2(split, 0.0); }
	if (k == 3) { return guv + vec2(px.x * 2.0, 0.0); }
	if (k == 4) { return guv - vec2(px.x * 2.0, 0.0); }
	if (k == 5) { return guv + vec2(0.0, px.y * 2.0); }
	return guv - vec2(0.0, px.y * 2.0);
}
float tap_l(vec3 s) { return (s.r + s.g + s.b) * 0.33; }

// FINISH: the foil step, picked by `fin` (finish.rs). Changes col and returns the finish's colour
// there, which tints the specular glint. uv is the point seen; foil_m, depth and pop its FX map; n its
// normal (card space); view the tilt-driven foil phase; tl the facing tilt; tp the art around it (glitch)
vec3 apply_finish(inout vec3 col, vec2 uv, float foil_m, float art_win, float pop, vec3 n, float view, vec2 tl, Card c, Taps tp, int fin) {
	float k = foil;
	float lum = luma(col);
	// where the art window is, and the foiled frame around it
	float art = art_win;   // the FX map's B: 1 in the art window, 0 on the frame and panels
	float frame = (1.0 - art) * smoothstep(0.3, 0.7, foil_m);
	bool pixel = c.pixel;
	float t = loop_period > 0.0 ? c.t / loop_period : c.t * 0.03;   // loop phase
	if (fin == 5) {
		// STANDARD: no foil at all, a plain printed card (it still catches the glare)
		return vec3(1.0);
	}
	if (fin == 1) {
		// CRACKED ICE: voronoi shards, each catching the light at its own angle
		vec2 g = vec2(uv.x * 7.0, uv.y * 10.0);
		vec2 gi = floor(g), gf = fract(g);
		float md = 8.0, md2 = 8.0;
		vec2 cell = vec2(0.0);
		for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec2 off = vec2(float(x), float(y));
			vec2 h = hash2(gi + off);
			vec2 dv = off + h - gf;
			float d = sqrt(dv.x * dv.x + dv.y * dv.y);
			if (d < md) {
				md2 = md;
				md = d;
				cell = gi + off;
			} else if (d < md2) {
				md2 = d;
			}
		}
		float r = hash(cell);
		float fl = max(sin(r * 31.0 + view * 9.0 + c.t * rate(0.2)), 0.0);
		float flash = fl * fl * fl * fl * fl * fl;
		vec3 tint = hsv(steps(fract(r + view * 0.5), c.hue_steps), 0.55, 1.0);
		vec3 shard = tint * (0.25 + flash);
		float edge = 1.0 - smoothstep(0.0, 0.05, md2 - md);
		float glit = sparkles(uv, view, c);
		float m = (art * 0.8 + (1.0 - art)) * k * (0.3 + 0.7 * max(foil_m, 0.4));
		col = screen_blend(col, (shard * 0.55 + vec3(edge * 0.18) + vec3(glit * 1.2 * sparkle)) * m);
		return tint;
	}
	if (fin == 2) {
		// GOLD: gild the whole card (the art lightly), a soft rainbow on the art's highlights, a sweeping shine bar
		vec3 gold_dark = vec3(0.45, 0.28, 0.05);
		vec3 gold_hi = vec3(1.0, 0.92, 0.55);
		float spec = 0.5 + 0.5 * sin(uv.y * 18.0 + uv.x * 6.0 + view * 8.0);
		vec3 gold = mix(gold_dark, gold_hi, clamp(lum * 0.8 + spec * 0.45, 0.0, 1.0));
		float gild = art * 0.35 + (1.0 - art) * (0.45 + 0.55 * smoothstep(0.3, 0.7, foil_m));
		float metal = gild * smoothstep(0.08, 0.5, lum + 0.25) * (1.0 - (lum > 0.9 ? 0.5 : 0.0));
		vec3 cc = mix(col, vec3(lum), gild * k);
		cc = mix(cc, gold * (0.7 + lum * 0.6), metal * 0.85 * k);
		vec3 rb = hsv(steps(fract(uv.y * 1.5 + view * 0.7 + t), c.hue_steps), 0.45, 1.0);
		cc = mix(cc, screen_blend(cc, rb * 0.5), art * (0.5 + 0.5 * foil_m) * smoothstep(0.3, 1.0, lum) * 0.6 * k);
		float sweep = fract(t * (loop_period > 0.0 ? 1.0 : 7.0) + seed) * 3.0 - 1.0;
		float bar = smoothstep_down(0.09, 0.0, abs(uv.x + uv.y * 0.45 - sweep - view * 0.3));
		cc += vec3(1.0, 0.95, 0.75) * (bar * 0.55 * k);
		col = cc;
		return gold_hi;
	}
	if (fin == 3) {
		// GALAXY: nebula and parallax stars living in the card's dark areas
		vec2 q = vec2(uv.x * 3.0 + tl.x * 0.6, uv.y * 3.0 + tl.y * 0.6);
		float drift = sin(t * TAU) * 0.15;
		float neb = fbm(vec2(q.x + drift, q.y));
		vec3 nebc = mix(vec3(0.15, 0.02, 0.35), vec3(0.1, 0.5, 0.95), neb);
		nebc = mix(nebc, vec3(1.0, 0.3, 0.7), smoothstep(0.55, 0.85, fbm(vec2(q.x * 1.7 + 5.0, q.y * 1.7 + 5.0))));
		float stars = 0.0;
		for (int l = 0; l < 3; l++) {
			float fl = float(l);
			float s = 90.0 + fl * 70.0;
			vec2 sp = vec2((uv.x + tl.x * (0.03 + fl * 0.03)) * s, (uv.y + tl.y * (0.03 + fl * 0.03)) * s);
			float h = hash(vec2(floor(sp.x) + fl * 7.0, floor(sp.y) + fl * 7.0));
			float tw = 0.5 + 0.5 * sin(c.t * rate(2.0 + h * 5.0) + h * 30.0);
			vec2 f = fract(sp) - 0.5;
			float dd = sqrt(f.x * f.x + f.y * f.y);
			stars += (h >= 0.988 ? 1.0 : 0.0) * tw * smoothstep_down(0.5, 0.0, dd);
		}
		float dark = 1.0 - smoothstep(0.08, 0.55, lum);
		vec3 cc = mix(col, nebc + vec3(stars), dark * 0.85 * k);
		cc += vec3(stars * 0.6 * k);
		vec3 rb = hsv(steps(fract(uv.x + view), c.hue_steps), 0.5, 1.0);
		cc = mix(cc, screen_blend(cc, rb * 0.35), frame * 0.6 * k);
		col = cc;
		return nebc;
	}
	if (fin == 4) {
		// GLITCH: edge glow, RGB split, scanlines, the occasional slice offset (the taps, see glitch_uv)
		vec3 cc = vec3(tp.r.r, tp.g.g, tp.b.b);
		cc = mix(col, cc, art);
		float edge = smoothstep(0.12, 0.45, abs(tap_l(tp.xp) - tap_l(tp.xm)) + abs(tap_l(tp.yp) - tap_l(tp.ym)));
		vec3 glitch = hsv(steps(fract(uv.y * 0.5 + t + view * 0.4), c.hue_steps), 0.85, 1.0);
		float pulse = 0.75 + 0.25 * sin(c.t * rate(3.0));
		cc = screen_blend(cc, glitch * (edge * 0.65 * pulse * art * k));
		cc = mix(cc, vec3(cc.r * 1.05, cc.g * 0.9, cc.b * 1.15), frame * 0.5);
		cc *= 0.94 + 0.06 * sin(uv.y * 700.0 + c.t * rate(10.0));
		col = cc;
		return glitch;
	}
	if (fin == 6) {
		// ARCANE: two sets of fine diagonal lines, each its own rainbow, sliding opposite ways with the
		// tilt, strongest under a broad band of light
		vec2 p = vec2(uv.x * c.face.x / c.face.y, uv.y);
		float s1 = 0.5 + 0.5 * sin((p.x + p.y) * 210.0 + view * 5.0);
		float s2 = 0.5 + 0.5 * sin((p.x - p.y) * 210.0 - view * 5.0);
		float l1, l2;
		if (pixel) {
			l1 = s1 > 0.75 ? 1.0 : 0.0;
			l2 = s2 > 0.75 ? 1.0 : 0.0;
		} else {
			l1 = pow(s1, 10.0);
			l2 = pow(s2, 10.0);
		}
		vec3 c1 = hsv(steps(fract((p.x - p.y) * 0.9 + view * 1.2 + t * hue_cycles), c.hue_steps), 0.7, 1.0);
		vec3 c2 = hsv(steps(fract((p.x + p.y) * 0.9 - view * 1.2 + 0.33), c.hue_steps), 0.7, 1.0);
		float b = fract((p.x * 0.6 - p.y * 0.8) * 0.8 + view * 0.8) - 0.5;
		float band = 0.35 + 0.65 * exp(-b * b * 14.0);
		float m = (art * (0.45 + 0.55 * foil_m) + (1.0 - art) * (0.45 + 0.55 * smoothstep(0.3, 0.7, foil_m))) * k * band * (1.0 - 0.3 * pop);
		vec3 lines = c1 * l1 + c2 * l2;
		vec3 cc = screen_blend(col, lines * (0.55 * m));
		cc = mix(cc, screen_blend(cc, (c1 + c2) * 0.12), m * 0.6);
		float glit = sparkles(uv, view, c);
		col = screen_blend(cc, vec3(glit * 0.6 * (art * foil_m + (1.0 - art) * smoothstep(0.3, 0.7, foil_m)) * k * sparkle));
		return mix(c1, c2, 0.5);
	}
	if (fin == 7) {
		// INVERSE: the frame and panels, and a lighter touch on the art: a rainbow sheen with a pebbled grain, lighter on the
		// unfoiled panels so the text still reads
		float m = (art * 0.35 + (1.0 - art) * (0.45 + 0.55 * smoothstep(0.3, 0.7, foil_m))) * k;
		vec3 rb = hsv(steps(fract((uv.x + uv.y) * 0.9 + view * 1.1 + t * hue_cycles), c.hue_steps), 0.55, 1.0);
		float sw = fract((uv.x * 0.7 + uv.y) * 0.75 - view * 1.1) - 0.5;
		float sweep = exp(-sw * sw * 22.0);
		if (pixel) { sweep = rnd(sweep * 3.0) / 3.0; }
		vec3 tinted = col * mix(vec3(1.0), rb * 1.2, 0.5);
		vec3 cc = mix(col, screen_blend(tinted, rb * (0.25 + 0.45 * sweep)), clamp(m * 0.85, 0.0, 1.0));
		float g = grain(uv, view, c, 3.0);
		cc = screen_blend(cc, vec3(g * (0.2 + 0.4 * sweep) * m));
		float glit = sparkles(uv, view, c);
		col = screen_blend(cc, vec3(glit * m * sparkle));
		return rb;
	}
	if (fin == 8) {
		// ENGRAVED: satin silver on the frame, cut with fine engraved lines that light up under a broad
		// pale sheen; on the art, finer lines and the highlights catch it
		vec3 pastel = hsv(steps(fract(uv.y * 0.8 + view * 0.6 + t * hue_cycles), c.hue_steps), 0.22, 1.0);
		float s = fract(uv.x * 0.5 + uv.y * 0.9 - view * 0.9) - 0.5;
		float sheen = exp(-s * s * 10.0);
		float wave = sin(uv.y * 22.0) * 0.06;
		float hatch = smoothstep(0.55, 1.0, sin((uv.x + wave) * c.face.x * 0.7 + uv.y * 40.0));
		if (pixel) { hatch = hatch > 0.5 ? 1.0 : 0.0; }
		vec3 silver = vec3(0.8, 0.82, 0.86) * (0.35 + 0.75 * lum);
		vec3 cc = mix(col, silver, frame * k * 0.5);
		cc += pastel * ((0.08 + 0.22 * sheen + hatch * (0.05 + 0.25 * sheen)) * frame * k);
		cc += pastel * ((0.04 + 0.14 * sheen + hatch * (0.04 + 0.18 * sheen)) * art * k);
		cc = mix(cc, screen_blend(cc, pastel * (0.25 + 0.35 * sheen)), art * foil_m * smoothstep(0.45, 1.0, lum) * k);
		col = cc;
		return mix(vec3(0.86, 0.88, 0.92), pastel, 0.5);
	}
	if (fin == 9) {
		// SPECTRUM: the whole card recoloured in a soft rainbow at the art's own brightness, a sheen over
		// it, and a dense glittering grain
		vec3 rb = hsv(steps(fract((uv.x * 0.6 + uv.y * 0.9) * 0.9 + view * 0.35 + t * hue_cycles), c.hue_steps), 0.45, 1.0);
		float m = (art * (0.55 + 0.45 * foil_m) + frame) * k * (1.0 - 0.25 * pop);
		vec3 cc = mix(col, rb * (0.3 + lum * 0.9), clamp(m * 0.55, 0.0, 1.0));
		float sw = fract((uv.x * 0.7 + uv.y) * 0.75 - 0.15 - view * 1.1) - 0.5;
		float sweep = exp(-sw * sw * 20.0);
		cc = screen_blend(cc, rb * ((0.1 + 0.3 * sweep) * m));
		float g = grain(uv, view, c, 2.5);
		cc = screen_blend(cc, vec3(g * 0.55 * m));
		float glit = sparkles(uv, view, c);
		col = screen_blend(cc, vec3(glit * m * sparkle));
		return rb;
	}
	// HOLO (0, and anything unknown): rainbow bands that slide with the viewing angle and the surface's
	// own slopes
	float hue = steps(fract((uv.x * 0.8 + uv.y * 1.2) * 1.3 + view * 0.9 + (n.x - n.y) * 0.2 + t * hue_cycles), c.hue_steps);
	vec3 rb = hsv(hue, 0.65, 1.0);
	float bands = 0.8 + 0.2 * sin((uv.x - uv.y) * 24.0 + view * 6.0);
	if (pixel) { bands = bands > 0.8 ? 1.0 : 0.7; }
	// a bright spectral sweep travels across the card with the tilt, over a quieter base sheen
	float sweep_pos = (uv.x * 0.7 + uv.y) * 0.75 - 0.15 - view * 1.1;
	float sw = fract(sweep_pos) - 0.5;
	float sweep = exp(-sw * sw * 28.0);
	if (pixel) { sweep = rnd(sweep * 3.0) / 3.0; }
	float m = clamp(foil_m * bands * k * (0.28 + 0.72 * sweep) * (1.0 - 0.35 * pop), 0.0, 1.0);
	vec3 tinted = col * mix(vec3(1.0), rb * 1.25, 0.6);
	vec3 cc = mix(col, screen_blend(tinted, rb * (0.35 + 0.4 * sweep)), m);
	float glit = sparkles(uv, view, c);
	col = screen_blend(cc, vec3(glit * foil_m * sparkle));
	return rb;
}

// a side of the card where the ray meets it: `tex` is its art at g.uv_e, `art_a` the art's alpha at
// g.uv. Premultiplied colour and coverage
vec4 shade_face(Geo g, vec4 tex, float art_a, Card c, Taps tp) {
	vec2 uv = g.uv, uv_e = g.uv_e;
	float asp = c.aspect;
	float ds = depth_scale;
	bool pixel = c.pixel;
	// the finish on this side: the back takes it only with back_finish, else it's standard
	int fin = (g.back && !back_finish) ? 5 : finish;
	// the frame, flat on the card over the art (sampled where the ray meets the card, so it never
	// shifts with the parallax); the front only
	vec4 fc = vec4(0.0);
	float ffoil = 0.0;
	if (has_frame && !g.back) {
		fc = frame_at(uv);
		ffoil = frame_foil_at(uv);
	}
	float coverage = max(art_a, fc.a);
	if (coverage <= 0.0) { return vec4(0.0); }
	vec3 col = color_of(tex);
	vec4 fx = fx_at(uv_e, pixel, g.back);
	float foil_m = fx.r, depth = fx.g, pop = fx.a;
	vec3 nm = normal_at(uv_e, pixel, g.back);
	// tangent space (+Y up, +Z out) to card space (y down, out of the card = -z)
	vec3 n = nrm(vec3(nm.x * 2.0 - 1.0, -(nm.y * 2.0 - 1.0), -(nm.z * 2.0 - 1.0)));
	vec2 tl = vec2(facing_yaw(tilt.x), tilt.y);
	float view = tl.x * 1.6 - tl.y * 1.1;

	// a point light hovering over the card, moving against the tilt (it is also the glare)
	vec2 gp = vec2(0.5 - tl.x * 1.4, 0.5 + tl.y * 1.4);
	vec3 p3 = vec3((uv_e.x - 0.5) * asp, uv_e.y - 0.5, -g.h_d * ds);
	vec3 l = nrm(vec3((gp.x - 0.5) * asp, gp.y - 0.5, -0.45) - p3);
	vec3 v = nrm(-g.d);

	// relief, on the subject only: brighter where it faces the light, darker where it turns away,
	// than the flat card would be (1.1 x relief / 0.9 at the default relief, clamped 0.75..1.3)
	float her = smoothstep(0.02, 0.15, depth);
	col *= clamp(1.0 + (max(dot(n, l), 0.0) - max(-l.z, 0.0)) * 1.1 * her * relief / 0.9, 0.75, 1.3);

	// pop-out shadow: the subject's matte, offset away from the light and softened, on what's behind it
	if (pop < 0.99 && shadow > 0.0) {
		vec3 away = nrm(vec3((uv_e.x - gp.x) * asp, uv_e.y - gp.y, 0.0));
		vec2 off = vec2(away.x / asp * 0.014, away.y * 0.014);
		float sh = 0.0;
		for (int i = 0; i < 8; i++) {
			float fi = float(i) + 0.5;
			float r = sqrt(fi / 8.0) * 0.03;
			vec2 o = vec2(cos(fi * 2.39996) * r / asp, sin(fi * 2.39996) * r);
			sh += fx_at(uv_e - off + o, false, g.back).a;
		}
		// segmentation of painted art is approximate: there the shadow is only a hint, while a crisp
		// pixel-art matte casts it at full strength
		float k_sh = pixel ? 1.0 : 0.4;
		col *= 1.0 - sh / 8.0 * shadow * k_sh * (1.0 - pop);
	}
	// rim light on the subject's edges facing the light
	if (pop > 0.01) {
		vec3 toward = nrm(vec3((gp.x - uv_e.x) * asp, gp.y - uv_e.y, 0.0));
		float px = 4.0 / c.face.y;
		float behind = fx_at(vec2(uv_e.x + toward.x * px / asp, uv_e.y + toward.y * px), pixel, g.back).a;
		col = screen_blend(col, vec3(clamp(pop - behind, 0.0, 1.0) * 0.2));
	}

	// the finish (holo foil, cracked ice, gold, galaxy, glitch, arcane, inverse, engraved, spectrum)
	vec3 glint_tint = apply_finish(col, uv_e, foil_m, fx.b, pop, n, view, tl, c, tp, fin);
	if (fc.a > 0.0) {
		// the frame takes the finish on its metal (window 0: it is frame, not art)
		vec3 flat_n = vec3(0.0, 0.0, -1.0);
		vec3 fcol = color_of(fc);
		vec3 ftint = apply_finish(fcol, uv_e, ffoil, 0.0, 0.0, flat_n, view, tl, c, tp, fin);
		col = mix(col, fcol, fc.a);
		n = nrm(mix(n, flat_n, fc.a));
		foil_m = mix(foil_m, ffoil, fc.a);
		glint_tint = mix(glint_tint, ftint, fc.a);
	}

	// specular glint off the normal map: a sharp metallic lobe on the foil, a soft one everywhere
	vec3 hv = nrm(l + v);
	float nh = max(dot(n, hv), 0.0);
	// a standard (non-foil) card is glossy, not metallic
	float metal = 0.25 + 0.75 * (fin == 5 ? 0.0 : foil_m);
	float spec = (pow(nh, 90.0) * 1.3 + pow(nh, 14.0) * 0.12) * metal * glint * (0.35 + (abs(tl.x) + abs(tl.y)) * 1.6);
	if (pixel) { spec = rnd(spec * 3.0) / 3.0; }
	col = screen_blend(col, mix(vec3(1.0), glint_tint, 0.25 * foil_m) * min(spec, 1.0));

	// glare and edge shading
	vec2 du = uv - gp;
	float gl = exp(-dot(du, du) * 5.0) * (0.10 + length(tl) * 0.5) * glare;
	if (pixel) { gl = floor(gl * 6.0) / 6.0; }
	col = screen_blend(col, vec3(gl));
	col *= 1.0 - (g.cn.x * (uv.x - 0.5) + g.cn.y * (uv.y - 0.5)) * 0.25;

	// debug views: the raw maps on the card
	if (debug_view == 1) { col = vec3(foil_m); }
	if (debug_view == 2) { col = vec3(depth); }
	if (debug_view == 3) { col = vec3(pop); }
	if (debug_view == 4) { col = nm; }

	return vec4(col * coverage, coverage);
}

void fragment() {
	vec2 art_size = vec2(textureSize(TEXTURE, 0));
	vec2 back_size = vec2(textureSize(back_tex, 0));
	float asp = aspect > 0.0 ? aspect : art_size.x / art_size.y;
	vec2 face = vec2(700.0 * asp, 700.0);
	float t = clock >= 0.0 ? clock : TIME;

	// --- ray-plane perspective so the flat card appears to rotate in 3D ---
	vec2 p = (UV - 0.5) / card_scale;   // card heights from the card's centre, y down
	p.x *= asp;
	mat3 R = pose(tilt);
	// the side facing the camera (the same across the card): the back when the camera is behind it
	bool back = (transpose(R) * vec3(0.0, 0.0, -CAMERA_D)).z > 0.0;
	vec2 native = back
		? (back_native_size.x > 0.0 && back_native_size.y > 0.0 ? back_native_size : back_size)
		: (native_size.x > 0.0 && native_size.y > 0.0 ? native_size : art_size);
	Card c = Card(asp, face, t, back ? back_pixel_art : pixel_art, native, face / native, back ? back_hue_steps : hue_steps,
		1.0 / (back ? back_size : art_size));

	// the card, supersampled on a rotated grid over the pixel footprint, like the CPU preview (whose
	// offsets are in screen pixels; mirrored where the API's window y points up, still a rotated grid)
	vec2 dpx = dFdx(p), dpy = dFdy(p);
	vec2 rgss[4] = vec2[4](vec2(0.125, 0.375), vec2(-0.375, 0.125), vec2(0.375, -0.125), vec2(-0.125, -0.375));
	int taps = supersample ? 4 : 1;
	vec4 acc = vec4(0.0);
	for (int i = 0; i < taps; i++) {
		vec2 ps = supersample ? p + dpx * rgss[i].x + dpy * rgss[i].y : p;
		Geo g = cast_ray(R, ps, c);
		if (!g.hit) { continue; }
		float art_a = (g.back ? back_at(g.uv, c.pixel) : ART_AT(g.uv, c.pixel)).a;
		float frame_a = has_frame && !g.back ? frame_at(g.uv).a : 0.0;
		if (max(art_a, frame_a) <= 0.0) { continue; }
		vec4 tex = g.back ? back_at(g.uv_e, c.pixel) : ART_AT(g.uv_e, c.pixel);
		Taps tp = Taps(vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0), vec3(0.0));
		if (finish == 4) {
			tp.r = color_of(SIDE_AT(glitch_uv(g.uv_e, c, 0), c.pixel, g.back));
			tp.g = color_of(SIDE_AT(glitch_uv(g.uv_e, c, 1), c.pixel, g.back));
			tp.b = color_of(SIDE_AT(glitch_uv(g.uv_e, c, 2), c.pixel, g.back));
			tp.xp = color_of(SIDE_AT(glitch_uv(g.uv_e, c, 3), c.pixel, g.back));
			tp.xm = color_of(SIDE_AT(glitch_uv(g.uv_e, c, 4), c.pixel, g.back));
			tp.yp = color_of(SIDE_AT(glitch_uv(g.uv_e, c, 5), c.pixel, g.back));
			tp.ym = color_of(SIDE_AT(glitch_uv(g.uv_e, c, 6), c.pixel, g.back));
		}
		acc += shade_face(g, tex, art_a, c, tp);
	}
	acc /= float(taps);

	COLOR = clamp(acc, 0.0, 1.0) * vec4(v_modulate.rgb * v_modulate.a, v_modulate.a);
}
