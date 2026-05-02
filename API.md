# API Compatibility Guide: ratatui → odintui

Этот документ гарантирует механическое портирование кода с ratatui на odintui.

## Основные принципы

1. **Имена функций идентичны** (с учетом snake_case)
2. **Builder pattern сохранен** (все setters возвращают копию)
3. **Stateful widgets** используют те же State структуры
4. **Layout system** идентичен (Constraint, Rect, split)

---

## Imports

### Rust (ratatui)
```rust
use ratatui::prelude::*;
use ratatui::widgets::*;
```

### Odin (odintui)
```odin
import tui "../odintui"
import w "../odintui/widgets"
```

---

## Terminal Initialization

### Rust
```rust
let mut terminal = Terminal::new(CrosstermBackend::new(io::stdout()))?;
terminal.clear()?;
// ... use terminal
terminal.show_cursor()?;
```

### Odin
```odin
term := tui.init()
defer tui.restore(&term)
// ... use terminal
```

---

## Drawing

### Rust
```rust
terminal.draw(|f| {
    let area = f.size();
    // render widgets
})?;
```

### Odin
```odin
tui.terminal_draw(&term, proc(f: ^tui.Frame) {
    area := tui.frame_size(f)
    // render widgets
})
```

---

## Layout

### Rust
```rust
let chunks = Layout::default()
    .direction(Direction::Vertical)
    .constraints([
        Constraint::Length(3),
        Constraint::Min(0),
    ])
    .split(area);
```

### Odin
```odin
layout := tui.layout_vertical([]tui.Constraint{
    tui.Constraint_Length(3),
    tui.Constraint_Min(0),
})
chunks := tui.layout_split(layout, area)
defer delete(chunks)
```

**Constraints mapping:**
- `Constraint::Length(n)` → `tui.Constraint_Length(n)`
- `Constraint::Min(n)` → `tui.Constraint_Min(n)`
- `Constraint::Max(n)` → `tui.Constraint_Max(n)`
- `Constraint::Percentage(n)` → `tui.Constraint_Percentage(n)`
- `Constraint::Ratio(a, b)` → `tui.Constraint_Ratio(a, b)`
- `Constraint::Fill(n)` → `tui.Constraint_Fill(n)`

---

## Block Widget

### Rust
```rust
let block = Block::default()
    .title("Title")
    .borders(Borders::ALL)
    .border_style(Style::default().fg(Color::Cyan));
```

### Odin
```odin
block := w.block_new()
block = w.block_title(block, "Title")
block = w.block_borders(block, w.BORDERS_ALL)
block = w.block_border_style(block, tui.style_with_fg(tui.Color_Cyan{}))
```

**Borders mapping:**
- `Borders::NONE` → `w.BORDERS_NONE`
- `Borders::ALL` → `w.BORDERS_ALL`
- `Borders::TOP` → `w.BORDERS_TOP`

---

## Paragraph Widget

### Rust
```rust
let paragraph = Paragraph::new("Hello, world!")
    .block(block)
    .style(Style::default().fg(Color::White))
    .wrap(Wrap { trim: true });
f.render_widget(paragraph, area);
```

### Odin
```odin
para := w.paragraph_from_string("Hello, world!")
para = w.paragraph_block(para, block)
para = w.paragraph_style(para, tui.style_with_fg(tui.Color_White{}))
para = w.paragraph_wrap(para, .Word)
tui.frame_render_widget(f, w.paragraph_widget(&para), area)
```

---

## Gauge Widget

### Rust
```rust
let gauge = Gauge::default()
    .percent(75)
    .label("75%")
    .gauge_style(Style::default().fg(Color::Green))
    .use_unicode(true);
f.render_widget(gauge, area);
```

### Odin
```odin
gauge := w.gauge_new()
gauge = w.gauge_percent(gauge, 75)
gauge = w.gauge_label(gauge, "75%")
gauge = w.gauge_gauge_style(gauge, tui.style_with_fg(tui.Color_Green{}))
gauge = w.gauge_use_unicode(gauge, true)
tui.frame_render_widget(f, w.gauge_widget(&gauge), area)
```

---

## List Widget (Stateful)

### Rust
```rust
let items = vec![
    ListItem::new("Item 1"),
    ListItem::new("Item 2"),
];
let list = List::new(items)
    .highlight_style(Style::default().fg(Color::Yellow))
    .highlight_symbol(">> ");

let mut state = ListState::default();
state.select(Some(0));

f.render_stateful_widget(list, area, &mut state);
```

### Odin
```odin
items := []w.List_Item{
    w.list_item_from_string("Item 1"),
    w.list_item_from_string("Item 2"),
}
list := w.list_new(items)
list = w.list_highlight_style(list, tui.style_with_fg(tui.Color_Yellow{}))
list = w.list_highlight_symbol(list, ">> ")

state := w.list_state_new()
w.list_state_select(&state, 0)

tui.frame_render_widget(f, w.list_widget(&list, &state), area)
```

---

## Table Widget (Stateful)

### Rust
```rust
let header = Row::new(vec!["Col1", "Col2"])
    .style(Style::default().fg(Color::Yellow));
let rows = vec![
    Row::new(vec!["Data1", "Data2"]),
];
let widths = [
    Constraint::Length(10),
    Constraint::Min(20),
];

let table = Table::new(rows, widths)
    .header(header)
    .highlight_style(Style::default().fg(Color::Green))
    .highlight_symbol(">> ");

let mut state = TableState::default();
state.select(Some(0));

f.render_stateful_widget(table, area, &mut state);
```

### Odin
```odin
header_cells := []w.Table_Cell{
    w.table_cell_from_string("Col1"),
    w.table_cell_from_string("Col2"),
}
header := w.table_row_new(header_cells)
header = w.table_row_style(header, tui.style_with_fg(tui.Color_Yellow{}))

rows := []w.Table_Row{
    w.table_row_new([]w.Table_Cell{
        w.table_cell_from_string("Data1"),
        w.table_cell_from_string("Data2"),
    }),
}

widths := []tui.Constraint{
    tui.Constraint_Length(10),
    tui.Constraint_Min(20),
}

table := w.table_new(rows, widths)
table = w.table_header(table, header)
table = w.table_row_highlight_style(table, tui.style_with_fg(tui.Color_Green{}))
table = w.table_highlight_symbol(table, ">> ")

state := w.table_state_new()
w.table_state_select(&state, 0)

tui.frame_render_widget(f, w.table_widget(&table, &state), area)
```

---

## Tabs Widget

### Rust
```rust
let tabs = Tabs::new(vec!["Tab1", "Tab2", "Tab3"])
    .select(0)
    .highlight_style(Style::default().fg(Color::Cyan));
f.render_widget(tabs, area);
```

### Odin
```odin
tabs := w.tabs_new([]string{"Tab1", "Tab2", "Tab3"})
tabs = w.tabs_select(tabs, 0)
tabs = w.tabs_highlight_style(tabs, tui.style_with_fg(tui.Color_Cyan{}))
tui.frame_render_widget(f, w.tabs_widget(&tabs), area)
```

---

## Sparkline Widget

### Rust
```rust
let data = vec![1, 2, 3, 5, 8, 13];
let sparkline = Sparkline::default()
    .data(&data)
    .style(Style::default().fg(Color::Green));
f.render_widget(sparkline, area);
```

### Odin
```odin
data := []u64{1, 2, 3, 5, 8, 13}
sparkline := w.sparkline_new()
sparkline = w.sparkline_data(sparkline, data)
sparkline = w.sparkline_style(sparkline, tui.style_with_fg(tui.Color_Green{}))
tui.frame_render_widget(f, w.sparkline_widget(&sparkline), area)
```

---

## BarChart Widget

### Rust
```rust
let data = vec![
    ("Label1", 10),
    ("Label2", 20),
];
let barchart = BarChart::default()
    .data(&data)
    .bar_width(3)
    .bar_style(Style::default().fg(Color::Yellow));
f.render_widget(barchart, area);
```

### Odin
```odin
bars := []w.Bar{
    w.bar_new("Label1", 10),
    w.bar_new("Label2", 20),
}
group := w.bar_group_new(bars)
chart := w.bar_chart_new([]w.Bar_Group{group})
chart = w.bar_chart_bar_width(chart, 3)
chart = w.bar_chart_bar_style(chart, tui.style_with_fg(tui.Color_Yellow{}))
tui.frame_render_widget(f, w.bar_chart_widget(&chart), area)
```

---

## Styles

### Rust
```rust
Style::default()
    .fg(Color::Cyan)
    .bg(Color::Black)
    .add_modifier(Modifier::BOLD)
```

### Odin
```odin
style := tui.style_default()
style = tui.style_with_fg(tui.Color_Cyan{})
style = tui.style_with_bg(tui.Color_Black{})
style = tui.style_add_modifier(style, tui.BOLD)
```

**Color mapping:**
- `Color::Reset` → `tui.Color_Reset{}`
- `Color::Black` → `tui.Color_Black{}`
- `Color::Red` → `tui.Color_Red{}`
- `Color::Green` → `tui.Color_Green{}`
- `Color::Yellow` → `tui.Color_Yellow{}`
- `Color::Blue` → `tui.Color_Blue{}`
- `Color::Magenta` → `tui.Color_Magenta{}`
- `Color::Cyan` → `tui.Color_Cyan{}`
- `Color::Gray` → `tui.Color_Gray{}`
- `Color::White` → `tui.Color_White{}`
- `Color::Rgb(r, g, b)` → `tui.Color_Rgb{r, g, b}`
- `Color::Indexed(i)` → `tui.Color_Indexed{i}`

**Modifier mapping:**
- `Modifier::BOLD` → `tui.BOLD`
- `Modifier::DIM` → `tui.DIM`
- `Modifier::ITALIC` → `tui.ITALIC`
- `Modifier::UNDERLINED` → `tui.UNDERLINED`
- `Modifier::REVERSED` → `tui.REVERSED`

---

## Events

### Rust
```rust
use crossterm::event::{self, Event, KeyCode};

if event::poll(Duration::from_millis(100))? {
    if let Event::Key(key) = event::read()? {
        match key.code {
            KeyCode::Char('q') => break,
            KeyCode::Up => { /* handle */ },
            _ => {}
        }
    }
}
```

### Odin
```odin
if tui.event_poll(100) {
    event := tui.event_read()
    #partial switch e in event {
    case tui.Key_Event:
        #partial switch code in e.code {
        case tui.Key_Char:
            if rune(code) == 'q' { break }
        case tui.Key_Arrow:
            if code == .Up { /* handle */ }
        }
    }
}
```

---

## Event Loop Pattern

### Rust
```rust
loop {
    terminal.draw(|f| {
        // render UI
    })?;

    if event::poll(Duration::from_millis(100))? {
        if let Event::Key(key) = event::read()? {
            if key.code == KeyCode::Char('q') {
                break;
            }
        }
    }
}
```

### Odin
```odin
for {
    tui.terminal_draw(&term, proc(f: ^tui.Frame) {
        // render UI
    })

    if tui.event_poll(100) {
        event := tui.event_read()
        #partial switch e in event {
        case tui.Key_Event:
            #partial switch code in e.code {
            case tui.Key_Char:
                if rune(code) == 'q' { break }
            }
        }
    }
}
```

**Или используя terminal_run:**

```odin
tui.terminal_run(&term, draw_func, event_handler, &app_state, 60)
```

---

## Ключевые различия

### 1. Memory Management
**Rust:** Автоматическое управление через ownership  
**Odin:** Явное `defer delete()` для динамических массивов

### 2. Error Handling
**Rust:** `Result<T, E>` и `?` operator  
**Odin:** Прямые вызовы, проверка возвращаемых значений

### 3. Closures
**Rust:** Захватывают переменные автоматически  
**Odin:** Используйте глобальные переменные или передавайте через user_data

### 4. Enums
**Rust:** `match` exhaustive по умолчанию  
**Odin:** Используйте `#partial switch` для неполных проверок

### 5. Builder Pattern
**Rust:** Методы берут `self` или `&mut self`  
**Odin:** Функции берут и возвращают копию структуры

---

## Гарантии совместимости

✅ **Все виджеты из ratatui реализованы**  
✅ **Layout system идентичен**  
✅ **Builder pattern сохранен**  
✅ **Stateful widgets работают так же**  
✅ **Event system совместим**  
✅ **Styles и Colors идентичны**

**Портирование = механическая замена синтаксиса Rust → Odin**

Если вы нашли несовместимость, это баг — сообщите в issues!
