package main

import tui "../odintui"
import w "../odintui/widgets"
import "core:fmt"
import "core:os"
import "core:sys/windows"

// Global state for demo
g_list_state: w.List_State
g_table_state: w.Table_State

main :: proc() {
	term := tui.init()
	defer tui.restore(&term)

	// Initialize state
	g_list_state = w.list_state_new()
	g_table_state = w.table_state_new()

	w.list_state_select(&g_list_state, 1)
	w.table_state_select(&g_table_state, 0)

	// Draw once
	tui.terminal_draw(
		&term,
		proc(f: ^tui.Frame) {
			area := tui.frame_size(f)

			// Main layout: vertical split
			main_layout := tui.layout_vertical(
				[]tui.Constraint {
					tui.Constraint_Length(3), // Tabs
					tui.Constraint_Length(5), // Gauges
					tui.Constraint_Length(5), // Sparkline
					tui.Constraint_Min(10), // Table
					tui.Constraint_Length(8), // List
				},
			)
			main_rects := tui.layout_split(main_layout, area)
			defer delete(main_rects)

			// 1. Tabs widget
			tabs := w.tabs_new([]string{"Main", "I/O", "Network", "GPU"})
			tabs = w.tabs_select(tabs, 0)
			tabs = w.tabs_highlight_style(tabs, tui.style_with_fg(tui.Color_Cyan{}))

			tabs_block := w.block_new()
			tabs_block = w.block_borders(tabs_block, w.BORDERS_ALL)
			tabs = w.tabs_block(tabs, tabs_block)

			tui.frame_render_widget(f, w.tabs_widget(&tabs), main_rects[0])

			// 2. Gauges (CPU, Memory, Disk)
			gauge_layout := tui.layout_horizontal(
				[]tui.Constraint {
					tui.Constraint_Percentage(33),
					tui.Constraint_Percentage(33),
					tui.Constraint_Percentage(34),
				},
			)
			gauge_rects := tui.layout_split(gauge_layout, main_rects[1])
			defer delete(gauge_rects)

			// CPU Gauge
			cpu_gauge := w.gauge_new()
			cpu_gauge = w.gauge_percent(cpu_gauge, 75)
			cpu_gauge = w.gauge_label(cpu_gauge, "CPU 75%")
			cpu_gauge = w.gauge_gauge_style(cpu_gauge, tui.style_with_fg(tui.Color_Green{}))
			cpu_gauge = w.gauge_use_unicode(cpu_gauge, true)

			cpu_block := w.block_new()
			cpu_block = w.block_title(cpu_block, " CPU ")
			cpu_block = w.block_borders(cpu_block, w.BORDERS_ALL)
			cpu_gauge = w.gauge_block(cpu_gauge, cpu_block)

			tui.frame_render_widget(f, w.gauge_widget(&cpu_gauge), gauge_rects[0])

			// Memory Gauge
			mem_gauge := w.gauge_new()
			mem_gauge = w.gauge_percent(mem_gauge, 45)
			mem_gauge = w.gauge_label(mem_gauge, "Memory 45%")
			mem_gauge = w.gauge_gauge_style(mem_gauge, tui.style_with_fg(tui.Color_Yellow{}))
			mem_gauge = w.gauge_use_unicode(mem_gauge, true)

			mem_block := w.block_new()
			mem_block = w.block_title(mem_block, " Memory ")
			mem_block = w.block_borders(mem_block, w.BORDERS_ALL)
			mem_gauge = w.gauge_block(mem_gauge, mem_block)

			tui.frame_render_widget(f, w.gauge_widget(&mem_gauge), gauge_rects[1])

			// Disk Gauge
			disk_gauge := w.gauge_new()
			disk_gauge = w.gauge_percent(disk_gauge, 90)
			disk_gauge = w.gauge_label(disk_gauge, "Disk 90%")
			disk_gauge = w.gauge_gauge_style(disk_gauge, tui.style_with_fg(tui.Color_Red{}))
			disk_gauge = w.gauge_use_unicode(disk_gauge, true)

			disk_block := w.block_new()
			disk_block = w.block_title(disk_block, " Disk ")
			disk_block = w.block_borders(disk_block, w.BORDERS_ALL)
			disk_gauge = w.gauge_block(disk_gauge, disk_block)

			tui.frame_render_widget(f, w.gauge_widget(&disk_gauge), gauge_rects[2])

			// 3. Sparkline
			sparkline_data := []u64{1, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610}
			sparkline := w.sparkline_new()
			sparkline = w.sparkline_data(sparkline, sparkline_data)
			sparkline = w.sparkline_style(sparkline, tui.style_with_fg(tui.Color_Cyan{}))

			spark_block := w.block_new()
			spark_block = w.block_title(spark_block, " Network Activity ")
			spark_block = w.block_borders(spark_block, w.BORDERS_ALL)
			sparkline = w.sparkline_block(sparkline, spark_block)

			tui.frame_render_widget(f, w.sparkline_widget(&sparkline), main_rects[2])

			// 4. Table
			header_cells := []w.Table_Cell {
				w.table_cell_from_string("PID"),
				w.table_cell_from_string("Name"),
				w.table_cell_from_string("CPU%"),
				w.table_cell_from_string("Memory"),
			}
			header := w.table_row_new(header_cells)
			header = w.table_row_style(header, tui.style_with_fg(tui.Color_Yellow{}))

			rows := []w.Table_Row {
				w.table_row_new(
					[]w.Table_Cell {
						w.table_cell_from_string("1234"),
						w.table_cell_from_string("chrome"),
						w.table_cell_from_string("45.2"),
						w.table_cell_from_string("2.1 GB"),
					},
				),
				w.table_row_new(
					[]w.Table_Cell {
						w.table_cell_from_string("5678"),
						w.table_cell_from_string("firefox"),
						w.table_cell_from_string("23.8"),
						w.table_cell_from_string("1.5 GB"),
					},
				),
				w.table_row_new(
					[]w.Table_Cell {
						w.table_cell_from_string("9012"),
						w.table_cell_from_string("vscode"),
						w.table_cell_from_string("12.4"),
						w.table_cell_from_string("800 MB"),
					},
				),
			}

			widths := []tui.Constraint {
				tui.Constraint_Length(8),
				tui.Constraint_Min(10),
				tui.Constraint_Length(8),
				tui.Constraint_Length(10),
			}

			table := w.table_new(rows, widths)
			table = w.table_header(table, header)
			table = w.table_row_highlight_style(table, tui.style_with_fg(tui.Color_Green{}))
			table = w.table_highlight_symbol(table, ">> ")

			table_block := w.block_new()
			table_block = w.block_title(table_block, " Processes ")
			table_block = w.block_borders(table_block, w.BORDERS_ALL)
			table = w.table_block(table, table_block)

			tui.frame_render_widget(f, w.table_widget(&table, &g_table_state), main_rects[3])

			// 5. List
			list_items := []w.List_Item {
				w.list_item_from_string("Sort by CPU"),
				w.list_item_from_string("Sort by Memory"),
				w.list_item_from_string("Sort by Name"),
				w.list_item_from_string("Kill Process"),
				w.list_item_from_string("Refresh"),
			}

			list := w.list_new(list_items)
			list = w.list_highlight_style(list, tui.style_with_fg(tui.Color_Cyan{}))
			list = w.list_highlight_symbol(list, "> ")

			list_block := w.block_new()
			list_block = w.block_title(list_block, " Actions ")
			list_block = w.block_borders(list_block, w.BORDERS_ALL)
			list = w.list_block(list, list_block)

			tui.frame_render_widget(f, w.list_widget(&list, &g_list_state), main_rects[4])
		},
	)

	fmt.println("Press Enter to exit...")
	buf: [1]byte
	when ODIN_OS == .Windows {
		// Windows stdin read
		handle := windows.GetStdHandle(windows.STD_INPUT_HANDLE)
		bytes_read: u32
		windows.ReadFile(handle, raw_data(buf[:]), u32(len(buf)), &bytes_read, nil)
	} else {
		os.read(os.stdin, buf[:])
	}
}
