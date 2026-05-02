package odintui

// Box drawing characters — mirrors ratatui::symbols::border
Border_Set :: struct {
    top_left, top_right:     string,
    bottom_left, bottom_right: string,
    horizontal, vertical:    string,
    horizontal_down:         string, // ┬
    horizontal_up:           string, // ┴
    vertical_right:          string, // ├
    vertical_left:           string, // ┤
    cross:                   string, // ┼
}

BORDER_PLAIN :: Border_Set{
    top_left      = "┌", top_right      = "┐",
    bottom_left   = "└", bottom_right   = "┘",
    horizontal    = "─", vertical       = "│",
    horizontal_down = "┬", horizontal_up  = "┴",
    vertical_right  = "├", vertical_left  = "┤",
    cross           = "┼",
}

BORDER_ROUNDED :: Border_Set{
    top_left      = "╭", top_right      = "╮",
    bottom_left   = "╰", bottom_right   = "╯",
    horizontal    = "─", vertical       = "│",
    horizontal_down = "┬", horizontal_up  = "┴",
    vertical_right  = "├", vertical_left  = "┤",
    cross           = "┼",
}

BORDER_DOUBLE :: Border_Set{
    top_left      = "╔", top_right      = "╗",
    bottom_left   = "╚", bottom_right   = "╝",
    horizontal    = "═", vertical       = "║",
    horizontal_down = "╦", horizontal_up  = "╩",
    vertical_right  = "╠", vertical_left  = "╣",
    cross           = "╬",
}

BORDER_THICK :: Border_Set{
    top_left      = "┏", top_right      = "┓",
    bottom_left   = "┗", bottom_right   = "┛",
    horizontal    = "━", vertical       = "┃",
    horizontal_down = "┳", horizontal_up  = "┻",
    vertical_right  = "┣", vertical_left  = "┫",
    cross           = "╋",
}

// Bar characters for gauges and sparklines
BAR_FULL  :: "█"
BAR_SEVEN :: "▇"
BAR_SIX   :: "▆"
BAR_FIVE  :: "▅"
BAR_FOUR  :: "▄"
BAR_THREE :: "▃"
BAR_TWO   :: "▂"
BAR_ONE   :: "▁"
BAR_EMPTY :: " "

// Bar_Set — named symbol set for sparklines and barcharts.
// Mirrors ratatui::symbols::bar::Set.
Bar_Set :: struct {
    full, seven, six, five,
    four, three, two, one, empty: string,
}

NINE_LEVELS :: Bar_Set{
    full  = BAR_FULL,  seven = BAR_SEVEN, six  = BAR_SIX,
    five  = BAR_FIVE,  four  = BAR_FOUR,  three = BAR_THREE,
    two   = BAR_TWO,   one   = BAR_ONE,   empty = BAR_EMPTY,
}

THREE_LEVELS :: Bar_Set{
    full  = BAR_FULL, seven = BAR_FULL,  six   = BAR_FULL,
    five  = BAR_FOUR, four  = BAR_FOUR,  three = BAR_FOUR,
    two   = BAR_EMPTY, one  = BAR_EMPTY, empty = BAR_EMPTY,
}

// Legacy array — kept for backward compatibility
BAR_SET :: [8]string{
    BAR_ONE, BAR_TWO, BAR_THREE, BAR_FOUR,
    BAR_FIVE, BAR_SIX, BAR_SEVEN, BAR_FULL,
}

// Unicode sub-block chars for high-precision gauge fill
GAUGE_BLOCKS :: [8]string{
    "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█",
}

// Half-block characters for braille-style sparklines
HALF_TOP    :: "▀"
HALF_BOTTOM :: "▄"
HALF_FULL   :: "█"

// Dot / braille markers
DOT :: "•"
