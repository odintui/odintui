package odintui_widgets

import tui ".."

Bar_Direction :: enum {
	Vertical,
	Horizontal,
}

// Bar represents a single bar in a bar chart.
Bar :: struct {
	label:       string,
	value:       u64,
	text_value:  string,
	style:       tui.Style,
	value_style: tui.Style,
	label_style: tui.Style,
}

bar_new :: proc(label: string, value: u64) -> Bar {
	return Bar {
		label = label,
		value = value,
		text_value = "",
		style = tui.style_default(),
		value_style = tui.style_default(),
		label_style = tui.style_default(),
	}
}

bar_text_value :: proc(b: Bar, s: string) -> Bar {
	b := b
	b.text_value = s
	return b
}

bar_style :: proc(b: Bar, s: tui.Style) -> Bar {
	b := b
	b.style = s
	return b
}

bar_value_style :: proc(b: Bar, s: tui.Style) -> Bar {
	b := b
	b.value_style = s
	return b
}

bar_label_style :: proc(b: Bar, s: tui.Style) -> Bar {
	b := b
	b.label_style = s
	return b
}

// Bar_Group represents a group of bars.
Bar_Group :: struct {
	label: string,
	bars:  []Bar,
}

bar_group_new :: proc(bars: []Bar) -> Bar_Group {
	return Bar_Group{label = "", bars = bars}
}

bar_group_label :: proc(g: Bar_Group, label: string) -> Bar_Group {
	g := g
	g.label = label
	return g
}

// Bar_Chart displays data as vertical or horizontal bars.
// Mirrors ratatui::widgets::BarChart.
Bar_Chart :: struct {
	block:       Maybe(Block),
	bar_width:   u16,
	bar_gap:     u16,
	group_gap:   u16,
	bar_set:     tui.Bar_Set,
	bar_style:   tui.Style,
	value_style: tui.Style,
	label_style: tui.Style,
	style:       tui.Style,
	max:         Maybe(u64),
	direction:   Bar_Direction,
	groups:      []Bar_Group,
}

bar_chart_new :: proc(groups: []Bar_Group) -> Bar_Chart {
	return Bar_Chart {
		bar_width = 3,
		bar_gap = 1,
		group_gap = 1,
		bar_set = tui.NINE_LEVELS,
		bar_style = tui.style_default(),
		value_style = tui.style_default(),
		label_style = tui.style_default(),
		style = tui.style_default(),
		direction = .Vertical,
		groups = groups,
	}
}

bar_chart_vertical :: proc(groups: []Bar_Group) -> Bar_Chart {
	chart := bar_chart_new(groups)
	return bar_chart_direction(chart, .Vertical)
}

bar_chart_horizontal :: proc(groups: []Bar_Group) -> Bar_Chart {
	chart := bar_chart_new(groups)
	return bar_chart_direction(chart, .Horizontal)
}

bar_chart_block :: proc(c: Bar_Chart, b: Block) -> Bar_Chart {
	c := c
	c.block = b
	return c
}

bar_chart_bar_width :: proc(c: Bar_Chart, w: u16) -> Bar_Chart {
	c := c
	c.bar_width = max(w, 1)
	return c
}

bar_chart_bar_gap :: proc(c: Bar_Chart, g: u16) -> Bar_Chart {
	c := c
	c.bar_gap = g
	return c
}

bar_chart_group_gap :: proc(c: Bar_Chart, g: u16) -> Bar_Chart {
	c := c
	c.group_gap = g
	return c
}

bar_chart_bar_set :: proc(c: Bar_Chart, bs: tui.Bar_Set) -> Bar_Chart {
	c := c
	c.bar_set = bs
	return c
}

bar_chart_bar_style :: proc(c: Bar_Chart, s: tui.Style) -> Bar_Chart {
	c := c
	c.bar_style = s
	return c
}

bar_chart_value_style :: proc(c: Bar_Chart, s: tui.Style) -> Bar_Chart {
	c := c
	c.value_style = s
	return c
}

bar_chart_label_style :: proc(c: Bar_Chart, s: tui.Style) -> Bar_Chart {
	c := c
	c.label_style = s
	return c
}

bar_chart_style :: proc(c: Bar_Chart, s: tui.Style) -> Bar_Chart {
	c := c
	c.style = s
	return c
}

bar_chart_max :: proc(c: Bar_Chart, m: u64) -> Bar_Chart {
	c := c
	c.max = m
	return c
}

bar_chart_direction :: proc(c: Bar_Chart, d: Bar_Direction) -> Bar_Chart {
	c := c
	c.direction = d
	return c
}

bar_chart_widget :: proc(c: ^Bar_Chart) -> tui.Widget {
	return tui.Widget{data = c, render = bar_chart_render}
}

@(private)
bar_chart_render :: proc(widget: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
	c := cast(^Bar_Chart)widget

	render_area := area
	if block, ok := c.block.?; ok {
		block_render(&block, area, buf)
		render_area = block_inner(&block, area)
	}

	if render_area.width < 1 || render_area.height < 1 {
		return
	}
	if len(c.groups) == 0 {
		return
	}

	// Fill background
	for y in 0 ..< render_area.height {
		for x in 0 ..< render_area.width {
			tui.buffer_set_cell(buf, render_area.x + x, render_area.y + y, " ", c.style)
		}
	}

	// Determine max value
	max_val := u64(0)
	if m, ok := c.max.?; ok {
		max_val = m
	} else {
		for group in c.groups {
			for bar in group.bars {
				if bar.value > max_val {
					max_val = bar.value
				}
			}
		}
	}

	if max_val == 0 {
		max_val = 1
	}

	if c.direction == .Vertical {
		bar_chart_render_vertical(c, render_area, buf, max_val)
	} else {
		bar_chart_render_horizontal(c, render_area, buf, max_val)
	}
}

@(private)
bar_chart_render_vertical :: proc(c: ^Bar_Chart, area: tui.Rect, buf: ^tui.Buffer, max_val: u64) {
	// Calculate total bars
	total_bars := 0
	for group in c.groups {
		total_bars += len(group.bars)
	}

	if total_bars == 0 {
		return
	}

	// Calculate required width
	total_width :=
		u16(total_bars) * c.bar_width +
		u16(max(total_bars - 1, 0)) * c.bar_gap +
		u16(max(len(c.groups) - 1, 0)) * c.group_gap

	if total_width > area.width {
		return // Not enough space
	}

	// Reserve space for labels (1 row at bottom)
	chart_height := area.height
	if chart_height > 1 {
		chart_height -= 1
	}

	x := area.x
	for group, group_idx in c.groups {
		for bar, bar_idx in group.bars {
			if x + c.bar_width > area.x + area.width {
				break
			}

			// Calculate bar height
			bar_height := u16((f64(bar.value) / f64(max_val)) * f64(chart_height))
			bar_height = min(bar_height, chart_height)

			// Render bar
			bar_y := area.y + chart_height - bar_height
			for dy in 0 ..< bar_height {
				for dx in 0 ..< c.bar_width {
					if x + dx < area.x + area.width {
						bar_style := bar.style
						if bar_style.fg == nil && bar_style.bg == nil {
							bar_style = c.bar_style
						}

						tui.buffer_set_cell(buf, x + dx, bar_y + dy, tui.BAR_FULL, bar_style)
					}
				}
			}

			// Render value on top of bar
			value_text := bar.text_value
			if len(value_text) == 0 {
				// Format value as string
				value_text = tui.format_u64(bar.value)
			}

			value_width := u16(tui.text_width(value_text))
			if value_width <= c.bar_width && bar_height > 0 {
				value_x := x + (c.bar_width - value_width) / 2
				value_y := bar_y

				x_offset := u16(0)
				for r in value_text {
					if value_x + x_offset < area.x + area.width {
						tui.buffer_set_cell(
							buf,
							value_x + x_offset,
							value_y,
							tui.rune_to_string(r),
							bar.value_style,
						)
					}
					x_offset += 1
				}
			}

			// Render label at bottom
			label_width := u16(tui.text_width(bar.label))
			if label_width <= c.bar_width {
				label_x := x + (c.bar_width - label_width) / 2
				label_y := area.y + area.height - 1

				x_offset := u16(0)
				for r in bar.label {
					if label_x + x_offset < area.x + area.width {
						tui.buffer_set_cell(
							buf,
							label_x + x_offset,
							label_y,
							tui.rune_to_string(r),
							bar.label_style,
						)
					}
					x_offset += 1
				}
			}

			x += c.bar_width + c.bar_gap
		}

		// Add group gap
		if group_idx < len(c.groups) - 1 {
			x += c.group_gap
		}
	}
}

@(private)
bar_chart_render_horizontal :: proc(
	c: ^Bar_Chart,
	area: tui.Rect,
	buf: ^tui.Buffer,
	max_val: u64,
) {
	// Calculate total bars
	total_bars := 0
	for group in c.groups {
		total_bars += len(group.bars)
	}

	if total_bars == 0 {
		return
	}

	// Calculate required height
	total_height :=
		u16(total_bars) * c.bar_width +
		u16(max(total_bars - 1, 0)) * c.bar_gap +
		u16(max(len(c.groups) - 1, 0)) * c.group_gap

	if total_height > area.height {
		return // Not enough space
	}

	y := area.y
	for group, group_idx in c.groups {
		for bar in group.bars {
			if y + c.bar_width > area.y + area.height {
				break
			}

			// Calculate bar width
			bar_width := u16((f64(bar.value) / f64(max_val)) * f64(area.width))
			bar_width = min(bar_width, area.width)

			// Render bar
			for dy in 0 ..< c.bar_width {
				for dx in 0 ..< bar_width {
					if area.x + dx < area.x + area.width {
						bar_style := bar.style
						if bar_style.fg == nil && bar_style.bg == nil {
							bar_style = c.bar_style
						}

						tui.buffer_set_cell(buf, area.x + dx, y + dy, tui.BAR_FULL, bar_style)
					}
				}
			}

			y += c.bar_width + c.bar_gap
		}

		// Add group gap
		if group_idx < len(c.groups) - 1 {
			y += c.group_gap
		}
	}
}
