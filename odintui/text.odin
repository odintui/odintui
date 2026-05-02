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
    for _ in s.content { n += 1 }
    return n
}

// Line is an ordered list of Spans rendered on a single row.
Line :: struct {
    spans:     [dynamic]Span,
    style:     Style,
    alignment: Alignment,
}

Alignment :: enum { Left, Center, Right }

line_new :: proc(spans: ..Span) -> Line {
    l := Line{}
    l.spans = make([dynamic]Span, 0, len(spans))
    for s in spans { append(&l.spans, s) }
    return l
}

line_from_string :: proc(s: string, style := Style{}) -> Line {
    return line_new(span_new(s, style))
}

line_width :: proc(l: Line) -> int {
    w := 0
    for s in l.spans { w += span_width(s) }
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
    for l in lines { append(&t.lines, l) }
    return t
}

text_from_string :: proc(s: string, style := Style{}) -> Text {
    lines := make([dynamic]Line, 0, 4)
    it := s
    for {
        idx := strings.index_byte(it, '\n')
        chunk := it[:idx] if idx >= 0 else it
        append(&lines, line_from_string(chunk, style))
        if idx < 0 { break }
        it = it[idx+1:]
    }
    t := Text{}
    t.lines = lines
    t.style = style
    return t
}

text_height :: proc(t: Text) -> int {
    return len(t.lines)
}

text_width :: proc(t: Text) -> int {
    w := 0
    for l in t.lines { w = max(w, line_width(l)) }
    return w
}

text_destroy :: proc(t: ^Text) {
    for &l in t.lines { line_destroy(&l) }
    delete(t.lines)
}
