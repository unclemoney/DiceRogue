#[compute]
#version 450
// Depth model (scripts/depth_model.gd): a linear layer over the tokens, out[m][n] = in[m] . W[n] + b[n].
// mode 0 writes it, 1 writes its GELU, 2 adds it to out scaled by a layer scale (a residual).

layout(local_size_x = 16, local_size_y = 16) in;
layout(set = 0, binding = 0, std430) readonly buffer Weights { uint w[]; };
layout(set = 0, binding = 1, std430) readonly buffer In { float a[]; };
layout(set = 0, binding = 2, std430) buffer Out { float o[]; };
layout(set = 0, binding = 3, std430) readonly buffer Extra { float x[]; };
layout(push_constant, std430) uniform P {
	int m, n, k, weight, bias, mode, scale, pad;
} p;

float wt(int i) { vec2 v = unpackHalf2x16(w[i >> 1]); return (i & 1) == 0 ? v.x : v.y; }

// erf, Abramowitz and Stegun 7.1.26 (error under 1.5e-7)
float erf_(float v) {
	float s = sign(v);
	v = abs(v);
	float t = 1.0 / (1.0 + 0.3275911 * v);
	float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-v * v);
	return s * y;
}

shared float as_[16][65];   // [k][m]
shared float bs[16][65];    // [k][n]

void main() {
	int tx = int(gl_LocalInvocationID.x);
	int ty = int(gl_LocalInvocationID.y);
	int m0 = int(gl_WorkGroupID.y) * 64;
	int n0 = int(gl_WorkGroupID.x) * 64;
	int lid = ty * 16 + tx;
	float acc[4][4];
	for (int i = 0; i < 4; i++)
		for (int j = 0; j < 4; j++)
			acc[i][j] = 0.0;
	for (int k0 = 0; k0 < p.k; k0 += 16) {
		for (int r = 0; r < 4; r++) {
			int e = lid + r * 256;   // 1024 = 64 rows x 16 k
			int row = e / 16;
			int kk = e % 16;
			int mm = m0 + row;
			int nn = n0 + row;
			as_[kk][row] = mm < p.m ? a[mm * p.k + k0 + kk] : 0.0;
			bs[kk][row] = nn < p.n ? wt(p.weight + nn * p.k + k0 + kk) : 0.0;
		}
		barrier();
		for (int kk = 0; kk < 16; kk++) {
			float av[4], bv[4];
			for (int i = 0; i < 4; i++) {
				av[i] = as_[kk][ty + 16 * i];
				bv[i] = bs[kk][tx + 16 * i];
			}
			for (int i = 0; i < 4; i++)
				for (int j = 0; j < 4; j++)
					acc[i][j] += av[i] * bv[j];
		}
		barrier();
	}
	for (int i = 0; i < 4; i++) {
		int mm = m0 + ty + 16 * i;
		if (mm >= p.m)
			continue;
		for (int j = 0; j < 4; j++) {
			int nn = n0 + tx + 16 * j;
			if (nn >= p.n)
				continue;
			float v = acc[i][j] + wt(p.bias + nn);
			int idx = mm * p.n + nn;
			if (p.mode == 1)
				o[idx] = 0.5 * v * (1.0 + erf_(v * 0.70710678));
			else if (p.mode == 2)
				o[idx] += wt(p.scale + nn) * v;
			else
				o[idx] = v;
		}
	}
}
