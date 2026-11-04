#[compute]
#version 450
// Depth model (scripts/depth_model.gd): a transposed convolution whose kernel is its stride (f), so
// each input pixel becomes an f x f block. Channel-major maps, as many channels out as in.

layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0, std430) readonly buffer Weights { uint w[]; };
layout(set = 0, binding = 1, std430) readonly buffer In { float a[]; };
layout(set = 0, binding = 2, std430) buffer Out { float o[]; };
layout(set = 0, binding = 3, std430) readonly buffer Extra { float x[]; };
layout(push_constant, std430) uniform P {
	int c, h, w, f, weight, bias, pad0, pad1;
} p;

float wt(int i) { vec2 v = unpackHalf2x16(w[i >> 1]); return (i & 1) == 0 ? v.x : v.y; }

void main() {
	int ox = int(gl_GlobalInvocationID.x);
	int oy = int(gl_GlobalInvocationID.y);
	int oc = int(gl_GlobalInvocationID.z);
	int wo = p.w * p.f;
	int ho = p.h * p.f;
	if (ox >= wo || oy >= ho)
		return;
	int ix = ox / p.f;
	int iy = oy / p.f;
	int kxy = (oy % p.f) * p.f + ox % p.f;
	float s = wt(p.bias + oc);
	for (int ic = 0; ic < p.c; ic++)
		s += a[(ic * p.h + iy) * p.w + ix] * wt(p.weight + (ic * p.c + oc) * p.f * p.f + kxy);
	o[(oc * ho + oy) * wo + ox] = s;
}
