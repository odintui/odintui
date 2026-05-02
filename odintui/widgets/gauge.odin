package odintui_widgets

import tui ".."
import "core:strings"
import "core:fmt"

Gauge :: struct {
    block:       Maybe(Block),
    ratio:       f64,
    label:       Maybe(string),
    style:       tui.Style,
    gauge_style: tui.Style,
    use_unicode: bool,
}

gauge_new :: proc() -> Gauge {
    return Gauge{}
}

gauge_block :: proc(g: Gauge, b: Block) -> Gauge {
    g := g
    g.block = b
    return g
}

// gauge_percent sets ratio from integer percentage (0-100).
gauge_percent :: proc(g: Gauge, pct: u16) -> Gauge {
    g := g
    p := clamp(int(pct), 0, 100)
    g.ratio = f64(p) / 100.0
    return g
}

// gauge_ratio sets ratio directly (0.0-1.0).
gauge_ratio :: proc(g: Gauge, r: f64) -> Gauge {
    g := g
    g.ratio = clamp(r, 0.0, 1.0)
    return g
}

gauge_label :: proc(g: Gauge, label: string) -> Gauge {
    g := g
    g.label = label
    return g
}

gauge_style :: proc(g: Gauge, s: tui.Style) -> Gauge {
    g := g
    g.style = s
    return g
}

gauge_gauge_style :: proc(g: Gauge, s: tui.Style) -> Gauge {
    g := g
    g.gauge_style = s
    return g
}

gauge_use_unicode :: proc(g: Gauge, v: bool) -> Gauge {
    g := g
    g.use_unicode = v
    return g
}

gauge_render :: proc(g: Gauge, area: tui.Rect, buf: ^tui.Buffer) {
    inner := area
    if b, ok := g.block.?; ok {
        block_render(b, area, buf)
        inner = block_inner(b, area)
    }
    if tui.rect_is_empty(inner) { return }

    tui.buffer_set_style(buf, inner, g.style)

    // Use middle row only (like ratatui)
    gauge_y := inner.y + inner.height / 2
    w := int(inner.width)

    filled_f := g.ratio * f64(w)
    filled   := int(filled_f)
    frac     := filled_f - f64(filled) // fractional part 0..1

    for x in 0..<w {
        cx := inner.x + u16(x)
        c  := tui.buffer_cell(buf, cx, gauge_y)
        if c == nil { continue }
        if x < filled {
            c.symbol = tui.BAR_FULL
            c.style  = g.gauge_style
        } else if x == filled && g.use_unicode && filled < w {
            // pick sub-block by frac (0..1 → index 0..7)
            idx := int(frac * 8.0)
            if idx >= 8 { idx = 7 }
            c.symbol = tui.GAUGE_BLOCKS[idx]
            c.style  = g.gauge_style
        } else {
            c.symbol = " "
            c.style  = g.style
        }
    }

    // Label centered over the gauge row
    lbl: string
    if l, ok := g.label.?; ok {
        lbl = l
    } else {
        // default: "XX%"
        buf_arr: [8]byte
        lbl = fmt.bprintf(buf_arr[:], "%d%%", int(g.ratio * 100))
    }
    if len(lbl) > 0 {
        lbl_w := len(lbl)
        lbl_x := inner.x + u16(w / 2) - u16(lbl_w / 2)
        tui.buffer_set_string(
            buf, lbl_x, gauge_y, lbl,
            tui.Style{}, u16(min(lbl_w, w)),
        )
    }
}

gauge_widget :: proc(g: ^Gauge) -> tui.Widget {
    return tui.Widget{
        data   = g,
        render = proc(data: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
            gauge_render((^Gauge)(data)^, area, buf)
        },
    }
}
