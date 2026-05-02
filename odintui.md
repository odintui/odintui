# odintui — план реализации

Цель: максимальная совместимость с ratatui, чтобы Rust-приложение (pstop, psmux)
можно было переписать на Odin механически — одинаковые концепции, похожие имена.

---

## Референс: что нужно pstop

pstop (https://github.com/psmux/pstop) использует:
- **Table** — главная таблица процессов (с highlight строки, скроллом)
- **Paragraph** — шапка с системными метриками (уже есть)
- **Gauge** — полосы CPU / Memory / Network / GPU
- **List** — меню сортировки, убийства, фильтрации
- **Block** — обрамление секций и модальных окон (уже есть)
- **Layout** — вертикальная нарезка: header / tab bar / table / footer
- **Events** — crossterm keyboard events (F1-F10, hjkl, Esc, Enter)
- **StatefulWidget** паттерн — List+ListState, Table+TableState
- **Tabs** — строка вкладок (Main | I/O | Net | GPU)
- **Модальные оверлеи** — centered popup area поверх основного UI

Паттерн event loop в pstop:
```
loop {
    if crossterm::event::poll(timeout)? {
        match crossterm::event::read()? {
            Event::Key(key) => handle_input(&mut app, key),
            Event::Resize(w, h) => { ... }
            _ => {}
        }
    }
    if app.should_quit { break }
    terminal.draw(|f| ui::draw(f, &app))?;
}
```

---

## Соглашения кода

- Builder-паттерн: setter принимает значение по значению (`b := b`), возвращает копию.
- Stateful-виджеты: `<name>_widget_stateful(^T, ^State) -> tui.Widget`.
- Все файлы в `odintui/widgets/`, импорт `import tui ".."`.
- Максимум 80 колонок.

---

## Порядок реализации

### Фаза 1 — виджеты (нет state)

#### 1. `widgets/gauge.odin`

```odin
Gauge :: struct {
    block:       Maybe(Block),
    ratio:       f64,           // 0.0 .. 1.0
    label:       Maybe(string),
    style:       tui.Style,
    gauge_style: tui.Style,
    use_unicode: bool,
}
```

API:
```
gauge_new() -> Gauge
gauge_block(g, b) -> Gauge
gauge_percent(g, pct: u16) -> Gauge   // 0-100
gauge_ratio(g, r: f64) -> Gauge       // 0.0-1.0
gauge_label(g, label: string) -> Gauge
gauge_style(g, s) -> Gauge
gauge_gauge_style(g, s) -> Gauge
gauge_use_unicode(g, v: bool) -> Gauge
gauge_widget(^Gauge) -> tui.Widget
```

Рендер: filled = int(ratio * width) ячеек из `gauge_style`,
остаток из `style`. Если `use_unicode` — последний символ
из `▏▎▍▌▋▊▉█` по дроби. Label по центру поверх.

---

#### 2. `widgets/sparkline.odin`

```odin
Sparkline_Direction :: enum { Left_To_Right, Right_To_Left }

Sparkline :: struct {
    block:               Maybe(Block),
    data:                []u64,
    max:                 Maybe(u64),
    bar_set:             tui.Bar_Set,
    style:               tui.Style,
    absent_value_style:  tui.Style,
    absent_value_symbol: string,
    direction:           Sparkline_Direction,
}
```

API:
```
sparkline_new() -> Sparkline
sparkline_block(s, b) -> Sparkline
sparkline_data(s, data: []u64) -> Sparkline
sparkline_max(s, max: u64) -> Sparkline
sparkline_bar_set(s, bs: tui.Bar_Set) -> Sparkline
sparkline_style(s, st) -> Sparkline
sparkline_absent_value_style(s, st) -> Sparkline
sparkline_absent_value_symbol(s, sym: string) -> Sparkline
sparkline_direction(s, d) -> Sparkline
sparkline_widget(^Sparkline) -> tui.Widget
```

Рендер: для каждой колонки выбрать символ из Bar_Set по
`value / max * levels`. Right_To_Left — итерировать data с конца.

---

#### 3. `widgets/tabs.odin`

Нужен pstop для tab bar (Main | I/O | Net | GPU).

```odin
Tabs :: struct {
    titles:          []string,
    selected:        int,
    block:           Maybe(Block),
    style:           tui.Style,
    highlight_style: tui.Style,
    divider:         string,   // default " | "
}
```

API:
```
tabs_new(titles: []string) -> Tabs
tabs_select(t, idx: int) -> Tabs
tabs_block(t, b) -> Tabs
tabs_style(t, s) -> Tabs
tabs_highlight_style(t, s) -> Tabs
tabs_divider(t, div: string) -> Tabs
tabs_widget(^Tabs) -> tui.Widget
```

Рендер: горизонтальная строка вкладок, активная — highlight_style,
остальные — style, между ними — divider.

---

### Фаза 2 — stateful виджеты

#### 4. `widgets/list.odin`

```odin
List_Item :: struct {
    content: tui.Text,
    style:   tui.Style,
}

List :: struct {
    items:            []List_Item,
    block:            Maybe(Block),
    style:            tui.Style,
    highlight_style:  tui.Style,
    highlight_symbol: string,
    repeat_highlight: bool,
    direction:        List_Direction,
    scroll_padding:   uint,
}

List_Direction :: enum { Top_To_Bottom, Bottom_To_Top }

List_State :: struct {
    offset:   int,
    selected: Maybe(int),
}
```

API:
```
list_item_new(text: tui.Text) -> List_Item
list_item_from_string(s: string) -> List_Item
list_item_style(i, s) -> List_Item

list_new(items: []List_Item) -> List
list_block(l, b) -> List
list_style(l, s) -> List
list_highlight_style(l, s) -> List
list_highlight_symbol(l, sym: string) -> List
list_repeat_highlight_symbol(l, v: bool) -> List
list_direction(l, d) -> List
list_scroll_padding(l, n: uint) -> List
list_len(l) -> int
list_is_empty(l) -> bool

list_state_new() -> List_State
list_state_select(state: ^List_State, idx: Maybe(int))
list_state_selected(state: ^List_State) -> Maybe(int)

list_widget(^List, ^List_State) -> tui.Widget
```

Рендер: видимое окно [offset .. offset+height], скролл при
selected выходит за scroll_padding. Highlight + symbol для выделенной строки.

---

#### 5. `widgets/table.odin`

Самый важный виджет для pstop.

```odin
Table_Cell :: struct {
    content: tui.Text,
    style:   tui.Style,
}

Table_Row :: struct {
    cells:         []Table_Cell,
    style:         tui.Style,
    height:        u16,
    top_margin:    u16,
    bottom_margin: u16,
}

Table :: struct {
    rows:                []Table_Row,
    header:              Maybe(Table_Row),
    footer:              Maybe(Table_Row),
    widths:              []tui.Constraint,
    column_spacing:      u16,
    style:               tui.Style,
    block:               Maybe(Block),
    row_highlight_style: tui.Style,
    highlight_symbol:    string,
}

Table_State :: struct {
    offset:          int,
    selected:        Maybe(int),
    selected_column: Maybe(int),
}
```

API:
```
table_cell_new(content: tui.Text) -> Table_Cell
table_cell_from_string(s: string) -> Table_Cell
table_cell_style(c, s) -> Table_Cell

table_row_new(cells: []Table_Cell) -> Table_Row
table_row_style(r, s) -> Table_Row
table_row_height(r, h: u16) -> Table_Row
table_row_top_margin(r, m: u16) -> Table_Row
table_row_bottom_margin(r, m: u16) -> Table_Row

table_new(rows: []Table_Row, widths: []tui.Constraint) -> Table
table_header(t, h: Table_Row) -> Table
table_footer(t, f: Table_Row) -> Table
table_widths(t, w: []tui.Constraint) -> Table
table_column_spacing(t, s: u16) -> Table
table_style(t, s) -> Table
table_block(t, b) -> Table
table_row_highlight_style(t, s) -> Table
table_highlight_symbol(t, sym: string) -> Table

table_state_new() -> Table_State
table_state_select(state: ^Table_State, idx: Maybe(int))
table_state_selected(state: ^Table_State) -> Maybe(int)

table_widget(^Table, ^Table_State) -> tui.Widget
```

Рендер: layout_split по widths горизонтально, header фиксирован
сверху, footer снизу, rows прокручиваются через state.offset.

---

#### 6. `widgets/barchart.odin`

```odin
Bar_Direction :: enum { Vertical, Horizontal }

Bar :: struct {
    label:       string,
    value:       u64,
    text_value:  string,
    style:       tui.Style,
    value_style: tui.Style,
    label_style: tui.Style,
}

Bar_Group :: struct {
    label: string,
    bars:  []Bar,
}

Bar_Chart :: struct {
    block:       Maybe(Block),
    bar_width:   u16,
    bar_gap:     u16,
    group_gap:   u16,
    bar_set:     tui.Bar_Set,
    bar_style:   tui.Style,
    value_style: tui.Style,
    label_style: tui.Style,
    style:       tui.Style,
    max:         Maybe(u64),
    direction:   Bar_Direction,
    groups:      []Bar_Group,
}
```

API:
```
bar_new(label: string, value: u64) -> Bar
bar_text_value(b, s: string) -> Bar
bar_style(b, s) -> Bar
bar_value_style(b, s) -> Bar
bar_label_style(b, s) -> Bar

bar_group_new(bars: []Bar) -> Bar_Group
bar_group_label(g, label: string) -> Bar_Group

bar_chart_new(groups: []Bar_Group) -> Bar_Chart
bar_chart_vertical(groups: []Bar_Group) -> Bar_Chart
bar_chart_horizontal(groups: []Bar_Group) -> Bar_Chart
bar_chart_block(c, b) -> Bar_Chart
bar_chart_bar_width(c, w: u16) -> Bar_Chart
bar_chart_bar_gap(c, g: u16) -> Bar_Chart
bar_chart_group_gap(c, g: u16) -> Bar_Chart
bar_chart_bar_set(c, bs) -> Bar_Chart
bar_chart_bar_style(c, s) -> Bar_Chart
bar_chart_value_style(c, s) -> Bar_Chart
bar_chart_label_style(c, s) -> Bar_Chart
bar_chart_style(c, s) -> Bar_Chart
bar_chart_max(c, m: u64) -> Bar_Chart
bar_chart_direction(c, d) -> Bar_Chart
bar_chart_widget(^Bar_Chart) -> tui.Widget
```

---

### Фаза 3 — события и event loop

#### 7. `events.odin` (в основном пакете)

Главный блокер для реальных приложений.

```odin
Key_Code :: union {
    Key_Char,        // rune
    Key_Special,     // enum: Enter, Esc, Backspace, Tab, ...
    Key_F,           // u8 (1-12)
    Key_Arrow,       // enum: Up, Down, Left, Right
    Key_PageUp, Key_PageDown,
    Key_Home, Key_End,
    Key_Insert, Key_Delete,
}

Key_Modifiers :: distinct bit_set[Key_Modifier_Flag]
Key_Modifier_Flag :: enum { Shift, Control, Alt }

Key_Event :: struct {
    code:      Key_Code,
    modifiers: Key_Modifiers,
}

Mouse_Event_Kind :: enum {
    Down, Up, Drag, Moved, ScrollDown, ScrollUp,
}

Mouse_Event :: struct {
    kind:      Mouse_Event_Kind,
    column:    u16,
    row:       u16,
    modifiers: Key_Modifiers,
}

Resize_Event :: struct { width, height: u16 }

Event :: union {
    Key_Event,
    Mouse_Event,
    Resize_Event,
}
```

API:
```
event_poll(timeout_ms: int) -> bool   // есть ли событие
event_read() -> (Event, bool)         // читать следующее
```

Платформенная реализация:
- `events_windows.odin` — ReadConsoleInput (Win32)
- `events_posix.odin`   — read() + termios (Linux/macOS)

---

### Фаза 4 — вспомогательные утилиты

#### 8. Popup helper (в `frame.odin` или отдельный `popup.odin`)

Нужен pstop для модальных окон.

```odin
// centered_rect возвращает Rect по центру parent
// заданного процентного размера (как в ratatui examples)
centered_rect :: proc(
    percent_x, percent_y: u16,
    r: Rect,
) -> Rect
```

#### 9. `symbols.odin` — дополнить `Bar_Set`

```odin
Bar_Set :: struct {
    full, seven, six, five,
    four, three, two, one, empty: string,
}

NINE_LEVELS  :: Bar_Set{"█","▇","▆","▅","▄","▃","▂","▁"," "}
THREE_LEVELS :: Bar_Set{"█","▄"," ","","","","","",""}
```

---

## Что нужно проверить перед началом

1. Есть ли уже `Bar_Set` в `symbols.odin`?
2. Как `layout_split` работает горизонтально — нужен параметр direction?
3. Нет ли утечек памяти в `paragraph_render` при клонировании символов?

---

## Порядок коммитов

```
feat(widgets): gauge
feat(widgets): sparkline + Bar_Set in symbols
feat(widgets): tabs
feat(widgets): list + List_State
feat(widgets): table + Table_State
feat(widgets): barchart
feat(events): keyboard/mouse events — windows
feat(events): keyboard/mouse events — posix
feat(frame): centered_rect popup helper
example: extend demo with all new widgets
```

---

## Проверка совместимости

После каждого виджета — убедиться, что Rust-код вида:

```rust
let table = Table::new(rows, widths)
    .header(header_row)
    .block(Block::bordered().title("Processes"))
    .row_highlight_style(Style::new().reversed())
    .highlight_symbol(">> ");
frame.render_stateful_widget(table, area, &mut state);
```

переписывается в Odin механически:

```odin
t := w.table_new(rows[:], widths[:])
t  = w.table_header(t, header_row)
b := w.block_new()
b  = w.block_title(b, "Processes")
b  = w.block_borders(b, w.BORDERS_ALL)
t  = w.table_block(t, b)
t  = w.table_row_highlight_style(t, tui.style_reversed())
t  = w.table_highlight_symbol(t, ">> ")
tui.frame_render_widget(f, w.table_widget(&t, &state), area)
```
