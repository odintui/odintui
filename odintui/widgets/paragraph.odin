package odintui_widgets

import tui ".."
import "core:strings"
import "core:unicode/utf8"

Wrap :: enum {
	None,
	Word,
	Char,
}

Paragraph :: struct {
	text:   tui.Text,
	block:  Maybe(Block),
	style:  tui.Style,
	wrap:   Wrap,
	scroll: [2]u16, // (y, x) offset
}

paragraph_new :: proc(text: tui.Text) -> Paragraph {
	return Paragraph{text = text}
}

paragraph_from_string :: proc(s: string, style := tui.Style{}) -> Paragraph {
	return paragraph_new(tui.text_from_string(s, style))
}

paragraph_block :: proc(p: Paragraph, b: Block) -> Paragraph {
	p := p
	p.block = b
	return p
}

paragraph_style :: proc(p: Paragraph, style: tui.Style) -> Paragraph {
	p := p
	p.style = style
	return p
}

paragraph_wrap :: proc(p: Paragraph, w: Wrap) -> Paragraph {
	p := p
	p.wrap = w
	return p
}

paragraph_scroll :: proc(p: Paragraph, y, x: u16) -> Paragraph {
	p := p
	p.scroll = {y, x}
	return p
}

paragraph_render :: proc(p: Paragraph, area: tui.Rect, buf: ^tui.Buffer) {
	inner := area
	if b, ok := p.block.?; ok {
		block_render(&b, area, buf)
		inner = block_inner(&b, area)
	}
	tui.buffer_set_style(buf, inner, p.style)

	if tui.rect_is_empty(inner) {return}

	y_offset := int(p.scroll[0])
	x_offset := int(p.scroll[1])

	for row in 0 ..< int(inner.height) {
		line_idx := row + y_offset
		if line_idx >= len(p.text.lines) {break}
		line := p.text.lines[line_idx]

		cy := inner.y + u16(row)
		cx := inner.x
		remaining := int(inner.width)
		skipped := x_offset

		for span in line.spans {
			style := tui.style_patch(p.text.style, line.style)
			style = tui.style_patch(style, span.style)

			for ch in span.content {
				if skipped > 0 {skipped -= 1; continue}
				if remaining <= 0 {break}
				c := tui.buffer_cell(buf, cx, cy)
				if c == nil {break}
				if c.symbol != " " && c.symbol != "" {
					delete(c.symbol)
				}
				enc, n := utf8.encode_rune(ch)
				c.symbol = strings.clone(string(enc[:n]))
				c.style = style
				cx += 1
				remaining -= 1
			}
		}
	}
}

paragraph_widget :: proc(p: ^Paragraph) -> tui.Widget {
	return tui.Widget{data = p, render = proc(data: rawptr, area: tui.Rect, buf: ^tui.Buffer) {
			paragraph_render((^Paragraph)(data)^, area, buf)
		}}
}
