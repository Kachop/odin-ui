package rwb

import "core:fmt"
import "platform"

/*
File for pre-built gui controls which can be used, for faster development

Checklist:
-[ ] Label
-[ ] Button
-[ ] Toggle
-[ ] Slider
-[ ] Text box
-[ ] Multi-line text input
-[ ] Radio button
-[ ] Panel
-[ ] Tab
-[ ] Images
-[ ] File dialog
-[ ] Dropdown
-[ ] Tooltip
-[ ] Progress bar
-[ ] Carousel
-[ ] Popup
*/

ui_button :: proc(id: UI_ID, style: UI_Ctrl_Styles) -> bool {
	focus_state := ui_button_start(id, style).focus_state
	ui_button_end()

	if (focus_state == .Focused) && (platform.is_mouse_button_pressed(.Left)) {
	}

	return false
}

ui_toggle_button :: proc(id: UI_ID, style: UI_Ctrl_Styles) -> bool {
	ctrl := ui_toggle_button_start(id, style)
	ui_toggle_button_end()

	if (ctrl.focus_state == .Focused) && (platform.is_mouse_button_pressed(.Left)) {
		ctrl.state_flags ~= {.Active}
	}

	if .Active in ctrl.state_flags {
		return true
	}

	return false
}
