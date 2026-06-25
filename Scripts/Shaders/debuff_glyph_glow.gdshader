// ============================================================
// MASTER PROCEDURAL GLYPH SHADER
// - Godot 4.x GDShader
// - shader_type: canvas_item
// - Target: ColorRect / TextureRect
// - Style: B1 (subtle wobble), C2 (natural proportions),
//          D1 (auto-center), F2 (medium icons),
//          G3 (balanced glow), H1 (preserve aspect ratio)
// ============================================================

shader_type canvas_item;

// ------------------------------------------------------------
// SECTION 1 — UNIFORMS
// ------------------------------------------------------------

uniform int glyph_id : hint_range(0, 15) = 0;

// Glow / look
uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0) = 1.4;
uniform float rim_thickness : hint_range(0.0, 0.2) = 0.03;
uniform float line_thickness : hint_range(0.0, 0.4) = 0.10;
uniform float bloom_softness : hint_range(0.0, 0.5) = 0.18;

// Stylization (B1 subtle)
uniform float wobble_strength : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_strength : hint_range(0.0, 1.0) = 0.35;

// Overall scale (for F2 ~96–128px icons)
uniform float glyph_scale : hint_range(0.2, 2.0) = 1.0;


// ------------------------------------------------------------
// SECTION 2 — UTILITY FUNCTIONS
// ------------------------------------------------------------

// Center UV in [-1, 1], preserve aspect ratio (H1)
vec2 get_centered_uv(vec2 in_uv, vec2 in_texture_pixel_size) {
    vec2 uv = in_uv * 2.0 - 1.0;
    // Correct aspect so shapes don't stretch
    float aspect = in_texture_pixel_size.y / in_texture_pixel_size.x;
    uv.x *= aspect;
    // Apply global scale
    uv /= glyph_scale;
    return uv;
}

mat2 rot(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(vec2(c, s), vec2(-s, c));
}


// ------------------------------------------------------------
// SECTION 3 — SDF PRIMITIVES
// ------------------------------------------------------------

float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float sdLine(vec2 p, vec2 a, vec2 b, float w) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - w;
}

// Simple isosceles triangle pointing up, centered
float sdTriangle(vec2 p, float h) {
    // Equilateral-ish triangle
    vec2 k = vec2(0.8660254, 0.5); // sqrt(3)/2, 1/2
    p.y -= h * 0.25;
    p.x = abs(p.x);
    float d = max(dot(p, vec2(k.x, -k.y)), -p.y) - h * 0.5;
    return d;
}

// Chevron (V shape), pointing down if flip_y > 0
float sdChevron(vec2 p, float w, float h, float thickness, float flip_y) {
    p.y *= flip_y;
    // Two lines forming a V
    float d1 = sdLine(p, vec2(-w, h), vec2(0.0, 0.0), thickness);
    float d2 = sdLine(p, vec2(w, h), vec2(0.0, 0.0), thickness);
    return min(d1, d2);
}

// Simple arc: ring segment between angles
float sdArc(vec2 p, float r, float t, float a0, float a1) {
    float ang = atan(p.y, p.x);
    float len = length(p);
    float da = 0.0;
    // Wrap angle into [a0, a1]
    if (ang < a0) {
        da = a0 - ang;
    } else if (ang > a1) {
        da = ang - a1;
    }
    float dr = abs(len - r) - t;
    return max(dr, r * da);
}


// ------------------------------------------------------------
// SECTION 4 — STYLIZATION LAYER (B1 SUBTLE)
// ------------------------------------------------------------

// Subtle wobble on position
vec2 apply_wobble(vec2 p, float time) {
    if (wobble_strength <= 0.0) {
        return p;
    }
    float w = wobble_strength * 0.02;
    p += w * vec2(
        sin(p.y * 40.0 + time * 0.7),
        cos(p.x * 37.0 - time * 0.5)
    );
    return p;
}

// Subtle roughness on distance
float apply_roughness(float d, vec2 p) {
    if (roughness_strength <= 0.0) {
        return d;
    }
    float r = roughness_strength * 0.01;
    d += r * sin(p.x * 60.0) * sin(p.y * 45.0);
    return d;
}


// ------------------------------------------------------------
// SECTION 5 — GLYPH SDFS (16 TOTAL)
// Each glyph uses natural proportions (C2) and assumes p in [-1,1]
// ------------------------------------------------------------

// 1. Coupon Block — Circle with bold X
float sdGlyphCouponBlock(vec2 p) {
    float d_circle = abs(sdCircle(p, 0.7)) - rim_thickness;

    float t = line_thickness;
    float d1 = sdLine(p, vec2(-0.5, -0.5), vec2(0.5, 0.5), t);
    float d2 = sdLine(p, vec2(-0.5, 0.5), vec2(0.5, -0.5), t);
    float d_x = min(d1, d2);

    float d = min(d_circle, d_x);
    return d;
}

float sdGlyphPaidRerolls(vec2 p) {
    // Outer coin ring
    float d_outer = abs(sdCircle(p, 0.7)) - (rim_thickness * 1.4);
    // Inner coin edge
    float d_inner = abs(sdCircle(p, 0.45)) - (rim_thickness * 1.2);
    float d_coin = min(d_outer, d_inner);

    // 45° slash
    vec2 a = vec2(-0.7, 0.7);
    vec2 b = vec2(0.7, -0.7);
    float d_slash = sdLine(p, a, b, line_thickness * 0.9);

    return min(d_coin, d_slash);
}


// 3. Color Drain — Hollow square with diagonal slash
float sdGlyphColorDrain(vec2 p) {
    float d_square = abs(sdBox(p, vec2(0.6))) - (line_thickness * 0.7);
    float d_slash = sdLine(p, vec2(-0.6, -0.6), vec2(0.6, 0.6), line_thickness * 0.8);
    return min(d_square, d_slash);
}

// 4. Mod Lockout — Gear with a cross through it
float sdGlyphModLockout(vec2 p) {
    // Base circle
    float d_base = abs(sdCircle(p, 0.45)) - (line_thickness * 0.7);

    // Teeth: approximate with 6 boxes around
    float d_teeth = 1e5;
    for (int i = 0; i < 6; i++) {
        float a = float(i) * (3.141592 * 2.0 / 6.0);
        vec2 q = p * rot(a);
        q.y -= 0.55;
        float dt = sdBox(q, vec2(0.08, 0.12));
        d_teeth = min(d_teeth, dt);
    }

    float d_gear = min(d_base, d_teeth);

    // Cross
    float t = line_thickness * 0.7;
    float d1 = sdLine(p, vec2(-0.6, 0.0), vec2(0.6, 0.0), t);
    float d2 = sdLine(p, vec2(0.0, -0.6), vec2(0.0, 0.6), t);
    float d_cross = min(d1, d2);

    return min(d_gear, d_cross);
}

// ------------------------------------------------------------
// #5 — NO TWOS ALLOWED
// Broken circle + geometric "2"
// ------------------------------------------------------------

// Basic line segment SDF
float sdLineSegment(vec2 p, vec2 a, vec2 b, float w) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - w;
}

// Top arc helper for the "2"
float sdArcTop(vec2 p, vec2 center, float radius, float stroke) {
    vec2 q = p - center;
    float d = abs(length(q) - radius) - stroke;
    // Keep only upper portion (clip below a small y threshold)
    d = max(d, p.y - 0.02);
    return d;
}

float sdBrokenCircle(vec2 p) {
    float radius = 0.82;
    float d = abs(sdCircle(p, radius)) - rim_thickness;

    float ang = atan(p.y, p.x);

    // --- Three thin gaps like the original ---
    // Top-left gap (~135°)
    if (ang > 2.30 && ang < 2.45) d = 1e5;

    // Top-right gap (~45°)
    if (ang > 0.70 && ang < 0.90) d = 1e5;

    // Bottom-right gap (~-45°)
    if (ang > -0.90 && ang < -0.70) d = 1e5;

    return d;
}


// Geometric digit "2": top arc + diagonal + bottom base
float sdDigit2(vec2 p) {
    // Slight horizontal scale for readability
    p *= vec2(1.10, 1.0);

    float t = 0.06; // stroke thickness

    // Top horizontal bar
    float d_top = sdLineSegment(
        p,
        vec2(-0.40,  0.40),
        vec2( 0.30,  0.40),
        t
    );

    // Vertical drop on the right
    float d_vert = sdLineSegment(
        p,
        vec2( 0.30,  0.40),
        vec2( 0.30,  0.05),
        t
    );

    // Diagonal stroke
    float d_diag = sdLineSegment(
        p,
        vec2( 0.30,  0.05),
        vec2(-0.30, -0.25),
        t
    );

    // Bottom horizontal base
    float d_base = sdLineSegment(
        p,
        vec2(-0.40, -0.46),
        vec2( 0.40, -0.46),
        t
    );

    float d = min(d_top, min(d_vert, min(d_diag, d_base)));
    return d;
}

// Candy cane shape (open to the left)
// Half‑circle outline (top half only)
float sdHalfCircle(vec2 p) {
    float radius = 0.50;
    float stroke = 0.08;

    // Base circle outline
    float d = abs(length(p) - radius) - stroke;

    // Angle in [-PI, PI]
    float a = atan(p.y, p.x);

    // Keep only the BOTTOM half: angles between -180° and 0°
    if (a > 0.0) {
        d = 1e5; // erase top half
    }

    return d;
}
// Vertical line inverted (goes UP instead of down)
float sdDownLine(vec2 p) {
    float stroke = 0.08;

    // Start at right side of bottom arc
    vec2 a = vec2(0.50,  0.0);
    vec2 b = vec2(0.50,  1.50); // inverted direction

    return sdLineSegment(p, a, b, stroke);
}

vec2 rotate(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(
        c*p.x - s*p.y,
        s*p.x + c*p.y
    );
}

// Candy cane built from bottom half-circle + vertical line
float sdCandyCane(vec2 p) {
    float d_arc  = sdHalfCircle(p); // your inverted bottom arc
    float d_line = sdDownLine(p);   // your upward vertical line
    return min(d_arc, d_line);
}


float sdCandyCaneRotated(vec2 p) {
    // Rotate input by +30° (inverse of clockwise 30°)
    p = rotate(p, radians(-40.0));

    return sdCandyCane(p); // your existing candy cane SDF
}

float sdBottomLine(vec2 p) {
    float stroke = 0.08;

    // Start at bottom-left of the vertical line
    vec2 a = vec2(0.50, 1.50);
    vec2 b = vec2(-0.60, 1.50); // extend left to match circle height

    return sdLineSegment(p, a, b, stroke);
}

float sdGlyphNoTwos(vec2 p) {
    // Shift the whole glyph UP by ~30%
    p.y += 0.0;

    // --- SCALE THE OUTER BROKEN CIRCLE UP ---
    float outer_scale = 1.1;
    float d_outer = sdBrokenCircle(p / outer_scale) * outer_scale;

    // --- SCALE THE INNER "2" DOWN ---
    float inner_scale = 0.50;
    vec2 pin = p / inner_scale;

    // Shift ONLY the "2" upward
    pin.y += 0.5;   // tweak this value to position the 2 inside the circle

    float d_circle = sdHalfCircle(pin);
    float d_cane   = sdCandyCaneRotated(pin);
    float d_base   = sdBottomLine(pin);

    float d_inner = min(d_base, min(d_circle, d_cane));
    d_inner *= inner_scale;

    return min(d_outer, d_inner);
}






// 6. Chore Surge — Three upward arrows
float sdGlyphChoreSurge(vec2 p) {
    float d = 1e5;
    float t = line_thickness * 0.7;

    // Helper: arrow at offset with given height
    for (int i = 0; i < 3; i++) {
        float x = float(i - 1) * 0.45; // -0.45, 0, 0.45
        float h = (i == 1) ? 1.0 : 0.8;

        vec2 head_p = p - vec2(x, 0.05);
        float d_head = sdTriangle(head_p, h);

        vec2 stem_a = vec2(x, -0.7);
        vec2 stem_b = vec2(x, -0.05);
        float d_stem = sdLine(p, stem_a, stem_b, t);

        d = min(d, min(d_head, d_stem));
    }

    return d;
}


// 7. Half Value — Half-filled circle
float sdGlyphHalfValue(vec2 p) {
    float d_circle = abs(sdCircle(p, 0.7)) - rim_thickness;

    // Side fill: left half
    vec2 q = p + vec2(0.05, 0.0);
    float d_fill = sdCircle(q, 0.65);
    // Only left side: x < 0
    d_fill = max(d_fill, p.x);

    return min(d_circle, d_fill);
}

// 8. Sold Out — Empty box
float sdGlyphSoldOut(vec2 p) {
    // Outer box
    float d_outer = abs(sdBox(p, vec2(0.7))) - (line_thickness * 0.7);
    // Inner inset to avoid “soft” corners
    float d_inner = abs(sdBox(p, vec2(0.6))) - (line_thickness * 0.7);
    return min(d_outer, d_inner);
}


// 9. No Locks — Open padlock
float sdGlyphNoLocks(vec2 p) {
    // Body
    vec2 body_p = p + vec2(0.0, 0.25);
    float d_body = abs(sdBox(body_p, vec2(0.45, 0.35))) - (line_thickness * 0.7);

    // Shackle
    vec2 sh = p + vec2(0.0, -0.1);
    float d_outer = sdCircle(sh, 0.55);
    float d_inner = sdCircle(sh, 0.35);
    float d_shackle = max(d_outer, -d_inner);

    // Open gap on right side only in a small window
    if (sh.x > 0.15 && sh.y > -0.25 && sh.y < 0.15) {
        d_shackle = 1e5;
    }

    return min(d_body, d_shackle);
}


// 10. D4 Swap — Triangle (hobo symbol)
float sdGlyphD4Swap(vec2 p) {
    // Outline triangle instead of solid
    float d_tri = sdTriangle(p, 1.1);
    return abs(d_tri) - (line_thickness * 0.7);
}


// 11. Power Cut — Lightning bolt with a slash
float sdGlyphPowerCut(vec2 p) {
    float t = line_thickness * 0.7;

    // Zigzag lightning: three segments
    float d1 = sdLine(p, vec2(-0.35, 0.6), vec2(-0.05, 0.1), t);
    float d2 = sdLine(p, vec2(-0.05, 0.1), vec2(0.15, -0.2), t);
    float d3 = sdLine(p, vec2(0.15, -0.2), vec2(0.4, -0.6), t);
    float d_bolt = min(d1, min(d2, d3));

    // Slash across
    float d_slash = sdLine(p, vec2(0.6, -0.6), vec2(-0.5, 0.6), t * 0.9);

    return min(d_bolt, d_slash);
}


// 12. One Roll Only — Single vertical bar
float sdGlyphOneRollOnly(vec2 p) {
    return sdBox(p, vec2(line_thickness * 0.7, 0.7));
}

// 13. Level Loss — Downward chevron
float sdGlyphLevelLoss(vec2 p) {
    return sdChevron(p, 0.6, 0.4, line_thickness * 0.7, -1.0);
}

// 14. Roll Tax — Stack of lines with downward arrow
float sdGlyphRollTax(vec2 p) {
    float t = line_thickness * 0.6;
    float d = 1e5;

    // Three horizontal lines
    for (int i = 0; i < 3; i++) {
        float y = 0.55 - float(i) * 0.3;
        float dl = sdLine(p, vec2(-0.6, y), vec2(0.6, y), t);
        d = min(d, dl);
    }

    // Down arrow clearly below stack
    vec2 pa = p + vec2(0.0, -0.55);
    float d_arrow = sdChevron(pa, 0.35, 0.3, t, -1.0);
    d = min(d, d_arrow);

    return d;
}


// 15. Divide All — Broken circle
float sdGlyphDivideAll(vec2 p) {
    float d_ring = abs(sdCircle(p, 0.7)) - rim_thickness;

    // Break left/right arcs
    float ang = atan(p.y, p.x);
    if (abs(ang) < 0.35 || abs(abs(ang) - 3.141592) < 0.35) {
        d_ring = 1e5;
    }

    // Clip edge elements: short radial stubs at gap edges
    float t = line_thickness * 0.7;
    float d_clip = 1e5;

    // Right gap stubs
    d_clip = min(d_clip, sdLine(p, vec2(0.2, 0.55), vec2(0.6, 0.75), t));
    d_clip = min(d_clip, sdLine(p, vec2(0.2, -0.55), vec2(0.6, -0.75), t));

    // Left gap stubs
    d_clip = min(d_clip, sdLine(p, vec2(-0.2, 0.55), vec2(-0.6, 0.75), t));
    d_clip = min(d_clip, sdLine(p, vec2(-0.2, -0.55), vec2(-0.6, -0.75), t));

    return min(d_ring, d_clip);
}


// 16. Wealth Drain — Dollar sign with downward chevron
float sdDollarShape(vec2 p) {
    // Slightly taller
    p *= vec2(0.9, 1.1);

    // Vertical bar
    float d_bar = sdBox(p, vec2(line_thickness * 0.5, 0.7));

    // Two circular lobes
    float d_top = sdCircle(p + vec2(0.0, 0.28), 0.32);
    float d_bot = sdCircle(p + vec2(0.0, -0.28), 0.32);
    float d_lobes = min(d_top, d_bot);

    // Outline feel: ring around lobes
    float d = min(d_bar, d_lobes);
    return d;
}

float sdGlyphWealthDrain(vec2 p) {
    float d_dollar = sdDollarShape(p * vec2(0.8, 1.0));

    // Downward chevron below
    vec2 pc = p + vec2(0.0, -0.75);
    float d_chev = sdChevron(pc, 0.4, 0.3, line_thickness * 0.7, -1.0);

    return min(d_dollar, d_chev);
}



// ------------------------------------------------------------
// SECTION 6 — GLYPH SELECTOR
// ------------------------------------------------------------

float glyph_distance(vec2 p, float time) {
    // Apply subtle wobble to position
    p = apply_wobble(p, time);

    float d;

    if (glyph_id == 0) {
        d = sdGlyphCouponBlock(p);
    } else if (glyph_id == 1) {
        d = sdGlyphPaidRerolls(p);
    } else if (glyph_id == 2) {
        d = sdGlyphColorDrain(p);
    } else if (glyph_id == 3) {
        d = sdGlyphModLockout(p);
    } else if (glyph_id == 4) {
        d = sdGlyphNoTwos(p);
    } else if (glyph_id == 5) {
        d = sdGlyphChoreSurge(p);
    } else if (glyph_id == 6) {
        d = sdGlyphHalfValue(p);
    } else if (glyph_id == 7) {
        d = sdGlyphSoldOut(p);
    } else if (glyph_id == 8) {
        d = sdGlyphNoLocks(p);
    } else if (glyph_id == 9) {
        d = sdGlyphD4Swap(p);
    } else if (glyph_id == 10) {
        d = sdGlyphPowerCut(p);
    } else if (glyph_id == 11) {
        d = sdGlyphOneRollOnly(p);
    } else if (glyph_id == 12) {
        d = sdGlyphLevelLoss(p);
    } else if (glyph_id == 13) {
        d = sdGlyphRollTax(p);
    } else if (glyph_id == 14) {
        d = sdGlyphDivideAll(p);
    } else if (glyph_id == 15) {
        d = sdGlyphWealthDrain(p);
    } else {
        d = 1.0;
    }

    // Apply subtle roughness to distance
    d = apply_roughness(d, p);

    return d;
}


// ------------------------------------------------------------
// SECTION 7 — GLOW + BLOOM PIPELINE (G3 BALANCED)
// ------------------------------------------------------------

void fragment() {
    vec2 p = get_centered_uv(UV, TEXTURE_PIXEL_SIZE);

    float d = glyph_distance(p, TIME);

    // Core glyph mask
    float core = 1.0 - smoothstep(-0.02, 0.0, d);

    // Bloom region
    float bloom = 1.0 - smoothstep(0.0, bloom_softness, d);

    // Balanced glow: soft core + slightly punchy rim
    float intensity = core + bloom * glow_strength;

    vec3 col = glow_color.rgb * intensity;
    float alpha = clamp(core + bloom * 0.6, 0.0, 1.0);

    COLOR = vec4(col, alpha * glow_color.a);
}
