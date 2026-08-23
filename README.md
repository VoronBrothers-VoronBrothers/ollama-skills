# ollama-skills

Скиллы Ollama (SKILL.md) для локального ИИ-оркестратора + вспомогательные скрипты в `Скрипты_ИИ/`.

## Скиллы

| Скилл | Назначение |
|---|---|
| browser-chat | Автоматизация чата DeepSeek (chat.deepseek.com): авто-старт Chrome, ввод вопроса, **чтение ответа копированием по зрению** (скрин → клик по Copy → буфер). Также — резервный интернет-поиск, когда web_search/web_fetch/webq недоступны |
| edit-tool | Правильное использование инструмента edit: ТОЛЬКО относительные пути от cwd, точечные правки, без retries |
| gui-input | Управление мышью/клавиатурой (move, click, type, press keys) в GUI-приложениях |
| model-boot-switch | Смена/запуск другой модели оркестратора (апгрейд кванта, смена бэкенда): Modelfile → create → boot-скрипт + перезапуск |
| ollama-safe-call | Безопасный вызов локальных Ollama-моделей: каждый вызов в фоне + polling, не рвётся bash-лимитом 180s |
| quant-cascade | Каскад квантов: эскалация iq3→iq4/q5/q8 на сложной задаче и ОБЯЗАТЕЛЬНАЯ деградация обратно; при переходе выше — num_ctx ≤ 16384 |
| save-session | Память + самовозобновление (self-restart): чекпоинты перед рискованными шагами, выход из зацикливания, работает из любого каталога |
| screenshot | Скриншоты рабочего стола/окон и визуальная проверка результата |
| show-image | Отправка изображения в собственное TUI-терминал оркестратора (консоль): следующий ход приходит со скриншотом, без нового окна |
| webq | Штатный локальный веб-поиск и чтение страниц (w3m + DuckDuckGo) без API-ключей; приоритет над web_search/web_fetch, Дипсик — только как fallback |

## Структура

```
<скрилл>/<SKILL.md>        # 10 скиллов — копируются в ~/.ollama/skills/
Скрипты_ИИ/                # скрипты оркестратора (пользователь вставляет в свои ~/.ollama / домашние пути)
├── browser_chat/          #   автоскрипты browser-chat: full_cycle.sh, open_url.sh,
│                          #   scroll_capture.sh, copy_vision.sh, win_fix.sh, save_session.sh
│   ├── sessions/  urls/   #   артефакты сессий и URL-файлы
│   └── archive/           #   устаревшие: copy_answer.sh, detect_copy_row.py
├── clip_hold.py  focus_consolidate.sh  ollama_console.sh
├── quant_switch.sh  restart_self.sh  show_image.sh
└── top_words.py
Modelfile_qwen38_orchestrator_promt_2   # Modelfile оркестратора (qwen3.8, базовый квант iq3_xxs)
```

## Установка

- Скиллы: скопировать каждый каталог в `~/.ollama/skills/`.
- Скрипт веб-поиска: `webq/webq.sh` → `~/.local/bin/webq` (`chmod +x`). Зависимости: `w3m`, `lynx`, `python3`; API-ключи не нужны.
- `Скрипты_ИИ/` — по необходимости, в рабочие пути оркестратора (не в `~/.ollama/skills/`).
