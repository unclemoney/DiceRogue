shader_type canvas_item;

// row_highlight_pulse.gdshader
// Gentle full-row breathing wash for the power-up highlight: a soft teal fill
// whose alpha pulses slowly (~1.26s period at default speed), slightly
// brighter toward the row's horizontal edges. No border chase, no glow.
// effect_strength is the master fade (0-1 normal; the trigger burst spikes
// it to 2.0).

uniform vec4 pulse_color : source_color = vec4(0.3, 0.85, 0.85, 1.0);
uniform float base_alpha = 0.10;
uniform float pulse_amplitude = 0.08;
uniform float pulse_speed = 5.0;
uniform float effect_strength : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	float pulse = (sin(TIME * pulse_speed) * 0.5 + 0.5) * pulse_amplitude;
	// Horizontal falloff from center: edges slightly brighter than the middle
	float edge = abs(UV.x - 0.5) * 2.0;
	float edge_boost = edge * edge * 0.05;
	float alpha = (base_alpha + pulse + edge_boost) * effect_strength;
	COLOR = vec4(pulse_color.rgb, alpha);
}
