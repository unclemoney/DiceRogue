shader_type canvas_item;

// row_blinds.gdshader
// Blind-stripe wipe for scorecard row populate/depopulate (plan §4.3):
// 5 horizontal stripes reveal left-to-right, each stripe offset by
// stripe_i * 0.06. Where not yet revealed the mask draws the opaque
// cover_color (the scorecard panel background); where revealed it draws
// nothing so the row shows through. The top-to-bottom vs bottom-to-top
// direction difference is carried by row iteration order, not this shader.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool reverse = false;
uniform vec4 cover_color : source_color = vec4(0.12, 0.10, 0.17, 1.0);

const float STRIPE_COUNT = 5.0;
const float STRIPE_OFFSET = 0.06;
const float MAX_OFFSET = (STRIPE_COUNT - 1.0) * STRIPE_OFFSET;

void fragment() {
	float stripe = floor(UV.y * STRIPE_COUNT);
	float stripe_offset = stripe * STRIPE_OFFSET;
	// Normalize so every stripe is fully revealed at progress = 1.0
	float local = clamp((progress - stripe_offset) / (1.0 - MAX_OFFSET), 0.0, 1.0);
	float x = UV.x;
	if (reverse) {
		x = 1.0 - x;
	}
	if (x > local) {
		COLOR = cover_color;
	} else {
		COLOR = vec4(0.0);
	}
}
