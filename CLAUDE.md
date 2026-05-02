# odintui

Odin-язычный TUI фреймворк, аналог ratatui (Rust). Цель — максимальная совместимость с ratatui API.

## Мотивация

Нужен для переписывания https://github.com/psmux/pstop на Odin.
Единственный блокер pstop → Odin это отсутствие TUI фреймворка.

## Структура

```
odintui/          -- основной пакет (library)
  buffer.odin     -- Cell, Buffer, diff
  layout.odin     -- Rect, Direction, Constraint, Layout, layout_split
  style.odin      -- Color, Modifier, Style, style_patch
  text.odin       -- Span, Line, Text
  symbols.odin    -- Border_Set, bar chars (BORDER_PLAIN/ROUNDED/DOUBLE/THICK)
  frame.odin      -- Widget (vtable), Frame, frame_render_widget
  terminal.odin   -- Terminal, terminal_draw, init, restore

  backend/
    backend.odin           -- Backend vtable, Draw_Cell, Ansi_Color (нет импорта родителя)
    crossterm.odin         -- общий ANSI код, Crossterm_Backend
    crossterm_windows.odin -- Win32 raw mode, GetConsoleScreenBufferInfo
    crossterm_posix.odin   -- termios raw mode, TIOCGWINSZ (#+build linux, darwin)

  widgets/
    block.odin      -- Block, Borders, block_inner, block_render
    paragraph.odin  -- Paragraph, wrap, scroll
```

## Ключевые архитектурные решения

- **Нет циклических импортов**: `backend` пакет не импортирует `odintui`.
  Вместо этого `backend.Draw_Cell` — независимый тип, `terminal.odin` конвертирует
  через `_cell_to_draw` / `_color_to_ansi`.
- **Платформенный код** через file suffixes (`_windows.odin`, `_posix.odin`),
  не через `when ODIN_OS` с импортами внутри (компилятор запрещает).
- **Widget** — vtable-struct `{data: rawptr, render: proc(...)}` вместо интерфейса.
- **Double buffer + diff flush** — как в ratatui: рендер в `current`, diff с `previous`,
  только изменившиеся ячейки идут в backend.
- **Backend.size** возвращает `[2]u16` (не Rect) чтобы не тянуть типы родителя.

## Что сделано

- [x] Ядро: Buffer, Layout, Style, Text, Frame, Terminal
- [x] Backend: Windows + POSIX
- [x] Widgets: Block, Paragraph
- [x] example/main.odin — собирается и линкуется

## Что делать дальше

- [ ] events.odin — ввод клавиатуры и мыши (ReadConsoleInput / read)
- [ ] widgets/list.odin
- [ ] widgets/table.odin
- [ ] widgets/gauge.odin
- [ ] widgets/sparkline.odin
- [ ] widgets/barchart.odin
- [ ] Проверить example в реальном терминале

## Сборка

```
odin build example -out:example/demo.exe
```

## GitHub

https://github.com/odintui/odintui
