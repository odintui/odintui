package odintui

import "core:strings"

// Span is a string fragment with a style.
Span :: struct {
	content: string,
	style:   Style,
}

span_new :: proc(content: string, style := Style{}) -> Span {
	return Span{content, style}
}

span_width :: proc(s: Span) -> int {
	// count Unicode scalar values (good enough for non-CJK)
	n := 0
	for _ in s.content {n += 1}
	return n
}

// Line is an ordered list of Spans rendered on a single row.
Line :: struct {
	spans:     [dynamic]Span,
	style:     Style,
	alignment: Alignment,
}

Alignment :: enum {
	Left,
	Center,
	Right,
}

line_new :: proc(spans: ..Span) -> Line {
	l := Line{}
	l.spans = make([dynamic]Span, 0, len(spans))
	for s in spans {append(&l.spans, s)}
	return l
}

line_from_string :: proc(s: string, style := Style{}) -> Line {
	return line_new(span_new(s, style))
}

line_width :: proc(l: Line) -> int {
	w := 0
	for s in l.spans {w += span_width(s)}
	return w
}

line_destroy :: proc(l: ^Line) {
	delete(l.spans)
}

// Text is a collection of Lines — the main text primitive.
Text :: struct {
	lines:     [dynamic]Line,
	style:     Style,
	alignment: Alignment,
}

text_new :: proc(lines: ..Line) -> Text {
	t := Text{}
	t.lines = make([dynamic]Line, 0, len(lines))
	for l in lines {append(&t.lines, l)}
	return t
}

text_from_string :: proc(s: string, style := Style{}) -> Text {
	lines := make([dynamic]Line, 0, 4)
	it := s
	for {
		idx := strings.index_byte(it, '\n')
		chunk := it[:idx] if idx >= 0 else it
		append(&lines, line_from_string(chunk, style))
		if idx < 0 {break}
		it = it[idx + 1:]
	}
	t := Text{}
	t.lines = lines
	t.style = style
	return t
}

text_height :: proc(t: Text) -> int {
	return len(t.lines)
}

text_width :: proc {
	text_width_text,
	text_width_string,
}

text_width_text :: proc(t: Text) -> int {
	w := 0
	for l in t.lines {w = max(w, line_width(l))}
	return w
}

text_width_string :: proc(s: string) -> int {
	n := 0
	for _ in s {n += 1}
	return n
}

text_destroy :: proc(t: ^Text) {
	for &l in t.lines {line_destroy(&l)}
	delete(t.lines)
}

// Helper: convert rune to string (for single character rendering)
rune_to_string :: proc(r: rune) -> string {
	buf: [4]byte
	n := 0
	switch {
	case r < 0x80:
		buf[0] = byte(r)
		n = 1
	case r < 0x800:
		buf[0] = 0xC0 | byte(r >> 6)
		buf[1] = 0x80 | byte(r & 0x3F)
		n = 2
	case r < 0x10000:
		buf[0] = 0xE0 | byte(r >> 12)
		buf[1] = 0x80 | byte((r >> 6) & 0x3F)
		buf[2] = 0x80 | byte(r & 0x3F)
		n = 3
	case:
		buf[0] = 0xF0 | byte(r >> 18)
		buf[1] = 0x80 | byte((r >> 12) & 0x3F)
		buf[2] = 0x80 | byte((r >> 6) & 0x3F)
		buf[3] = 0x80 | byte(r & 0x3F)
		n = 4
	}
	return string(buf[:n])
}

// Helper: format u64 as string
format_u64 :: proc(value: u64) -> string {
	if value == 0 {
		return "0"
	}

	buf: [20]byte // max u64 is 20 digits
	i := 19
	v := value

	for v > 0 {
		buf[i] = byte('0' + (v % 10))
		v /= 10
		i -= 1
	}

	return string(buf[i + 1:])
}
