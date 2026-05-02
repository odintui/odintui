package odintui_widgets

import tui ".."
import "core:strings"

Tabs :: struct {
    titles:          []string,
    selected:        int,
    block:           Maybe(Block),
    style:           tui.Style,
    highlight_style: tui.Style,
    divider:         string,
}

tabs_new :: proc(titles: []string) -> Tabs {
    return Tabs{
        titles  = titles,
        divider = " │ ",
    }
}

tabs_select :: proc(t: Tabs, idx: int) -> Tabs {
    t := t
    t.selected = idx
    return t
}

tabs_block :: proc(t: Tabs, b: Block) -> Tabs {
    t := t
    t.block = b
    return t
}

tabs_style :: proc(t: Tabs, s: tui.Style) -> Tabs {
    t := t
    t.style = s
    return t
}

tabs_highlight_style :: proc(t: Tabs, s: tui.Style) -> Tabs {
    t := t
    t.highlight_style = s
    return t
}

tabs_divider :: proc(t: Tabs, div: string) -> Tabs {
    t := t
    t.divider = div
    return t
}

tabs_render :: proc(t: Tabs, area: tui.Rect, buf: ^tui.Buffer) {
    inner := area
    if b, ok := t.block.?; ok {
        block_render(b, area, buf)
        inner = block_inner(b, area)
    }
    if tui.rect_is_empty(inner) { return }

    tui.buffer_set_style(buf, inner, t.style)

    cx := inner.x
    y  := inner.y
    max_x := inner.x + inner.width

    for title, i in t.titles {
        style := t.style
        if i == t.selected {
            style = tui.style_patch(t.style, t.highlight_style)
        }
        // Write title
        title_w := u16(len(title))
        if cx + title_w > max_x { break }
        tui.buffer_set_string(buf, cx, y, title, style, max_x - cx)
        cx += title_w

        // Write divider (except after last tab)
        if i < len(t.titles) - 1 {
            div_w := u16(len(t.divider))
            if cx + div_w > max_x { break }
            tui.buffer_set_string(
                buf, cx, y, t.divider, t.style, max_x - cx,
            )
            cx += div_w
        }
    }
}

tabs_widget :: proc(t: ^Tabs) -> tui.Widget {
    return tui.Widget{
        data   = t,
        render = proc(data: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
            tabs_render((^Tabs)(data)^, area, buf)
        },
    }
}
