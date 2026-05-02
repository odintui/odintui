package odintui

// Event system for keyboard, mouse, and terminal resize events.
// Mirrors crossterm::event API from Rust.

// ── Key Events ────────────────────────────────────────────────────────────────

Key_Code :: union {
	Key_Char,
	Key_Special,
	Key_F,
	Key_Arrow,
	Key_Modifier_Key,
}

Key_Char :: distinct rune

Key_Special :: enum {
	Backspace,
	Enter,
	Left, // deprecated, use Key_Arrow
	Right, // deprecated, use Key_Arrow
	Up, // deprecated, use Key_Arrow
	Down, // deprecated, use Key_Arrow
	Home,
	End,
	PageUp,
	PageDown,
	Tab,
	BackTab, // Shift+Tab
	Delete,
	Insert,
	Esc,
	CapsLock,
	ScrollLock,
	NumLock,
	PrintScreen,
	Pause,
	Menu,
	KeypadBegin,
	Null, // Ctrl+Space or Ctrl+@
}

Key_F :: distinct u8 // F1-F12 (1-12)

Key_Arrow :: enum {
	Up,
	Down,
	Left,
	Right,
}

Key_Modifier_Key :: enum {
	LeftShift,
	LeftControl,
	LeftAlt,
	LeftSuper, // Windows/Command key
	LeftHyper,
	LeftMeta,
	RightShift,
	RightControl,
	RightAlt,
	RightSuper,
	RightHyper,
	RightMeta,
	IsoLevel3Shift,
	IsoLevel5Shift,
}

Key_Modifier_Flag :: enum {
	Shift,
	Control,
	Alt,
	Super,
	Hyper,
	Meta,
}

Key_Modifiers :: distinct bit_set[Key_Modifier_Flag]

Key_Event :: struct {
	code:      Key_Code,
	modifiers: Key_Modifiers,
	kind:      Key_Event_Kind,
	state:     Key_Event_State,
}

Key_Event_Kind :: enum {
	Press,
	Repeat,
	Release,
}

Key_Event_State :: enum {
	None,
	KeypadBegin,
	CapsLock,
	NumLock,
}

// ── Mouse Events ──────────────────────────────────────────────────────────────

Mouse_Event_Kind :: enum {
	Down,
	Up,
	Drag,
	Moved,
	ScrollDown,
	ScrollUp,
}

Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}

Mouse_Event :: struct {
	kind:      Mouse_Event_Kind,
	column:    u16,
	row:       u16,
	modifiers: Key_Modifiers,
}

// ── Resize Events ─────────────────────────────────────────────────────────────

Resize_Event :: struct {
	width:  u16,
	height: u16,
}

// ── Focus Events ──────────────────────────────────────────────────────────────

Focus_Event :: enum {
	Gained,
	Lost,
}

// ── Paste Events ──────────────────────────────────────────────────────────────

Paste_Event :: struct {
	content: string,
}

// ── Event Union ───────────────────────────────────────────────────────────────

Event :: union {
	Key_Event,
	Mouse_Event,
	Resize_Event,
	Focus_Event,
	Paste_Event,
}

// ── Event API ─────────────────────────────────────────────────────────────────

// event_poll checks if an event is available within the timeout.
// timeout_ms: timeout in milliseconds, 0 = non-blocking, -1 = blocking
// Returns: true if event is available, false otherwise
event_poll :: proc(timeout_ms: int) -> bool {
	return _event_poll_impl(timeout_ms)
}

// event_read reads the next event from the input stream.
// Returns: (event, ok) where ok is false if no event available
event_read :: proc() -> (Event, bool) {
	return _event_read_impl()
}

// ── Helper Functions ──────────────────────────────────────────────────────────

key_event_new :: proc(code: Key_Code, modifiers := Key_Modifiers{}) -> Key_Event {
	return Key_Event{code = code, modifiers = modifiers, kind = .Press, state = .None}
}

mouse_event_new :: proc(
	kind: Mouse_Event_Kind,
	column, row: u16,
	modifiers := Key_Modifiers{},
) -> Mouse_Event {
	return Mouse_Event{kind = kind, column = column, row = row, modifiers = modifiers}
}

resize_event_new :: proc(width, height: u16) -> Resize_Event {
	return Resize_Event{width = width, height = height}
}

// ── Key Code Helpers ──────────────────────────────────────────────────────────

key_char :: proc(c: rune) -> Key_Code {
	return Key_Char(c)
}

key_f :: proc(n: u8) -> Key_Code {
	return Key_F(n)
}

key_arrow :: proc(dir: Key_Arrow) -> Key_Code {
	return dir
}

key_special :: proc(s: Key_Special) -> Key_Code {
	return s
}

// ── Platform-specific implementations ─────────────────────────────────────────

// These are implemented in events_windows.odin and events_posix.odin
// Forward declarations removed to avoid redeclaration errors
// _event_poll_impl :: proc(timeout_ms: int) -> bool
// _event_read_impl :: proc() -> (Event, bool)
