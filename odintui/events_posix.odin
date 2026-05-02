#+build linux, darwin, freebsd, openbsd, netbsd
package odintui

import "core:c"
import "core:os"
import "core:time"

// POSIX event implementation using read() and ANSI escape sequence parsing

foreign import libc "system:c"

@(private)
STDIN_FILENO :: 0

@(private)
Event_Buffer :: struct {
	pending: Maybe(Event),
	buf:     [256]byte,
	len:     int,
	pos:     int,
}

@(private)
g_event_buffer: Event_Buffer

@(private)
_event_poll_impl :: proc(timeout_ms: int) -> bool {
	// Check if we have a pending event
	if _, ok := g_event_buffer.pending.?; ok {
		return true
	}

	// Check if we have buffered data
	if g_event_buffer.pos < g_event_buffer.len {
		return true
	}

	// Use select() to check for input with timeout
	fd_set: c.fd_set
	_FD_ZERO(&fd_set)
	_FD_SET(STDIN_FILENO, &fd_set)

	timeout: c.timeval
	timeout_ptr: ^c.timeval = nil

	if timeout_ms >= 0 {
		timeout.tv_sec = c.long(timeout_ms / 1000)
		timeout.tv_usec = c.long((timeout_ms % 1000) * 1000)
		timeout_ptr = &timeout
	}

	result := _select(STDIN_FILENO + 1, &fd_set, nil, nil, timeout_ptr)
	return result > 0
}

@(private)
_event_read_impl :: proc() -> (Event, bool) {
	// Return pending event if available
	if event, ok := g_event_buffer.pending.?; ok {
		g_event_buffer.pending = nil
		return event, true
	}

	// Read more data if buffer is empty
	if g_event_buffer.pos >= g_event_buffer.len {
		n := _read(STDIN_FILENO, &g_event_buffer.buf[0], len(g_event_buffer.buf))

		if n <= 0 {
			return nil, false
		}

		g_event_buffer.len = int(n)
		g_event_buffer.pos = 0
	}

	// Parse event from buffer
	return _parse_event()
}

@(private)
_parse_event :: proc() -> (Event, bool) {
	if g_event_buffer.pos >= g_event_buffer.len {
		return nil, false
	}

	first_byte := g_event_buffer.buf[g_event_buffer.pos]

	// ESC sequence
	if first_byte == 0x1B {
		if event, ok := _parse_escape_sequence(); ok {
			return event, true
		}
	}

	// Control characters
	if first_byte < 32 {
		g_event_buffer.pos += 1

		switch first_byte {
		case 0x08, 0x7F:
			// Backspace or DEL
			return Key_Event{code = Key_Special.Backspace, kind = .Press}, true
		case 0x09:
			// Tab
			return Key_Event{code = Key_Special.Tab, kind = .Press}, true
		case 0x0A, 0x0D:
			// LF or CR (Enter)
			return Key_Event{code = Key_Special.Enter, kind = .Press}, true
		case 0x1B:
			// ESC (standalone)
			return Key_Event{code = Key_Special.Esc, kind = .Press}, true
		case 0x00:
			// Ctrl+Space or Ctrl+@
			return Key_Event{code = Key_Special.Null, kind = .Press, modifiers = {.Control}}, true
		case 0x01 ..= 0x1A:
			// Ctrl+A to Ctrl+Z
			return Key_Event {
					code = Key_Char(rune('a' + first_byte - 1)),
					kind = .Press,
					modifiers = {.Control},
				},
				true
		}

		return nil, false
	}

	// Regular UTF-8 character
	if event, ok := _parse_utf8_char(); ok {
		return event, true
	}

	// Unknown, skip byte
	g_event_buffer.pos += 1
	return nil, false
}

@(private)
_parse_escape_sequence :: proc() -> (Event, bool) {
	// Need at least ESC + one more byte
	if g_event_buffer.pos + 1 >= g_event_buffer.len {
		return nil, false
	}

	second_byte := g_event_buffer.buf[g_event_buffer.pos + 1]

	// CSI sequence: ESC [
	if second_byte == '[' {
		return _parse_csi_sequence()
	}

	// SS3 sequence: ESC O (used for F1-F4 in some terminals)
	if second_byte == 'O' {
		return _parse_ss3_sequence()
	}

	// Alt+key: ESC followed by character
	if second_byte >= 0x20 {
		g_event_buffer.pos += 2
		return Key_Event{code = Key_Char(rune(second_byte)), kind = .Press, modifiers = {.Alt}},
			true
	}

	// Unknown escape sequence, consume ESC
	g_event_buffer.pos += 1
	return nil, false
}

@(private)
_parse_csi_sequence :: proc() -> (Event, bool) {
	// ESC [ already checked
	start := g_event_buffer.pos + 2

	if start >= g_event_buffer.len {
		return nil, false
	}

	// Find the end of CSI sequence (letter or ~)
	end := start
	for end < g_event_buffer.len {
		c := g_event_buffer.buf[end]
		if (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '~' {
			break
		}
		end += 1
	}

	if end >= g_event_buffer.len {
		return nil, false
	}

	final_byte := g_event_buffer.buf[end]
	params := g_event_buffer.buf[start:end]

	g_event_buffer.pos = end + 1

	// Arrow keys: ESC [ A/B/C/D
	switch final_byte {
	case 'A':
		return Key_Event{code = Key_Arrow.Up, kind = .Press}, true
	case 'B':
		return Key_Event{code = Key_Arrow.Down, kind = .Press}, true
	case 'C':
		return Key_Event{code = Key_Arrow.Right, kind = .Press}, true
	case 'D':
		return Key_Event{code = Key_Arrow.Left, kind = .Press}, true
	case 'H':
		return Key_Event{code = Key_Special.Home, kind = .Press}, true
	case 'F':
		return Key_Event{code = Key_Special.End, kind = .Press}, true
	}

	// Sequences ending with ~
	if final_byte == '~' && len(params) > 0 {
		// Parse number
		num := 0
		for b in params {
			if b >= '0' && b <= '9' {
				num = num * 10 + int(b - '0')
			} else {
				break
			}
		}

		switch num {
		case 1, 7:
			return Key_Event{code = Key_Special.Home, kind = .Press}, true
		case 2:
			return Key_Event{code = Key_Special.Insert, kind = .Press}, true
		case 3:
			return Key_Event{code = Key_Special.Delete, kind = .Press}, true
		case 4, 8:
			return Key_Event{code = Key_Special.End, kind = .Press}, true
		case 5:
			return Key_Event{code = Key_Special.PageUp, kind = .Press}, true
		case 6:
			return Key_Event{code = Key_Special.PageDown, kind = .Press}, true
		case 11 ..= 15:
			// F1-F5
			return Key_Event{code = Key_F(u8(num - 10)), kind = .Press}, true
		case 17 ..= 21:
			// F6-F10
			return Key_Event{code = Key_F(u8(num - 11)), kind = .Press}, true
		case 23, 24:
			// F11-F12
			return Key_Event{code = Key_F(u8(num - 12)), kind = .Press}, true
		}
	}

	// Mouse events: ESC [ < ... M/m
	if len(params) > 0 && params[0] == '<' {
		return _parse_sgr_mouse(params[1:], final_byte)
	}

	return nil, false
}

@(private)
_parse_ss3_sequence :: proc() -> (Event, bool) {
	// ESC O already checked
	if g_event_buffer.pos + 2 >= g_event_buffer.len {
		return nil, false
	}

	third_byte := g_event_buffer.buf[g_event_buffer.pos + 2]
	g_event_buffer.pos += 3

	// F1-F4 keys
	switch third_byte {
	case 'P':
		return Key_Event{code = Key_F(1), kind = .Press}, true
	case 'Q':
		return Key_Event{code = Key_F(2), kind = .Press}, true
	case 'R':
		return Key_Event{code = Key_F(3), kind = .Press}, true
	case 'S':
		return Key_Event{code = Key_F(4), kind = .Press}, true
	}

	return nil, false
}

@(private)
_parse_sgr_mouse :: proc(params: []byte, final: byte) -> (Event, bool) {
	// Parse SGR mouse format: <button;column;row M/m
	// M = press, m = release

	values: [3]int
	idx := 0
	num := 0

	for b in params {
		if b == ';' {
			if idx < 3 {
				values[idx] = num
				idx += 1
				num = 0
			}
		} else if b >= '0' && b <= '9' {
			num = num * 10 + int(b - '0')
		}
	}

	if idx < 3 {
		values[idx] = num
	}

	button := values[0]
	column := u16(values[1] - 1) // 1-based to 0-based
	row := u16(values[2] - 1)

	kind: Mouse_Event_Kind
	if final == 'M' {
		kind = .Down
	} else {
		kind = .Up
	}

	// Check for scroll events
	if button == 64 {
		kind = .ScrollUp
	} else if button == 65 {
		kind = .ScrollDown
	}

	return Mouse_Event{kind = kind, column = column, row = row}, true
}

@(private)
_parse_utf8_char :: proc() -> (Event, bool) {
	if g_event_buffer.pos >= g_event_buffer.len {
		return nil, false
	}

	first := g_event_buffer.buf[g_event_buffer.pos]

	// Determine UTF-8 sequence length
	char_len := 1
	if first & 0x80 == 0 {
		char_len = 1
	} else if first & 0xE0 == 0xC0 {
		char_len = 2
	} else if first & 0xF0 == 0xE0 {
		char_len = 3
	} else if first & 0xF8 == 0xF0 {
		char_len = 4
	} else {
		// Invalid UTF-8
		g_event_buffer.pos += 1
		return nil, false
	}

	// Check if we have enough bytes
	if g_event_buffer.pos + char_len > g_event_buffer.len {
		return nil, false
	}

	// Decode UTF-8
	r: rune
	switch char_len {
	case 1:
		r = rune(first)
	case 2:
		r = rune((first & 0x1F) << 6 | (g_event_buffer.buf[g_event_buffer.pos + 1] & 0x3F))
	case 3:
		r = rune(
			(first & 0x0F) << 12 |
			(g_event_buffer.buf[g_event_buffer.pos + 1] & 0x3F) << 6 |
			(g_event_buffer.buf[g_event_buffer.pos + 2] & 0x3F),
		)
	case 4:
		r = rune(
			(first & 0x07) << 18 |
			(g_event_buffer.buf[g_event_buffer.pos + 1] & 0x3F) << 12 |
			(g_event_buffer.buf[g_event_buffer.pos + 2] & 0x3F) << 6 |
			(g_event_buffer.buf[g_event_buffer.pos + 3] & 0x3F),
		)
	}

	g_event_buffer.pos += char_len

	return Key_Event{code = Key_Char(r), kind = .Press}, true
}

// ── Foreign functions ─────────────────────────────────────────────────────────

foreign libc {
	@(link_name = "select")
	_select :: proc(nfds: c.int, readfds: ^c.fd_set, writefds: ^c.fd_set, exceptfds: ^c.fd_set, timeout: ^c.timeval) -> c.int ---

	@(link_name = "read")
	_read :: proc(fd: c.int, buf: rawptr, count: c.size_t) -> c.ssize_t ---
}

@(private)
_FD_ZERO :: proc(set: ^c.fd_set) {
	for i in 0 ..< len(set.fds_bits) {
		set.fds_bits[i] = 0
	}
}

@(private)
_FD_SET :: proc(fd: c.int, set: ^c.fd_set) {
	idx := fd / (8 * size_of(c.long))
	bit := fd % (8 * size_of(c.long))
	set.fds_bits[idx] |= c.long(1 << uint(bit))
}
