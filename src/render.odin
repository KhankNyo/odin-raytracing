package iacta

import "core:math"
import "core:math/linalg"
import "core:math/rand"

Camera :: struct {
	// Camera position, in world space.
	pos:          Vec3,

	// Up, a unit vector in world space.
	// Used to determine roll, whereas yaw and pitch is determined by `view`.
	up:           Vec3,

	// View direction, a unit vector, origined at the camera. (NOT world space)
	// i.e. if looking parallel to +X direction, this would be Vec3{1,0,0}
	view:         Vec3,

	// Distance from camera position to the viewport plane ("near plane" in RT rendering convention)
	focal_length: f32,

	// Horizontal FOV of the camera.
	horz_fov:     f32,

	// width/height
	aspect_ratio: f32,
}

make_camera :: proc() -> Camera {
	return Camera {
		pos = Vec3{0, 0, 0},
		up = Vec3{0, 0, 1},
		view = Vec3{1, 0, 0},
		focal_length = 1.0,
	}
}

// Look at a point in world space, without changing the focal distance.
camera_look_at :: proc(cam: ^Camera, pt: Vec3) {
	cam.view = linalg.normalize(pt - cam.pos)
}

NormalDebugMaterial :: struct {}

PureColorMaterial :: struct {
	color: Vec4,
}

render :: proc(
	cam: ^Camera,
	world: ^World,
	samples_per_pixel: i32,

	// Dimension of the rendered image, in pixels.
	// Aspect ratio `f32(viewport_width) / f32(viewport_height)` should match the `Camera.aspect_ratio` used for rendering.
	// `viewport_width * viewport_height` should match length of `image`.
	viewport_width, viewport_height: i32,
	image: []Pixel,
) {
	// Dimensions (in world space) of the focal plane
	fp_width := 2 * cam.focal_length * math.tan(cam.horz_fov / 2)
	fp_height := fp_width / cam.aspect_ratio

	// Orthonormal basis i,j,k for camera space.

	// k is Y-dierction basis, forward in camera space
	cam_k := linalg.normalize(cam.view)
	// i is X-direction basis, pointing to the *right* in camera space
	cam_i := linalg.normalize(linalg.cross(cam.view, cam.up))
	// j is Z-direction basis, pointing to the *top* in camera space
	cam_j := linalg.cross(cam_i, cam_k)

	vp_horz := cam_i * fp_width
	vp_vert := -cam_j * fp_height
	vp_origin := cam.pos + cam.view * cam.focal_length - vp_horz / 2 - vp_vert / 2

	pixel_delta_x := vp_horz / f32(viewport_width)
	pixel_delta_y := vp_vert / f32(viewport_height)

	sample_scaling_factor := 1 / f32(samples_per_pixel)

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

				closest_hit: ^SceneObject = nil
				closest_t: f32 = math.inf_f32(+1)
				for &so in world.scene_objects {
					t := ray_hits(&view_ray, &so)
					if !math.is_nan(t) && t < closest_t {
						closest_hit = &so
						closest_t = t
					}
				}

				if closest_hit == nil {
					accum += world.skybox.sky_color
				} else {
					hit_pt := ray_at(&view_ray, closest_t)
					hit_normal := surface_normal_at(closest_hit, hit_pt)
					accum += material_contribution_at(closest_hit, hit_pt, hit_normal)
				}
			}

			pixel_color := accum * sample_scaling_factor
			image[y * viewport_width + x] = pixel_denormalize(pixel_color)
		}
	}
}
