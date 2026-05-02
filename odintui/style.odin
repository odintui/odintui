package odintui

// Color represents a terminal color.
Color :: union {
	Color_Reset,
	Color_Black,
	Color_Red,
	Color_Green,
	Color_Yellow,
	Color_Blue,
	Color_Magenta,
	Color_Cyan,
	Color_Gray,
	Color_Dark_Gray,
	Color_Light_Red,
	Color_Light_Green,
	Color_Light_Yellow,
	Color_Light_Blue,
	Color_Light_Magenta,
	Color_Light_Cyan,
	Color_White,
	Color_Rgb,
	Color_Indexed,
}

Color_Reset :: distinct struct{}
Color_Black :: distinct struct{}
Color_Red :: distinct struct{}
Color_Green :: distinct struct{}
Color_Yellow :: distinct struct{}
Color_Blue :: distinct struct{}
Color_Magenta :: distinct struct{}
Color_Cyan :: distinct struct{}
Color_Gray :: distinct struct{}
Color_Dark_Gray :: distinct struct{}
Color_Light_Red :: distinct struct{}
Color_Light_Green :: distinct struct{}
Color_Light_Yellow :: distinct struct{}
Color_Light_Blue :: distinct struct{}
Color_Light_Magenta :: distinct struct{}
Color_Light_Cyan :: distinct struct{}
Color_White :: distinct struct{}

Color_Rgb :: struct {
	r, g, b: u8,
}

Color_Indexed :: struct {
	index: u8,
}

Modifier :: distinct bit_set[Modifier_Flag;u16]

Modifier_Flag :: enum u16 {
	Bold,
	Dim,
	Italic,
	Underlined,
	Slow_Blink,
	Rapid_Blink,
	Reversed,
	Hidden,
	Crossed_Out,
}

BOLD :: Modifier{.Bold}
DIM :: Modifier{.Dim}
ITALIC :: Modifier{.Italic}
UNDERLINED :: Modifier{.Underlined}
SLOW_BLINK :: Modifier{.Slow_Blink}
RAPID_BLINK :: Modifier{.Rapid_Blink}
REVERSED :: Modifier{.Reversed}
HIDDEN :: Modifier{.Hidden}
CROSSED_OUT :: Modifier{.Crossed_Out}

Style :: struct {
	fg:              Maybe(Color),
	bg:              Maybe(Color),
	underline_color: Maybe(Color),
	add_modifier:    Modifier,
	sub_modifier:    Modifier,
}

style_default :: proc() -> Style {
	return Style{}
}

style_fg :: proc(s: Style, color: Color) -> Style {
	s := s
	s.fg = color
	return s
}

style_bg :: proc(s: Style, color: Color) -> Style {
	s := s
	s.bg = color
	return s
}

style_add_modifier :: proc(s: Style, m: Modifier) -> Style {
	s := s
	s.sub_modifier -= m
	s.add_modifier += m
	return s
}

style_remove_modifier :: proc(s: Style, m: Modifier) -> Style {
	s := s
	s.add_modifier -= m
	s.sub_modifier += m
	return s
}

// Patch applies other on top of self — other wins on non-zero fields.
style_patch :: proc(base, other: Style) -> Style {
	result := base
	if other.fg != nil {result.fg = other.fg}
	if other.bg != nil {result.bg = other.bg}
	if other.underline_color != nil {
		result.underline_color = other.underline_color
	}
	result.add_modifier += other.add_modifier
	result.add_modifier -= other.sub_modifier
	result.sub_modifier += other.sub_modifier
	result.sub_modifier -= other.add_modifier
	return result
}

// Helper functions for creating styles with colors
style_with_fg :: proc(color: Color) -> Style {
	return Style{fg = color}
}

style_with_bg :: proc(color: Color) -> Style {
	return Style{bg = color}
}

style_reversed :: proc() -> Style {
	return Style{add_modifier = REVERSED}
}
