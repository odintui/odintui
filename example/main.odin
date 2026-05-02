package main

import "core:os"
import tui "../odintui"
import w "../odintui/widgets"

main :: proc() {
    term := tui.init()
    defer tui.restore(&term)

    tui.terminal_draw(&term, proc(f: ^tui.Frame) {
        area := tui.frame_size(f)

        // Split vertically: title bar (3 rows) + main area
        layout := tui.layout_vertical(
            []tui.Constraint{
                tui.Constraint_Length(3),
                tui.Constraint_Min(0),
            },
        )
        rects := tui.layout_split(layout, area)
        defer delete(rects)

        // Title block
        title_block := w.block_new()
        title_block  = w.block_title(title_block, " odintui demo ")
        title_block  = w.block_borders(title_block, w.BORDERS_ALL)
        tui.frame_render_widget(f, w.block_widget(&title_block), rects[0])

        // Main paragraph
        txt  := tui.text_from_string("Hello from odintui!\nPress Ctrl-C to exit.")
        para := w.paragraph_new(txt)
        b    := w.block_new()
        b     = w.block_title(b, " Main ")
        b     = w.block_borders(b, w.BORDERS_ALL)
        para  = w.paragraph_block(para, b)
        tui.frame_render_widget(f, w.paragraph_widget(&para), rects[1])
    })

    // Wait for any key
    buf: [1]byte
    os.read(os.stdin, buf[:])
}
