package odintui

// Widget is the core rendering interface.
// Implemented via a vtable-style struct so any type can be a widget.
Widget :: struct {
	data:   rawptr,
	render: proc(data: rawptr, area: Rect, buf: ^Buffer),
}

// Frame is passed to the user's draw closure each tick.
Frame :: struct {
	buffer:     ^Buffer,
	cursor_pos: Maybe([2]u16),
}

frame_render_widget :: proc(f: ^Frame, w: Widget, area: Rect) {
	if w.render != nil {
		w.render(w.data, area, f.buffer)
	}
}

frame_set_cursor :: proc(f: ^Frame, x, y: u16) {
	f.cursor_pos = [2]u16{x, y}
}

frame_size :: proc(f: ^Frame) -> Rect {
	return f.buffer.area
}

// centered_rect returns a Rect centered within parent area
// with the specified percentage of parent's width and height.
// Useful for modal popups and dialogs.
centered_rect :: proc(percent_x, percent_y: u16, r: Rect) -> Rect {
	// Clamp percentages to 0-100
	px := clamp(percent_x, 0, 100)
	py := clamp(percent_y, 0, 100)

	// Calculate popup dimensions
	popup_width := (r.width * px) / 100
	popup_height := (r.height * py) / 100

	// Calculate centered position
	popup_x := r.x + (r.width - popup_width) / 2
	popup_y := r.y + (r.height - popup_height) / 2

	return Rect{x = popup_x, y = popup_y, width = popup_width, height = popup_height}
}
