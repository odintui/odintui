package odintui_widgets

import tui ".."

// Table_Cell represents a single cell in a table.
Table_Cell :: struct {
	content: tui.Text,
	style:   tui.Style,
}

table_cell_new :: proc(content: tui.Text) -> Table_Cell {
	return Table_Cell{content = content, style = tui.style_default()}
}

table_cell_from_string :: proc(s: string) -> Table_Cell {
	return Table_Cell{content = tui.text_from_string(s), style = tui.style_default()}
}

table_cell_style :: proc(c: Table_Cell, s: tui.Style) -> Table_Cell {
	c := c
	c.style = s
	return c
}

// Table_Row represents a row in a table.
Table_Row :: struct {
	cells:         []Table_Cell,
	style:         tui.Style,
	height:        u16,
	top_margin:    u16,
	bottom_margin: u16,
}

table_row_new :: proc(cells: []Table_Cell) -> Table_Row {
	return Table_Row{cells = cells, style = tui.style_default(), height = 1}
}

table_row_style :: proc(r: Table_Row, s: tui.Style) -> Table_Row {
	r := r
	r.style = s
	return r
}

table_row_height :: proc(r: Table_Row, h: u16) -> Table_Row {
	r := r
	r.height = max(h, 1)
	return r
}

table_row_top_margin :: proc(r: Table_Row, m: u16) -> Table_Row {
	r := r
	r.top_margin = m
	return r
}

table_row_bottom_margin :: proc(r: Table_Row, m: u16) -> Table_Row {
	r := r
	r.bottom_margin = m
	return r
}

// Table displays data in rows and columns with optional header/footer.
// Mirrors ratatui::widgets::Table.
Table :: struct {
	rows:                []Table_Row,
	header:              Maybe(Table_Row),
	footer:              Maybe(Table_Row),
	widths:              []tui.Constraint,
	column_spacing:      u16,
	style:               tui.Style,
	block:               Maybe(Block),
	row_highlight_style: tui.Style,
	highlight_symbol:    string,
}

table_new :: proc(rows: []Table_Row, widths: []tui.Constraint) -> Table {
	return Table {
		rows = rows,
		widths = widths,
		column_spacing = 1,
		style = tui.style_default(),
		row_highlight_style = tui.style_default(),
		highlight_symbol = "",
	}
}

table_header :: proc(t: Table, h: Table_Row) -> Table {
	t := t
	t.header = h
	return t
}

table_footer :: proc(t: Table, f: Table_Row) -> Table {
	t := t
	t.footer = f
	return t
}

table_widths :: proc(t: Table, w: []tui.Constraint) -> Table {
	t := t
	t.widths = w
	return t
}

table_column_spacing :: proc(t: Table, s: u16) -> Table {
	t := t
	t.column_spacing = s
	return t
}

table_style :: proc(t: Table, s: tui.Style) -> Table {
	t := t
	t.style = s
	return t
}

table_block :: proc(t: Table, b: Block) -> Table {
	t := t
	t.block = b
	return t
}

table_row_highlight_style :: proc(t: Table, s: tui.Style) -> Table {
	t := t
	t.row_highlight_style = s
	return t
}

table_highlight_symbol :: proc(t: Table, sym: string) -> Table {
	t := t
	t.highlight_symbol = sym
	return t
}

// Table_State tracks scroll offset and selection.
Table_State :: struct {
	offset:          int,
	selected:        Maybe(int),
	selected_column: Maybe(int),
}

table_state_new :: proc() -> Table_State {
	return Table_State{}
}

table_state_select :: proc(state: ^Table_State, idx: Maybe(int)) {
	state.selected = idx
}

table_state_selected :: proc(state: ^Table_State) -> Maybe(int) {
	return state.selected
}

table_widget :: proc(t: ^Table, state: ^Table_State) -> tui.Widget {
	// Allocate widget data on heap
	data := new(Table_Widget_Data)
	data.table = t
	data.state = state
	return tui.Widget{data = data, render = table_render}
}

@(private)
Table_Widget_Data :: struct {
	table: ^Table,
	state: ^Table_State,
}

@(private)
table_render :: proc(widget: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
	data := cast(^Table_Widget_Data)widget
	t := data.table
	state := data.state

	render_area := area
	if block, ok := t.block.?; ok {
		block_render(&block, area, buf)
		render_area = block_inner(&block, area)
	}

	if render_area.width < 1 || render_area.height < 1 {
		return
	}

	// Fill background
	for y in 0 ..< render_area.height {
		for x in 0 ..< render_area.width {
			tui.buffer_set_cell(buf, render_area.x + x, render_area.y + y, " ", t.style)
		}
	}

	// Calculate column widths
	if len(t.widths) == 0 {
		return
	}

	// Calculate total spacing
	num_cols := len(t.widths)
	total_spacing := t.column_spacing * u16(max(num_cols - 1, 0))

	// Create layout for columns
	available_width := render_area.width
	if total_spacing >= available_width {
		return
	}

	layout := tui.layout_horizontal(t.widths)
	layout = tui.layout_with_spacing(layout, t.column_spacing)

	column_areas := tui.layout_split(layout, render_area, context.temp_allocator)
	defer delete(column_areas, context.temp_allocator)

	current_y := render_area.y

	// Render header
	header_height := u16(0)
	if header, ok := t.header.?; ok {
		row_height := header.height + header.top_margin + header.bottom_margin
		if current_y + row_height <= render_area.y + render_area.height {
			table_render_row(buf, &header, column_areas, current_y, row_height, false, "", t.style)
			current_y += row_height
			header_height = row_height
		}
	}

	// Calculate footer height
	footer_height := u16(0)
	if footer, ok := t.footer.?; ok {
		footer_height = footer.height + footer.top_margin + footer.bottom_margin
	}

	// Calculate available height for rows
	rows_area_height := render_area.height - header_height - footer_height
	if rows_area_height == 0 {
		return
	}

	// Adjust offset based on selection
	if selected, ok := state.selected.?; ok {
		// Calculate cumulative heights to determine visible range
		visible_height := int(rows_area_height)

		// Simple scroll: ensure selected row is visible
		if selected < state.offset {
			state.offset = selected
		} else if selected >= state.offset + visible_height {
			state.offset = selected - visible_height + 1
		}

		state.offset = clamp(state.offset, 0, max(len(t.rows) - 1, 0))
	}

	// Render visible rows
	row_y := current_y
	for i in state.offset ..< len(t.rows) {
		if row_y >= render_area.y + render_area.height - footer_height {
			break
		}

		row := &t.rows[i]
		row_height := row.height + row.top_margin + row.bottom_margin

		if row_y + row_height > render_area.y + render_area.height - footer_height {
			break
		}

		is_selected := false
		if selected, ok := state.selected.?; ok {
			is_selected = (i == selected)
		}

		table_render_row(
			buf,
			row,
			column_areas,
			row_y,
			row_height,
			is_selected,
			t.highlight_symbol,
			t.row_highlight_style,
		)

		row_y += row_height
	}

	// Render footer
	if footer, ok := t.footer.?; ok {
		footer_y := render_area.y + render_area.height - footer_height
		if footer_y >= current_y {
			table_render_row(
				buf,
				&footer,
				column_areas,
				footer_y,
				footer_height,
				false,
				"",
				t.style,
			)
		}
	}
}

@(private)
table_render_row :: proc(
	buf: ^tui.Buffer,
	row: ^Table_Row,
	column_areas: []tui.Rect,
	y: u16,
	total_height: u16,
	is_selected: bool,
	highlight_symbol: string,
	highlight_style: tui.Style,
) {
	content_y := y + row.top_margin
	content_height := row.height

	row_style := row.style
	if is_selected {
		row_style = highlight_style
	}

	// Render highlight symbol if selected
	symbol_width := u16(0)
	if is_selected && len(highlight_symbol) > 0 && len(column_areas) > 0 {
		symbol_width = u16(tui.text_width(highlight_symbol))
		first_col := column_areas[0]

		x_offset := u16(0)
		for r in highlight_symbol {
			if first_col.x + x_offset >= first_col.x + first_col.width {
				break
			}
			tui.buffer_set_cell(
				buf,
				first_col.x + x_offset,
				content_y,
				tui.rune_to_string(r),
				highlight_style,
			)
			x_offset += 1
		}
	}

	// Render cells
	for cell, col_idx in row.cells {
		if col_idx >= len(column_areas) {
			break
		}

		col_area := column_areas[col_idx]

		// Adjust first column for highlight symbol
		if col_idx == 0 && symbol_width > 0 {
			if symbol_width >= col_area.width {
				continue
			}
			col_area.x += symbol_width
			col_area.width -= symbol_width
		}

		cell_style := cell.style
		if is_selected {
			cell_style = highlight_style
		}

		// Render cell content
		cell_x := col_area.x
		for line_idx in 0 ..< int(content_height) {
			if line_idx >= len(cell.content.lines) {
				break
			}

			line := cell.content.lines[line_idx]
			line_y := content_y + u16(line_idx)

			if line_y >= content_y + content_height {
				break
			}

			x := cell_x
			for span in line.spans {
				span_style := cell_style
				if span.style.fg != nil || span.style.bg != nil || span.style.add_modifier != {} {
					span_style = span.style
				}

				for r in span.content {
					if x >= col_area.x + col_area.width {
						break
					}
					tui.buffer_set_cell(buf, x, line_y, tui.rune_to_string(r), span_style)
					x += 1
				}
			}

			// Fill remaining cell width
			for x < col_area.x + col_area.width {
				tui.buffer_set_cell(buf, x, line_y, " ", cell_style)
				x += 1
			}
		}
	}
}
