package rwb

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
import platform "platform"
import renderer "renderer"

/*
TODO:Potentially add proportional size controlls.
DONE:1.Handle all layout cases
TODO:2.Adjust sizes if there are violations (do simple cases first.) Uses strictness.

Order for adjusting violations.

- look at all children and proportionally reduce the size of anything with a non-1 strictness.
- If all 1 strictness look for .Grow_From_Children, go a level down and shrink that.

NOTE:Ctrls with scrollable flag cannot have violations in the scrolling axis.

If no solution can be found either:
1. Pluck last items from tree and do not display (Can cause issues with functionality.)
2. Make the Ctrl scrollable in that axis.

NOTE:Make this some option set by the user

TODO:3.Figure out hovering

Basic controlls to add:
- Label
- Button
- Toggle button
- Slider (x and y)
- Slider toggle button
- Single-line text input
- Multi-line text input
- Panel
- Window (collapsable)
- Image (includng some imaging tooling)
*/

Rectangle :: renderer.Rectangle

set_window_size_limits :: platform.set_window_size_limits
process_input :: platform.process_input
get_char :: platform.get_char
is_key_pressed :: platform.is_key_pressed
is_key_released :: platform.is_key_released
is_key_up :: platform.is_key_up
is_key_down :: platform.is_key_down

ui_arena: vmem.Arena
frame_arena: vmem.Arena
tree_arena: vmem.Arena
cache_arena: vmem.Arena

ui_alloc: mem.Allocator
frame_alloc: mem.Allocator
tree_alloc: mem.Allocator
cache_alloc: mem.Allocator

UI_Layout_Direction :: enum {
	Left_To_Right,
	Top_To_Bottom,
	Right_To_Left,
	Bottom_To_Top,
}

@(private)
UI_H_Alignment :: enum {
	Left,
	Right,
	Center,
}

@(private)
UI_V_Alignment :: enum {
	Top,
	Bottom,
	Center,
}

@(private)
UI_Alignment :: struct {
	x_align: UI_V_Alignment,
	y_align: UI_H_Alignment,
}

@(private)
Edge_Quantity :: struct {
	l: f32,
	r: f32,
	u: f32,
	d: f32,
}

ui_padding_all :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{value, value, value, value}
}

ui_pading_ud :: proc(up_value, down_value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, 0, up_value, down_value}
}

ui_padding_lr :: proc(left_value, right_value: f32) -> Edge_Quantity {
	return Edge_Quantity{left_value, right_value, 0, 0}
}

ui_padding_l :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{value, 0, 0, 0}
}

ui_padding_r :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, value, 0, 0}
}

ui_padding_u :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, 0, value, 0}
}

ui_padding_d :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, 0, 0, value}
}

ui_padding :: proc(l, r, u, d: f32) -> Edge_Quantity {
	return Edge_Quantity{l, r, u, d}
}

ui_margin_all :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{value, value, value, value}
}

ui_margin_ud :: proc(up_value, down_value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, 0, up_value, down_value}
}

ui_margin_lr :: proc(left_value, right_value: f32) -> Edge_Quantity {
	return Edge_Quantity{left_value, right_value, 0, 0}
}

ui_margin_l :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{value, 0, 0, 0}
}

ui_margin_r :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, value, 0, 0}
}

ui_margin_u :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, 0, value, 0}
}

ui_margin_d :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, 0, 0, value}
}

ui_margin :: proc(l, r, u, d: f32) -> Edge_Quantity {
	return Edge_Quantity{l, r, u, d}
}

ui_border_all :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{value, value, value, value}
}

ui_border_ud :: proc(up_value, down_value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, 0, up_value, down_value}
}

ui_border_lr :: proc(left_value, right_value: f32) -> Edge_Quantity {
	return Edge_Quantity{left_value, right_value, 0, 0}
}

ui_border_l :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{value, 0, 0, 0}
}

ui_border_r :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, value, 0, 0}
}

ui_border_u :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, 0, value, 0}
}

ui_border_d :: proc(value: f32) -> Edge_Quantity {
	return Edge_Quantity{0, 0, 0, value}
}

ui_border :: proc(l, r, u, d: f32) -> Edge_Quantity {
	return Edge_Quantity{l, r, u, d}
}

@(private)
UI_Size_Hint :: enum {
	Grow_To_Parent,
	Pixels,
	Size_From_Text,
	Percentage_Of_Parent,
	Grow_From_Children,
}

@(private)
UI_Size :: struct {
	size_hint:  UI_Size_Hint,
	value:      f32,
	strictness: f32, //sdasds1-1, 1 = no flexibility, 0 = fully resizable.
}

ui_size_grow :: proc() -> UI_Size {
	return UI_Size{.Grow_To_Parent, 0, 0}
}

ui_size_fixed :: proc(value: f32, strictness: f32 = 1) -> UI_Size {
	return UI_Size{.Pixels, value, strictness}
}

ui_size_from_text :: proc() -> UI_Size {
	return UI_Size{.Size_From_Text, 0, 1}
}

ui_size_from_parent :: proc(percentage: f32, strictness: f32 = 1) -> UI_Size {
	return UI_Size{.Percentage_Of_Parent, percentage, strictness}
}

ui_size_from_children :: proc() -> UI_Size {
	return UI_Size{.Grow_From_Children, 0, 1}
}

@(private)
UI_Flags :: enum {
	Focusable, //Hovering
	Pressable,
	Toggleable,
	Selectable,
	Scrollable_Vertical,
	Scrollable_Horizontal,
}

@(private)
UI_Ctrl_Flags :: bit_set[UI_Flags]

UI_Focus_State :: enum {
	Unfocused,
	Focused,
}

UI_Ctrl_State :: enum {
	Default,
	Focused,
	Active,
	Disables,
}

@(private)
UI_Ctrl_State_Flags :: bit_set[UI_Ctrl_State]

ui_colour_rgb :: proc(r, g, b: u8) -> renderer.Colour_RGB {
	return renderer.Colour_RGB{r, g, b}
}

ui_colour_rgba :: proc(r, g, b, a: u8) -> renderer.Colour_RGBA {
	return renderer.Colour_RGBA{r, g, b, a}
}

ui_colour_alpha :: proc {
	ui_colour_alpha_from_rgb,
	ui_colour_alpha_from_rgba,
}

ui_colour_alpha_from_rgb :: proc(colour: renderer.Colour_RGB, alpha: u8) -> renderer.Colour_RGBA {
	return renderer.colour_alpha_from_RGB(colour, alpha)
}

ui_colour_alpha_from_rgba :: proc(
	colour: renderer.Colour_RGBA,
	alpha: u8,
) -> renderer.Colour_RGBA {
	return renderer.colour_alpha_from_RGBA(colour, alpha)
}

UI_Ctrl_Styles :: struct {
	margin:                Edge_Quantity,
	padding:               Edge_Quantity,
	bg_colour:             renderer.Colour_RGBA,
	border_colour:         renderer.Colour_RGBA,
	regular_bg_colour:     renderer.Colour_RGBA,
	regular_border_colour: renderer.Colour_RGBA,
	hovered_bg_colour:     renderer.Colour_RGBA,
	hovered_border_colour: renderer.Colour_RGBA,
	active_bg_colour:      renderer.Colour_RGBA,
	active_border_colour:  renderer.Colour_RGBA,
	border_width:          Edge_Quantity,
	radius:                [4]f32,
	sizing:                [2]UI_Size,
	layout_direction:      UI_Layout_Direction,
	alignment:             UI_Alignment,
	image_data:            []u8,
	text:                  string,
}

ui_ctrl_style :: proc(
	margin: Edge_Quantity = {},
	padding: Edge_Quantity = {},
	regular_bg_colour: renderer.Colour_RGBA = {255, 255, 255, 255},
	regular_border_colour: renderer.Colour_RGBA = {0, 0, 0, 255},
	hovered_bg_colour: renderer.Colour_RGBA = {255, 255, 255, 255},
	hovered_border_colour: renderer.Colour_RGBA = {0, 0, 0, 255},
	active_bg_colour: renderer.Colour_RGBA = {255, 255, 255, 255},
	active_border_colour: renderer.Colour_RGBA = {0, 0, 0, 255},
	border_width: Edge_Quantity = {},
	radius: [4]f32 = {},
	sizing: [2]UI_Size = {},
	layout_direction: UI_Layout_Direction = {},
	alignment: UI_Alignment = {},
	image_data: []u8 = {},
	text: string = "",
) -> UI_Ctrl_Styles {
	return UI_Ctrl_Styles {
		margin,
		padding,
		regular_bg_colour,
		regular_border_colour,
		regular_bg_colour,
		regular_border_colour,
		hovered_bg_colour,
		hovered_border_colour,
		active_bg_colour,
		active_border_colour,
		border_width,
		radius,
		sizing,
		layout_direction,
		alignment,
		image_data,
		text,
	}
}

UI_ID :: struct {
	id_string:    string,
	id_iteration: int,
	id:           string,
}

//Creates an ID based on a string
ui_id :: proc(identifier: string) -> UI_ID {
	context.allocator = frame_alloc
	return UI_ID {
		identifier,
		0,
		transmute(string)hex.encode(hash.hash(hash.Algorithm.SHA512_256, identifier)),
	}
}

//Creates an ID based on a string and a loop iteration
ui_idi :: proc(identifier: string, iteration: int) -> UI_ID {
	context.allocator = frame_alloc
	id_i := fmt.tprint(identifier, iteration, sep = "")
	return UI_ID {
		identifier,
		iteration,
		transmute(string)hex.encode(hash.hash(hash.Algorithm.SHA512_256, id_i)),
	}
}

ui_id_match :: proc(id_a, id_b: UI_ID) -> bool {
	return id_a.id == id_b.id
}

@(private)
UI_Ctrl :: struct {
	//For navigating the ctrl tree rebuilt every frame
	parent:             ^UI_Ctrl,
	child_first:        ^UI_Ctrl,
	child_last:         ^UI_Ctrl,
	sibling_prev:       ^UI_Ctrl,
	sibling_next:       ^UI_Ctrl,

	//For persistent info lookup
	id:                 UI_ID,
	last_frame_touched: u64, //If this is out of date prune the info from the map

	//Position, recalculated every frame
	bounds:             renderer.Rectangle,

	//Ctrl properties
	flags:              UI_Ctrl_Flags,

	//Persistent state
	focus_state:        UI_Focus_State, //If it is hovered or not.
	state_flags:        UI_Ctrl_State_Flags, //State flags, like hovered, active etc.

	//Stuff for scrolling and styling
	scroll_offset_x:    f32,
	scroll_offset_y:    f32,
	styles:             UI_Ctrl_Styles,
}

Render_Type :: enum {
	Rect,
	Text,
	Img,
}

@(private)
Render_Command :: struct {
	type:     Render_Type,
	bounds:   Rectangle,
	style:    UI_Ctrl_Styles,
	vertices: []renderer.Point,
	indices:  []u32,
}

render_command :: proc(
	type: Render_Type,
	bounds: Rectangle,
	style: UI_Ctrl_Styles,
	vertices: []renderer.Point = {},
	indices: []u32 = {},
) -> Render_Command {
	return Render_Command{type, bounds, style, vertices, indices}
}

@(private)
UI_State :: struct {
	window_state:             ^platform.Window_State,
	font:                     Font,
	bg_colour:                renderer.Colour_RGBA,
	rendering:                bool,
	ui_mutex:                 sync.Mutex,
	render_mutex:             sync.Mutex,
	render_thread:            ^thread.Thread,
	root_ctrl:                ^UI_Ctrl,
	parent_ctrl:              ^UI_Ctrl,
	previous_sibling:         ^UI_Ctrl,
	cached_ctrls:             map[string]^UI_Ctrl,
	frame_idx:                u64,
	cursor:                   [2]f32,
	render_commands:          Dynamic_Slice(Render_Command),
	last_render_commands:     Dynamic_Slice(Render_Command),
	non_tree_render_commands: Dynamic_Slice(Render_Command),
}

clear_colour :: proc(colour: renderer.Colour_RGBA) {
	state.bg_colour = colour
}

@(private)
state: UI_State

@(init)
init :: proc "contextless" () {
	context = runtime.default_context()

	arena_err := vmem.arena_init_static(&ui_arena, 100 * mem.Megabyte)
	if arena_err == .None {
		ui_alloc = vmem.arena_allocator(&ui_arena)
	}
	arena_err = vmem.arena_init_static(&frame_arena, 50 * mem.Megabyte)
	if arena_err == .None {
		frame_alloc = vmem.arena_allocator(&frame_arena)
	}
	arena_err = vmem.arena_init_static(&tree_arena, 1 * mem.Megabyte)
	if arena_err == .None {
		tree_alloc = vmem.arena_allocator(&tree_arena)
	}
	arena_err = vmem.arena_init_static(&cache_arena, 5 * mem.Megabyte)
	if arena_err == .None {
		cache_alloc = vmem.arena_allocator(&cache_arena)
	}

	platform.init()
	renderer.init()

	state.cached_ctrls = make(map[string]^UI_Ctrl, 4096, allocator = cache_alloc)
	//platform.state.keys_to_update = make([dynamic]platform.Keyboard_Key, allocator = ui_alloc)
	//platform.state.char_queue = make([dynamic]rune, allocator = tree_alloc)
	state.render_commands = make_dynamic_slice(Render_Command, 4096, allocator = ui_alloc)
	state.last_render_commands = make_dynamic_slice(Render_Command, 4096, allocator = ui_alloc)
	state.non_tree_render_commands = make_dynamic_slice(Render_Command, 4096, allocator = ui_alloc)

	state.render_thread = thread.create(render_proc)
}

create_window :: proc(width, height: i32, title: cstring) -> platform.Window_Error {
	err: platform.Window_Error
	state.window_state, err = platform.create_window(width, height, title)

	renderer.init_context()

	if err != .None {
		fmt.eprint("Failed to create window")
		return err
	}

	//glfw.SetInputMode(state.window, glfw.STICKY_KEYS, 1)

	platform.set_key_callback(platform.key_callback)
	platform.set_char_callback(platform.char_callback)
	platform.set_mouse_button_callback(platform.mouse_button_callback)
	platform.clear_current_context()

	thread.start(state.render_thread)

	return .None
}

close_window :: proc() {
	platform.close_window()
}

render_loop :: proc() -> bool {
	if platform.window_should_close() {
		state.rendering = false
		return false
	}
	//Do stuff here which needs doing every frame
	state.frame_idx += 1

	when ODIN_DEBUG {
		fmt.println(
			"UI Arena | Reserved:",
			ui_arena.total_reserved,
			", Used:",
			ui_arena.total_used,
		)
		fmt.println(
			"Frame Arena | Reserved:",
			frame_arena.total_reserved,
			", Used:",
			frame_arena.total_used,
		)
		fmt.println(
			"Tree Arena | Reserved:",
			tree_arena.total_reserved,
			", Used:",
			tree_arena.total_used,
		)
		fmt.println(
			"Cache Arena | Reserved:",
			cache_arena.total_reserved,
			", Used:",
			cache_arena.total_used,
		)

	}

	return true
}

render_proc :: proc(t: ^thread.Thread) {
	for !platform.window_should_close() {
		if state.rendering {
			//Check if new tree is being built
			sync.lock(&state.render_mutex)
			renderer.begin_drawing(state.window_state.window)
			for command, i in to_slice(&state.last_render_commands) {
				//fmt.println(command.bounds, command.style)
				switch command.type {
				case .Rect:
					//fmt.println("Drawing rect, index:", i, command.bounds)
					renderer.draw_rect(
						command.bounds,
						command.style.radius,
						command.style.bg_colour,
						command.style.border_width.l,
						command.style.border_colour,
					)
				case .Text:
					renderer.draw_glyf(
						{command.bounds.x, command.bounds.y},
						command.vertices,
						command.indices,
						5,
					)
				case .Img:
					fmt.println("Drawing img")
				}
			}

			renderer.end_drawing(state.window_state.window)

			sync.unlock(&state.ui_mutex)
		}
	}
}

prune_cached_ctrls :: proc() {
	for id, ctrl in state.cached_ctrls {
		if ctrl.last_frame_touched != state.frame_idx {
			delete_key(&state.cached_ctrls, id)
			delete(ctrl.id.id, allocator = frame_alloc)
			free(ctrl, allocator = ui_alloc)
		}
	}
}

insert_ctrl_in_tree :: proc(id: UI_ID) -> (^UI_Ctrl, bool) #optional_ok {
	ctrl: ^UI_Ctrl
	cached: bool

	if id.id in state.cached_ctrls {
		ctrl = state.cached_ctrls[id.id]
		cached = true
	} else {
		ctrl = new(UI_Ctrl, allocator = ui_alloc)
		state.cached_ctrls[id.id] = ctrl
		ctrl.id = id
	}

	ctrl.last_frame_touched = state.frame_idx

	if state.root_ctrl == nil {
		state.root_ctrl = ctrl
		state.parent_ctrl = ctrl
		return ctrl, cached
	}

	parent := state.parent_ctrl

	ctrl.parent = nil
	ctrl.child_first = nil
	ctrl.child_last = nil
	ctrl.sibling_prev = nil
	ctrl.sibling_next = nil
	if parent.child_last != nil {
		parent.child_last.sibling_next = ctrl
		ctrl.sibling_prev = parent.child_last
		parent.child_last = ctrl
	} else {
		parent.child_first = ctrl
		parent.child_last = ctrl
	}

	ctrl.parent = parent
	state.parent_ctrl = ctrl
	return ctrl, cached
}

get_parent_ctrl :: proc(id: UI_ID) -> (parent_ctrl: ^UI_Ctrl, ok: bool) #optional_ok {
	root := state.root_ctrl
	current_ctrl := root.child_first
	children_checked: bool
	for {
		if ui_id_match(current_ctrl.id, id) {
			return current_ctrl, true
		}

		if (current_ctrl == root) {
			return nil, false
		}

		if (current_ctrl.child_first != nil) && !children_checked {
			current_ctrl = current_ctrl.child_first
		} else {
			if (current_ctrl.sibling_next != nil) {
				children_checked = false
				current_ctrl = current_ctrl.sibling_next
			} else {
				current_ctrl = current_ctrl.parent
				children_checked = true
			}
		}
	}
}

ui_ctrl_start :: proc(id: UI_ID, flags: UI_Ctrl_Flags, styles: UI_Ctrl_Styles) -> ^UI_Ctrl {
	ctrl, cached := insert_ctrl_in_tree(id)
	if !cached {
		//Only assign stuff if the ctrl wasn't cached
		ctrl.id = id
		ctrl.flags = flags
		ctrl.styles = styles
	}

	return ctrl
}

ui_ctrl_end :: proc() {
	state.previous_sibling = state.parent_ctrl
	if state.parent_ctrl != state.root_ctrl {
		state.parent_ctrl = state.parent_ctrl.parent
	}
}

ui_box_start :: proc(id: UI_ID, styles: UI_Ctrl_Styles) {
	ctrl := ui_ctrl_start(id, {}, styles)
}

ui_box_end :: proc() {
	ui_ctrl_end()
}

ui_button_start :: proc(id: UI_ID, styles: UI_Ctrl_Styles) -> ^UI_Ctrl {
	ctrl := ui_ctrl_start(id, {.Focusable, .Pressable}, styles)
	return ctrl
}

ui_button_end :: proc() {
	ui_ctrl_end()
}

ui_toggle_button_start :: proc(id: UI_ID, styles: UI_Ctrl_Styles) -> ^UI_Ctrl {
	ctrl := ui_ctrl_start(id, {.Focusable, .Toggleable}, styles)
	return ctrl
}

ui_toggle_button_end :: proc() {
	ui_ctrl_end()
}

ui_handle_tree_layout :: proc(ctrl: ^UI_Ctrl) {
	to_layout := make_dynamic_slice(^UI_Ctrl, 4096, allocator = frame_alloc)
	ctrl := ctrl
	for ctrl.sibling_next != nil {
		append_dynamic_slice(&to_layout, ctrl)
		ctrl = ctrl.sibling_next
	}
	append_dynamic_slice(&to_layout, ctrl)

	ui_get_ctrl_bounds(to_layout)

	for ctrl in to_slice(&to_layout) {
		append_dynamic_slice(
			&state.render_commands,
			render_command(.Rect, ctrl.bounds, ctrl.styles),
		)

		if (.Focusable in ctrl.flags) {
			if (state.window_state.mouse_pos.x > cast(f64)ctrl.bounds.x) &&
			   (state.window_state.mouse_pos.x < cast(f64)(ctrl.bounds.x + ctrl.bounds.width)) &&
			   (state.window_state.mouse_pos.y > cast(f64)ctrl.bounds.y) &&
			   (state.window_state.mouse_pos.y < cast(f64)(ctrl.bounds.y + ctrl.bounds.height)) {
				ctrl.focus_state = .Focused
				ctrl.styles.bg_colour = ctrl.styles.hovered_bg_colour
				ctrl.styles.border_colour = ctrl.styles.hovered_border_colour
			} else {
				ctrl.focus_state = .Unfocused
				ctrl.styles.bg_colour = ctrl.styles.regular_bg_colour
				ctrl.styles.border_colour = ctrl.styles.regular_border_colour
			}
		}

		if (.Toggleable in ctrl.flags) {
			if (.Active in ctrl.state_flags) {
				ctrl.styles.bg_colour = ctrl.styles.active_bg_colour
				ctrl.styles.border_colour = ctrl.styles.active_border_colour
			} else {
				ctrl.styles.bg_colour = ctrl.styles.regular_bg_colour
				ctrl.styles.border_colour = ctrl.styles.regular_border_colour
			}
		}

		if ctrl.styles.text != "" {
			//Figure out stuff to do with rendering text, deciding if .Rect or .Text commands should be issued.
		}
		if ctrl.child_first != nil {
			ui_handle_tree_layout(ctrl.child_first)
		}
	}
	//add anything here to render on top of layout
	for command, i in to_slice(&state.non_tree_render_commands) {
		append_dynamic_slice(&state.render_commands, command)
	}
}

ui_get_ctrl_bounds :: proc(ctrls: Dynamic_Slice(^UI_Ctrl)) {
	//TODO: Figure out if a container needs to be scrollable.
	//		If the children cannot be fit in make the parent scrollable.
	//		For already scrollable containers, calculate the bounds normally, and
	//		When displaying the container it should do a scissor and use the ctrls 
	//		Scroll properties to figure out what to render.
	ctrls := ctrls
	window_width, window_height :=
		state.window_state.window_width, state.window_state.window_height
	layout_direction: UI_Layout_Direction

	parent_bounds: Rectangle
	parent_padding: Edge_Quantity

	violation_checking := true

	if get(ctrls, 0).parent != nil {
		parent_bounds = get(ctrls, 0).parent.bounds
		parent_padding = get(ctrls, 0).parent.styles.padding

		layout_direction = get(ctrls, 0).parent.styles.layout_direction

		state.cursor = {parent_bounds.x + parent_padding.l, parent_bounds.y + parent_padding.u}
	} else {
		parent_bounds = {0, 0, window_width, window_height}
		state.cursor = {0, 0}
		violation_checking = false
	}

	immediate_list := make_dynamic_slice(^UI_Ctrl, 4096, allocator = frame_alloc)
	deferred_list := make_dynamic_slice(^UI_Ctrl, 4096, allocator = frame_alloc) //List for .Grow elements so their size can be calculated last

	available_width := parent_bounds.width - parent_padding.l - parent_padding.r
	available_height := parent_bounds.height - parent_padding.u - parent_padding.d

	for ctrl in to_slice(&ctrls) {
		switch layout_direction {
		case .Left_To_Right, .Right_To_Left:
			available_width -= (ctrl.styles.margin.l + ctrl.styles.margin.r)
		case .Top_To_Bottom, .Bottom_To_Top:
			available_height -= (ctrl.styles.margin.u + ctrl.styles.margin.d)
		}
	}

	current_available_width := available_width
	current_available_height := available_height

	for ctrl in to_slice(&ctrls) {
		size_hint: UI_Size_Hint

		switch layout_direction {
		case .Left_To_Right, .Right_To_Left:
			size_hint = ctrl.styles.sizing.x.size_hint
		case .Top_To_Bottom, .Bottom_To_Top:
			size_hint = ctrl.styles.sizing.y.size_hint
		}

		if size_hint == .Grow_To_Parent {
			append_dynamic_slice(&deferred_list, ctrl)
		} else {
			append_dynamic_slice(&immediate_list, ctrl)
		}
	}

	for ctrl in to_slice(&immediate_list) {
		calc_ctrl_size(
			ctrl,
			available_width,
			available_height,
			&current_available_width,
			&current_available_height,
			cast(f32)dynamic_slice_len(deferred_list),
		)
	}

	for ctrl in to_slice(&deferred_list) {
		calc_ctrl_size(
			ctrl,
			available_width,
			available_height,
			&current_available_width,
			&current_available_height,
			cast(f32)dynamic_slice_len(deferred_list),
		)
	}

	clear_dynamic_slice(&immediate_list)
	clear_dynamic_slice(&deferred_list)

	for ctrl in to_slice(&ctrls) {
		calc_ctrl_pos(ctrl)
	}

	//Use position and size info, along with layout direction to figure out and fix any overspill issues. (Proportionally shrink what you can)

	//Check for size violations
	total_overspill: [2]f32
	flexible_x_ctrls := make_dynamic_slice(^UI_Ctrl, 4096, allocator = frame_alloc) //Number of non-1 strictness x ctrls.
	static_x_ctrls := make_dynamic_slice(^UI_Ctrl, 4096, allocator = frame_alloc)
	flexible_y_ctrls := make_dynamic_slice(^UI_Ctrl, 4096, allocator = frame_alloc) //Number of non-1 strictness y ctrls.
	static_y_ctrls := make_dynamic_slice(^UI_Ctrl, 4096, allocator = frame_alloc)

	if violation_checking {
		for ctrl in to_slice(&ctrls) {
			//In case there are violations these ctrls can be resized easily to try fix the issues
			if ctrl.bounds.width > 0 {
				if ctrl.styles.sizing.x.strictness < 1 {
					append_dynamic_slice(&flexible_x_ctrls, ctrl)
				} else {
					append_dynamic_slice(&static_x_ctrls, ctrl)
				}

				if ctrl.bounds.x < ctrl.parent.bounds.x + ctrl.parent.styles.padding.l {
					//Overspilling to the left
					total_overspill.x =
						(ctrl.parent.bounds.x + ctrl.parent.styles.padding.l - ctrl.bounds.x)
				}

				if ctrl.bounds.x + ctrl.bounds.width + ctrl.styles.margin.r >
				   ctrl.parent.bounds.x + ctrl.parent.bounds.width - ctrl.parent.styles.padding.r {
					//Overspill to the right
					total_overspill.x =
						((ctrl.bounds.x + ctrl.bounds.width + ctrl.styles.margin.r) -
							(ctrl.parent.bounds.x +
									ctrl.parent.bounds.width -
									ctrl.parent.styles.padding.r))
				}
			}

			if ctrl.bounds.height > 0 {
				if ctrl.styles.sizing.y.strictness < 1 {
					append_dynamic_slice(&flexible_y_ctrls, ctrl)
				} else {
					append_dynamic_slice(&static_y_ctrls, ctrl)
				}

				if ctrl.bounds.y < ctrl.parent.bounds.y + ctrl.parent.styles.padding.u {
					//Overspill above
					total_overspill.y =
						(ctrl.parent.bounds.y + ctrl.parent.styles.padding.u - ctrl.bounds.y)
				}

				if ctrl.bounds.y + ctrl.bounds.height + ctrl.styles.margin.d >
				   ctrl.parent.bounds.y +
					   ctrl.parent.bounds.height -
					   ctrl.parent.styles.padding.d {
					//Overspill below
					total_overspill.y =
						((ctrl.bounds.y + ctrl.bounds.height + ctrl.parent.styles.margin.d) -
							(ctrl.parent.bounds.y +
									ctrl.parent.bounds.height -
									ctrl.parent.styles.padding.d))
				}
			}
		}
	}

	if total_overspill.x > 0 {
		//fmt.println("x overspill in", ctrls.data[0].parent.id.id_string, "by", total_overspill.x)
		//Check if any of the controls have non-1 strictness.
		//If so reduce all of their sizes proportionally to remove the overspill.
		if dynamic_slice_len(flexible_x_ctrls) > 0 {
			denominator: f32
			//fmt.println("flexible controls:", dynamic_slice_len(flexible_x_ctrls))
			for ctrl in to_slice(&flexible_x_ctrls) {
				denominator += (1 - ctrl.styles.sizing.x.strictness) * ctrl.bounds.width
				//fmt.println(ctrl.id.id_string, "width:", ctrl.bounds.width)
			}

			//fmt.println("denominator:", denominator)

			proportion := total_overspill.x / denominator
			//fmt.println("Proportion:", proportion)

			for ctrl in to_slice(&flexible_x_ctrls) {
				ctrl.bounds.width /= ((1 - ctrl.styles.sizing.x.strictness) * proportion)
			}
		}

		//Check if there's still an overspill, if so force all controls to shrink.
		total_overspill.x = 0
		//topological_sort
		for ctrl in to_slice(&ctrls) {
			if ctrl.bounds.x > 0 {
				if ctrl.bounds.x < ctrl.parent.bounds.x + ctrl.parent.styles.padding.l {
					//Overspilling to the left
					total_overspill.x +=
						(ctrl.parent.bounds.x + ctrl.parent.styles.padding.l - ctrl.bounds.x)
				}

				if ctrl.bounds.x + ctrl.bounds.width + ctrl.styles.margin.r >
				   ctrl.parent.bounds.x + ctrl.parent.bounds.width - ctrl.parent.styles.padding.r {
					//Overspill to the right
					total_overspill.x =
						((ctrl.bounds.x + ctrl.bounds.width + ctrl.styles.margin.r) -
							(ctrl.parent.bounds.x +
									ctrl.parent.bounds.width -
									ctrl.parent.styles.padding.r))
				}
			}
		}

		if total_overspill.x > 0 {
			//Still and overspill, reduce everything.
			//fmt.println("Still an overspill of:", total_overspill.x)

			total_width: f32
			for ctrl in to_slice(&ctrls) {
				if (ctrl.bounds.width > 0) {
					total_width += ctrl.bounds.width + ctrl.styles.margin.l + ctrl.styles.margin.r
				}
			}

			percentage: f32
			for ctrl in to_slice(&ctrls) {
				if ctrl.bounds.width > 0 {
					percentage = ctrl.bounds.width / total_width
					ctrl.bounds.width -= total_overspill.x * percentage
					//fmt.println(ctrl.id.id_string, "percentage:", percentage)
				}
			}
		}
	}

	if total_overspill.y > 0 {
		//fmt.println("y overspill in", ctrls.data[0].parent.id.id_string, "by", total_overspill.y)
		//If so reduce all of their sizes proportionally to remove the overspill.
		if dynamic_slice_len(flexible_y_ctrls) > 0 {
			denominator: f32
			for ctrl in to_slice(&flexible_y_ctrls) {
				denominator += (1 - ctrl.styles.sizing.y.strictness) * ctrl.bounds.height
			}

			proportion := total_overspill.y / denominator

			if proportion > 1 {
				proportion = 1
				//Needs to redude the size of the ctrls more than possible.
				//Need to do more than just reduce non-strict ctrls.
			}
			//fmt.println("propotion:", proportion)

			for ctrl in to_slice(&flexible_y_ctrls) {
				//fmt.println(ctrl.id.id_string, ctrl.bounds.height)
				ctrl.bounds.height -=
					((1 - ctrl.styles.sizing.y.strictness) * proportion * ctrl.bounds.height)
				//fmt.println(ctrl.id.id_string, ctrl.bounds.height)
			}
		} else {
			//No flexible ctrls. Either force smaller or add scrolling.
		}
	}

	if total_overspill.x > 0 || total_overspill.y > 0 {
		state.cursor = {parent_bounds.x + parent_padding.l, parent_bounds.y + parent_padding.u}
		for ctrl in to_slice(&ctrls) {
			calc_ctrl_pos(ctrl)
		}
	}
	//REDO position calculations
}

calc_ctrl_size :: proc(
	ctrl: ^UI_Ctrl,
	tot_available_width, tot_available_height: f32,
	curr_available_width, curr_available_height: ^f32,
	no_of_growers: f32,
) {
	layout_direction: UI_Layout_Direction

	if ctrl.parent != nil {
		layout_direction = ctrl.parent.styles.layout_direction
	}

	switch layout_direction {
	case .Left_To_Right, .Right_To_Left:
		//Calculate all widths, then go in order of controls to calculate x positions.	
		switch ctrl.styles.sizing.x.size_hint {
		//Immediate cases
		case .Percentage_Of_Parent:
			ctrl.bounds.width = tot_available_width * ctrl.styles.sizing.x.value
			curr_available_width^ -= ctrl.bounds.width
		case .Pixels:
			ctrl.bounds.width = ctrl.styles.sizing.x.value
			curr_available_width^ -= ctrl.bounds.width
		case .Size_From_Text:
			ctrl.bounds.width = measure_text_width(ctrl.styles.text)
			curr_available_width^ -= ctrl.bounds.width
		//Deferred cases	
		case .Grow_To_Parent:
			//Grow_To_Parent containers will not be rendered if there is no room.
			ctrl.bounds.width = curr_available_width^ / no_of_growers
		case .Grow_From_Children:
			ctrl.bounds.width = calc_children_width(ctrl)
			curr_available_width^ -= ctrl.bounds.width
		}

		switch ctrl.styles.sizing.y.size_hint {
		//Immediate cases
		case .Percentage_Of_Parent:
			ctrl.bounds.height = tot_available_height * ctrl.styles.sizing.y.value
		case .Pixels:
			ctrl.bounds.height = ctrl.styles.sizing.y.value
		case .Size_From_Text:
			ctrl.bounds.width = measure_text_height(ctrl.styles.text)
		//Deferred cases	
		case .Grow_To_Parent:
			ctrl.bounds.height = tot_available_height - ctrl.styles.margin.u - ctrl.styles.margin.d
		case .Grow_From_Children:
			ctrl.bounds.height = calc_children_height(ctrl)
		}

		if (curr_available_width^ < 0) {
			curr_available_width^ = 0
		}

	case .Top_To_Bottom, .Bottom_To_Top:
		//Calculate all widths, then go in order of controls to calculate x positions.	
		switch ctrl.styles.sizing.y.size_hint {
		//Immediate cases
		case .Percentage_Of_Parent:
			ctrl.bounds.height = tot_available_height * ctrl.styles.sizing.y.value
			curr_available_height^ -= ctrl.bounds.height
		case .Pixels:
			ctrl.bounds.height = ctrl.styles.sizing.y.value
			curr_available_height^ -= ctrl.bounds.height
		case .Size_From_Text:
			ctrl.bounds.width = measure_text_width(ctrl.styles.text)
			curr_available_height^ -= ctrl.bounds.height
		//Deferred cases
		case .Grow_To_Parent:
			ctrl.bounds.height = curr_available_height^ / no_of_growers
		case .Grow_From_Children:
			ctrl.bounds.height = calc_children_height(ctrl)
			curr_available_height^ -= ctrl.bounds.height
		}

		if (curr_available_height^ < 0) {
			curr_available_height^ = 0
		}

		switch ctrl.styles.sizing.x.size_hint {
		//Immediate cases
		case .Percentage_Of_Parent:
			ctrl.bounds.width = tot_available_width * ctrl.styles.sizing.x.value
		case .Pixels:
			ctrl.bounds.width = ctrl.styles.sizing.x.value
		case .Size_From_Text:
			ctrl.bounds.width = measure_text_height(ctrl.styles.text)
		//Deferred cases
		case .Grow_To_Parent:
			ctrl.bounds.width = tot_available_width - ctrl.styles.margin.l - ctrl.styles.margin.r
		case .Grow_From_Children:
			ctrl.bounds.width = calc_children_width(ctrl)
		}
	}
}

calc_ctrl_pos :: proc(ctrl: ^UI_Ctrl) {
	window_width, window_height := platform.get_window_size()
	layout_direction: UI_Layout_Direction

	parent_bounds: Rectangle
	parent_padding: Edge_Quantity

	if ctrl.parent != nil {
		layout_direction = ctrl.parent.styles.layout_direction
		parent_bounds = ctrl.parent.bounds
		parent_padding = ctrl.parent.styles.padding
	}

	switch layout_direction {
	case .Left_To_Right:
		ctrl.bounds.x = state.cursor.x + ctrl.styles.margin.l
		ctrl.bounds.y = state.cursor.y + ctrl.styles.margin.u

		state.cursor.x += ctrl.bounds.width + ctrl.styles.margin.l + ctrl.styles.margin.r
	case .Right_To_Left:
		state.cursor.x = parent_bounds.x + parent_bounds.width - parent_padding.r
		ctrl.bounds.x = state.cursor.x - ctrl.bounds.width - ctrl.styles.margin.r
		ctrl.bounds.y = window_height - state.cursor.y - ctrl.bounds.height - ctrl.styles.margin.u

		state.cursor.x -= (ctrl.bounds.width + ctrl.styles.margin.l + ctrl.styles.margin.r)
	case .Top_To_Bottom:
		ctrl.bounds.x = state.cursor.x + ctrl.styles.margin.l
		ctrl.bounds.y = state.cursor.y + ctrl.styles.margin.u

		state.cursor.y += ctrl.bounds.height + ctrl.styles.margin.u + ctrl.styles.margin.d
	case .Bottom_To_Top:
		state.cursor.y = parent_bounds.y + parent_bounds.height - parent_padding.d
		ctrl.bounds.x = state.cursor.x + ctrl.styles.margin.l
		ctrl.bounds.y = state.cursor.y + ctrl.styles.margin.d

		state.cursor.y -= (ctrl.bounds.height + ctrl.styles.margin.u + ctrl.styles.margin.d)
	}
}

//Calculate the combined size of all the children of a ctrl.
//Will ignore if child has .Grow_To_Parent and .Percent_Of_Parent constraint. (Nothing to grow into).
//If any of the children also have .Grow_From_Children will go a level deeper.
calc_children_width :: proc(ctrl: ^UI_Ctrl) -> f32 {
	child: ^UI_Ctrl
	total_size: f32

	if ctrl.child_first != nil {
		child = ctrl.child_first
	} else {
		return 0
	}

	total_size += child.parent.styles.padding.l + child.parent.styles.padding.r

	for child != nil {
		switch child.styles.sizing.x.size_hint {
		case .Pixels:
			total_size += child.styles.sizing.x.value + child.styles.margin.l
		case .Size_From_Text:
			total_size += measure_text_width(child.styles.text)
		case .Grow_From_Children:
			total_size += calc_children_width(ctrl)
		//Issuse cases, size of parent is unkown.
		case .Grow_To_Parent, .Percentage_Of_Parent:
			fmt.eprintln(
				"Invalid sizing used in: ",
				ctrl.parent.id.id_string,
				". Children need to know the size of the parent",
				sep = "",
			)
		}
		total_size += child.styles.margin.l + child.styles.margin.r

		child = child.sibling_next
	}
	return total_size
}

calc_children_height :: proc(ctrl: ^UI_Ctrl) -> f32 {
	child: ^UI_Ctrl
	total_size: f32

	if ctrl.child_first != nil {
		child = ctrl.child_first
	} else {
		return 0
	}

	total_size += child.parent.styles.padding.u + child.parent.styles.padding.d

	for child != nil {
		switch child.styles.sizing.y.size_hint {
		case .Pixels:
			total_size += child.styles.sizing.y.value
		case .Size_From_Text:
			total_size += measure_text_height(child.styles.text)
		case .Grow_From_Children:
			total_size += calc_children_height(ctrl)
		//Issuse cases, size of parent is unkown.
		case .Grow_To_Parent, .Percentage_Of_Parent:
			fmt.eprintln(
				"Invalid sizing used in: ",
				ctrl.parent.id.id_string,
				". Children need to know the size of the parent",
				sep = "",
			)
		}
		total_size += child.styles.margin.u + child.styles.margin.d

		child = child.sibling_next
	}

	return total_size
}

ui_begin :: proc() {
	//Deal with user input
	//Traverse the frame from the previous frame to figure out what the mouse is pointing at.
	vmem.arena_free_all(&tree_arena) //Clear tree ready for building new one	
	state.root_ctrl = nil
	state.parent_ctrl = nil

	ui_box_start(ui_id("Main container"), ui_ctrl_style(regular_bg_colour = state.bg_colour))
}

ui_end :: proc() {
	ui_box_end()

	vmem.arena_free_all(&frame_arena)

	process_input()

	ctrl := state.root_ctrl

	state.parent_ctrl = ctrl

	if ctrl != nil {
		ui_handle_tree_layout(ctrl)

		prune_cached_ctrls()
	}

	sync.lock(&state.ui_mutex)

	clear_dynamic_slice(&state.last_render_commands)
	dynamic_slice_copy(&state.last_render_commands, &state.render_commands)

	clear_dynamic_slice(&state.render_commands)
	clear_dynamic_slice(&state.non_tree_render_commands)

	sync.unlock(&state.render_mutex)

	if !state.rendering {
		state.rendering = true
	}
}
