#+private file
package iacta

import "core:fmt"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import "core:c"
import "core:os"
import "core:strings"

import "core:math"
import "core:math/linalg"
import "core:math/rand"


COLOR_PALETTE_COUNT:: 16
GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 0
GLuint :: u32
GLint :: i32

render_state :: struct 
{
	ShaderProgramID: GLuint,
	VAO: GLuint, /* vertex attribute object */
	ShouldReloadShader: bool,
}


@private /* this is visible in the package */
render_gpu :: proc(
	cam: ^Camera,
	world: ^World, 
	samples_per_pixel: i32, 
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


	/* obj components to send to the gpu */
	WORLD_OBJ_CAPACITY :: 32
	obj_type :: enum(i32) {
		SPHERE = 0,
	}
	obj_material_type :: enum(i32) {
		NORMAL_DEBUG = 0,
		PURE_COLOR = 1,
	}
	ObjData: [WORLD_OBJ_CAPACITY]Vec4
	ObjMaterialColor: [WORLD_OBJ_CAPACITY]Vec4
	ObjType: [WORLD_OBJ_CAPACITY]obj_type
	ObjMaterialType: [WORLD_OBJ_CAPACITY]obj_material_type
	assert(len(world.scene_objects) < WORLD_OBJ_CAPACITY, "TODO: sending dynamic shit to the gpu")
	ObjCount: i32 = 0;
	for &Obj in world.scene_objects 
	{
		switch &Material in Obj.material 
		{
		case NormalDebugMaterial: 
			ObjMaterialType[ObjCount] = obj_material_type.NORMAL_DEBUG;
		case PureColorMaterial:
			ObjMaterialType[ObjCount] = obj_material_type.PURE_COLOR;
			ObjMaterialColor[ObjCount] = Material.color;
		}

		switch &Shape in Obj.shape
		{
		case Sphere:
			ObjType[ObjCount] = obj_type.SPHERE;
			ObjData[ObjCount].xyz = Shape.center.xyz;
			ObjData[ObjCount].w = Shape.radius;
		}
		ObjCount += 1;
	}


	FragmentShaderFileName := "shaders/FragmentShader.glsl";
	VertexShaderFileName := "shaders/VertexShader.glsl";
	State: render_state = {
		ShouldReloadShader = false,
	};
	Window := Init(&State, "hello ray tracin'", viewport_width, viewport_height);
	defer Deinit(Window);

	LoadShaderData(&State);
	LoadShader(&State, FragmentShaderFileName, VertexShaderFileName);
	for (!glfw.WindowShouldClose(Window)) 
	{
		glfw.PollEvents()
		Width, Height := glfw.GetWindowSize(Window)

		/* update */
		if State.ShouldReloadShader 
		{
			LoadShader(&State, FragmentShaderFileName, VertexShaderFileName);
			State.ShouldReloadShader = false;
		}

		/* draw */
		if State.ShaderProgramID != 0 
		{
			gl.UseProgram(State.ShaderProgramID)
			gl.BindVertexArray(State.VAO)
			{
				ShaderSetInt(State.ShaderProgramID, "u_SamplesPerPixel", samples_per_pixel)
				ShaderSetFloat(State.ShaderProgramID, "u_SampleScalingFactor", sample_scaling_factor)
				ShaderSetVec3(State.ShaderProgramID, "u_VpOrigin", &vp_origin[0], 1)
				ShaderSetVec3(State.ShaderProgramID, "u_PixelDeltaX", &pixel_delta_x[0], 1)
				ShaderSetVec3(State.ShaderProgramID, "u_PixelDeltaY", &pixel_delta_y[0], 1)
				ShaderSetVec3(State.ShaderProgramID, "u_CamPos", &cam.pos[0], 1)
				ShaderSetVec4(State.ShaderProgramID, "u_SkyColor", &world.skybox.sky_color[0], 1)

				ShaderSetInt(State.ShaderProgramID, "u_WorldObjCount", ObjCount)
				ShaderSetVec4(State.ShaderProgramID, "u_WorldObjData", &ObjData[0][0], ObjCount)
				ShaderSetVec4(State.ShaderProgramID, "u_WorldObjMaterialColor", &ObjMaterialColor[0][0], ObjCount)
				ShaderSetIntArray(State.ShaderProgramID, "u_WorldObjType", transmute([^]i32)&ObjType[0], ObjCount)
				ShaderSetIntArray(State.ShaderProgramID, "u_WorldObjMaterialType", transmute([^]i32)&ObjMaterialType[0], ObjCount)

				ShaderSetFloat(State.ShaderProgramID, "u_ScreenHeight", f32(Height))
			}
			gl.DrawElements(gl.TRIANGLES, 2*3, gl.UNSIGNED_INT, nil)
		}
		glfw.SwapBuffers(Window)
	}
}


LoadShaderData :: proc(State: ^render_state)
{
	/* VAO, VBO, EBO */
	FullScreen := [?]f32 {
		-1.0, 1.0, 0.0, 
		1.0, 1.0, 0.0, 
		1.0, -1.0, 0.0, 
		-1.0, -1.0, 0.0, 
	}
	Indices := [?]u32 {
		0, 1, 2, 
		2, 3, 0,
	}

	/* vertex attrib */
	State.ShaderProgramID = 0;
	gl.GenVertexArrays(1, &State.VAO)
	gl.BindVertexArray(State.VAO)
	{
		/* vertex buffer object */
		VBO: GLuint
		gl.GenBuffers(1, &VBO)
		gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
		gl.BufferData(gl.ARRAY_BUFFER, size_of(FullScreen), &FullScreen, gl.STATIC_DRAW)

		/* element buffer object */
		EBO: GLuint
		gl.GenBuffers(1, &EBO)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
		gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(Indices), &Indices, gl.STATIC_DRAW)

		/* data to the gpu */
		VertexLocationInVertexShader: GLuint = 0
		gl.VertexAttribPointer(VertexLocationInVertexShader, 3, gl.FLOAT, gl.FALSE, 3*size_of(f32), 0)
		gl.EnableVertexAttribArray(VertexLocationInVertexShader)
	}
}

KeyCallback :: proc "c" (Window: glfw.WindowHandle, Key, Scancode, Action, Mod: i32)
{
	State := transmute(^render_state)glfw.GetWindowUserPointer(Window)
	if Action == glfw.PRESS
	{
		switch (Key)
		{
		case glfw.KEY_R:
			State.ShouldReloadShader = true;
		}
	}
}

Init :: proc(State: ^render_state, WindowName: cstring, Width, Height: i32) -> (glfw.WindowHandle)
{
	// glfw hints
	glfw.WindowHint(glfw.RESIZABLE, 1)
	// opengl shit
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION) 
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	if (!glfw.Init())
	{
		fmt.println("Failed to initialize GLFW")
		os.exit(1);
	}

	Window := glfw.CreateWindow(Width, Height, WindowName, nil, nil)
	if Window == nil 
	{
		fmt.println("Unable to create window")
		os.exit(1);
	}
	glfw.MakeContextCurrent(Window)
	// Enable vsync
	glfw.SwapInterval(0)
	glfw.SetFramebufferSizeCallback(Window, SizeCallback)
	glfw.SetKeyCallback(Window, KeyCallback);
	glfw.SetWindowUserPointer(Window, State);

	// Set OpenGL Context bindings using the helper function
	// See Odin Vendor source for specifc implementation details
	// https://github.com/odin-lang/Odin/tree/master/vendor/OpenGL
	// https://www.glfw.org/docs/3.3/group__context.html#ga35f1837e6f666781842483937612f163
	gl.load_up_to(int(GL_MAJOR_VERSION), GL_MINOR_VERSION, glfw.gl_set_proc_address) 

	return Window;
}

Deinit :: proc(Window: glfw.WindowHandle)
{
	glfw.Terminate();
	glfw.DestroyWindow(Window);
}





SizeCallback :: proc "c" (window: glfw.WindowHandle, Width, Height: i32)
{
	gl.Viewport(0, 0, Width, Height)
}




ShaderSetVec4 :: proc(Program: GLuint, UniformName: cstring, Values: [^]f32, CountVec4: i32)
{
	Location := gl.GetUniformLocation(Program, UniformName)
	gl.Uniform4fv(Location, CountVec4, Values)
}

ShaderSetVec3 :: proc(Program: GLuint, UniformName: cstring, Values: [^]f32, CountVec3: i32)
{
	Location := gl.GetUniformLocation(Program, UniformName)
	gl.Uniform3fv(Location, CountVec3, Values)
}

ShaderSetFloat :: proc(Program: GLuint, UniformName: cstring, Value: f32)
{
	Location := gl.GetUniformLocation(Program, UniformName)
	gl.Uniform1f(Location, Value)
}

ShaderSetInt :: proc(Program: GLuint, UniformName: cstring, Value: GLint)
{
	Location := gl.GetUniformLocation(Program, UniformName)
	gl.Uniform1i(Location, Value)
}

ShaderSetIntArray :: proc(Program: GLuint, UniformName: cstring, Values: [^]GLint, Count: i32)
{
	Location := gl.GetUniformLocation(Program, UniformName)
	gl.Uniform1iv(Location, Count, Values)
}




LoadShader :: proc(
	State: ^render_state, 
	FragmentShaderFileName: string, 
	VertexShaderFileName: string) 
{
	ShaderProgramID: GLuint;
	gl.UseProgram(0);
	gl.DeleteProgram(State.ShaderProgramID);

	ErrMsg: [1024]u8
	if VertexShaderSource, Ok := os.read_entire_file_from_filename(VertexShaderFileName); Ok 
	{
		defer delete_slice(VertexShaderSource);
		if FragmentShaderSource, Ok := os.read_entire_file_from_filename(FragmentShaderFileName); Ok 
		{
			defer delete_slice(FragmentShaderSource);

			/* read shaders ok, compile the shaders */
			if VertexShaderID, Ok := CompileShader(gl.VERTEX_SHADER, VertexShaderSource); Ok 
			{
				defer gl.DeleteShader(VertexShaderID);
				if FragmentShaderID, Ok := CompileShader(gl.FRAGMENT_SHADER, FragmentShaderSource); Ok 
				{
					defer gl.DeleteShader(FragmentShaderID);

					/* compile ok, link the shaders */
					ShaderProgramID = gl.CreateProgram()
					gl.AttachShader(ShaderProgramID, VertexShaderID)
					gl.AttachShader(ShaderProgramID, FragmentShaderID)
					gl.LinkProgram(ShaderProgramID)

					LinkOk: GLint 
					gl.GetProgramiv(ShaderProgramID, gl.LINK_STATUS, &LinkOk)
					if LinkOk == 0
					{
						gl.GetProgramInfoLog(ShaderProgramID, size_of(ErrMsg), nil, &ErrMsg[0])
						fmt.println("Shader program link error: ", 
							transmute(cstring)&ErrMsg[0], sep=""
						)
					}
				}
				else
				{
					gl.GetShaderInfoLog(FragmentShaderID, size_of(ErrMsg), nil, &ErrMsg[0])
					fmt.println("Fragment shader '", FragmentShaderFileName, "' compile error: ", 
						transmute(cstring)&ErrMsg[0], sep=""
					)
				}
			}
			else
			{
				gl.GetShaderInfoLog(VertexShaderID, size_of(ErrMsg), nil, &ErrMsg[0])
				fmt.println("Vertex shader '", VertexShaderFileName, "' compile error: ", 
					transmute(cstring)&ErrMsg[0], sep=""
				)
			}
		}
		else
		{
			fmt.println("Unable to open '", FragmentShaderFileName, "'", sep="")
		}
	}
	else
	{
		fmt.println("Unable to open '", VertexShaderFileName, "'", sep="")
	}

	State.ShaderProgramID = ShaderProgramID;
	gl.UseProgram(State.ShaderProgramID);
}


CompileShader :: proc(ShaderType: GLuint, ShaderProgram: []u8) -> (ShaderID: GLuint, Ok: bool)
{
	ShaderProgramCStr := strings.clone_to_cstring(transmute(string)ShaderProgram)
	defer delete_cstring(ShaderProgramCStr)

	ShaderID = gl.CreateShader(ShaderType)

	gl.ShaderSource(shader=ShaderID, count=1, string=&ShaderProgramCStr, length=nil)
	gl.CompileShader(ShaderID)

	CompilationOk: GLint
	gl.GetShaderiv(ShaderID, gl.COMPILE_STATUS, &CompilationOk)

	Ok = CompilationOk != 0
	return ShaderID, Ok
}

