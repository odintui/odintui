package odintui_widgets

import tui ".."

// Tabs displays a horizontal tab bar with selectable items.
// Mirrors ratatui::widgets::Tabs.
Tabs :: struct {
	titles:          []string,
	selected:        int,
	block:           Maybe(Block),
	style:           tui.Style,
	highlight_style: tui.Style,
	divider:         string,
}

tabs_new :: proc(titles: []string) -> Tabs {
	return Tabs {
		titles = titles,
		selected = 0,
		style = tui.style_default(),
		highlight_style = tui.style_default(),
		divider = " | ",
	}
}

tabs_select :: proc(t: Tabs, idx: int) -> Tabs {
	t := t
	t.selected = clamp(idx, 0, len(t.titles) - 1)
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

tabs_widget :: proc(t: ^Tabs) -> tui.Widget {
	return tui.Widget{variant = t, render = tabs_render}
}

@(private)
tabs_render :: proc(widget: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
	t := cast(^Tabs)widget

	render_area := area
	if block, ok := t.block.?; ok {
		block_render(&block, area, buf)
		render_area = block_inner(block, area)
	}

	if render_area.width < 1 || render_area.height < 1 {
		return
	}
	if len(t.titles) == 0 {
		return
	}

	// Fill background
	for y in 0 ..< render_area.height {
		for x in 0 ..< render_area.width {
			tui.buffer_set_cell(buf, render_area.x + x, render_area.y + y, " ", t.style)
		}
	}

	// Render tabs horizontally
	x := render_area.x
	y := render_area.y
	divider_width := u16(tui.text_width(t.divider))

	for i in 0 ..< len(t.titles) {
		if x >= render_area.x + render_area.width {
			break
		}

		title := t.titles[i]
		title_width := u16(tui.text_width(title))

		// Check if we have space for this title
		if x + title_width > render_area.x + render_area.width {
			break
		}

		// Select style
		tab_style := t.style
		if i == t.selected {
			tab_style = t.highlight_style
		}

		// Render title
		x_offset := u16(0)
		for r in title {
			if x + x_offset >= render_area.x + render_area.width {
				break
			}
			tui.buffer_set_cell(buf, x + x_offset, y, tui.rune_to_string(r), tab_style)
			x_offset += 1
		}
		x += title_width

		// Render divider (except after last tab)
		if i < len(t.titles) - 1 {
			if x + divider_width <= render_area.x + render_area.width {
				div_offset := u16(0)
				for r in t.divider {
					if x + div_offset >= render_area.x + render_area.width {
						break
					}
					tui.buffer_set_cell(buf, x + div_offset, y, tui.rune_to_string(r), t.style)
					div_offset += 1
				}
				x += divider_width
			}
		}
	}
}
