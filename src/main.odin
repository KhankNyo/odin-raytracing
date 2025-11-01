package iacta

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import stbi "vendor:stb/image"

inverse_only_color :: proc(col: ^Pixel) {
	for i in 0 ..= 2 {
		col^[i] = 0xFF - col^[i]
	}
}

main :: proc() {
	// Use fixed RNG seed for reproducible rendering results
	rand.reset(0x531864e09a8e25d6)

	COMP :: len(Pixel(0))

	sphere := new(Sphere)
	sphere.center = Vec3{0, 0, 0}
	sphere.radius = 0.5

	sky_color := pixel_normalize(Pixel{162, 224, 242, 0xFF})

	camera := make_camera()
	camera.pos = Vec3{-2, 0, 1}
	camera.vp_width = 160
	camera.vp_height = 80
	camera.aspect_ratio = 160.0 / 80.0
	camera_look_at(&camera, Vec3{0, 0, 0})

	rt_params := RayTraceParams {
		samples_per_pixel = 16,
	}

	cam_aux := CameraAux{}
	populate_camera_aux(&camera, &cam_aux)

	image := render(&camera, &cam_aux, &rt_params)

	stbi.write_png(
		"./out/output.png",
		camera.vp_width,
		camera.vp_height,
		COMP,
		&image[0],
		size_of(image[0]) * camera.vp_width,
	)
}
