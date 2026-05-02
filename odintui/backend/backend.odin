package odintui_backend

// Draw_Cell is the unit passed from Terminal to Backend.
// It avoids importing the parent package and breaking the cycle.
Draw_Cell :: struct {
    x, y:   u16,
    symbol: string,
    fg:     Maybe(Ansi_Color),
    bg:     Maybe(Ansi_Color),
    bold, dim, italic, underlined,
    blink, rapid_blink, reversed,
    hidden, crossed_out: bool,
}

// Ansi_Color is a backend-level color representation.
Ansi_Color :: union {
    Ansi_Named,
    Ansi_Rgb,
    Ansi_Indexed,
}

Ansi_Named :: enum u8 {
    Reset,
    Black, Red, Green, Yellow, Blue, Magenta, Cyan, Gray,
    Dark_Gray,
    Light_Red, Light_Green, Light_Yellow, Light_Blue,
    Light_Magenta, Light_Cyan,
    White,
}

Ansi_Rgb     :: struct { r, g, b: u8 }
Ansi_Indexed :: struct { index: u8 }

// Backend is the vtable interface to the actual terminal.
Backend :: struct {
    draw:        proc(b: ^Backend, cells: []Draw_Cell),
    hide_cursor: proc(b: ^Backend),
    show_cursor: proc(b: ^Backend),
    get_cursor:  proc(b: ^Backend) -> (u16, u16),
    set_cursor:  proc(b: ^Backend, x, y: u16),
    clear:       proc(b: ^Backend),
    size:        proc(b: ^Backend) -> [2]u16,
    flush:       proc(b: ^Backend),
}
