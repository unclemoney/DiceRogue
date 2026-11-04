#[compute]
#version 450
// Depth model (scripts/depth_model.gd): layer norm of each token.

layout(local_size_x = 64) in;
layout(set = 0, binding = 0, std430) readonly buffer Weights { uint w[]; };
layout(set = 0, binding = 1, std430) readonly buffer In { float a[]; };
layout(set = 0, binding = 2, std430) buffer Out { float o[]; };
layout(set = 0, binding = 3, std430) readonly buffer Extra { float x[]; };
layout(push_constant, std430) uniform P {
	int tokens, gamma, beta, pad;
} p;

const int C = 384;

float wt(int i) { vec2 v = unpackHalf2x16(w[i >> 1]); return (i & 1) == 0 ? v.x : v.y; }

void main() {
	int t = int(gl_GlobalInvocationID.x);
	if (t >= p.tokens)
		return;
	int base = t * C;
	float mean = 0.0;
	for (int i = 0; i < C; i++)
		mean += a[base + i];
	mean /= float(C);
	float v = 0.0;
	for (int i = 0; i < C; i++) {
		float d = a[base + i] - mean;
		v += d * d;
	}
	float inv = inversesqrt(v / float(C) + 1e-6);
	for (int i = 0; i < C; i++)
		o[base + i] = (a[base + i] - mean) * inv * wt(p.gamma + i) + wt(p.beta + i);
}
