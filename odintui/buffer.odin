package odintui

import "core:strings"
import "core:unicode/utf8"

Cell :: struct {
	symbol: string, // owned; default " "
	style:  Style,
	skip:   bool, // wide char continuation cell
}

CELL_EMPTY :: Cell {
	symbol = " ",
}

cell_reset :: proc(c: ^Cell) {
	if c.symbol != " " && len(c.symbol) > 0 {
		delete(c.symbol)
	}
	c.symbol = " "
	c.style = {}
	c.skip = false
}

Buffer :: struct {
	area:    Rect,
	content: [dynamic]Cell,
}

buffer_empty :: proc(area: Rect, allocator := context.allocator) -> Buffer {
	n := int(area.width) * int(area.height)
	content := make([dynamic]Cell, n, n, allocator)
	for &c in content {c = CELL_EMPTY}
	return Buffer{area = area, content = content}
}

buffer_destroy :: proc(b: ^Buffer, allocator := context.allocator) {
	for &c in b.content {
		if c.symbol != " " && len(c.symbol) > 0 {
			delete(c.symbol, allocator)
		}
	}
	delete(b.content)
}

buffer_resize :: proc(b: ^Buffer, area: Rect, allocator := context.allocator) {
	buffer_destroy(b, allocator)
	b^ = buffer_empty(area, allocator)
}

buffer_reset :: proc(b: ^Buffer) {
	for &c in b.content {cell_reset(&c)}
}

buffer_index_of :: proc(b: ^Buffer, x, y: u16) -> int {
	return int(y - b.area.y) * int(b.area.width) + int(x - b.area.x)
}

buffer_cell :: proc(b: ^Buffer, x, y: u16) -> ^Cell {
	if x < b.area.x ||
	   x >= b.area.x + b.area.width ||
	   y < b.area.y ||
	   y >= b.area.y + b.area.height {
		return nil
	}
	return &b.content[buffer_index_of(b, x, y)]
}

_cell_set :: proc(c: ^Cell, ch: rune, style: Style) {
	if c.symbol != " " && len(c.symbol) > 0 {delete(c.symbol)}
	r, n := utf8.encode_rune(ch)
	c.symbol = strings.clone(string(r[:n]))
	c.style = style
}

buffer_set_string :: proc(
	b: ^Buffer,
	x, y: u16,
	s: string,
	style: Style,
	max_width: u16 = max(u16),
) -> (
	u16,
	u16,
) {
	cx := x
	remaining := int(max_width)
	for ch in s {
		if remaining <= 0 {break}
		c := buffer_cell(b, cx, y)
		if c == nil {break}
		_cell_set(c, ch, style)
		cx += 1
		remaining -= 1
	}
	return cx, y
}

// Helper to set a single cell with a string
buffer_set_cell :: proc(b: ^Buffer, x, y: u16, s: string, style: Style) {
	c := buffer_cell(b, x, y)
	if c == nil {return}
	if c.symbol != " " && len(c.symbol) > 0 {delete(c.symbol)}
	c.symbol = s
	c.style = style
}

buffer_set_style :: proc(b: ^Buffer, area: Rect, style: Style) {
	x1 := max(area.x, b.area.x)
	y1 := max(area.y, b.area.y)
	x2 := min(area.x + area.width, b.area.x + b.area.width)
	y2 := min(area.y + area.height, b.area.y + b.area.height)
	for y in y1 ..< y2 {
		for x in x1 ..< x2 {
			if c := buffer_cell(b, x, y); c != nil {
				c.style = style_patch(c.style, style)
			}
		}
	}
}

Diff_Cell :: struct {
	x, y: u16,
	cell: ^Cell,
}

buffer_diff :: proc(prev, next: ^Buffer, allocator := context.allocator) -> []Diff_Cell {
	result := make([dynamic]Diff_Cell, 0, 64, allocator)
	w := next.area.width
	for i in 0 ..< len(next.content) {
		n := &next.content[i]
		same :=
			i < len(prev.content) &&
			prev.content[i].symbol == n.symbol &&
			prev.content[i].style == n.style
		if !same {
			x := next.area.x + u16(i) % w
			y := next.area.y + u16(i) / w
			append(&result, Diff_Cell{x, y, n})
		}
	}
	return result[:]
}
