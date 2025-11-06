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

	IMAGE_WIDTH :: 1024
	IMAGE_HEIGHT :: 720
	IAMGE_ASPECT_RATIO :: f32(IMAGE_WIDTH) / f32(IMAGE_HEIGHT)
	COMP :: len(Pixel(0))

	camera := make_camera()
	camera.pos = Vec3{-3, -3, 2}
	camera.horz_fov = 70.0 / 180 * math.PI
	camera.aspect_ratio = IAMGE_ASPECT_RATIO
	camera_look_at(&camera, Vec3{0, 0, 0})

	world := make_world()
	world.skybox.sky_color = pixel_normalize(Pixel{162, 224, 242, 0xFF})
	add_obj :: proc(world: ^World, s: $T) {
		append(&world.scene_objects, SceneObject{shape = s, material = NormalDebugMaterial{}})
	}
	add_obj(world, Sphere{center = Vec3{0, 0, 0.5}, radius = 0.5})
	add_obj(world, Sphere{center = Vec3{0, 1, 0.5}, radius = 0.5})
	add_obj(world, Sphere{center = Vec3{0, -1, 0.5}, radius = 0.5})
	append(
		&world.scene_objects,
		SceneObject {
			shape = Sphere{center = Vec3{0, 0, -50}, radius = 50},
			material = PureColorMaterial{color = pixel_normalize(RED_PIXEL)},
		},
	)


	image := make([dynamic]Pixel, IMAGE_WIDTH * IMAGE_HEIGHT)
	if false
	{
		render(
			&camera,
			world,
			samples_per_pixel = 16,
			viewport_width = IMAGE_WIDTH,
			viewport_height = IMAGE_HEIGHT,
			image = image[:],
		)

		stbi.write_png(
			"./out/output.png",
			IMAGE_WIDTH,
			IMAGE_HEIGHT,
			COMP,
			&image[0],
			size_of(image[0]) * IMAGE_WIDTH,
		)
	}
	else
	{
		render_gpu(
			&camera,
			world,
			samples_per_pixel = 16,
			viewport_width = IMAGE_WIDTH,
			viewport_height = IMAGE_HEIGHT,
			image = image[:],
		)
	}
}
