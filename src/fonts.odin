package rwb

import "core:fmt"
import "fonts"

Font :: fonts.Font

load_font :: proc(filepath: string) -> fonts.TTF_Reader_Error {
	font, error := fonts.ttf_load_font(filepath)

	if error == .None {
		state.font = font
	}
	return error
}

measure_text_width :: proc(text: string) -> f32 {return {}}

measure_text_height :: proc(text: string) -> f32 {return {}}

draw_text :: proc(x, y: f32, text: string) {

	x, y := x, y

	for char in text {
		draw_glyf(&x, &y, char)
	}
}

draw_glyf :: proc(x, y: ^f32, char: rune) {
	glyf_data: ^fonts.Glyf_Data
	if char in state.font.glyf_info {
		glyf_data = &state.font.glyf_info[char]
	} else {
		//Assign missing glyf
		glyf_data = &state.font.glyf_info[rune(65535)]
	}
	if glyf_data.cached {
		append_dynamic_slice(
			&state.non_tree_render_commands,
			render_command(
				.Text,
				{x^, y^, 0, 0},
				ui_ctrl_style(radius = {5, 5, 5, 5}),
				glyf_data.bezier_curve_points,
				glyf_data.bezier_contour_end_pts,
			),
		)
		x^ += glyf_data.spacing
	} else {
		fonts.calculate_curve_points(glyf_data)
		glyf_data.cached = true
		draw_glyf(x, y, char)
	}
}
