#[compute]
#version 450
// Depth model (scripts/depth_model.gd): self-attention, one query token per thread and one head per
// workgroup row, over the keys in tiles of 32 with a running softmax. in: the tokens' query, key and
// value side by side (3 x 384 each); out: each head's 64 values at its place in 384.

layout(local_size_x = 64) in;
layout(set = 0, binding = 0, std430) readonly buffer Weights { uint w[]; };
layout(set = 0, binding = 1, std430) readonly buffer In { float a[]; };
layout(set = 0, binding = 2, std430) buffer Out { float o[]; };
layout(set = 0, binding = 3, std430) readonly buffer Extra { float x[]; };
layout(push_constant, std430) uniform P {
	int tokens, pad0, pad1, pad2;
} p;

const int D = 64;
const int ROW = 3 * 384;
const int TILE = 32;

shared float ks[TILE][D];
shared float vs[TILE][D];

void main() {
	int t = int(gl_GlobalInvocationID.x);
	int h = int(gl_WorkGroupID.y);
	int lid = int(gl_LocalInvocationID.x);
	bool live = t < p.tokens;
	float q[D];
	float acc[D];
	for (int d = 0; d < D; d++) {
		q[d] = live ? a[t * ROW + h * D + d] * 0.125 : 0.0;
		acc[d] = 0.0;
	}
	float mx = -1e30;
	float l = 0.0;
	for (int k0 = 0; k0 < p.tokens; k0 += TILE) {
		for (int r = 0; r < TILE * D / 64; r++) {
			int e = lid + r * 64;
			int j = e / D;
			int d = e % D;
			int kt = k0 + j;
			ks[j][d] = kt < p.tokens ? a[kt * ROW + 384 + h * D + d] : 0.0;
			vs[j][d] = kt < p.tokens ? a[kt * ROW + 768 + h * D + d] : 0.0;
		}
		barrier();
		int n = min(TILE, p.tokens - k0);
		float s[TILE];
		float tmax = mx;
		for (int j = 0; j < n; j++) {
			float v = 0.0;
			for (int d = 0; d < D; d++)
				v += q[d] * ks[j][d];
			s[j] = v;
			tmax = max(tmax, v);
		}
		float corr = exp(mx - tmax);
		l *= corr;
		for (int d = 0; d < D; d++)
			acc[d] *= corr;
		for (int j = 0; j < n; j++) {
			float e = exp(s[j] - tmax);
			l += e;
			for (int d = 0; d < D; d++)
				acc[d] += e * vs[j][d];
		}
		mx = tmax;
		barrier();
	}
	if (live)
		for (int d = 0; d < D; d++)
			o[t * 384 + h * D + d] = acc[d] / l;
}
