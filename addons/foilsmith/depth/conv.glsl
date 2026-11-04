#[compute]
#version 450
// Depth model (scripts/depth_model.gd): a 2D convolution over channel-major maps ([c][y][x]).
// flags: 1 ReLU its input, 2 ReLU its output, 4 add extra (a residual), 8 add to out instead of
// writing it, 16 the input is tokens ([1 + y * w + x][c], after the class token).

layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0, std430) readonly buffer Weights { uint w[]; };
layout(set = 0, binding = 1, std430) readonly buffer In { float a[]; };
layout(set = 0, binding = 2, std430) buffer Out { float o[]; };
layout(set = 0, binding = 3, std430) readonly buffer Extra { float x[]; };
layout(push_constant, std430) uniform P {
	int cin, h, w, cout, ho, wo, k, stride, pad, weight, bias, flags;
} p;

float wt(int i) { vec2 v = unpackHalf2x16(w[i >> 1]); return (i & 1) == 0 ? v.x : v.y; }

void main() {
	int ox = int(gl_GlobalInvocationID.x);
	int oy = int(gl_GlobalInvocationID.y);
	int oc = int(gl_GlobalInvocationID.z);
	if (ox >= p.wo || oy >= p.ho)
		return;
	bool relu_in = (p.flags & 1) != 0;
	bool tokens = (p.flags & 16) != 0;
	float s = p.bias >= 0 ? wt(p.bias + oc) : 0.0;
	int kk = p.k * p.k;
	for (int ic = 0; ic < p.cin; ic++) {
		int wbase = p.weight + (oc * p.cin + ic) * kk;
		for (int ky = 0; ky < p.k; ky++) {
			int iy = oy * p.stride - p.pad + ky;
			if (iy < 0 || iy >= p.h)
				continue;
			for (int kx = 0; kx < p.k; kx++) {
				int ix = ox * p.stride - p.pad + kx;
				if (ix < 0 || ix >= p.w)
					continue;
				float v = tokens ? a[(1 + iy * p.w + ix) * p.cin + ic] : a[(ic * p.h + iy) * p.w + ix];
				if (relu_in)
					v = max(v, 0.0);
				s += wt(wbase + ky * p.k + kx) * v;
			}
		}
	}
	if ((p.flags & 2) != 0)
		s = max(s, 0.0);
	int idx = (oc * p.ho + oy) * p.wo + ox;
	if ((p.flags & 4) != 0)
		s += x[idx];
	if ((p.flags & 8) != 0)
		o[idx] += s;
	else
		o[idx] = s;
}
