package platform
//All code related to opening and managing a window using GLFW.
//All user input stuff and callbacks too.
//Will eventually have platform specific stuff.

import "base:runtime"
import "core:fmt"
import gl "vendor:OpenGL"
import "vendor:glfw"

Window_Error :: enum {
	None,
	Create_Error,
}

Window_State :: struct {
	initialised:    bool,
	window:         glfw.WindowHandle,
	window_width:   f32,
	window_height:  f32,
	keys_to_update: [dynamic]Keyboard_Key,
	char_queue:     [dynamic]rune,
	key_states:     map[Keyboard_Key]Button_State,
}

@(private)
state: Window_State

error_callback :: proc "c" (code: i32, desc: cstring) {
	context = runtime.default_context()

	fmt.eprintln("Error:", code, desc)
}

init :: proc() -> bool {
	//Do any sort of platform specific stuff here
	//Fixes min size constraints on Hyprland.
	state.initialised = true
	state.keys_to_update = make([dynamic]Keyboard_Key, context.allocator)
	state.char_queue = make([dynamic]rune, context.allocator)

	state.key_states = make(map[Keyboard_Key]Button_State, context.allocator)

	glfw.InitHint(glfw.WAYLAND_LIBDECOR, glfw.WAYLAND_DISABLE_LIBDECOR)

	glfw.SetErrorCallback(error_callback)

	return cast(bool)glfw.Init()
}

set_window_hint :: proc {
	set_window_hint_int,
	set_window_hint_bool,
}

set_window_hint_int :: proc(hint, value: i32) {
	glfw.WindowHint(hint, value)
}

set_window_hint_bool :: proc(hint: i32, value: bool) {
	glfw.WindowHint(hint, cast(b32)value)
}

create_window :: proc(width, height: i32, title: cstring) -> (^Window_State, Window_Error) {
	state.window = glfw.CreateWindow(width, height, title, nil, nil)
	if (state.window == nil) {
		fmt.eprintln("Failed to create window")
		glfw.Terminate()
		return {}, .Create_Error
	}
	fmt.println("Initialised window:", state.window)

	state.window_width = f32(width)
	state.window_height = f32(height)

	glfw.MakeContextCurrent(state.window)
	fmt.println("Current context:", glfw.GetCurrentContext())

	glfw.SetFramebufferSizeCallback(state.window, framebuffer_size_callback)
	glfw.SetWindowSizeCallback(state.window, window_size_callback)

	glfw.SwapInterval(1)

	return &state, .None
}

set_window_size_limits :: proc(min_width, min_height, max_width, max_height: i32) {
	glfw.SetWindowSizeLimits(state.window, min_width, min_height, max_width, max_height)
}

get_window_size :: proc() -> (width: f32, height: f32) {
	width = state.window_width
	height = state.window_height
	return
}

window_should_close :: proc() -> bool {
	return cast(bool)glfw.WindowShouldClose(state.window)
}

close_window :: proc() {
	glfw.Terminate()
}

set_error_callback :: proc(callback: proc "c" (_: i32, _: cstring)) {
	glfw.SetErrorCallback(callback)
}

set_framebuffer_size_callback :: proc(
	callback: proc "c" (_: glfw.WindowHandle, width, height: i32),
) {
	glfw.SetFramebufferSizeCallback(state.window, callback)
}

set_window_size_callback :: proc(callback: proc "c" (_: glfw.WindowHandle, width, height: i32)) {
	glfw.SetWindowSizeCallback(state.window, callback)
}

window_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	state.window_width = f32(width)
	state.window_height = f32(height)
	glfw.SetWindowSize(window, width, height)
}

framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	state.window_width = f32(width)
	state.window_height = f32(height)
	gl.Viewport(0, 0, width, height)
}
