package odintui_widgets

import tui ".."

Border_Flag :: enum { Top, Bottom, Left, Right }
Borders :: distinct bit_set[Border_Flag]

BORDERS_NONE :: Borders{}
BORDERS_ALL  :: Borders{.Top, .Bottom, .Left, .Right}
BORDERS_TOP  :: Borders{.Top}

Block :: struct {
    title:        string,
    title_style:  tui.Style,
    borders:      Borders,
    border_set:   tui.Border_Set,
    border_style: tui.Style,
    style:        tui.Style,
}

block_new :: proc() -> Block {
    return Block{
        borders    = BORDERS_ALL,
        border_set = tui.BORDER_PLAIN,
    }
}

block_title :: proc(b: Block, title: string, style := tui.Style{}) -> Block {
    b := b
    b.title       = title
    b.title_style = style
    return b
}

block_borders :: proc(b: Block, borders: Borders) -> Block {
    b := b
    b.borders = borders
    return b
}

block_border_set :: proc(b: Block, set: tui.Border_Set) -> Block {
    b := b
    b.border_set = set
    return b
}

block_border_style :: proc(b: Block, style: tui.Style) -> Block {
    b := b
    b.border_style = style
    return b
}

block_style :: proc(b: Block, style: tui.Style) -> Block {
    b := b
    b.style = style
    return b
}

// inner returns the area inside the block's borders.
block_inner :: proc(b: Block, area: tui.Rect) -> tui.Rect {
    r := area
    if .Top    in b.borders { r.y += 1; r.height -= 1 }
    if .Bottom in b.borders && r.height > 0 { r.height -= 1 }
    if .Left   in b.borders { r.x += 1; r.width  -= 1 }
    if .Right  in b.borders && r.width  > 0 { r.width  -= 1 }
    return r
}

block_render :: proc(b: Block, area: tui.Rect, buf: ^tui.Buffer) {
    if tui.rect_is_empty(area) { return }

    // Fill background
    tui.buffer_set_style(buf, area, b.style)

    bs := b.border_set
    style := b.border_style

    if .Top in b.borders {
        for x in area.x..<area.x + area.width {
            c := tui.buffer_cell(buf, x, area.y)
            if c == nil { continue }
            c.symbol = bs.horizontal
            c.style  = style
        }
        if .Left in b.borders {
            if c := tui.buffer_cell(buf, area.x, area.y); c != nil {
                c.symbol = bs.top_left
                c.style  = style
            }
        }
        if .Right in b.borders {
            if c := tui.buffer_cell(
                buf, area.x + area.width - 1, area.y,
            ); c != nil {
                c.symbol = bs.top_right
                c.style  = style
            }
        }
    }

    if .Bottom in b.borders {
        y := area.y + area.height - 1
        for x in area.x..<area.x + area.width {
            c := tui.buffer_cell(buf, x, y)
            if c == nil { continue }
            c.symbol = bs.horizontal
            c.style  = style
        }
        if .Left in b.borders {
            if c := tui.buffer_cell(buf, area.x, y); c != nil {
                c.symbol = bs.bottom_left
                c.style  = style
            }
        }
        if .Right in b.borders {
            if c := tui.buffer_cell(
                buf, area.x + area.width - 1, y,
            ); c != nil {
                c.symbol = bs.bottom_right
                c.style  = style
            }
        }
    }

    if .Left in b.borders {
        for y in area.y..<area.y + area.height {
            c := tui.buffer_cell(buf, area.x, y)
            if c == nil { continue }
            c.symbol = bs.vertical
            c.style  = style
        }
    }

    if .Right in b.borders {
        x := area.x + area.width - 1
        for y in area.y..<area.y + area.height {
            c := tui.buffer_cell(buf, x, y)
            if c == nil { continue }
            c.symbol = bs.vertical
            c.style  = style
        }
    }

    // Title
    if len(b.title) > 0 && .Top in b.borders {
        tx := area.x + 1
        max_w := int(area.width) - 2
        if max_w > 0 {
            tui.buffer_set_string(
                buf, tx, area.y, b.title,
                b.title_style, u16(max_w),
            )
        }
    }
}

// widget returns a Widget interface for this Block.
block_widget :: proc(b: ^Block) -> tui.Widget {
    return tui.Widget{
        data   = b,
        render = proc(data: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
            block_render((^Block)(data)^, area, buf)
        },
    }
}
