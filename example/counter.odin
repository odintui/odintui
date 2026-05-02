package main

import tui "../odintui"
import w "../odintui/widgets"
import "core:fmt"

// Simple counter app demonstrating terminal_run

Counter_App :: struct {
	counter: int,
}

main :: proc() {
	term := tui.init()
	defer tui.restore(&term)

	app := Counter_App {
		counter = 0,
	}

	// Use terminal_run with user_data
	tui.terminal_run(&term, draw_counter, handle_counter_event, &app, 60)
}

draw_counter :: proc(f: ^tui.Frame, user_data: rawptr) {
	app := cast(^Counter_App)user_data
	area := tui.frame_size(f)

	// Create text
	text := fmt.tprintf(
		"Counter: %d\n\nPress:\n  j/↓ - Decrement\n  k/↑ - Increment\n  r   - Reset\n  q   - Quit",
		app.counter,
	)
	content := tui.text_from_string(text)

	// Create paragraph
	para := w.paragraph_new(content)
	para = w.paragraph_style(para, tui.style_with_fg(tui.Color_Cyan{}))

	// Add block
	block := w.block_new()
	block = w.block_title(block, " Counter Demo ")
	block = w.block_borders(block, w.BORDERS_ALL)
	para = w.paragraph_block(para, block)

	// Render
	tui.frame_render_widget(f, w.paragraph_widget(&para), area)
}

handle_counter_event :: proc(event: tui.Event, user_data: rawptr) -> bool {
	app := cast(^Counter_App)user_data

	#partial switch e in event {
	case tui.Key_Event:
		#partial switch code in e.code {
		case tui.Key_Char:
			c := rune(code)
			switch c {
			case 'q':
				return false // Quit
			case 'j':
				app.counter -= 1
			case 'k':
				app.counter += 1
			case 'r':
				app.counter = 0
			}
		case tui.Key_Arrow:
			switch code {
			case .Down:
				app.counter -= 1
			case .Up:
				app.counter += 1
			case .Left, .Right:
			// Not used
			}
		case tui.Key_Special:
			if code == .Esc {
				return false // Quit
			}
		}
	}
	return true // Continue
}
