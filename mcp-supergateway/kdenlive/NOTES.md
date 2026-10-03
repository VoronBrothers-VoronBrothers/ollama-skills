# Kdenlive MCP — Headless Video Editing

MCP-сервер для работы с видео без GUI. Генерит MLT XML + рендер через melt.
Порт: **8815**. Запуск и подключение — в основном скилле `mcp-supergateway`.

## Инструменты

### `build_project` — собрать проект

Создаёт .mlt файл из клипов, переходов, музыки и титров.

```json
{
  "clips": [
    {"path": "/home/voron/Videos/a.mp4"},
    {"path": "/home/voron/Videos/b.mp4", "trim_in": 5, "trim_out": 30},
    {"path": "/home/voron/Videos/c.mp4", "speed": 0.5}
  ],
  "project_name": "my_edit",
  "width": 1920, "height": 1080, "fps_num": 25, "fps_den": 1,
  "transitions": [
    {"type": "dissolve", "duration": 1.0},
    {"type": "wipe_right", "duration": 0.5}
  ],
  "audio_tracks": ["/home/voron/Music/track.ogg"],
  "text_overlays": [
    {"content": "Привет!", "start": 2, "end": 5, "position": "center", "size": 64}
  ]
}
```

**Поля клипа:**
| Поле | Тип | Значение |
|------|-----|----------|
| path | str | Абсолютный путь к файлу (обязательно) |
| trim_in | float | С какой секунды начать (default 0) |
| trim_out | float | До какой секунды, -1 = до конца (default -1) |
| speed | float | 1.0=норма, 0.5=замедление x2, 2.0=ускорение x2 |

**Типы переходов:** dissolve, wipe_left, wipe_right, wipe_up, wipe_down

**Позиции титров:** top, center, bottom

### `render_video` — рендер

```json
{
  "project_path": "/home/voron/Videos/kdenlive-mcp/my_edit.mlt",
  "output_path": "",
  "format": "mp4",
  "vcodec": "libx264",
  "acodec": "aac",
  "crf": 23
}
```

**Кодеки:** libx264 (h.264), libx265 (hevc), libvpx-vp9, mpeg4  
**Контейнеры:** mp4, mkv, webm  
**CRF:** 18=почти без потерь, 23=баланс, 28=малый размер

### `probe_file` — информация о файле

```json
{"path": "/home/voron/Videos/a.mp4"}
```
Возвращает: длительность, разрешение, fps, видео/аудио кодеки, размер.

### `list_projects` — список проектов

Без аргументов. Показывает все .mlt файлы с датами и размерами.

### `get_capabilities` — возможности melt

Без аргументов. Профили (1080p, 720p…), видео- и аудиокодеки.

## Приёмы

- **Склейка клипов:** просто `build_project` с clips без transitions → последовательная нарезка
- **Crossfade между клипами:** укажи transitions, их количество = len(clips)-1 максимум
- **Замедление (slow-mo):** speed=0.3–0.5 для драматичного замедления
- **Фоновая музыка:** audio_tracks — стартует с 0 и идёт на весь проект
- **Титры в начале/конце:** text_overlays с start/end по секундам

## Ограничения

- melt рендерит медленно (CPU), для GPU нужен CUDA-enabled build MLT
- Переходы вставлены между клипами, но точное поведение luma-фильтров может отличаться от Kdenlive GUI
- qtext (титры) — базовый рендер текста без анимации
- Нет поддержки ключевых кадров (keyframes) для фильтров
- При speed≠1.0 тайминг может сдвинуться на 1-2 кадра

## Файлы

| Путь | Назначение |
|------|-----------|
| /home/voron/mcp-kdenlive/server.py | MCP сервер (5 инструментов) |
| /home/voron/mcp-kdenlive/.venv/ | Python venv с mcp==1.30.0 |
| ~/Videos/kdenlive-mcp/ | Проекты .mlt и рендерный вывод |

## Остановка

```bash
pkill -f "supergateway.*8815"
```
