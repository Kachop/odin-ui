#+feature global-context

package main

import rwb "../src/"
import "core:fmt"
import vmem "core:mem/virtual"
import "core:sync"
import "core:sys/info"
import "core:time"

side_bar := rwb.UI_Ctrl_Styles {
	margin           = rwb.ui_margin_all(16),
	padding          = rwb.ui_padding_all(16),
	bg_colour        = rwb.ui_colour_rgba(224, 215, 210, 255),
	sizing           = {rwb.ui_size_fixed(300), rwb.ui_size_grow()},
	layout_direction = .Top_To_Bottom,
}

profile_picture := rwb.UI_Ctrl_Styles {
	bg_colour = rwb.ui_colour_rgba(168, 66, 28, 255),
	sizing    = {rwb.ui_size_grow(), rwb.ui_size_fixed(70, 0.1)},
}

side_bar_component := rwb.ui_ctrl_style(
	margin = rwb.ui_margin_u(16),
	regular_bg_colour = {225, 138, 50, 255},
	hovered_bg_colour = {138, 255, 50, 255},
	regular_border_colour = {0, 0, 0, 255},
	border_width = {5, 5, 5, 5},
	sizing = {rwb.ui_size_grow(), rwb.ui_size_fixed(50, 0.8)},
	radius = {10, 10, 10, 10},
)

main_content := rwb.UI_Ctrl_Styles {
	margin    = {0, 16, 16, 16},
	padding   = {16, 16, 16, 16},
	bg_colour = rwb.ui_colour_rgba(224, 215, 210, 255),
	sizing    = {rwb.ui_size_grow(), rwb.ui_size_grow()},
}

btn_style1 := rwb.UI_Ctrl_Styles {
	margin        = {10, 10, 10, 10},
	padding       = {0, 0, 0, 0},
	bg_colour     = rwb.ui_colour_rgba(130, 130, 130, 255),
	border_colour = rwb.ui_colour_rgba(255, 255, 255, 255),
	radius        = {10, 0, 0, 10},
	sizing        = {rwb.ui_size_from_parent(0.4), rwb.ui_size_fixed(50)},
}

btn_style2 := rwb.UI_Ctrl_Styles {
	margin        = {10, 10, 10, 10},
	padding       = {0, 0, 0, 0},
	bg_colour     = rwb.ui_colour_rgba(255, 0, 0, 255),
	border_colour = rwb.ui_colour_rgba(255, 255, 255, 255),
	radius        = {0, 0, 0, 0},
	sizing        = {rwb.ui_size_from_parent(0.4), rwb.ui_size_from_parent(0.5)},
}

left_box_style := rwb.UI_Ctrl_Styles {
	margin        = {50, 50, 50, 50},
	padding       = {30, 30, 30, 30},
	bg_colour     = rwb.ui_colour_rgba(0, 0, 140, 0),
	border_colour = rwb.ui_colour_rgba(0, 0, 0, 255),
	border_width  = {5, 5, 5, 5},
	radius        = {50, 50, 50, 50},
	sizing        = {rwb.ui_size_grow(), rwb.ui_size_grow()},
}

right_box_style := rwb.UI_Ctrl_Styles {
	margin           = {50, 50, 50, 50},
	padding          = {30, 30, 30, 30},
	bg_colour        = rwb.ui_colour_rgba(0, 0, 140, 0),
	border_colour    = rwb.ui_colour_rgba(0, 0, 0, 255),
	border_width     = {5, 5, 5, 5},
	layout_direction = .Top_To_Bottom,
	radius           = {50, 50, 50, 50},
	sizing           = {rwb.ui_size_grow(), rwb.ui_size_grow()},
}

test_button :: proc(id: rwb.UI_ID) {
	rwb.ui_button_start(
		id,
		rwb.ui_ctrl_style(
			padding = rwb.ui_padding_all(5),
			margin = rwb.ui_margin_r(10),
			regular_bg_colour = rwb.ui_colour_rgba(200, 60, 70, 255),
			sizing = {rwb.ui_size_from_children(), rwb.ui_size_fixed(50)},
		),
	)

	rwb.ui_box_start(
		rwb.ui_id(fmt.tprint(id.id_string, "black box")),
		rwb.ui_ctrl_style(
			regular_bg_colour = {0, 0, 0, 255},
			margin = rwb.ui_margin_r(5),
			radius = {5, 5, 5, 5},
			sizing = {rwb.ui_size_fixed(100), rwb.ui_size_grow()},
		),
	)
	rwb.ui_box_end()

	rwb.ui_box_start(
		rwb.ui_id(fmt.tprint(id.id_string, "grey box")),
		rwb.ui_ctrl_style(
			regular_bg_colour = {150, 150, 150, 255},
			sizing = {rwb.ui_size_fixed(200), rwb.ui_size_grow()},
		),
	)

	rwb.ui_box_end()
	rwb.ui_button_end()
}

main_box := rwb.UI_Ctrl_Styles {
	sizing = {rwb.ui_size_grow(), rwb.ui_size_grow()},
}

gui_button :: proc(id: rwb.UI_ID, style: rwb.UI_Ctrl_Styles) -> bool {
	focus_state := rwb.ui_button_start(id, style).focus_state
	rwb.ui_button_end()

	return false
}

main :: proc() {
	context.allocator = rwb.ui_alloc
	context.temp_allocator = rwb.frame_alloc
	//Boilerplater setup

	rwb.load_font(
		"/home/robert/Development/odin/odin-ui/src/fonts/paul-font/paul_font.ttf", //"/mnt/Guido/Development/Odin/odin-ui/src/fonts/Paul/Paul.ttf",//"/mnt/Guido/Development/Odin/odin-ui/src/fonts/paul-font/paul_font.ttf",
	)

	err := rwb.create_window(800, 600, "Example")

	if err != .None {
		fmt.eprintln("Error creating window")
		return
	}

	rwb.set_window_size_limits(800, 600, 1920, 1080)

	frame: f64

	timer: time.Stopwatch
	time.stopwatch_start(&timer)

	for rwb.render_loop() {
		rwb.clear_colour(rwb.ui_colour_rgba(250, 250, 250, 255))

		rwb.ui_begin()
		///*
		{

			for char, ok := rwb.get_char(); ok; char, ok = rwb.get_char() {
				fmt.print(char)
			}
			if rwb.is_key_pressed(.Enter) {
				fmt.print('\n')
			}
			if rwb.is_key_down(.Enter) {
				fmt.println("Enter down")
			}
			if rwb.is_key_released(.Enter) {
				fmt.println("Enter released")
			}

			rwb.ui_box_start(rwb.ui_id("Side bar"), side_bar)

			rwb.ui_box_start(rwb.ui_id("Profile pic"), profile_picture)
			rwb.ui_box_end()

			for i in 0 ..< 7 {
				rwb.ui_box_start(rwb.ui_idi("Side bar component", i), side_bar_component)
				rwb.ui_box_end()
			}

			rwb.ui_button(rwb.ui_id("Test button"), side_bar_component)

			rwb.ui_toggle_button(rwb.ui_id("Test2 button"), side_bar_component)

			rwb.ui_box_end()

			rwb.ui_box_start(rwb.ui_id("Main content"), main_content)

			test_button(rwb.ui_id("Test button1"))
			test_button(rwb.ui_id("Test button2"))
			test_button(rwb.ui_id("Test button3"))
			//test_button(rwb.ui_id("Test button4"))
			//test_button(rwb.ui_id("Test button5"))

			rwb.ui_box_start(rwb.ui_id("gm"), side_bar_component)
			rwb.ui_box_end()

			rwb.ui_box_end()


			//rwb.ui_box_start(rwb.ui_id("Main box 1"), profile_picture)
			//rwb.ui_box_end()

			//rwb.ui_box_start(rwb.ui_id("Main box 2"), side_bar_component)
			//rwb.ui_box_end()

			rwb.ui_box_end()

			fmt.println("fps:", frame / time.duration_seconds(time.stopwatch_duration(timer)))

			//rwb.draw_point(400, 300, 5)

			rwb.draw_glyf(400, 300, 'H')
			rwb.draw_glyf(450, 300, 'a')
			rwb.draw_glyf(490, 300, 'b')
			rwb.draw_glyf(550, 300, 'g')
			rwb.draw_glyf(600, 300, 'o')
			rwb.draw_glyf(650, 300, 'o')
			rwb.draw_glyf(700, 300, 'd')
			//rwb.draw_glyf(450, 400, 'C')
			//rwb.draw_glyf(700, 400, 'D')

			frame += 1
		}
		//*/
		/*
		fmt.println(rwb.is_key_pressed(.A))
		*/

		rwb.ui_end()

	}


	rwb.close_window()
}
