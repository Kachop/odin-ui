package renderer

Colour_RGB :: [3]u8
Colour_RGBA :: [4]u8
@(private)
Colour_GL :: [4]f32

WHITE :: Colour_RGBA{255, 255, 255, 255}
BLACK :: Colour_RGBA{0, 0, 0, 255}
RED :: Colour_RGBA{255, 0, 0, 255}
GREEN :: Colour_RGBA{0, 255, 0, 255}
BLUE :: Colour_RGBA{0, 0, 255, 255}

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

@(private)
normalise_colour :: proc(colour: Colour_RGBA) -> Colour_GL {
	return Colour_GL {
		normalise_val_0(cast(f32)colour[0], 0, 255),
		normalise_val_0(cast(f32)colour[1], 0, 255),
		normalise_val_0(cast(f32)colour[2], 0, 255),
		normalise_val_0(cast(f32)colour[3], 0, 255),
	}
}
