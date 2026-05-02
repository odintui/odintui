#+build linux, darwin
package odintui_backend

import "core:sys/posix"

_platform_enable_vt :: proc(b: ^Crossterm_Backend) {}

_platform_raw_mode :: proc(b: ^Crossterm_Backend) {
    orig: posix.termios
    posix.tcgetattr(posix.STDIN_FILENO, &orig)
    b.prev_mode = u32(orig.c_lflag)
    raw := orig
    posix.cfmakeraw(&raw)
    posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &raw)
}

_platform_restore_mode :: proc(b: ^Crossterm_Backend) {
    t: posix.termios
    posix.tcgetattr(posix.STDIN_FILENO, &t)
    t.c_lflag = posix.tcflag_t(b.prev_mode)
    posix.tcsetattr(posix.STDIN_FILENO, .TCSAFLUSH, &t)
}

_ct_size :: proc(b: ^Backend) -> [2]u16 {
    ws: posix.winsize
    if posix.ioctl(posix.STDOUT_FILENO, posix.TIOCGWINSZ, &ws) == 0 {
        return {u16(ws.ws_col), u16(ws.ws_row)}
    }
    return {80, 24}
}
