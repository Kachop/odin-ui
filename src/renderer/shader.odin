package renderer

import "core:fmt"
import "core:os/os2"
import "core:strings"
import "core:unicode/utf8"
import gl "vendor:OpenGL"

Uniform_Val :: union {
	bool,
	i32,
	f32,
}

Uniform_Vals2 :: union {
	[2]bool,
	[2]i32,
	[2]f32,
}

Uniform_Vals3 :: union {
	[3]bool,
	[3]i32,
	[3]f32,
}

Uniform_Vals4 :: union {
	[4]bool,
	[4]i32,
	[4]f32,
}

Shader_Program :: struct {
	id: u32,
}

create_shader_program :: proc(program: Shader, vertex_path, fragment_path: string) {
	vertex_data, vert_err := os2.read_entire_file(vertex_path, context.allocator)
	fragment_data, frag_err := os2.read_entire_file(fragment_path, context.allocator)
	defer delete(vertex_data)
	defer delete(fragment_data)

	if (frag_err == .NONE && vert_err == .NONE) {
		vertex_code := strings.clone_to_cstring(transmute(string)vertex_data)
		fragment_code := strings.clone_to_cstring(transmute(string)fragment_data)

		success: i32
		info_log: [512]u8

		vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
		gl.ShaderSource(vertex_shader, 1, &vertex_code, nil)
		gl.CompileShader(vertex_shader)

		gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)

		if (success != 1) {
			gl.GetShaderInfoLog(vertex_shader, 512, nil, cast([^]u8)&info_log)
			fmt.println(
				"ERROR COMPILING VERTEX SHADER",
				strings.string_from_ptr(cast([^]u8)&info_log, 512),
			)
		}

		fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
		gl.ShaderSource(fragment_shader, 1, &fragment_code, nil)
		gl.CompileShader(fragment_shader)

		gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)

		if (success != 1) {
			gl.GetShaderInfoLog(fragment_shader, 512, nil, cast([^]u8)&info_log)
			fmt.println(
				"ERROR COMPILING FRAGMENT SHADER",
				strings.string_from_ptr(cast([^]u8)&info_log, 512),
			)
		}

		state.shaders[program] = gl.CreateProgram()
		gl.AttachShader(state.shaders[program], vertex_shader)
		gl.AttachShader(state.shaders[program], fragment_shader)
		gl.LinkProgram(state.shaders[program])

		gl.GetProgramiv(state.shaders[program], gl.LINK_STATUS, &success)

		if (success != 1) {
			gl.GetProgramInfoLog(state.shaders[program], 512, nil, cast([^]u8)&info_log)
			fmt.println(
				"ERROR LINKING SHADER PROGRAM",
				strings.string_from_ptr(cast([^]u8)&info_log, 512),
			)
		}

		gl.DeleteShader(vertex_shader)
		gl.DeleteShader(fragment_shader)
	} else {
		fmt.eprintln("ERROR LOADING VERTEX OR FRAGMENT SHADER")
		return
	}
}

use_shader_program :: proc(program_id: u32) {
	gl.UseProgram(program_id)
}

delete_shader_program :: proc(program_id: u32) {
	gl.DeleteProgram(program_id)
}

shader_set_uniform1 :: proc(program_id: u32, name: cstring, value: Uniform_Val) {
	uniform_location := gl.GetUniformLocation(program_id, name)

	switch t in value {
	case bool:
		gl.Uniform1i(uniform_location, i32(value.(bool)))
	case i32:
		gl.Uniform1i(uniform_location, value.(i32))
	case f32:
		gl.Uniform1f(uniform_location, value.(f32))
	}
}

shader_set_uniform2 :: proc(program_id: u32, name: cstring, vals: Uniform_Vals2) {
	uniform_location := gl.GetUniformLocation(program_id, name)

	switch t in vals {
	case [2]bool:
		bools := vals.([2]bool)
		gl.Uniform2i(uniform_location, i32(bools[0]), i32(bools[1]))
	case [2]i32:
		ints := vals.([2]i32)
		gl.Uniform2i(uniform_location, ints[0], ints[1])
	case [2]f32:
		floats := vals.([2]f32)
		gl.Uniform2f(uniform_location, floats[0], floats[1])
	}
}

shader_set_uniform3 :: proc(program_id: u32, name: cstring, vals: Uniform_Vals3) {
	uniform_location := gl.GetUniformLocation(program_id, name)

	switch t in vals {
	case [3]bool:
		bools := vals.([3]bool)
		gl.Uniform3i(uniform_location, i32(bools[0]), i32(bools[1]), i32(bools[2]))
	case [3]i32:
		ints := vals.([3]i32)
		gl.Uniform3i(uniform_location, ints[0], ints[1], ints[2])
	case [3]f32:
		floats := vals.([3]f32)
		gl.Uniform3f(uniform_location, floats[0], floats[1], floats[2])
	}
}

shader_set_uniform4 :: proc(program_id: u32, name: cstring, vals: Uniform_Vals4) {
	uniform_location := gl.GetUniformLocation(program_id, name)

	switch t in vals {
	case [4]bool:
		bools := vals.([4]bool)
		gl.Uniform4i(uniform_location, i32(bools[0]), i32(bools[1]), i32(bools[2]), i32(bools[3]))
	case [4]i32:
		ints := vals.([4]i32)
		gl.Uniform4i(uniform_location, ints[0], ints[1], ints[2], ints[3])
	case [4]f32:
		floats := vals.([4]f32)
		gl.Uniform4f(uniform_location, floats[0], floats[1], floats[2], floats[3])
	}
}
