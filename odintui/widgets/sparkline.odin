package odintui_widgets

import tui ".."

Sparkline_Direction :: enum {
	Left_To_Right,
	Right_To_Left,
}

// Sparkline displays a compact bar chart.
// Mirrors ratatui::widgets::Sparkline.
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
	return Sparkline {
		bar_set = tui.NINE_LEVELS,
		style = tui.style_default(),
		absent_value_style = tui.style_default(),
		absent_value_symbol = " ",
		direction = .Left_To_Right,
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

sparkline_max :: proc(s: Sparkline, max: u64) -> Sparkline {
	s := s
	s.max = max
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

sparkline_absent_value_style :: proc(s: Sparkline, st: tui.Style) -> Sparkline {
	s := s
	s.absent_value_style = st
	return s
}

sparkline_absent_value_symbol :: proc(s: Sparkline, sym: string) -> Sparkline {
	s := s
	s.absent_value_symbol = sym
	return s
}

sparkline_direction :: proc(s: Sparkline, d: Sparkline_Direction) -> Sparkline {
	s := s
	s.direction = d
	return s
}

sparkline_widget :: proc(s: ^Sparkline) -> tui.Widget {
	return tui.Widget{data = s, render = sparkline_render}
}

@(private)
sparkline_render :: proc(widget: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
	s := cast(^Sparkline)widget

	render_area := area
	if block, ok := s.block.?; ok {
		block_render(&block, area, buf)
		render_area = block_inner(&block, area)
	}

	if render_area.width < 1 || render_area.height < 1 {
		return
	}
	if len(s.data) == 0 {
		return
	}

	// Determine max value
	max_val := u64(0)
	if m, ok := s.max.?; ok {
		max_val = m
	} else {
		for v in s.data {
			if v > max_val {
				max_val = v
			}
		}
	}

	if max_val == 0 {
		max_val = 1 // avoid division by zero
	}

	// Bar set has 9 levels (full, seven, six, five, four, three, two, one, empty)
	levels := 8 // 0-7 index into bar symbols

	// Render sparkline
	width := int(render_area.width)
	data_len := len(s.data)

	for col in 0 ..< width {
		if col >= data_len {
			break
		}

		// Get data index based on direction
		data_idx := col
		if s.direction == .Right_To_Left {
			data_idx = data_len - 1 - col
		}

		value := s.data[data_idx]

		// Calculate bar level (0-8)
		level := int((f64(value) / f64(max_val)) * f64(levels))
		level = clamp(level, 0, levels)

		// Select symbol
		symbol := ""
		bar_style := s.style

		switch level {
		case 8:
			symbol = s.bar_set.full
		case 7:
			symbol = s.bar_set.seven
		case 6:
			symbol = s.bar_set.six
		case 5:
			symbol = s.bar_set.five
		case 4:
			symbol = s.bar_set.four
		case 3:
			symbol = s.bar_set.three
		case 2:
			symbol = s.bar_set.two
		case 1:
			symbol = s.bar_set.one
		case 0:
			symbol = s.absent_value_symbol
			bar_style = s.absent_value_style
		}

		// Render for all rows in height
		for row in 0 ..< render_area.height {
			tui.buffer_set_cell(
				buf,
				render_area.x + u16(col),
				render_area.y + row,
				symbol,
				bar_style,
			)
		}
	}
}
