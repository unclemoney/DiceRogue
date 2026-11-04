#[compute]
#version 450
// Depth model (scripts/depth_model.gd): bilinear resize of channel-major maps, as torch does it
// with align_corners on (align 1) or off.

layout(local_size_x = 8, local_size_y = 8) in;
layout(set = 0, binding = 0, std430) readonly buffer Weights { uint w[]; };
layout(set = 0, binding = 1, std430) readonly buffer In { float a[]; };
layout(set = 0, binding = 2, std430) buffer Out { float o[]; };
layout(set = 0, binding = 3, std430) readonly buffer Extra { float x[]; };
layout(push_constant, std430) uniform P {
	int c, h, w, ho, wo, align, pad0, pad1;
} p;

float src(int d, int n, int no) {
	if (p.align == 1)
		return no > 1 ? float(d) * float(n - 1) / float(no - 1) : 0.0;
	return max((float(d) + 0.5) * float(n) / float(no) - 0.5, 0.0);
}

void main() {
	int ox = int(gl_GlobalInvocationID.x);
	int oy = int(gl_GlobalInvocationID.y);
	int oc = int(gl_GlobalInvocationID.z);
	if (ox >= p.wo || oy >= p.ho)
		return;
	float sx = src(ox, p.w, p.wo);
	float sy = src(oy, p.h, p.ho);
	int x0 = min(int(sx), p.w - 1);
	int y0 = min(int(sy), p.h - 1);
	int x1 = min(x0 + 1, p.w - 1);
	int y1 = min(y0 + 1, p.h - 1);
	float fx = sx - float(x0);
	float fy = sy - float(y0);
	int base = oc * p.h * p.w;
	float top = mix(a[base + y0 * p.w + x0], a[base + y0 * p.w + x1], fx);
	float bot = mix(a[base + y1 * p.w + x0], a[base + y1 * p.w + x1], fx);
	o[(oc * p.ho + oy) * p.wo + ox] = mix(top, bot, fy);
}
