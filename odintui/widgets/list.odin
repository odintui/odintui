package odintui_widgets

import tui ".."

List_Direction :: enum {
	Top_To_Bottom,
	Bottom_To_Top,
}

// List_Item represents a single item in a list.
List_Item :: struct {
	content: tui.Text,
	style:   tui.Style,
}

list_item_new :: proc(text: tui.Text) -> List_Item {
	return List_Item{content = text, style = tui.style_default()}
}

list_item_from_string :: proc(s: string) -> List_Item {
	return List_Item{content = tui.text_from_string(s), style = tui.style_default()}
}

list_item_style :: proc(i: List_Item, s: tui.Style) -> List_Item {
	i := i
	i.style = s
	return i
}

// List displays a scrollable list of items with optional selection.
// Mirrors ratatui::widgets::List.
List :: struct {
	items:            []List_Item,
	block:            Maybe(Block),
	style:            tui.Style,
	highlight_style:  tui.Style,
	highlight_symbol: string,
	repeat_highlight: bool,
	direction:        List_Direction,
	scroll_padding:   uint,
}

list_new :: proc(items: []List_Item) -> List {
	return List {
		items = items,
		style = tui.style_default(),
		highlight_style = tui.style_default(),
		highlight_symbol = "",
		repeat_highlight = true,
		direction = .Top_To_Bottom,
		scroll_padding = 0,
	}
}

list_block :: proc(l: List, b: Block) -> List {
	l := l
	l.block = b
	return l
}

list_style :: proc(l: List, s: tui.Style) -> List {
	l := l
	l.style = s
	return l
}

list_highlight_style :: proc(l: List, s: tui.Style) -> List {
	l := l
	l.highlight_style = s
	return l
}

list_highlight_symbol :: proc(l: List, sym: string) -> List {
	l := l
	l.highlight_symbol = sym
	return l
}

list_repeat_highlight_symbol :: proc(l: List, v: bool) -> List {
	l := l
	l.repeat_highlight = v
	return l
}

list_direction :: proc(l: List, d: List_Direction) -> List {
	l := l
	l.direction = d
	return l
}

list_scroll_padding :: proc(l: List, n: uint) -> List {
	l := l
	l.scroll_padding = n
	return l
}

list_len :: proc(l: List) -> int {
	return len(l.items)
}

list_is_empty :: proc(l: List) -> bool {
	return len(l.items) == 0
}

// List_State tracks scroll offset and selection.
List_State :: struct {
	offset:   int,
	selected: Maybe(int),
}

list_state_new :: proc() -> List_State {
	return List_State{}
}

list_state_select :: proc(state: ^List_State, idx: Maybe(int)) {
	state.selected = idx
}

list_state_selected :: proc(state: ^List_State) -> Maybe(int) {
	return state.selected
}

list_widget :: proc(l: ^List, state: ^List_State) -> tui.Widget {
	// Allocate widget data on heap
	data := new(List_Widget_Data)
	data.list = l
	data.state = state
	return tui.Widget{data = data, render = list_render}
}

@(private)
List_Widget_Data :: struct {
	list:  ^List,
	state: ^List_State,
}

@(private)
list_render :: proc(widget: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
	data := cast(^List_Widget_Data)widget
	l := data.list
	state := data.state

	render_area := area
	if block, ok := l.block.?; ok {
		block_render(&block, area, buf)
		render_area = block_inner(&block, area)
	}

	if render_area.width < 1 || render_area.height < 1 {
		return
	}
	if len(l.items) == 0 {
		return
	}

	// Adjust offset based on selected and scroll_padding
	if selected, ok := state.selected.?; ok {
		height := int(render_area.height)
		padding := int(l.scroll_padding)

		// Scroll down if selected is below visible area
		if selected >= state.offset + height - padding {
			state.offset = selected - height + padding + 1
		}

		// Scroll up if selected is above visible area
		if selected < state.offset + padding {
			state.offset = selected - padding
		}

		// Clamp offset
		state.offset = clamp(state.offset, 0, max(len(l.items) - height, 0))
	}

	// Determine visible range
	start_idx := state.offset
	end_idx := min(state.offset + int(render_area.height), len(l.items))

	// Render items
	symbol_width := u16(tui.text_width(l.highlight_symbol))

	for i in start_idx ..< end_idx {
		row := u16(i - start_idx)
		if row >= render_area.height {
			break
		}

		y := render_area.y + row
		item := l.items[i]

		// Determine if this item is selected
		is_selected := false
		if selected, ok := state.selected.?; ok {
			is_selected = (i == selected)
		}

		// Render highlight symbol
		x := render_area.x
		if is_selected && len(l.highlight_symbol) > 0 {
			x_offset := u16(0)
			for r in l.highlight_symbol {
				if x + x_offset >= render_area.x + render_area.width {
					break
				}
				tui.buffer_set_cell(buf, x + x_offset, y, tui.rune_to_string(r), l.highlight_style)
				x_offset += 1
			}
			x += symbol_width
		} else if l.repeat_highlight && len(l.highlight_symbol) > 0 {
			// Add spacing for alignment
			x += symbol_width
		}

		// Render item content
		item_style := item.style
		if is_selected {
			item_style = l.highlight_style
		}

		content_width := render_area.width
		if x > render_area.x {
			content_width = render_area.x + render_area.width - x
		}

		// Render text content
		text_x := x
		for line in item.content.lines {
			if text_x >= render_area.x + render_area.width {
				break
			}

			for span in line.spans {
				span_style := item_style
				if span.style.fg != nil || span.style.bg != nil || span.style.add_modifier != {} {
					span_style = span.style
				}

				for r in span.content {
					if text_x >= render_area.x + render_area.width {
						break
					}
					tui.buffer_set_cell(buf, text_x, y, tui.rune_to_string(r), span_style)
					text_x += 1
				}
			}
		}

		// Fill remaining space with style
		for text_x < render_area.x + render_area.width {
			tui.buffer_set_cell(buf, text_x, y, " ", item_style)
			text_x += 1
		}
	}
}
