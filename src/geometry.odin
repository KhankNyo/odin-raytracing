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
	shape:    union {
		Sphere,
	},
	material: union {
		NormalDebugMaterial,
		PureColorMaterial,
	},
}

surface_normal_at :: proc(so: ^SceneObject, pt: Vec3) -> Vec3 {
	switch &shape in so.shape {
	case Sphere:
		return sphere_surface_normal_at(&shape, pt)
	}

	return Vec3{}
}

material_contribution_at :: proc(so: ^SceneObject, pt, n: Vec3) -> Vec4 {
	switch &material in so.material {
	case NormalDebugMaterial:
		return colorize_normal_vec(n)
	case PureColorMaterial:
		return material.color
	}

	return Vec4{}
}

ray_hits :: proc(ray: ^Ray, so: ^SceneObject) -> f32 {
	switch &shape in so.shape {
	case Sphere:
		return sphere_ray_hits(ray, &shape)
	}

	return math.nan_f32()
}

Sphere :: struct {
	center: Vec3,
	radius: f32,
}

sphere_surface_normal_at :: proc(sphere: ^Sphere, pt: Vec3) -> Vec3 {
	return LA.normalize(pt - sphere.center)
}

sphere_ray_hits :: proc(ray: ^Ray, sphere: ^Sphere) -> f32 {
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
	skybox:        SkyBox,
	scene_objects: [dynamic]SceneObject,
}

make_world :: proc() -> ^World {
	w := new(World)
	w.scene_objects = make([dynamic]SceneObject)
	return w
}
