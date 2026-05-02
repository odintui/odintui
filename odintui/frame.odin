package odintui

// Widget is the core rendering interface.
// Implemented via a vtable-style struct so any type can be a widget.
Widget :: struct {
    data:   rawptr,
    render: proc(data: rawptr, area: Rect, buf: ^Buffer),
}

// Frame is passed to the user's draw closure each tick.
Frame :: struct {
    buffer:      ^Buffer,
    cursor_pos:  Maybe([2]u16),
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
