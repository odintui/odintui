package odintui


Rect :: struct {
    x, y:          u16,
    width, height: u16,
}

rect_new :: proc(x, y, width, height: u16) -> Rect {
    return Rect{x, y, width, height}
}

rect_area :: proc(r: Rect) -> u32 {
    return u32(r.width) * u32(r.height)
}

rect_is_empty :: proc(r: Rect) -> bool {
    return r.width == 0 || r.height == 0
}

rect_left   :: proc(r: Rect) -> u16 { return r.x }
rect_right  :: proc(r: Rect) -> u16 { return r.x + r.width }
rect_top    :: proc(r: Rect) -> u16 { return r.y }
rect_bottom :: proc(r: Rect) -> u16 { return r.y + r.height }

rect_inner :: proc(r: Rect, margin: u16) -> Rect {
    if r.width < margin * 2 || r.height < margin * 2 {
        return Rect{}
    }
    return Rect{
        x      = r.x + margin,
        y      = r.y + margin,
        width  = r.width  - margin * 2,
        height = r.height - margin * 2,
    }
}

rect_union :: proc(a, b: Rect) -> Rect {
    x1 := min(a.x, b.x)
    y1 := min(a.y, b.y)
    x2 := max(rect_right(a),  rect_right(b))
    y2 := max(rect_bottom(a), rect_bottom(b))
    return Rect{x1, y1, x2 - x1, y2 - y1}
}

rect_intersection :: proc(a, b: Rect) -> Rect {
    x1 := max(a.x, b.x)
    y1 := max(a.y, b.y)
    x2 := min(rect_right(a),  rect_right(b))
    y2 := min(rect_bottom(a), rect_bottom(b))
    if x2 <= x1 || y2 <= y1 { return Rect{} }
    return Rect{x1, y1, x2 - x1, y2 - y1}
}

rect_clamp :: proc(r, bounds: Rect) -> Rect {
    x := clamp(r.x, bounds.x, rect_right(bounds))
    y := clamp(r.y, bounds.y, rect_bottom(bounds))
    w := min(r.width,  rect_right(bounds)  - x)
    h := min(r.height, rect_bottom(bounds) - y)
    return Rect{x, y, w, h}
}

// ── Direction ─────────────────────────────────────────────────────────────────

Direction :: enum { Horizontal, Vertical }

// ── Constraint ────────────────────────────────────────────────────────────────

Constraint :: union {
    Constraint_Length,
    Constraint_Min,
    Constraint_Max,
    Constraint_Percentage,
    Constraint_Fill,
    Constraint_Ratio,
}

Constraint_Length     :: distinct u16
Constraint_Min        :: distinct u16
Constraint_Max        :: distinct u16
Constraint_Percentage :: distinct u16        // 0..=100
Constraint_Fill       :: distinct u16        // weight
Constraint_Ratio      :: struct{ num, den: u32 }

// ── Layout ────────────────────────────────────────────────────────────────────

Layout :: struct {
    direction:   Direction,
    constraints: []Constraint,
    margin:      u16,
    spacing:     u16,
}

layout_new :: proc(
    direction: Direction,
    constraints: []Constraint,
) -> Layout {
    return Layout{direction = direction, constraints = constraints}
}

layout_vertical :: proc(constraints: []Constraint) -> Layout {
    return layout_new(.Vertical, constraints)
}

layout_horizontal :: proc(constraints: []Constraint) -> Layout {
    return layout_new(.Horizontal, constraints)
}

layout_with_margin :: proc(l: Layout, margin: u16) -> Layout {
    l := l
    l.margin = margin
    return l
}

layout_with_spacing :: proc(l: Layout, spacing: u16) -> Layout {
    l := l
    l.spacing = spacing
    return l
}

// split divides area according to constraints and returns allocated rects.
// Caller owns the returned slice (allocated with context allocator).
layout_split :: proc(
    l: Layout,
    area: Rect,
    allocator := context.allocator,
) -> []Rect {
    n := len(l.constraints)
    if n == 0 { return nil }

    inner := rect_inner(area, l.margin)
    total := u32(inner.width  if l.direction == .Horizontal else inner.height)
    spacing_total := u32(l.spacing) * u32(max(n - 1, 0))
    if spacing_total >= total { spacing_total = 0 }
    available := total - spacing_total

    sizes := make([]u16, n, allocator)

    // Pass 1: fixed lengths and percentages
    remaining := available
    fill_total: u32 = 0
    for c, i in l.constraints {
        switch v in c {
        case Constraint_Length:
            sz := min(u32(v), remaining)
            sizes[i] = u16(sz)
            remaining -= sz
        case Constraint_Percentage:
            sz := min(available * u32(v) / 100, remaining)
            sizes[i] = u16(sz)
            remaining -= sz
        case Constraint_Ratio:
            sz := min(
                available * v.num / max(v.den, 1),
                remaining,
            )
            sizes[i] = u16(sz)
            remaining -= sz
        case Constraint_Min:
            sizes[i] = u16(v) // tentative minimum
        case Constraint_Max:
            // handled in pass 2
        case Constraint_Fill:
            fill_total += u32(v)
        }
    }

    // Pass 2: Fill weights
    if fill_total > 0 {
        fill_budget := remaining
        for c, i in l.constraints {
            if v, ok := c.(Constraint_Fill); ok {
                sz := fill_budget * u32(v) / fill_total
                sizes[i] = u16(sz)
            }
        }
    }

    // Pass 3: Min/Max adjustments
    for c, i in l.constraints {
        switch v in c {
        case Constraint_Min:
            if u32(sizes[i]) < u32(v) { sizes[i] = u16(v) }
        case Constraint_Max:
            if u32(sizes[i]) > u32(v) { sizes[i] = u16(v) }
        case Constraint_Length, Constraint_Percentage,
             Constraint_Fill,   Constraint_Ratio:
            // already handled in pass 1/2
        }
    }

    // Build output rects
    rects := make([]Rect, n, allocator)
    pos := u16(inner.x if l.direction == .Horizontal else inner.y)
    for i in 0..<n {
        if l.direction == .Horizontal {
            rects[i] = Rect{pos, inner.y, sizes[i], inner.height}
        } else {
            rects[i] = Rect{inner.x, pos, inner.width, sizes[i]}
        }
        pos += sizes[i] + l.spacing
    }

    delete(sizes, allocator)
    return rects
}
