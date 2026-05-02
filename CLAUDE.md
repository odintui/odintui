# odintui — План работы

## Цель
Создать TUI фреймворк на Odin, максимально совместимый с ratatui (Rust).
Главная задача: портировать https://github.com/psmux/pstop с Rust на Odin.

## Текущий статус

### ✅ Готово
- Ядро: Buffer, Layout, Style, Text, Frame, Terminal
- Backend: Windows (Win32) + POSIX (termios)
- Базовые виджеты: Block, Paragraph
- Все виджеты для pstop:
  - Gauge (прогресс-бары)
  - Sparkline (компактные графики)
  - Tabs (вкладки)
  - List + State (списки с selection)
  - Table + State (таблицы — ключевой виджет)
  - BarChart (bar charts)
- **Events system:**
  - events.odin — общий интерфейс (Key, Mouse, Resize, Focus, Paste)
  - events_windows.odin — ReadConsoleInput (Win32)
  - events_posix.odin — read() + ANSI escape parsing
  - event_poll, event_read API
- **Event loop integration:**
  - terminal_run — event loop с user_data
  - terminal_run_simple — event loop с closures
- Helpers: centered_rect, rune_to_string, format_u64, style helpers
- Примеры: basic demo + interactive demo + counter demo
- **Все ошибки компиляции исправлены:**
  - Сигнатуры block_render и block_inner (принимают ^Block)
  - Добавлена buffer_set_cell для установки одной ячейки
  - Перегрузка text_width для string и Text
  - Исправлена индексация GAUGE_BLOCKS
  - Добавлены #partial switch
  - Исправлены проверки span.style
  - Исправлено создание Widget для List и Table

### ⏳ В работе
**Ничего** — все компилируется и собирается без ошибок!

**Проверено:**
- ✅ example/main.odin
- ✅ example/counter.odin  
- ✅ example/interactive.odin
- ✅ example/widgets_demo.odin

### 📋 Следующие шаги

**Приоритет 1: Тестирование**
- Проверить все виджеты в реальном терминале
- Unicode rendering (gauge sub-blocks, sparkline bars)
- Scroll и selection в List/Table
- Popup окна через centered_rect

**Приоритет 3: Порт pstop**
- Event loop pattern
- Keyboard navigation (hjkl, arrows, F-keys)
- Process table с real-time updates
- Модальные окна (kill, filter, sort)

## Архитектура

### Ключевые решения
- **No circular imports**: backend не импортирует odintui
- **Widget vtable**: `{data: rawptr, render: proc(...)}`
- **Builder pattern**: все setters возвращают копию
- **Stateful widgets**: отдельные State структуры
- **Platform code**: file suffixes (`_windows.odin`, `_posix.odin`)

### Структура
```
odintui/
├── [core files]         # buffer, layout, style, text, frame, terminal
├── backend/             # crossterm (ANSI + platform-specific)
└── widgets/             # block, paragraph, gauge, sparkline, tabs, list, table, barchart

example/
├── main.odin           # базовый пример
└── widgets_demo.odin   # демо всех виджетов
```

## Совместимость с ratatui

Rust код:
```rust
let table = Table::new(rows, widths)
    .header(header_row)
    .block(Block::bordered().title("Processes"))
    .highlight_symbol(">> ");
frame.render_stateful_widget(table, area, &mut state);
```

Odin код (механический перенос):
```odin
t := w.table_new(rows[:], widths[:])
t  = w.table_header(t, header_row)
b := w.block_new()
b  = w.block_title(b, "Processes")
b  = w.block_borders(b, w.BORDERS_ALL)
t  = w.table_block(t, b)
t  = w.table_highlight_symbol(t, ">> ")
tui.frame_render_widget(f, w.table_widget(&t, &state), area)
```

## Сборка
```bash
odin build example -out:example/demo.exe
odin build example/widgets_demo.odin -file -out:example/widgets_demo.exe
```

## GitHub
https://github.com/odintui/odintui
