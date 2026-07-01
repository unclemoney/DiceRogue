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
// One single filled triangle, nothing else.
// Proper upright isosceles triangle, height = h, base centered on x=0
float sdArrowTriangle(vec2 p) {
    // Upright isosceles triangle with tip at y=+0.5 and base at y=-0.5
    vec2 a = vec2( 0.0,  0.5);   // top
    vec2 b = vec2(-0.5, -0.5);   // bottom-left
    vec2 c = vec2( 0.5, -0.5);   // bottom-right

    // Edges
    vec2 e0 = b - a;
    vec2 e1 = c - b;
    vec2 e2 = a - c;

    // Signed distances to each edge (positive outside)
    float d0 = (e0.y)*(p.x - a.x) - (e0.x)*(p.y - a.y);
    float d1 = (e1.y)*(p.x - b.x) - (e1.x)*(p.y - b.y);
    float d2 = (e2.y)*(p.x - c.x) - (e2.x)*(p.y - c.y);

    // Outside = max of edge distances
    float outside = max(max(d0, d1), d2);

    // This is a *mask-style* SDF: negative inside, positive outside
    return outside;
}
vec2 rotate180(vec2 p) { return -p; }

float sdArrowBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return max(d.x, d.y);
}
float sdArrowStem(vec2 p) {
    float w = 0.20;
    float h = w * 7.0;

    // Center of the stem rectangle
    // Top of stem touches triangle base at y = -0.5
    // So center is at y = -0.5 - h/2
    vec2 center = vec2(0.0, -0.5 - h * 0.45);

    return sdArrowBox(p - center, vec2(w, h * 0.5));
}

float sdSingleArrow(vec2 p) {
    vec2 q = rotate180(p);

    float d_tri  = sdArrowTriangle(q);
    float d_stem = sdArrowStem(q);

    return min(d_tri, d_stem);
}

float sdArrowInstance(vec2 p, vec2 offset, float scale) {
    vec2 q = (p - offset) / scale;
    return sdSingleArrow(q) * scale;
}


float sdGlyphChoreSurge(vec2 p) {
    float spacing = 0.85;   // horizontal spacing between arrows
    float lift    = -0.45;  // middle arrow Y offset
    float scale   = 0.7;   // global arrow scale

    float d = 1e5;

    // Left arrow
    d = min(d, sdArrowInstance(p, vec2(-spacing, 0.0), scale));

    // Middle arrow (lifted by 5%)
    d = min(d, sdArrowInstance(p, vec2(0.0, lift), scale));

    // Right arrow
    d = min(d, sdArrowInstance(p, vec2(spacing, 0.0), scale));

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

// Outline of a top half-circle
float sdHalfCircleOutline(vec2 p, float r, float thickness) {
    // Distance to circle ring
    float d_ring = abs(length(p) - r) - thickness;

    // Cut away the bottom half (keep only y > 0)
    if (p.y < 0.0) {
        d_ring = 1e5;
    }

    return d_ring;
}

vec2 rot180(vec2 p) {
    return -p;
}


float sdSquare(vec2 p, float s) {
    vec2 d = abs(p) - vec2(s);
    return max(d.x, d.y);
}

float sdShackleSquare(vec2 p, vec2 center, float halfW, float halfH) {
    vec2 d = abs(p - center) - vec2(halfW, halfH);
    return max(d.x, d.y);
}
float sdLeftSquare(vec2 p) {
    float halfW = 0.05;
    float h     = 0.20;
    float halfH = h * 0.5;

    float yLift = 0.03;   // bump upward

    vec2 center = vec2(-0.6, -halfH + yLift);
    return sdShackleSquare(p, center, halfW, halfH);
}

float sdRightSquare(vec2 p) {
    float halfW = 0.05;
    float h     = 0.20;
    float halfH = h * 0.5;

    float yLift = 0.03;   // bump upward

    vec2 center = vec2(0.6, -halfH + yLift);
    return sdShackleSquare(p, center, halfW, halfH);
}

float sdRoundedRect(vec2 p, vec2 halfSize, vec4 radii) {
    // radii = (topLeft, topRight, bottomRight, bottomLeft)
    vec2 q = p;

    // Determine which corner radius applies
    float rx = (q.x > 0.0) ? radii.y : radii.x;
    float ry = (q.y > 0.0) ? radii.z : radii.w;

    vec2 r = vec2(rx, ry);

    // Signed distance to rounded rectangle
    vec2 d = abs(q) - halfSize + r;
    return max(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - min(r.x, r.y);
}

float sdLockCircle(vec2 p, float r) {
    return length(p) - r;
}

float sdLockCutout(vec2 p) {
    float r = 0.20;      // tweakable radius
    float yOffset = -0.65;  // tweakable vertical position

    vec2 center = vec2(0.0, yOffset);
    return sdLockCircle(p - center, r);
}

float sdLockSquareCutout(vec2 p) {
    float r = 0.20;          // match your circle radius
    float w = r * 0.8;       // half-width (slightly less than circle radius)
    float h = r * 0.9;       // half-height (tweakable)

    float yOffset = -0.85;   // place it below the circle (tweakable)

    vec2 center = vec2(0.0, yOffset);

    vec2 d = abs(p - center) - vec2(w, h);
    return max(d.x, d.y);
}

float sdKeyhole(vec2 p) {
    float d_circle = sdLockCutout(p);
    float d_square = sdLockSquareCutout(p);
    return min(d_circle, d_square);
}


float sdLockBody(vec2 p) {
    vec2 halfSize = vec2(0.8, 0.5);   // width=1.6, height=1.0

    float rTop    = 0.15;
    float rBottom = 0.10;

    // radii order: TL, TR, BR, BL
    vec4 radii = vec4(rTop, rTop, rBottom, rBottom);

    // Position the body so its top touches y = -0.20 (adjust as needed)
    vec2 center = vec2(0.0, -0.8);

    return sdRoundedRect(p - center, halfSize, radii);
}


float sdGlyphNoLocks(vec2 p) {
    vec2 q = rot180(p);

    float d_arc    = sdHalfCircleOutline(q, 0.6, 0.05);
    float d_left   = sdLeftSquare(q);
    float d_right  = sdRightSquare(q);

    float d_body   = sdLockBody(q);
    float d_keyhole = sdKeyhole(q);
    float d_bodyWithHole = max(d_body, -d_keyhole);

    return min(min(d_arc, min(d_left, d_right)), d_bodyWithHole);
}








// 10. D4 Swap — Triangle (hobo symbol)
vec2 TriangleRotate(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(
        c*p.x - s*p.y,
        s*p.x + c*p.y
    );
}

float sdD4Triangle(vec2 p, float size, float angle) {
    // Rotate first
    p = TriangleRotate(p, angle);

    // Scale space
    p /= size;

    // Move triangle so base is at y = -0.5 and tip at y = +0.5
    p.y += 0.25;

    // Triangle vertices
    vec2 a = vec2(0.0,  0.5);
    vec2 b = vec2(-0.5, -0.5);
    vec2 c = vec2(0.5, -0.5);

    // Edges
    vec2 e0 = b - a;
    vec2 e1 = c - b;
    vec2 e2 = a - c;

    float d0 = (e0.y)*(p.x - a.x) - (e0.x)*(p.y - a.y);
    float d1 = (e1.y)*(p.x - b.x) - (e1.x)*(p.y - b.y);
    float d2 = (e2.y)*(p.x - c.x) - (e2.x)*(p.y - c.y);

    float outside = max(max(d0, d1), d2);

    return outside * size;
}


float sdD4TriangleOutline(vec2 p, float size, float angle, float triangleline_thickness) {
    float d = sdD4Triangle(p, size, angle);
    return abs(d) - triangleline_thickness;
}


float sdGlyphD4Swap(vec2 p) {
    float size          = 0.8;          // tweakable
    float angle         = 3.14159265;   // 180 degrees
    float lineThickness = 0.04;         // tweakable

    return sdD4TriangleOutline(p, size, angle, lineThickness);
}




// 11. Power Cut — Lightning bolt with a slash
float sdTaperedQuad(vec2 p, float wTop, float wBottom, float h) {
    // p is already in quad-local space
    // y = 0 is top, y = h is bottom

    float t = clamp(p.y / h, 0.0, 1.0);
    float halfW = mix(wTop * 0.5, wBottom * 0.5, t);

    vec2 d = abs(vec2(p.x, p.y - h * 0.5)) - vec2(halfW, h * 0.5);
    return max(d.x, d.y);
}

float sdSegment(vec2 p, vec2 a, vec2 b, float thickness) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - thickness;
}

vec2 Boltrotate(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c*p.x - s*p.y, s*p.x + c*p.y);
}

float sdBoltFoot(vec2 p) {
    // Original segment direction (for orientation only)
    vec2 C = vec2(-0.30,  0.25);
    vec2 D = vec2( 0.65, -0.60);

    vec2 CD = D - C;
    float h = length(CD);

    // Center of the quad BEFORE offset
    vec2 mid = (C + D) * 0.5;

    // Add your manual offset (this is what you wanted)
    vec2 offset = vec2(-0.5, 0.25);   // move right + up
    mid += offset;

    // Transform p into local CD space
    float angleCD = atan(CD.y, CD.x);
    vec2 q = Boltrotate(p - mid, -angleCD);

    // Now rotate the quad itself by 45 degrees
    float angle45 = radians(105.0);
    q = Boltrotate(q, angle45);

    // Taper: top narrower, bottom wider
    float wTop    = 0.20;
    float wBottom = 0.45;

    return sdTaperedQuad(q, wTop, wBottom, h);
}
float sdBoltHead(vec2 p) {
    // Segment 1 direction (orientation only)
    vec2 A = vec2(-0.30,  0.65);
    vec2 B = vec2( 0.25,  0.05);

    vec2 AB = B - A;
    float h = length(AB * 1.5);

    // Center BEFORE offset
    vec2 mid = (A + B) * 0.5;

    // Manual offset — tweak these freely
    vec2 offset = vec2(-0.28, 0.66);   // move right/up/down/left
    mid += offset;

    // Transform p into local AB space
    float angleAB = atan(AB.y, AB.x);
    vec2 q = Boltrotate(p - mid, -angleAB);

    // Rotate the quad itself (try 20–40 degrees)
    float angle = radians(95.0);
    q = Boltrotate(q, angle);

    // Taper: top narrower, bottom wider
    float wTop    = 0.0;
    float wBottom = 0.40;

    return sdTaperedQuad(q, wTop, wBottom, h);
}

float sdLightningBolt(vec2 p, float thickness) {
    float d_head = sdBoltHead(p);   // NEW quadrilateral for segment 1
    float d2     = sdSegment(p, vec2(0.48, 0.05), vec2(-0.26, 0.05), thickness * 3.2);
    float d3     = sdBoltFoot(p);   // tapered quad for segment 3

    return min(d_head, min(d2, d3));
}
struct SlashResult {
    float carve;
    float line;
};

SlashResult sdSlash(vec2 p, float thickness, float carve) {
    vec2 A = vec2(-0.7,  0.8);
    vec2 B = vec2( 0.7, -0.7);

    float angle = radians(-15.0);   // tweakable
    p = Boltrotate(p, angle);

    SlashResult r;
    r.carve = sdSegment(p, A, B, thickness + carve);
    r.line  = sdSegment(p, A, B, thickness);
    return r;
}



float sdGlyphPowerCut(vec2 p) {
    float t = line_thickness * 0.9;

    float d_bolt = sdLightningBolt(p, t);

    float slashThickness = t * 2.1;
    float carveAmount    = t * 3.4;

    SlashResult slash = sdSlash(p, slashThickness, carveAmount);

    // Step 1: carve slash out of bolt
    float d_carved = max(d_bolt, -slash.carve);

    // Step 2: add visible slash line
    float d_final = min(d_carved, slash.line);

    return d_final;
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
// --- Arrow pieces (from your working #6 code) ---

float sdArrowTriangleRedux(vec2 p) {
    // Upright isosceles triangle with tip at y=+0.5 and base at y=-0.5
    vec2 a = vec2( 0.0,  0.5);   // top
    vec2 b = vec2(-0.5, -0.5);   // bottom-left
    vec2 c = vec2( 0.5, -0.5);   // bottom-right

    vec2 e0 = b - a;
    vec2 e1 = c - b;
    vec2 e2 = a - c;

    float d0 = (e0.y)*(p.x - a.x) - (e0.x)*(p.y - a.y);
    float d1 = (e1.y)*(p.x - b.x) - (e1.x)*(p.y - b.y);
    float d2 = (e2.y)*(p.x - c.x) - (e2.x)*(p.y - c.y);

    // Negative inside, positive outside (mask-style)
    return max(max(d0, d1), d2);
}

vec2 rotate180Triangle(vec2 p) { return p; }

float sdArrowBoxRedux(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return max(d.x, d.y);
}

float sdArrowStemRedux(vec2 p) {
    float w = 0.20;
    float h = w * 7.0;

    // Center of the stem rectangle
    // Top of stem touches triangle base at y = -0.5
    vec2 center = vec2(0.0, -0.5 - h * 0.45);

    return sdArrowBoxRedux(p - center, vec2(w, h * 0.5));
}

float sdSingleArrowRedux(vec2 p) {
    // Rotate so the triangle points down
    vec2 q = rotate180Triangle(p);

    float d_tri  = sdArrowTriangleRedux(q);
    float d_stem = sdArrowStemRedux(q);

    return min(d_tri, d_stem);
}

float sdArrowInstanceRedux(vec2 p, vec2 offset, float scale) {
    vec2 q = (p - offset) / scale;
    return sdSingleArrowRedux(q) * scale;
}

// --- Final glyph: three lines + one down arrow under them ---

float sdGlyphRollTax(vec2 p) {
    float t = line_thickness * 0.6;
    float d = 1e5;

    // Three horizontal lines
    for (int i = 0; i < 3; i++) {
        float y = 0.55 - float(i) * 0.3;
        float dl = sdLine(p, vec2(-0.6, y), vec2(0.6, y), t);
        d = min(d, dl);
    }

    // Single down arrow clearly below the stack
    vec2 arrowOffset = vec2(0.0, 1.0);  // vertical placement
    float arrowScale = 0.4;               // size

    float d_arrow = sdArrowInstanceRedux(p, arrowOffset, arrowScale);
    d = min(d, d_arrow);

    return d;
}






// 15. Divide All — Broken circle

vec2 rotate2D(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c*p.x - s*p.y, s*p.x + c*p.y);
}

float sdDivisionBrokenCircle(vec2 p, float angle) {
    // Rotate first
    p = rotate2D(p, angle);

    float radius = 0.82;
    float d = abs(sdCircle(p, radius)) - rim_thickness;

    float ang = atan(p.y, p.x);

    // Three thin gaps
    if (ang > 2.30 && ang < 2.45) d = 1e5;   // top-left
    if (ang > 0.70 && ang < 0.90) d = 1e5;   // top-right
    if (ang > -0.90 && ang < -0.70) d = 1e5; // bottom-right

    return d;
}

float sdDivisionStem(vec2 p) {
    float w = 0.10;
    float h = w * 3.0;

    vec2 center = vec2(0.0, -0.5 - h * 0.45);
    return sdArrowBoxRedux(p - center, vec2(w, h * 0.5));
}

float sdDivisionStemInstance(vec2 p, vec2 offset, float angle, float scale) {
    vec2 q = p - offset;
    q = rotate2D(q, angle);
    q /= scale;

    return sdDivisionStem(q) * scale;
}


float sdGlyphDivideAll(vec2 p) {
    float d = 1e5;

    // --- Broken circle ---
    float circleAngle = 90.0;   // rotate circle here
    float d_circle = sdDivisionBrokenCircle(p, circleAngle);
    d = min(d, d_circle);

    // --- Two stems ---
    vec2 stemOffset1 = vec2(-0.00, 0.02);
    vec2 stemOffset2 = vec2(1.08, 0.65);

    float stemAngle1 = 45.0;
    float stemAngle2 = 45.0;

    float stemScale = 1.0;

    float d_stem1 = sdDivisionStemInstance(p, stemOffset1, stemAngle1, stemScale);
    float d_stem2 = sdDivisionStemInstance(p, stemOffset2, stemAngle2, stemScale);

    d = min(d, d_stem1);
    d = min(d, d_stem2);

    return d;
}



// 16. Wealth Drain — Dollar sign with downward chevron
vec2 ccRotate(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c*p.x - s*p.y, s*p.x + c*p.y);
}

vec2 ccMirrorY(vec2 p) {
    return vec2(p.x, -p.y);
}
float sdCC_HalfCircle(vec2 p, float radius, float stroke, float extraArc) {
    float d = abs(length(p) - radius) - stroke;

    float a = atan(p.y, p.x);   // [-PI, PI]

    // Extend arc on LEFT side (near +PI)
    // Keep:
    //   a <= 0  (bottom half)
    //   a >= PI - extraArc  (top-left extension)
    // Cut:
    //   0 < a < PI - extraArc  (top-right + most top-left)
    if (a > 0.0 && a < (3.14159265 - extraArc)) {
        d = 1e5;
    }

    return d;
}



float sdCC_Line(vec2 p, float length, float stroke) {
    vec2 a = vec2(0.50, 0.0);
    vec2 b = vec2(0.50, length);

    return sdLineSegment(p, a, b, stroke);
}
float sdCandyCaneModule(vec2 p, float radius, float stroke, float lineLen, float extraArc) {
    float d_arc  = sdCC_HalfCircle(p, radius, stroke, extraArc);
    float d_line = sdCC_Line(p, lineLen, stroke);
    return min(d_arc, d_line);
}


float sdCandyCaneInstance(
    vec2 p,
    vec2 offset,
    float angle,
    bool mirrorY,
    float scale,
    float radius,
    float stroke,
    float lineLen,
    float extraArc
) {
    vec2 q = p - offset;

    if (mirrorY) q = ccMirrorY(q);

    q = ccRotate(q, angle);
    q /= scale;

    float d = sdCandyCaneModule(q, radius, stroke, lineLen, extraArc);

    return d * scale;
}

float sdSShape(vec2 p, vec2 offset, float angle, float scale) {
    vec2 q = p - offset;
    q = ccRotate(q, angle);
    q /= scale;

    float d = 1e5;

    float radius = 0.50;
    float stroke = 0.08;
    float lineLen = 0.35;
    float extraArc = radians(40.0);

    float d_top = sdCandyCaneInstance(
        q,
        vec2(-0.3, 0.80),
        radians(-50.0),
        true,
        1.0,
        radius, stroke, lineLen, extraArc
    );

    float d_bot = sdCandyCaneInstance(
        q,
        vec2(-0.20, -0.40),
        radians(128.0),
        true,
        1.0,
        radius, stroke, lineLen, extraArc
    );

    d = min(d, d_top);
    d = min(d, d_bot);

    return d * scale;
}


float sdBoxInstance(vec2 p, vec2 offset, float angle, float scale, vec2 halfSize) {
    vec2 q = p - offset;
    q = ccRotate(q, angle);
    q /= scale;

    float d = sdBox(q, halfSize);
    return d * scale;
}

float sdTriangleDown(vec2 p, float size) {
    // Equilateral triangle pointing down
    vec2 a = vec2(-size,  size);
    vec2 b = vec2( size,  size);
    vec2 c = vec2( 0.0,  -size);

    // Signed distance to triangle
    vec2 e0 = b - a,  v0 = p - a;
    vec2 e1 = c - b,  v1 = p - b;
    vec2 e2 = a - c,  v2 = p - c;

    float d0 = (e0.y * v0.x - e0.x * v0.y);
    float d1 = (e1.y * v1.x - e1.x * v1.y);
    float d2 = (e2.y * v2.x - e2.x * v2.y);

    float s = (d0 < 0.0 || d1 < 0.0 || d2 < 0.0) ? 1.0 : -1.0;

    float d = min(
        min(
            dot(v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0),
                v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0)),
            dot(v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0),
                v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0))
        ),
        dot(v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0),
            v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0))
    );

    return s * sqrt(d);
}
float sdTriangleInstance(vec2 p, vec2 offset, float angle, float scale, float size) {
    vec2 q = p - offset;
    q = ccRotate(q, angle);
    q /= scale;

    float d = sdTriangleDown(q, size);
    return d * scale;
}


float sdGlyphWealthDrain(vec2 p) {
    float d = 1e5;

    // --- S instance ---
    vec2 sOffset = vec2(0.2, -0.40);
    float sAngle = 0.0;
    float sScale = 0.8;

    float d_s = sdSShape(p, sOffset, sAngle, sScale);
    d = min(d, d_s);

    // --- Vertical bar instance ---
    vec2 barOffset = vec2(0.0, -0.10);
    float barAngle = 0.0;
    float barScale = 0.8;
    vec2 barHalfSize = vec2(line_thickness * 1.5, 1.45);

    float d_bar = sdBoxInstance(p, barOffset, barAngle, barScale, barHalfSize);
    d = min(d, d_bar);

    // --- Triangle instance (new) ---
    vec2 triOffset = vec2(0.0, 1.0);   // position under the S
    float triAngle = 3.15;                // rotate if needed
    float triScale = 0.90;                // scale triangle
    float triSize  = 0.25;               // half-size of triangle

    float d_tri = sdTriangleInstance(p, triOffset, triAngle, triScale, triSize);
    d = min(d, d_tri);

    return d;
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
