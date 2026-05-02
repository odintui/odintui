package odintui

import backend "backend"
import "core:mem"

Terminal :: struct {
	backend:   ^backend.Backend,
	current:   Buffer,
	previous:  Buffer,
	allocator: mem.Allocator,
}

terminal_init :: proc(b: ^backend.Backend, allocator := context.allocator) -> Terminal {
	sz := b.size(b)
	area := Rect{0, 0, sz.x, sz.y}
	return Terminal {
		backend = b,
		current = buffer_empty(area, allocator),
		previous = buffer_empty(area, allocator),
		allocator = allocator,
	}
}

terminal_destroy :: proc(t: ^Terminal) {
	buffer_destroy(&t.current, t.allocator)
	buffer_destroy(&t.previous, t.allocator)
}

terminal_draw :: proc(t: ^Terminal, render: proc(f: ^Frame)) {
	sz := t.backend.size(t.backend)
	area := Rect{0, 0, sz.x, sz.y}
	if area != t.current.area {
		buffer_resize(&t.current, area, t.allocator)
		buffer_resize(&t.previous, area, t.allocator)
	}

	buffer_reset(&t.current)

	frame := Frame {
		buffer = &t.current,
	}
	render(&frame)

	diff := buffer_diff(&t.previous, &t.current, t.allocator)
	draw_cells := make([]backend.Draw_Cell, len(diff), t.allocator)
	for dc, i in diff {
		draw_cells[i] = _cell_to_draw(dc)
	}
	delete(diff)

	t.backend.draw(t.backend, draw_cells)
	delete(draw_cells, t.allocator)

	if pos, ok := frame.cursor_pos.?; ok {
		t.backend.set_cursor(t.backend, pos.x, pos.y)
		t.backend.show_cursor(t.backend)
	} else {
		t.backend.hide_cursor(t.backend)
	}

	t.backend.flush(t.backend)
	t.previous, t.current = t.current, t.previous
}

// Convert a Diff_Cell to the backend's Draw_Cell (no shared types).
_cell_to_draw :: proc(dc: Diff_Cell) -> backend.Draw_Cell {
	out := backend.Draw_Cell {
		x      = dc.x,
		y      = dc.y,
		symbol = dc.cell.symbol,
	}
	if fg, ok := dc.cell.style.fg.?; ok {
		out.fg = _color_to_ansi(fg)
	}
	if bg, ok := dc.cell.style.bg.?; ok {
		out.bg = _color_to_ansi(bg)
	}
	m := dc.cell.style.add_modifier
	out.bold = .Bold in m
	out.dim = .Dim in m
	out.italic = .Italic in m
	out.underlined = .Underlined in m
	out.blink = .Slow_Blink in m
	out.rapid_blink = .Rapid_Blink in m
	out.reversed = .Reversed in m
	out.hidden = .Hidden in m
	out.crossed_out = .Crossed_Out in m
	return out
}

_color_to_ansi :: proc(c: Color) -> backend.Ansi_Color {
	switch v in c {
	case Color_Reset:
		return backend.Ansi_Named.Reset
	case Color_Black:
		return backend.Ansi_Named.Black
	case Color_Red:
		return backend.Ansi_Named.Red
	case Color_Green:
		return backend.Ansi_Named.Green
	case Color_Yellow:
		return backend.Ansi_Named.Yellow
	case Color_Blue:
		return backend.Ansi_Named.Blue
	case Color_Magenta:
		return backend.Ansi_Named.Magenta
	case Color_Cyan:
		return backend.Ansi_Named.Cyan
	case Color_Gray:
		return backend.Ansi_Named.Gray
	case Color_Dark_Gray:
		return backend.Ansi_Named.Dark_Gray
	case Color_Light_Red:
		return backend.Ansi_Named.Light_Red
	case Color_Light_Green:
		return backend.Ansi_Named.Light_Green
	case Color_Light_Yellow:
		return backend.Ansi_Named.Light_Yellow
	case Color_Light_Blue:
		return backend.Ansi_Named.Light_Blue
	case Color_Light_Magenta:
		return backend.Ansi_Named.Light_Magenta
	case Color_Light_Cyan:
		return backend.Ansi_Named.Light_Cyan
	case Color_White:
		return backend.Ansi_Named.White
	case Color_Rgb:
		return backend.Ansi_Rgb{v.r, v.g, v.b}
	case Color_Indexed:
		return backend.Ansi_Indexed{v.index}
	}
	return backend.Ansi_Named.Reset
}

init :: proc(allocator := context.allocator) -> Terminal {
	b := backend.crossterm_init(allocator)
	return terminal_init((^backend.Backend)(b), allocator)
}

restore :: proc(t: ^Terminal) {
	ct := (^backend.Crossterm_Backend)(t.backend)
	backend.crossterm_restore(ct)
	terminal_destroy(t)
}

// ── Event Loop ────────────────────────────────────────────────────────────────

// Event_Handler is called for each event.
// Return false to quit the event loop.
Event_Handler :: proc(event: Event, user_data: rawptr) -> bool

// Thread-local context for terminal_run
@(private, thread_local)
_terminal_run_ctx: struct {
	render_fn: proc(f: ^Frame, user_data: rawptr),
	user_data: rawptr,
}

// terminal_run runs an event loop with automatic rendering.
//
// Parameters:
//   t: Terminal instance
//   render: Draw function called on each frame
//   handle_event: Event handler, return false to quit
//   user_data: Optional user data passed to render and handle_event
//   fps: Target frames per second (default 60)
//
// The loop:
//   1. Polls for events with timeout based on fps
//   2. If event available, reads and calls handle_event
//   3. Calls render to draw the frame
//   4. Repeats until handle_event returns false
//
// Example:
//   terminal_run(&term, draw_ui, handle_event, &app_state, 60)
terminal_run :: proc(
	t: ^Terminal,
	render_fn: proc(f: ^Frame, user_data: rawptr),
	handle_event_fn: Event_Handler,
	user_data: rawptr = nil,
	fps: int = 60,
) {
	frame_time_ms := 1000 / fps

	// Store in thread-local context
	_terminal_run_ctx.render_fn = render_fn
	_terminal_run_ctx.user_data = user_data

	for {
		// Poll for events
		if event_poll(frame_time_ms) {
			if event, ok := event_read(); ok {
				// Handle event, quit if returns false
				if !handle_event_fn(event, user_data) {
					break
				}
			}
		}

		// Draw frame
		terminal_draw(t, _terminal_run_render_callback)
	}
}

@(private)
_terminal_run_render_callback :: proc(f: ^Frame) {
	_terminal_run_ctx.render_fn(f, _terminal_run_ctx.user_data)
}

// terminal_run_simple is a simplified version without user_data.
// Useful when render and handle_event are closures that capture state.
//
// Example:
//   app := App_State{}
//   terminal_run_simple(&term,
//       proc(f: ^Frame) { draw_ui(f, &app) },
//       proc(e: Event) -> bool { return handle_event(&app, e) },
//   )
terminal_run_simple :: proc(
	t: ^Terminal,
	render_fn: proc(f: ^Frame),
	handle_event_fn: proc(event: Event) -> bool,
	fps: int = 60,
) {
	frame_time_ms := 1000 / fps

	for {
		// Poll for events
		if event_poll(frame_time_ms) {
			if event, ok := event_read(); ok {
				// Handle event, quit if returns false
				if !handle_event_fn(event) {
					break
				}
			}
		}

		// Draw frame
		terminal_draw(t, render_fn)
	}
}
