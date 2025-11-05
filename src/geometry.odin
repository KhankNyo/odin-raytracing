package iacta

import "core:math"
import LA "core:math/linalg"

Ray :: struct {
	origin: Vec3,
	dir:    Vec3,
}

ray_at :: proc(ray: ^Ray, t: f32) -> Vec3 {
	return ray.origin + ray.dir * t
}

SceneObject :: struct {
	derived: any,
}

surface_normal_at :: proc {
	surface_normal_sphere,
}

ray_intersects :: proc {
	ray_intersects_sphere,
}

Sphere :: struct {
	using so: SceneObject,
	center:   Vec3,
	radius:   f32,
}

surface_normal_sphere :: proc(sphere: ^Sphere, pt: Vec3) -> Vec3 {
	return LA.normalize(pt - sphere.center)
}

ray_intersects_sphere :: proc(ray: ^Ray, sphere: ^Sphere) -> f32 {
	dp := sphere.center - ray.origin // displacement vector from ray origin to sphere center
	r := sphere.radius

	a := LA.dot(ray.dir, ray.dir)
	b := -2 * LA.dot(ray.dir, dp)
	c := LA.dot(dp, dp) - r * r
	r1, _ := solve_quadratic_real(a, b, c)
	// Doesn't hit
	if math.is_nan(r1) {
		return r1
	}
	// Take the smaller root, that's the closer hit
	return r1
}

SkyBox :: struct {
	sky_color: Vec4,
}

World :: struct {
	skybox:     SkyBox,
	so_spheres: [dynamic]Sphere,
}

make_world :: proc() -> ^World {
	w := new(World)
	w.so_spheres = make([dynamic]Sphere)
	return w
}
