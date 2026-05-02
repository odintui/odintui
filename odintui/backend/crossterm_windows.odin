package odintui_backend

import win32 "core:sys/windows"

ENABLE_VIRTUAL_TERMINAL_PROCESSING :: u32(0x0004)
ENABLE_PROCESSED_INPUT             :: u32(0x0001)
ENABLE_LINE_INPUT                  :: u32(0x0002)
ENABLE_ECHO_INPUT                  :: u32(0x0004)
ENABLE_MOUSE_INPUT                 :: u32(0x0010)
ENABLE_WINDOW_INPUT                :: u32(0x0008)

_platform_enable_vt :: proc(b: ^Crossterm_Backend) {
    h := win32.GetStdHandle(win32.STD_OUTPUT_HANDLE)
    mode: u32
    win32.GetConsoleMode(h, &mode)
    win32.SetConsoleMode(h, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING)
}

_platform_raw_mode :: proc(b: ^Crossterm_Backend) {
    h := win32.GetStdHandle(win32.STD_INPUT_HANDLE)
    win32.GetConsoleMode(h, &b.prev_mode)
    raw := b.prev_mode &~
        (ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT)
    raw |= ENABLE_MOUSE_INPUT | ENABLE_WINDOW_INPUT
    win32.SetConsoleMode(h, raw)
}

_platform_restore_mode :: proc(b: ^Crossterm_Backend) {
    h := win32.GetStdHandle(win32.STD_INPUT_HANDLE)
    win32.SetConsoleMode(h, b.prev_mode)
}

_ct_size :: proc(b: ^Backend) -> [2]u16 {
    h := win32.GetStdHandle(win32.STD_OUTPUT_HANDLE)
    info: win32.CONSOLE_SCREEN_BUFFER_INFO
    if win32.GetConsoleScreenBufferInfo(h, &info) {
        w  := u16(info.srWindow.Right  - info.srWindow.Left + 1)
        h  := u16(info.srWindow.Bottom - info.srWindow.Top  + 1)
        return {w, h}
    }
    return {80, 24}
}
