package odintui_widgets

import tui ".."

// Gauge displays a progress bar with optional label.
// Mirrors ratatui::widgets::Gauge.
Gauge :: struct {
	block:       Maybe(Block),
	ratio:       f64, // 0.0 .. 1.0
	label:       Maybe(string),
	style:       tui.Style,
	gauge_style: tui.Style,
	use_unicode: bool,
}

gauge_new :: proc() -> Gauge {
	return Gauge {
		ratio = 0.0,
		style = tui.style_default(),
		gauge_style = tui.style_default(),
		use_unicode = false,
	}
}

gauge_block :: proc(g: Gauge, b: Block) -> Gauge {
	g := g
	g.block = b
	return g
}

gauge_percent :: proc(g: Gauge, pct: u16) -> Gauge {
	g := g
	g.ratio = f64(clamp(pct, 0, 100)) / 100.0
	return g
}

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

gauge_widget :: proc(g: ^Gauge) -> tui.Widget {
	return tui.Widget{variant = g, render = gauge_render}
}

@(private)
gauge_render :: proc(widget: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
	g := cast(^Gauge)widget

	render_area := area
	if block, ok := g.block.?; ok {
		block_render(&block, area, buf)
		render_area = block_inner(block, area)
	}

	if render_area.width < 1 || render_area.height < 1 {
		return
	}

	// Fill background with style
	for y in 0 ..< render_area.height {
		for x in 0 ..< render_area.width {
			tui.buffer_set_cell(buf, render_area.x + x, render_area.y + y, " ", g.style)
		}
	}

	// Calculate filled width
	width := f64(render_area.width)
	filled_f := g.ratio * width
	filled := int(filled_f)
	fraction := filled_f - f64(filled)

	// Render gauge bar
	for y in 0 ..< render_area.height {
		// Full blocks
		for x in 0 ..< u16(filled) {
			tui.buffer_set_cell(
				buf,
				render_area.x + x,
				render_area.y + y,
				tui.BAR_FULL,
				g.gauge_style,
			)
		}

		// Partial block (unicode)
		if g.use_unicode && filled < int(render_area.width) && fraction > 0.0 {
			idx := int(fraction * 8.0)
			if idx > 0 && idx <= 8 {
				symbol := tui.GAUGE_BLOCKS[idx - 1]
				tui.buffer_set_cell(
					buf,
					render_area.x + u16(filled),
					render_area.y + y,
					symbol,
					g.gauge_style,
				)
			}
		}
	}

	// Render label centered
	if label, ok := g.label.?; ok && len(label) > 0 {
		label_width := u16(tui.text_width(label))
		if label_width <= render_area.width {
			label_x := render_area.x + (render_area.width - label_width) / 2
			label_y := render_area.y + render_area.height / 2

			// Determine style for each character based on position
			x_offset := u16(0)
			for r in label {
				char_x := label_x + x_offset

				// Use gauge_style if in filled area, otherwise style
				char_style := g.style
				if char_x < render_area.x + u16(filled) {
					char_style = g.gauge_style
				} else if g.use_unicode &&
				   char_x == render_area.x + u16(filled) &&
				   fraction > 0.5 {
					char_style = g.gauge_style
				}

				tui.buffer_set_cell(buf, char_x, label_y, tui.rune_to_string(r), char_style)
				x_offset += 1
			}
		}
	}
}
