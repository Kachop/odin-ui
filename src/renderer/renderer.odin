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
}

Shader :: enum {
	Rect,
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
	window_width:  f32,
	window_height: f32,
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

	create_shader_program(
		.Rect,
		"/mnt/Guido/Development/Odin/RWB-UI/src/renderer/shaders/rec.vs",
		"/mnt/Guido/Development/Odin/RWB-UI/src/renderer/shaders/rec.fs",
	)

	use_shader_program(state.shaders[.Rect])
}

//Start building layout structure
begin_drawing :: proc(window: glfw.WindowHandle) {
	glfw.MakeContextCurrent(window)
	//Update window dimensions, used for normalising the vertex coords.
	state.window_width, state.window_height = platform.get_window_size()
	gl.Clear(gl.COLOR_BUFFER_BIT)
}
//Layout build, figure all the positions out
end_drawing :: proc(window: glfw.WindowHandle) {
	glfw.PollEvents()
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
