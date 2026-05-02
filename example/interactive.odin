package main

import tui "../odintui"
import w "../odintui/widgets"
import "core:fmt"

App_State :: struct {
	should_quit:  bool,
	selected_tab: int,
	list_state:   w.List_State,
	table_state:  w.Table_State,
	message:      string,
}

main :: proc() {
	term := tui.init()
	defer tui.restore(&term)

	// Initialize app state
	app := App_State {
		selected_tab = 0,
		list_state   = w.list_state_new(),
		table_state  = w.table_state_new(),
		message      = "Press hjkl or arrows to navigate, Tab to switch tabs, q to quit",
	}

	w.list_state_select(&app.list_state, 0)
	w.table_state_select(&app.table_state, 0)

	// Run event loop with terminal_run
	tui.terminal_run(
		&term,
		draw_ui,
		handle_event_wrapper,
		&app,
		60, // 60 FPS
	)
}

// Wrapper to convert Event_Handler signature
handle_event_wrapper :: proc(event: tui.Event, user_data: rawptr) -> bool {
	app := cast(^App_State)user_data
	handle_event(app, event)
	return !app.should_quit
}

draw_ui :: proc(f: ^tui.Frame, user_data: rawptr) {
	app := cast(^App_State)user_data
	area := tui.frame_size(f)

	// Main layout
	layout := tui.layout_vertical(
	[]tui.Constraint {
		tui.Constraint_Length(3), // Tabs
		tui.Constraint_Min(10), // Content
		tui.Constraint_Length(3), // Status bar
	},
	)
	rects := tui.layout_split(layout, area)
	defer delete(rects)

	// Tabs
	tabs := w.tabs_new([]string{"List Demo", "Table Demo", "Help"})
	tabs = w.tabs_select(tabs, app.selected_tab)
	tabs = w.tabs_highlight_style(tabs, tui.style_with_fg(tui.Color_Cyan{}))

	tabs_block := w.block_new()
	tabs_block = w.block_borders(tabs_block, w.BORDERS_ALL)
	tabs = w.tabs_block(tabs, tabs_block)

	tui.frame_render_widget(f, w.tabs_widget(&tabs), rects[0])

	// Content based on selected tab
	switch app.selected_tab {
	case 0:
		draw_list_demo(f, app, rects[1])
	case 1:
		draw_table_demo(f, app, rects[1])
	case 2:
		draw_help(f, rects[1])
	}

	// Status bar
	status_text := tui.text_from_string(app.message)
	status_para := w.paragraph_new(status_text)

	status_block := w.block_new()
	status_block = w.block_borders(status_block, w.BORDERS_ALL)
	status_para = w.paragraph_block(status_para, status_block)

	tui.frame_render_widget(f, w.paragraph_widget(&status_para), rects[2])
}

draw_list_demo :: proc(f: ^tui.Frame, app: ^App_State, area: tui.Rect) {
	items := []w.List_Item {
		w.list_item_from_string("Item 1 - Press Enter to select"),
		w.list_item_from_string("Item 2 - Use hjkl or arrows"),
		w.list_item_from_string("Item 3 - Press Tab to switch tabs"),
		w.list_item_from_string("Item 4 - Press q to quit"),
		w.list_item_from_string("Item 5 - More items..."),
		w.list_item_from_string("Item 6"),
		w.list_item_from_string("Item 7"),
		w.list_item_from_string("Item 8"),
		w.list_item_from_string("Item 9"),
		w.list_item_from_string("Item 10"),
	}

	list := w.list_new(items)
	list = w.list_highlight_style(list, tui.style_with_fg(tui.Color_Green{}))
	list = w.list_highlight_symbol(list, ">> ")
	list = w.list_scroll_padding(list, 2)

	list_block := w.block_new()
	list_block = w.block_title(list_block, " List Navigation Demo ")
	list_block = w.block_borders(list_block, w.BORDERS_ALL)
	list = w.list_block(list, list_block)

	tui.frame_render_widget(f, w.list_widget(&list, &app.list_state), area)
}

draw_table_demo :: proc(f: ^tui.Frame, app: ^App_State, area: tui.Rect) {
	// Header
	header_cells := []w.Table_Cell {
		w.table_cell_from_string("ID"),
		w.table_cell_from_string("Name"),
		w.table_cell_from_string("Status"),
		w.table_cell_from_string("Value"),
	}
	header := w.table_row_new(header_cells)
	header = w.table_row_style(header, tui.style_with_fg(tui.Color_Yellow{}))

	// Rows
	rows := []w.Table_Row {
		w.table_row_new(
			[]w.Table_Cell {
				w.table_cell_from_string("1"),
				w.table_cell_from_string("Alpha"),
				w.table_cell_from_string("Active"),
				w.table_cell_from_string("100"),
			},
		),
		w.table_row_new(
			[]w.Table_Cell {
				w.table_cell_from_string("2"),
				w.table_cell_from_string("Beta"),
				w.table_cell_from_string("Pending"),
				w.table_cell_from_string("250"),
			},
		),
		w.table_row_new(
			[]w.Table_Cell {
				w.table_cell_from_string("3"),
				w.table_cell_from_string("Gamma"),
				w.table_cell_from_string("Active"),
				w.table_cell_from_string("175"),
			},
		),
		w.table_row_new(
			[]w.Table_Cell {
				w.table_cell_from_string("4"),
				w.table_cell_from_string("Delta"),
				w.table_cell_from_string("Inactive"),
				w.table_cell_from_string("50"),
			},
		),
		w.table_row_new(
			[]w.Table_Cell {
				w.table_cell_from_string("5"),
				w.table_cell_from_string("Epsilon"),
				w.table_cell_from_string("Active"),
				w.table_cell_from_string("300"),
			},
		),
	}

	widths := []tui.Constraint {
		tui.Constraint_Length(6),
		tui.Constraint_Min(10),
		tui.Constraint_Length(12),
		tui.Constraint_Length(10),
	}

	table := w.table_new(rows, widths)
	table = w.table_header(table, header)
	table = w.table_row_highlight_style(table, tui.style_with_fg(tui.Color_Green{}))
	table = w.table_highlight_symbol(table, ">> ")

	table_block := w.block_new()
	table_block = w.block_title(table_block, " Table Navigation Demo ")
	table_block = w.block_borders(table_block, w.BORDERS_ALL)
	table = w.table_block(table, table_block)

	tui.frame_render_widget(f, w.table_widget(&table, &app.table_state), area)
}

draw_help :: proc(f: ^tui.Frame, area: tui.Rect) {
	help_text := `Keyboard Controls:

Navigation:
  h, ←     - Move up/left
  j, ↓     - Move down
  k, ↑     - Move up
  l, →     - Move down/right
  
  Tab      - Switch tabs
  Enter    - Select item
  
  q, Esc   - Quit

Mouse:
  Scroll   - Navigate lists/tables
  Click    - Select items (if supported)

This demo shows:
- Event handling (keyboard, mouse, resize)
- Stateful widgets (List, Table)
- Tab navigation
- Real-time UI updates`

	text := tui.text_from_string(help_text)
	para := w.paragraph_new(text)

	help_block := w.block_new()
	help_block = w.block_title(help_block, " Help ")
	help_block = w.block_borders(help_block, w.BORDERS_ALL)
	para = w.paragraph_block(para, help_block)

	tui.frame_render_widget(f, w.paragraph_widget(&para), area)
}

handle_event :: proc(app: ^App_State, event: tui.Event) {
	switch e in event {
	case tui.Key_Event:
		handle_key_event(app, e)
	case tui.Mouse_Event:
		handle_mouse_event(app, e)
	case tui.Resize_Event:
		app.message = fmt.tprintf("Terminal resized to %dx%d", e.width, e.height)
	case tui.Focus_Event:
		if e == .Gained {
			app.message = "Focus gained"
		} else {
			app.message = "Focus lost"
		}
	case tui.Paste_Event:
		app.message = fmt.tprintf("Pasted: %s", e.content)
	}
}

handle_key_event :: proc(app: ^App_State, event: tui.Key_Event) {
	// Global keys
	#partial switch code in event.code {
	case tui.Key_Char:
		c := rune(code)
		if c == 'q' {
			app.should_quit = true
			return
		}
	case tui.Key_Special:
		if code == .Esc {
			app.should_quit = true
			return
		}
		if code == .Tab {
			app.selected_tab = (app.selected_tab + 1) % 3
			app.message = fmt.tprintf("Switched to tab %d", app.selected_tab)
			return
		}
	}

	// Tab-specific keys
	switch app.selected_tab {
	case 0:
		// List demo
		handle_list_keys(app, event)
	case 1:
		// Table demo
		handle_table_keys(app, event)
	case 2: // Help
	// No navigation in help
	}
}

handle_list_keys :: proc(app: ^App_State, event: tui.Key_Event) {
	selected, has_selected := w.list_state_selected(&app.list_state).?
	if !has_selected {
		selected = 0
	}

	#partial switch code in event.code {
	case tui.Key_Char:
		c := rune(code)
		switch c {
		case 'j':
			w.list_state_select(&app.list_state, selected + 1)
			app.message = fmt.tprintf("Selected item %d", selected + 1)
		case 'k':
			if selected > 0 {
				w.list_state_select(&app.list_state, selected - 1)
				app.message = fmt.tprintf("Selected item %d", selected - 1)
			}
		}
	case tui.Key_Arrow:
		#partial switch code {
		case .Down:
			w.list_state_select(&app.list_state, selected + 1)
			app.message = fmt.tprintf("Selected item %d", selected + 1)
		case .Up:
			if selected > 0 {
				w.list_state_select(&app.list_state, selected - 1)
				app.message = fmt.tprintf("Selected item %d", selected - 1)
			}
		}
	case tui.Key_Special:
		if code == .Enter {
			app.message = fmt.tprintf("Activated item %d", selected)
		}
	case:
	// Other key types
	}
}

handle_table_keys :: proc(app: ^App_State, event: tui.Key_Event) {
	selected, has_selected := w.table_state_selected(&app.table_state).?
	if !has_selected {
		selected = 0
	}

	#partial switch code in event.code {
	case tui.Key_Char:
		c := rune(code)
		switch c {
		case 'j':
			w.table_state_select(&app.table_state, selected + 1)
			app.message = fmt.tprintf("Selected row %d", selected + 1)
		case 'k':
			if selected > 0 {
				w.table_state_select(&app.table_state, selected - 1)
				app.message = fmt.tprintf("Selected row %d", selected - 1)
			}
		}
	case tui.Key_Arrow:
		#partial switch code {
		case .Down:
			w.table_state_select(&app.table_state, selected + 1)
			app.message = fmt.tprintf("Selected row %d", selected + 1)
		case .Up:
			if selected > 0 {
				w.table_state_select(&app.table_state, selected - 1)
				app.message = fmt.tprintf("Selected row %d", selected - 1)
			}
		}
	case tui.Key_Special:
		if code == .Enter {
			app.message = fmt.tprintf("Activated row %d", selected)
		}
	case:
	// Other key types
	}
}

handle_mouse_event :: proc(app: ^App_State, event: tui.Mouse_Event) {
	switch event.kind {
	case .Down:
		app.message = fmt.tprintf("Mouse down at (%d, %d)", event.column, event.row)
	case .Up:
		app.message = fmt.tprintf("Mouse up at (%d, %d)", event.column, event.row)
	case .ScrollUp:
		app.message = "Mouse scroll up"
	// Could adjust list/table selection here
	case .ScrollDown:
		app.message = "Mouse scroll down"
	// Could adjust list/table selection here
	case .Moved:
	// Too noisy to show every move
	case .Drag:
		app.message = fmt.tprintf("Mouse drag at (%d, %d)", event.column, event.row)
	}
}
