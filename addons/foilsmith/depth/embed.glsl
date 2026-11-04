#[compute]
#version 450
// Depth model (scripts/depth_model.gd): her picture's 14x14 patches embedded as tokens, after the
// class token, each plus its position embedding (bicubic-resized from the 37x37 it was trained at).

layout(local_size_x = 64, local_size_y = 4) in;
layout(set = 0, binding = 0, std430) readonly buffer Weights { uint w[]; };
layout(set = 0, binding = 1, std430) readonly buffer Pixels { uint px[]; };   // RGBA8
layout(set = 0, binding = 2, std430) buffer Out { float o[]; };
layout(set = 0, binding = 3, std430) readonly buffer Extra { float x[]; };
layout(push_constant, std430) uniform P {
	int ph, pw, patch_w, patch_b, cls, pos, grid, pad;
} p;

const int C = 384;
const vec3 MEAN = vec3(0.485, 0.456, 0.406);
const vec3 STD = vec3(0.229, 0.224, 0.225);

float wt(int i) { vec2 v = unpackHalf2x16(w[i >> 1]); return (i & 1) == 0 ? v.x : v.y; }

float cubic1(float t) { return ((1.25 * t - 2.25) * t) * t + 1.0; }               // |t| <= 1, A = -0.75
float cubic2(float t) { return ((-0.75 * t + 3.75) * t - 6.0) * t + 3.0; }        // 1 < |t| < 2

// torch's bicubic (align_corners=False) of channel c of the position grid at patch (gy, gx)
float pos_at(int c, int gy, int gx) {
	float sy = (float(gy) + 0.5) * float(p.grid) / float(p.ph) - 0.5;
	float sx = (float(gx) + 0.5) * float(p.grid) / float(p.pw) - 0.5;
	int iy = int(floor(sy));
	int ix = int(floor(sx));
	float ty = sy - float(iy);
	float tx = sx - float(ix);
	float wy[4] = float[4](cubic2(ty + 1.0), cubic1(ty), cubic1(1.0 - ty), cubic2(2.0 - ty));
	float wx[4] = float[4](cubic2(tx + 1.0), cubic1(tx), cubic1(1.0 - tx), cubic2(2.0 - tx));
	float s = 0.0;
	for (int j = 0; j < 4; j++) {
		int yy = clamp(iy - 1 + j, 0, p.grid - 1);
		float r = 0.0;
		for (int i = 0; i < 4; i++) {
			int xx = clamp(ix - 1 + i, 0, p.grid - 1);
			r += wx[i] * wt(p.pos + (1 + yy * p.grid + xx) * C + c);
		}
		s += wy[j] * r;
	}
	return s;
}

void main() {
	int c = int(gl_GlobalInvocationID.x);
	int t = int(gl_GlobalInvocationID.y);
	if (c >= C || t > p.ph * p.pw)
		return;
	if (t == 0) {
		o[c] = wt(p.cls + c) + wt(p.pos + c);
		return;
	}
	int gy = (t - 1) / p.pw;
	int gx = (t - 1) % p.pw;
	int iw = p.pw * 14;
	float s = wt(p.patch_b + c);
	for (int ky = 0; ky < 14; ky++) {
		for (int kx = 0; kx < 14; kx++) {
			vec3 rgb = (unpackUnorm4x8(px[(gy * 14 + ky) * iw + gx * 14 + kx]).rgb - MEAN) / STD;
			int k = (c * 3 * 14 + ky) * 14 + kx;
			s += wt(p.patch_w + k) * rgb.r + wt(p.patch_w + k + 196) * rgb.g + wt(p.patch_w + k + 392) * rgb.b;
		}
	}
	o[t * C + c] = s + pos_at(c, gy, gx);
}
