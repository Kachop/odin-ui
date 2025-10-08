package platform

import "base:runtime"
import "core:fmt"
import "vendor:glfw"

Button_State :: enum {
	Up,
	Down,
	Pressed,
	Released,
}

Mouse_Button :: enum i32 {
	Left   = glfw.MOUSE_BUTTON_LEFT,
	Right  = glfw.MOUSE_BUTTON_RIGHT,
	Middle = glfw.MOUSE_BUTTON_MIDDLE,
}

Keyboard_Key :: enum i32 {
	A         = glfw.KEY_A,
	B         = glfw.KEY_B,
	C         = glfw.KEY_C,
	D         = glfw.KEY_D,
	E         = glfw.KEY_E,
	F         = glfw.KEY_F,
	G         = glfw.KEY_G,
	H         = glfw.KEY_H,
	I         = glfw.KEY_I,
	J         = glfw.KEY_J,
	K         = glfw.KEY_K,
	L         = glfw.KEY_L,
	M         = glfw.KEY_M,
	N         = glfw.KEY_N,
	O         = glfw.KEY_O,
	P         = glfw.KEY_P,
	Q         = glfw.KEY_Q,
	R         = glfw.KEY_R,
	S         = glfw.KEY_S,
	T         = glfw.KEY_T,
	U         = glfw.KEY_U,
	V         = glfw.KEY_V,
	W         = glfw.KEY_W,
	X         = glfw.KEY_X,
	Y         = glfw.KEY_Y,
	Z         = glfw.KEY_Z,
	Num_1     = glfw.KEY_1,
	Num_2     = glfw.KEY_2,
	Num_3     = glfw.KEY_3,
	Num_4     = glfw.KEY_4,
	Num_5     = glfw.KEY_5,
	Num_6     = glfw.KEY_6,
	Num_7     = glfw.KEY_7,
	Num_8     = glfw.KEY_8,
	Num_9     = glfw.KEY_9,
	Num_0     = glfw.KEY_0,
	ESC       = glfw.KEY_ESCAPE,
	Space     = glfw.KEY_SPACE,
	Enter     = glfw.KEY_ENTER,
	Backspace = glfw.KEY_BACKSPACE,
	Del       = glfw.KEY_DELETE,
	Tab       = glfw.KEY_TAB,
}

process_input :: proc() {
	for key, i in state.keys_to_update {
		update_key_state(key)
		if state.key_states[key] == Button_State.Up {
			ordered_remove(&state.keys_to_update, i)
		}
	}

	if is_key_pressed(.ESC) {
		glfw.SetWindowShouldClose(state.window, true)
	}
	//clear(&state.keys_to_update)
	clear(&state.char_queue)
}

//Runs too slowly for good text input, manually updating register key_state instead
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	//Triggers on a key press, hold and release, slow.
	context = runtime.default_context()
	if action == glfw.PRESS {
		append(&state.keys_to_update, cast(Keyboard_Key)key)
	}
}

char_callback :: proc "c" (window: glfw.WindowHandle, char: rune) {
	context = runtime.default_context()
	append(&state.char_queue, char)
}

update_key_state :: proc(key: Keyboard_Key) {
	current_key_state := glfw.GetKey(state.window, cast(i32)key)

	switch current_key_state {
	case glfw.PRESS:
		if state.key_states[key] == Button_State.Pressed {
			state.key_states[key] = Button_State.Down
			return
		} else if state.key_states[key] != Button_State.Down {
			state.key_states[key] = Button_State.Pressed
		}
		return
	case glfw.RELEASE:
		if state.key_states[key] == Button_State.Pressed ||
		   state.key_states[key] == Button_State.Down {
			state.key_states[key] = Button_State.Released
			return
		}
		if state.key_states[key] == Button_State.Released {
			state.key_states[key] = Button_State.Up
			return
		}
	}
}

is_key_up :: proc(key: Keyboard_Key) -> bool {
	return state.key_states[key] == Button_State.Up
}

is_key_down :: proc(key: Keyboard_Key) -> bool {
	return state.key_states[key] == Button_State.Down
}

is_key_pressed :: proc(key: Keyboard_Key) -> bool {
	return state.key_states[key] == Button_State.Pressed
}

is_key_released :: proc(key: Keyboard_Key) -> bool {
	return state.key_states[key] == Button_State.Released
}

get_char :: proc() -> (char: rune, ok: bool) {
	if char, ok := pop_front_safe(&state.char_queue); ok {
		return char, ok
	}
	return {}, ok
}
