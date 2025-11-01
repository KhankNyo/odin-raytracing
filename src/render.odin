package iacta

import "core:math"
import "core:math/linalg"
import "core:math/rand"

Camera :: struct {
	pos:          Vec3,
	view:         Vec3,
	up:           Vec3,
	horz_fov:     f32,
	// width/height
	aspect_ratio: f32,

	// TODO disallow mismatched aspec_ratio vs. vp_height
	vp_width, vp_height: i32,
}

make_camera :: proc() -> Camera {
	return Camera {
		pos = Vec3{0, 0, 0},
		view = Vec3{1, 0, 0},
		up = Vec3{0, 0, 1},
		horz_fov = 70,
		aspect_ratio = 16 / 9,
	}
}

// Look at a point in world space, without changing the focal distance.
camera_look_at :: proc(cam: ^Camera, pt: Vec3) {
	focal_distance := linalg.length(cam.pos - cam.view)
	cam.view = linalg.normalize(pt - cam.pos) * focal_distance
}

camear_set_viewport :: proc(cam: ^Camera, vw, vh: i32) {
	cam.aspect_ratio = f32(vw) / f32(vh)
}

RayTraceParams :: struct {
	samples_per_pixel: i32,
}

// Auxiliary data that can be dervied from the primary parameters.
CameraAux :: struct {
	// Distance from camera center pos to the viewport plane ("near plane" in RT rendering convention)
	focal_length:        f32,
	// Dimensions (in world space) of the focal plane
	fp_width, fp_height: f32,
}

populate_camera_aux :: proc(cam: ^Camera, aux: ^CameraAux) {
	aux.focal_length = linalg.length(cam.pos - cam.view)
	aux.fp_width = 2 * aux.focal_length * math.tan(cam.horz_fov / 2)
	aux.fp_height = aux.fp_width / cam.aspect_ratio
}

render :: proc(cam: ^Camera, aux: ^CameraAux, rt_param: ^RayTraceParams) -> [dynamic]Pixel {
	fp_width := aux.fp_width
	fp_height := aux.fp_height
	viewport_width := cam.vp_width
	viewport_height := cam.vp_height

	// Orthonormal basis i,j,k for camera space.

	// k is Y-dierction basis, forward in camera space
	cam_k := linalg.normalize(cam.view)
	// i is X-direction basis, pointing to the *right* in camera space
	cam_i := linalg.normalize(linalg.cross(cam.view, cam.up))
	// j is Z-direction basis, pointing to the *top* in camera space
	cam_j := linalg.cross(cam_i, cam_k)

	vp_horz := cam_i * fp_width
	vp_vert := -cam_j * fp_height
	vp_origin := cam.pos + cam.view - vp_horz / 2 - vp_vert / 2

	pixel_delta_x := vp_horz / f32(viewport_width)
	pixel_delta_y := vp_vert / f32(viewport_height)

	samples_per_pixel := rt_param.samples_per_pixel
	sample_scaling_factor := 1 / f32(samples_per_pixel)

	// TODO prepare this for long running, no longer single-shot rendering process
	image := make([dynamic]Pixel, viewport_width * viewport_height)

	for y in 0 ..< viewport_height {
		for x in 0 ..< viewport_width {
			accum := Vec4{}
			for _ in 0 ..< samples_per_pixel {
				sample_x_off := rand.float32_uniform(0, 1)
				sample_y_off := rand.float32_uniform(0, 1)

				pixel_center :=
					vp_origin +
					pixel_delta_x * (f32(x) + sample_x_off) +
					pixel_delta_y * (f32(y) + sample_y_off)
				view_ray := Ray{cam.pos, pixel_center - cam.pos}

				// TODO
			}

			pixel_color := accum * sample_scaling_factor
			image[y * viewport_width + x] = pixel_denormalize(pixel_color)
		}
	}

	return image
}
