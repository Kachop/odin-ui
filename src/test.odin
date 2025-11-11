package test

import "base:runtime"
import "core:c"
import "core:crypto/hash"
import "core:encoding/hex"
import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import "core:slice"
import "core:sync"
import "core:thread"
import gl "vendor:OpenGL"
import "vendor:glfw"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 6

window_should_close: bool

Colour_RGB :: distinct [3]u8
Colour_RGBA :: distinct [4]u8
@(private)
Colour_GL :: distinct [4]f32

colour_alpha :: proc {
	colour_alpha_from_RGB,
	colour_alpha_from_RGBA,
}

colour_alpha_from_RGB :: proc(colour: Colour_RGB, alpha: u8) -> Colour_RGBA {
	return Colour_RGBA{colour[0], colour[1], colour[2], alpha}
}

colour_alpha_from_RGBA :: proc(colour: Colour_RGBA, alpha: u8) -> Colour_RGBA {
	return Colour_RGBA{colour[0], colour[1], colour[2], alpha}
}

normalise_val_0 :: proc(val, max: f32) -> f32 {
	return val / max
}

normalise_val :: proc(val, min, max: f32) -> f32 {
	return (2 * ((val - min) / (max - min))) - 1
}

normalise_colour :: proc(colour: Colour_RGBA) -> Colour_GL {
	return Colour_GL {
		normalise_val_0(cast(f32)colour[0], 255),
		normalise_val_0(cast(f32)colour[1], 255),
		normalise_val_0(cast(f32)colour[2], 255),
		normalise_val_0(cast(f32)colour[3], 255),
	}
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
