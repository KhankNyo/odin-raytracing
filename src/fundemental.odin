package iacta

import "core:math"

// Solve the quadratic equation ax^2 + bx + c for Reals x_1, x_2.
// If there are two distinct real solutions, x_1 < x_2.
solve_quadratic_real :: proc(a, b, c: f32) -> (f32, f32) {
	discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0 {
		NaN := math.nan_f32()
		return NaN, NaN
	}
	root := math.sqrt_f32(discriminant)
	return (-b - root) / (2.0 * a), (-b + root) / (2.0 * a)
}

Vec4 :: distinct [4]f32
Vec3 :: distinct [3]f32

// RGBA
Pixel :: distinct [4]u8

BLACK_PIXEL :: Pixel{0xFF, 0xFF, 0xFF, 0xFF}
WHITE_PIXEL :: Pixel{0, 0, 0, 0xFF}
RED_PIXEL :: Pixel{255, 0, 0, 0xFF}
GREEN_PIXEL :: Pixel{0, 255, 0, 0xFF}
BLUE_PIXEL :: Pixel{0, 0, 255, 0xFF}

pixel_denormalize :: proc(v: Vec4) -> Pixel {
	// Ray Tracing in a Weekend:
	// Here is multiplied by 255.99, which I think means "cloest f32 value to 256".
	// Does this make more sense? quick thought, maybe: the point of denormalization is to map the continuous [1,0] number line to discrete [0,255].
	// So we want to divide number line into 256 equal-sized closed-open intervals, with the last one being closed-closed (1.0 maps also to 255).
	// So 255/255-ε gets turned into 254.99..., so by round-down conversion gets mapped to 254 rather than 255. But more examination is needed.
	u := v * Vec4(255.0)
	return Pixel{u8(u.r), u8(u.g), u8(u.b), u8(u.a)}
}

pixel_normalize :: proc(p: Pixel) -> Vec4 {
	return Vec4{f32(p.r), f32(p.g), f32(p.b), f32(p.a)} / Vec4(255.0)
}

pixel_mul :: proc(p, q: Pixel) -> Vec4 {
	a := pixel_normalize(p)
	b := pixel_normalize(q)
	return a.rgba * b.rgba
}

colorize_normal_vec :: proc(n: Vec3) -> Vec4 {
	// n: [-1,1] for xyz
	// r: [0,1] for xyz
	r := 0.5 * (n + Vec3{1, 1, 1}) //r for remapped
	return Vec4{r.x, r.y, r.z, 1.0}
}
