package odintui_backend

import "core:fmt"
import "core:os"
import "core:strings"

Crossterm_Backend :: struct {
    using base: Backend,
    stdout:     os.Handle,
    buf:        strings.Builder,
    prev_mode:  u32,
}

crossterm_init :: proc(
    allocator := context.allocator,
) -> ^Crossterm_Backend {
    b := new(Crossterm_Backend, allocator)
    b.stdout = os.stdout
    strings.builder_init(&b.buf, allocator)

    _platform_enable_vt(b)
    _platform_raw_mode(b)

    b.draw        = _ct_draw
    b.hide_cursor = _ct_hide_cursor
    b.show_cursor = _ct_show_cursor
    b.get_cursor  = _ct_get_cursor
    b.set_cursor  = _ct_set_cursor
    b.clear       = _ct_clear
    b.size        = _ct_size
    b.flush       = _ct_flush

    _ct_write(b, "\x1b[?1049h\x1b[?25l")
    _ct_flush_impl(b)
    return b
}

crossterm_restore :: proc(b: ^Crossterm_Backend) {
    _ct_write(b, "\x1b[?1049l\x1b[?25h")
    _ct_flush_impl(b)
    _platform_restore_mode(b)
    strings.builder_destroy(&b.buf)
}

// ── helpers ───────────────────────────────────────────────────────────────────

_ct_write :: proc(b: ^Crossterm_Backend, s: string) {
    strings.write_string(&b.buf, s)
}

_ct_flush_impl :: proc(b: ^Crossterm_Backend) {
    s := strings.to_string(b.buf)
    if len(s) > 0 {
        os.write(b.stdout, transmute([]u8)s)
        strings.builder_reset(&b.buf)
    }
}

_write_fg :: proc(b: ^Crossterm_Backend, color: Ansi_Color) {
    switch c in color {
    case Ansi_Named:
        codes := [Ansi_Named]string{
            .Reset         = "\x1b[39m",
            .Black         = "\x1b[30m", .Red           = "\x1b[31m",
            .Green         = "\x1b[32m", .Yellow        = "\x1b[33m",
            .Blue          = "\x1b[34m", .Magenta       = "\x1b[35m",
            .Cyan          = "\x1b[36m", .Gray          = "\x1b[37m",
            .Dark_Gray     = "\x1b[90m", .Light_Red     = "\x1b[91m",
            .Light_Green   = "\x1b[92m", .Light_Yellow  = "\x1b[93m",
            .Light_Blue    = "\x1b[94m", .Light_Magenta = "\x1b[95m",
            .Light_Cyan    = "\x1b[96m", .White         = "\x1b[97m",
        }
        _ct_write(b, codes[c])
    case Ansi_Rgb:
        fmt.sbprintf(&b.buf, "\x1b[38;2;%d;%d;%dm", c.r, c.g, c.b)
    case Ansi_Indexed:
        fmt.sbprintf(&b.buf, "\x1b[38;5;%dm", c.index)
    }
}

_write_bg :: proc(b: ^Crossterm_Backend, color: Ansi_Color) {
    switch c in color {
    case Ansi_Named:
        codes := [Ansi_Named]string{
            .Reset         = "\x1b[49m",
            .Black         = "\x1b[40m",  .Red           = "\x1b[41m",
            .Green         = "\x1b[42m",  .Yellow        = "\x1b[43m",
            .Blue          = "\x1b[44m",  .Magenta       = "\x1b[45m",
            .Cyan          = "\x1b[46m",  .Gray          = "\x1b[47m",
            .Dark_Gray     = "\x1b[100m", .Light_Red     = "\x1b[101m",
            .Light_Green   = "\x1b[102m", .Light_Yellow  = "\x1b[103m",
            .Light_Blue    = "\x1b[104m", .Light_Magenta = "\x1b[105m",
            .Light_Cyan    = "\x1b[106m", .White         = "\x1b[107m",
        }
        _ct_write(b, codes[c])
    case Ansi_Rgb:
        fmt.sbprintf(&b.buf, "\x1b[48;2;%d;%d;%dm", c.r, c.g, c.b)
    case Ansi_Indexed:
        fmt.sbprintf(&b.buf, "\x1b[48;5;%dm", c.index)
    }
}

// ── Backend vtable procs ──────────────────────────────────────────────────────

_ct_draw :: proc(b: ^Backend, cells: []Draw_Cell) {
    self := (^Crossterm_Backend)(b)
    last_x, last_y: u16 = max(u16), max(u16)

    for dc in cells {
        if dc.x != last_x + 1 || dc.y != last_y {
            fmt.sbprintf(&self.buf, "\x1b[%d;%dH", dc.y + 1, dc.x + 1)
        }
        last_x = dc.x
        last_y = dc.y

        _ct_write(self, "\x1b[0m")
        if fg, ok := dc.fg.?; ok { _write_fg(self, fg) }
        if bg, ok := dc.bg.?; ok { _write_bg(self, bg) }
        if dc.bold        { _ct_write(self, "\x1b[1m") }
        if dc.dim         { _ct_write(self, "\x1b[2m") }
        if dc.italic      { _ct_write(self, "\x1b[3m") }
        if dc.underlined  { _ct_write(self, "\x1b[4m") }
        if dc.blink       { _ct_write(self, "\x1b[5m") }
        if dc.rapid_blink { _ct_write(self, "\x1b[6m") }
        if dc.reversed    { _ct_write(self, "\x1b[7m") }
        if dc.hidden      { _ct_write(self, "\x1b[8m") }
        if dc.crossed_out { _ct_write(self, "\x1b[9m") }
        _ct_write(self, dc.symbol)
    }
}

_ct_hide_cursor :: proc(b: ^Backend) {
    _ct_write((^Crossterm_Backend)(b), "\x1b[?25l")
}

_ct_show_cursor :: proc(b: ^Backend) {
    _ct_write((^Crossterm_Backend)(b), "\x1b[?25h")
}

_ct_get_cursor :: proc(b: ^Backend) -> (u16, u16) {
    return 0, 0
}

_ct_set_cursor :: proc(b: ^Backend, x, y: u16) {
    self := (^Crossterm_Backend)(b)
    fmt.sbprintf(&self.buf, "\x1b[%d;%dH", y + 1, x + 1)
}

_ct_clear :: proc(b: ^Backend) {
    _ct_write((^Crossterm_Backend)(b), "\x1b[2J\x1b[H")
}

_ct_flush :: proc(b: ^Backend) {
    _ct_flush_impl((^Crossterm_Backend)(b))
}
