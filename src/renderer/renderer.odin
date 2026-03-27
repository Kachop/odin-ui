package renderer

import "../platform"
import "base:runtime"
import "core:fmt"
import "core:time/timezone"
import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 6

WindowError :: enum {
	NONE,
	CREATE_ERROR,
}

Mode :: enum {
	Triangles,
	Point,
	Line,
	Glyf,
}

Shader :: enum {
	Rect,
	Point,
}

Point :: [2]f32

Rectangle :: struct #packed {
	x:      f32,
	y:      f32,
	width:  f32,
	height: f32,
}

@(private)
Render_State :: struct {
	window_width:  f32, //Pixels
	window_height: f32, //Pixels
	shaders:       map[Shader]u32,
	mode:          Mode,
	vertex_list:   [dynamic]Point,
	indices_list:  [dynamic]u32,
}

@(private)
state: Render_State

init :: proc() {
	platform.set_window_hint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR_VERSION)
	platform.set_window_hint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR_VERSION)
	platform.set_window_hint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	//Other window hints can be set here
}

init_context :: proc() {
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.Enable(gl.PROGRAM_POINT_SIZE)
	gl.LineWidth(2)

	create_shader_program(
		.Rect,
		//"/mnt/Guido/Development/Odin/odin-ui/src/renderer/shaders/rec_vs.shader",
		//"/mnt/Guido/Development/Odin/odin-ui/src/renderer/shaders/rec_fs.shader",
		"/home/robert/Development/odin/odin-ui/src/renderer/shaders/rec_vs.shader",
		"/home/robert/Development/odin/odin-ui/src/renderer/shaders/rec_fs.shader",
	)

	create_shader_program(
		.Point,
		//"/mnt/Guido/Development/Odin/odin-ui/src/renderer/shaders/point_vs.shader",
		//"/mnt/Guido/Development/Odin/odin-ui/src/renderer/shaders/point_fs.shader",
		"/home/robert/Development/odin/odin-ui/src/renderer/shaders/point_vs.shader",
		"/home/robert/Development/odin/odin-ui/src/renderer/shaders/point_fs.shader",
	)

	use_shader_program(state.shaders[.Rect])
}

//Start building layout structure
begin_drawing :: proc(window: glfw.WindowHandle) {
	glfw.MakeContextCurrent(window)
	glfw.PollEvents()
	//Update window dimensions, used for normalising the vertex coords.
	state.window_width, state.window_height = platform.get_window_size()
	gl.Clear(gl.COLOR_BUFFER_BIT)
}
//Layout build, figure all the positions out
end_drawing :: proc(window: glfw.WindowHandle) {
	glfw.PollEvents()
	platform.update_mouse_pos()
	glfw.SwapBuffers(window)
	glfw.MakeContextCurrent(nil)
}

clear_colour :: proc(colour: Colour_RGBA) {
	normalised_colour := normalise_colour(colour)
	gl.ClearColor(
		normalised_colour[0],
		normalised_colour[1],
		normalised_colour[2],
		normalised_colour[3],
	)
}

rwb_begin :: proc(mode: Mode) {
	state.mode = mode
	switch state.mode {
	case .Triangles:
		clear(&state.vertex_list)
		clear(&state.indices_list)
	case .Point:
		clear(&state.vertex_list)
		clear(&state.indices_list)
	case .Line:
		clear(&state.vertex_list)
		clear(&state.indices_list)
	case .Glyf:
		clear(&state.vertex_list)
		clear(&state.indices_list)
	}
}

rwb_end :: proc() {
	switch state.mode {
	case .Triangles:
		vertices := state.vertex_list[:]
		indices := state.indices_list[:]

		VBO, VAO, EBO: u32
		gl.GenVertexArrays(1, &VAO)
		gl.GenBuffers(1, &VBO)
		gl.GenBuffers(1, &EBO)

		gl.BindVertexArray(VAO)

		gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
		gl.BufferData(
			gl.ARRAY_BUFFER,
			size_of(Point) * len(vertices),
			raw_data(vertices),
			gl.STATIC_DRAW,
		)

		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
		gl.BufferData(
			gl.ELEMENT_ARRAY_BUFFER,
			size_of(u32) * len(indices),
			raw_data(indices),
			gl.STATIC_DRAW,
		)

		gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, cast(uintptr)0)
		gl.EnableVertexAttribArray(0)

		gl.BindVertexArray(VAO)

		gl.DrawElements(gl.TRIANGLES, cast(i32)len(indices), gl.UNSIGNED_INT, rawptr(uintptr(0)))

		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
		gl.BindVertexArray(0)

		gl.DeleteVertexArrays(1, &VAO)
		gl.DeleteBuffers(1, &VBO)
		gl.DeleteBuffers(1, &EBO)
	case .Point:
		vertices := state.vertex_list[:]
		indices := state.indices_list[:]

		VBO, VAO: u32
		gl.GenVertexArrays(1, &VAO)
		gl.GenBuffers(1, &VBO)

		gl.BindVertexArray(VAO)

		gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
		gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices), gl.STATIC_DRAW)

		gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, cast(uintptr)0)
		gl.EnableVertexAttribArray(0)

		gl.BindVertexArray(VAO)

		gl.DrawArrays(gl.POINTS, 0, cast(i32)len(vertices))

		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
		gl.BindVertexArray(0)

		gl.DeleteVertexArrays(1, &VAO)
		gl.DeleteBuffers(1, &VBO)
	case .Line:
		vertices := state.vertex_list[:]
		indices := state.indices_list[:]

		VBO, VAO: u32
		gl.GenVertexArrays(1, &VAO)
		gl.GenBuffers(1, &VBO)

		gl.BindVertexArray(VAO)

		gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
		gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), raw_data(vertices), gl.STATIC_DRAW)

		gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, cast(uintptr)0)
		gl.EnableVertexAttribArray(0)

		gl.BindVertexArray(VAO)

		gl.DrawArrays(gl.LINES, 0, cast(i32)len(vertices))

		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
		gl.BindVertexArray(0)

		gl.DeleteVertexArrays(1, &VAO)
		gl.DeleteBuffers(1, &VBO)
	case .Glyf:
		vertices := state.vertex_list[:]
		indices := state.indices_list[:]

		VBO, VAO, EBO: u32
		gl.GenVertexArrays(1, &VAO)
		gl.GenBuffers(1, &VBO)
		gl.GenBuffers(1, &EBO)

		gl.BindVertexArray(VAO)

		gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
		gl.BufferData(
			gl.ARRAY_BUFFER,
			size_of(Point) * len(vertices),
			raw_data(vertices),
			gl.STATIC_DRAW,
		)

		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
		gl.BufferData(
			gl.ELEMENT_ARRAY_BUFFER,
			size_of(u32) * len(indices),
			raw_data(indices),
			gl.STATIC_DRAW,
		)

		gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, cast(uintptr)0)
		gl.EnableVertexAttribArray(0)

		gl.BindVertexArray(VAO)

		gl.DrawElements(gl.LINE_LOOP, cast(i32)len(indices), gl.UNSIGNED_INT, rawptr(uintptr(0)))

		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
		gl.BindVertexArray(0)

		gl.DeleteVertexArrays(1, &VAO)
		gl.DeleteBuffers(1, &VBO)
		gl.DeleteBuffers(1, &EBO)
	}
}

rwb_vertex_2f :: proc(vertex: Point) {
	append(&state.vertex_list, vertex)
}

rwb_indices :: proc(indices: []u32) {
	for index in indices {
		append(&state.indices_list, index)
	}
}

@(private)
normalise_val_0 :: proc(val, min, max: f32) -> f32 {
	return (val - min) / (max - min)
}

@(private)
normalise_val :: proc(val, min, max: f32) -> f32 {
	return (2 * ((val - min) / (max - min))) - 1
}

//Takes bounds and styling arguments and draws a rect to the window.
//{0, 0} = top left

//TODO: Add Point rendering to renderer + also probably line rendering
draw_point :: proc(pos: Point, radius: f32, colour: Colour_RGBA = RED) {
	x := pos.x
	y := pos.y

	rwb_begin(.Point)

	rwb_vertex_2f(
		{normalise_val(x, 0, state.window_width), normalise_val(y, 0, state.window_height)},
	)

	use_shader_program(state.shaders[.Point])
	shader_set_uniform4(state.shaders[.Point], "colour", normalise_colour(colour))
	shader_set_uniform1(state.shaders[.Point], "point_size", radius)

	rwb_end()
}

draw_line :: proc(p0, p1: Point, colour: Colour_RGBA = RED) {
	x_1 := p0.x
	y_1 := p0.y

	x_2 := p1.x
	y_2 := p1.y

	//fmt.println("Draw line called:", "p0:", p0, ", p1:", p1)

	rwb_begin(.Line)

	rwb_vertex_2f(
		{normalise_val(x_1, 0, state.window_width), normalise_val(y_1, 0, state.window_height)},
	)

	rwb_vertex_2f(
		{normalise_val(x_2, 0, state.window_width), normalise_val(y_2, 0, state.window_height)},
	)

	use_shader_program(state.shaders[.Point])
	shader_set_uniform4(state.shaders[.Point], "colour", normalise_colour(colour))

	rwb_end()
}

draw_text :: proc(pos: Point, text: string) {
	for codepoint in text {
		//draw_glyf(pos, codepoint)
		//Do glyf spacing based on font info
	}
}
//need to add sizing
//draw_glyf :: proc(pos: Point, glyf: rune) {
//Direct font rendering, can use the glyf info to render the text given in the Render_Command without faffing with making custom render commands

/*
	- Check glyf cache for full extrapolated point info.
	- If there draw the lines.
	- If not get the glyf info (from some sort of font struct)
	- Calculate the besier curve points
	- Add to the cache
	- Draw.
	*/


//}

draw_glyf :: proc(
	origin: Point,
	points: []Point,
	contour_end_points: []u32,
	radius: f32,
	colour: Colour_RGBA = RED,
) {
	use_shader_program(state.shaders[.Point])
	contour_start: u32 = 0

	for end_index in contour_end_points {
		rwb_begin(.Glyf)

		indices := make([]u32, end_index - contour_start + 1, allocator = context.temp_allocator)
		//SOME MEMORY LEAK HERE WITH THE INDICES ARRAY

		for point, i in points[contour_start:end_index + 1] {
			rwb_vertex_2f(
				{
					normalise_val(origin.x + point.x, 0, state.window_width),
					normalise_val(origin.y + point.y, 0, state.window_height),
				},
			)
			indices[i] = cast(u32)i
		}

		rwb_indices(indices[:])

		delete(indices, allocator = context.temp_allocator)

		shader_set_uniform4(state.shaders[.Point], "colour", normalise_colour(colour))
		shader_set_uniform1(state.shaders[.Point], "point_size", radius)

		rwb_end()
		contour_start = end_index + 1
	}
}

draw_rect :: proc(
	bounds: Rectangle,
	radius: [4]f32 = {0, 0, 0, 0},
	colour: Colour_RGBA = WHITE,
	border_thickness: f32 = 5,
	border_colour: Colour_RGBA = BLACK,
) {
	x := bounds.x
	y := bounds.y
	width := bounds.width
	height := bounds.height

	rwb_begin(.Triangles)

	rwb_vertex_2f(
		{
			normalise_val(x + width, 0, state.window_width),
			normalise_val(y, 0, state.window_height),
		},
	)

	rwb_vertex_2f(
		{
			normalise_val(x + width, 0, state.window_width),
			normalise_val(y + height, 0, state.window_height),
		},
	)

	rwb_vertex_2f(
		{
			normalise_val(x, 0, state.window_width),
			normalise_val(y + height, 0, state.window_height),
		},
	)

	rwb_vertex_2f(
		{normalise_val(x, 0, state.window_width), normalise_val(y, 0, state.window_height)},
	)

	rwb_indices([]u32{0, 1, 3, 1, 2, 3})

	use_shader_program(state.shaders[.Rect])
	shader_set_uniform2(state.shaders[.Rect], "origin", [2]f32{x, y})
	shader_set_uniform2(state.shaders[.Rect], "size", [2]f32{width, height})
	shader_set_uniform4(state.shaders[.Rect], "radius", radius)
	shader_set_uniform4(state.shaders[.Rect], "colour", normalise_colour(colour))
	shader_set_uniform1(state.shaders[.Rect], "border_thickness", border_thickness)
	shader_set_uniform4(state.shaders[.Rect], "border_colour", normalise_colour(border_colour))

	rwb_end()
}
