package odintui_widgets

import tui ".."

Sparkline_Direction :: enum { Left_To_Right, Right_To_Left }

Sparkline :: struct {
    block:               Maybe(Block),
    data:                []u64,
    max:                 Maybe(u64),
    bar_set:             tui.Bar_Set,
    style:               tui.Style,
    absent_value_style:  tui.Style,
    absent_value_symbol: string,
    direction:           Sparkline_Direction,
}

sparkline_new :: proc() -> Sparkline {
    return Sparkline{
        bar_set              = tui.NINE_LEVELS,
        absent_value_symbol  = " ",
    }
}

sparkline_block :: proc(s: Sparkline, b: Block) -> Sparkline {
    s := s
    s.block = b
    return s
}

sparkline_data :: proc(s: Sparkline, data: []u64) -> Sparkline {
    s := s
    s.data = data
    return s
}

sparkline_max :: proc(s: Sparkline, m: u64) -> Sparkline {
    s := s
    s.max = m
    return s
}

sparkline_bar_set :: proc(s: Sparkline, bs: tui.Bar_Set) -> Sparkline {
    s := s
    s.bar_set = bs
    return s
}

sparkline_style :: proc(s: Sparkline, st: tui.Style) -> Sparkline {
    s := s
    s.style = st
    return s
}

sparkline_absent_value_style :: proc(
    s: Sparkline, st: tui.Style,
) -> Sparkline {
    s := s
    s.absent_value_style = st
    return s
}

sparkline_absent_value_symbol :: proc(
    s: Sparkline, sym: string,
) -> Sparkline {
    s := s
    s.absent_value_symbol = sym
    return s
}

sparkline_direction :: proc(
    s: Sparkline, d: Sparkline_Direction,
) -> Sparkline {
    s := s
    s.direction = d
    return s
}

// _bar_symbol picks one of 9 levels (empty … full).
_bar_symbol :: proc(bs: tui.Bar_Set, level: int) -> string {
    switch level {
    case 0:  return bs.empty
    case 1:  return bs.one
    case 2:  return bs.two
    case 3:  return bs.three
    case 4:  return bs.four
    case 5:  return bs.five
    case 6:  return bs.six
    case 7:  return bs.seven
    case 8:  return bs.full
    }
    return bs.full
}

sparkline_render :: proc(s: Sparkline, area: tui.Rect, buf: ^tui.Buffer) {
    inner := area
    if b, ok := s.block.?; ok {
        block_render(b, area, buf)
        inner = block_inner(b, area)
    }
    if tui.rect_is_empty(inner) { return }

    tui.buffer_set_style(buf, inner, s.style)

    w    := int(inner.width)
    h    := int(inner.height)
    data := s.data

    // Compute effective max
    eff_max: u64 = 1
    if m, ok := s.max.?; ok {
        eff_max = max(m, 1)
    } else {
        for v in data {
            if v > eff_max { eff_max = v }
        }
        if eff_max == 0 { eff_max = 1 }
    }

    levels := h * 8 // total sub-row levels

    for col in 0..<w {
        // data index depends on direction
        data_idx: int
        if s.direction == .Left_To_Right {
            data_idx = len(data) - w + col
        } else {
            data_idx = w - 1 - col
        }

        if data_idx < 0 || data_idx >= len(data) {
            // absent value
            cy := inner.y + u16(h) - 1
            c  := tui.buffer_cell(buf, inner.x + u16(col), cy)
            if c != nil {
                c.symbol = s.absent_value_symbol
                c.style  = s.absent_value_style
            }
            continue
        }

        v := data[data_idx]
        // total sub-levels for this value
        filled := int(u64(levels) * v / eff_max)

        for row in 0..<h {
            // row 0 is bottom
            bottom_row := h - 1 - row
            cy := inner.y + u16(bottom_row)
            cx := inner.x + u16(col)
            c  := tui.buffer_cell(buf, cx, cy)
            if c == nil { continue }

            row_filled := filled - row * 8
            level      := clamp(row_filled, 0, 8)

            c.symbol = _bar_symbol(s.bar_set, level)
            c.style  = s.style
        }
    }
}

sparkline_widget :: proc(s: ^Sparkline) -> tui.Widget {
    return tui.Widget{
        data   = s,
        render = proc(data: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
            sparkline_render((^Sparkline)(data)^, area, buf)
        },
    }
}
