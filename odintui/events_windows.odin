#+build windows
package odintui

import "core:sys/windows"
import "core:time"

// Windows event implementation using ReadConsoleInput

// Windows console event type constants (not in core:sys/windows)
KEY_EVENT :: windows.Event_Type(0x0001)
MOUSE_EVENT :: windows.Event_Type(0x0002)
WINDOW_BUFFER_SIZE_EVENT :: windows.Event_Type(0x0004)
MENU_EVENT :: windows.Event_Type(0x0008)
FOCUS_EVENT :: windows.Event_Type(0x0010)

// Mouse event flags
MOUSE_MOVED :: 0x0001
DOUBLE_CLICK :: 0x0002
MOUSE_WHEELED :: 0x0004

// Button state flags
FROM_LEFT_1ST_BUTTON_PRESSED :: 0x0001

// Control key state flags
RIGHT_ALT_PRESSED :: 0x0001
LEFT_ALT_PRESSED :: 0x0002
RIGHT_CTRL_PRESSED :: 0x0004
LEFT_CTRL_PRESSED :: 0x0008
SHIFT_PRESSED :: 0x0010

@(private)
Event_Buffer :: struct {
	pending: Maybe(Event),
}

@(private)
g_event_buffer: Event_Buffer

@(private)
_event_poll_impl :: proc(timeout_ms: int) -> bool {
	// Check if we have a pending event
	if _, ok := g_event_buffer.pending.?; ok {
		return true
	}

	handle := windows.GetStdHandle(windows.STD_INPUT_HANDLE)
	if handle == windows.INVALID_HANDLE_VALUE {
		return false
	}

	// Non-blocking check
	if timeout_ms == 0 {
		available: u32
		if !windows.GetNumberOfConsoleInputEvents(handle, &available) {
			return false
		}
		return available > 0
	}

	// Blocking or timed wait
	wait_time := u32(windows.INFINITE) if timeout_ms < 0 else u32(timeout_ms)
	result := windows.WaitForSingleObject(handle, wait_time)

	return result == windows.WAIT_OBJECT_0
}

@(private)
_event_read_impl :: proc() -> (Event, bool) {
	// Return pending event if available
	if event, ok := g_event_buffer.pending.?; ok {
		g_event_buffer.pending = nil
		return event, true
	}

	handle := windows.GetStdHandle(windows.STD_INPUT_HANDLE)
	if handle == windows.INVALID_HANDLE_VALUE {
		return nil, false
	}

	// Read console input events
	for {
		input_record: windows.INPUT_RECORD
		events_read: u32

		if !windows.ReadConsoleInputW(handle, &input_record, 1, &events_read) {
			return nil, false
		}

		if events_read == 0 {
			return nil, false
		}

		// Process the input record
		#partial switch input_record.EventType {
		case KEY_EVENT:
			if event, ok := _parse_key_event(&input_record.Event.KeyEvent); ok {
				return event, true
			}

		case MOUSE_EVENT:
			if event, ok := _parse_mouse_event(&input_record.Event.MouseEvent); ok {
				return event, true
			}

		case WINDOW_BUFFER_SIZE_EVENT:
			size := input_record.Event.WindowBufferSizeEvent.dwSize
			return Resize_Event{width = u16(size.X), height = u16(size.Y)}, true

		case FOCUS_EVENT:
			if input_record.Event.FocusEvent.bSetFocus != false {
				return Focus_Event.Gained, true
			} else {
				return Focus_Event.Lost, true
			}
		}

		// Continue reading if event was not interesting
	}
}

@(private)
_parse_key_event :: proc(key_event: ^windows.KEY_EVENT_RECORD) -> (Event, bool) {
	// Only process key down events (or repeat)
	if key_event.bKeyDown == false {
		return nil, false
	}

	vk := key_event.wVirtualKeyCode
	scan := key_event.wVirtualScanCode
	char := key_event.uChar.UnicodeChar
	control_key_state := key_event.dwControlKeyState

	// Parse modifiers
	modifiers := _parse_modifiers(transmute(u32)control_key_state)

	// Parse key code
	code: Key_Code

	// Special keys
	switch vk {
	case windows.VK_BACK:
		code = Key_Special.Backspace
	case windows.VK_RETURN:
		code = Key_Special.Enter
	case windows.VK_TAB:
		if .Shift in modifiers {
			code = Key_Special.BackTab
		} else {
			code = Key_Special.Tab
		}
	case windows.VK_ESCAPE:
		code = Key_Special.Esc
	case windows.VK_HOME:
		code = Key_Special.Home
	case windows.VK_END:
		code = Key_Special.End
	case windows.VK_PRIOR:
		// Page Up
		code = Key_Special.PageUp
	case windows.VK_NEXT:
		// Page Down
		code = Key_Special.PageDown
	case windows.VK_DELETE:
		code = Key_Special.Delete
	case windows.VK_INSERT:
		code = Key_Special.Insert
	case windows.VK_UP:
		code = Key_Arrow.Up
	case windows.VK_DOWN:
		code = Key_Arrow.Down
	case windows.VK_LEFT:
		code = Key_Arrow.Left
	case windows.VK_RIGHT:
		code = Key_Arrow.Right
	case windows.VK_F1 ..= windows.VK_F12:
		code = Key_F(u8(vk - windows.VK_F1 + 1))
	case:
		// Character key
		if char != 0 {
			// Handle Ctrl+key combinations
			if .Control in modifiers && char < 32 {
				// Ctrl+A = 1, Ctrl+B = 2, etc.
				if char == 0 {
					code = Key_Special.Null
				} else {
					code = Key_Char(rune('a' + char - 1))
				}
			} else {
				code = Key_Char(rune(char))
			}
		} else {
			// Unknown key, skip
			return nil, false
		}
	}

	kind := Key_Event_Kind.Press
	if key_event.wRepeatCount > 1 {
		kind = .Repeat
	}

	return Key_Event{code = code, modifiers = modifiers, kind = kind, state = .None}, true
}

@(private)
_parse_mouse_event :: proc(mouse_event: ^windows.MOUSE_EVENT_RECORD) -> (Event, bool) {
	pos := mouse_event.dwMousePosition
	button_state := mouse_event.dwButtonState
	event_flags := mouse_event.dwEventFlags
	control_key_state := mouse_event.dwControlKeyState

	modifiers := _parse_modifiers(control_key_state)

	column := u16(pos.X)
	row := u16(pos.Y)

	// Mouse wheel
	if event_flags & MOUSE_WHEELED != 0 {
		// High word of dwButtonState contains wheel delta
		delta := i16(button_state >> 16)
		if delta > 0 {
			return Mouse_Event {
					kind = .ScrollUp,
					column = column,
					row = row,
					modifiers = modifiers,
				},
				true
		} else {
			return Mouse_Event {
					kind = .ScrollDown,
					column = column,
					row = row,
					modifiers = modifiers,
				},
				true
		}
	}

	// Mouse movement
	if event_flags & MOUSE_MOVED != 0 {
		return Mouse_Event{kind = .Moved, column = column, row = row, modifiers = modifiers}, true
	}

	// Mouse button events
	kind: Mouse_Event_Kind

	if event_flags == 0 {
		// Button press or release
		if button_state & FROM_LEFT_1ST_BUTTON_PRESSED != 0 {
			kind = .Down
		} else {
			kind = .Up
		}
	} else if event_flags & DOUBLE_CLICK != 0 {
		kind = .Down
	}

	return Mouse_Event{kind = kind, column = column, row = row, modifiers = modifiers}, true
}

@(private)
_parse_modifiers :: proc(state: u32) -> Key_Modifiers {
	modifiers := Key_Modifiers{}

	if state & SHIFT_PRESSED != 0 {
		modifiers += {.Shift}
	}

	if state & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED) != 0 {
		modifiers += {.Control}
	}

	if state & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED) != 0 {
		modifiers += {.Alt}
	}

	return modifiers
}
