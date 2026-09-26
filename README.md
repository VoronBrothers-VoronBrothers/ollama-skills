# ollama-skills

Скиллы Ollama (`SKILL.md`) для локального ИИ-оркестратора + вспомогательные скрипты, промты и база знаний.

## Скиллы (28)

| Скилл | Назначение |
|---|---|
| ai-solid-brain | Спросить ИИ-чат в Chrome: Квен(Qwen), Дипсик(DeepSeek) — с приоритетом выбора чата и копированием ответа |
| browser-chat | Чат с DeepSeek (Дипсик) по визуальному алгоритму: скриншоты → свои клики/ввод глазами, скрипты — только fallback. Также — FALLBACK интернет-поиск, когда web_search/web_fetch/webq упёрлись |
| carbonyl | Терминальный браузер на Chromium (Carbonyl) для тяжёлых JS-сайтов: когда `webq`/`w3m` возвращают пустое или обрезанное содержимое (SPA, React, Vue); рендерит страницу целиком через tmux-сессию |
| cpu-assistant-cpu | Рекомендация тестовых моделей: лёгкий локальный или облачный ИИ, не вытесняет модель с VRAM |
| deepseek | Спросить deepseek в чате Chrome: задать вопрос, дождаться ответа и скопировать его (совет/второе мнение) |
| edit-tool | Правильное использование инструмента edit: абсолютные пути и `..`, `~` раскрывается в home, относительный — от cwd; точечные правки без retries |
| enterwatch | Гарантия отправки сообщений самому себе (selfshot): каждые 5 минут жмёт Enter в tmux-сессии оркестратора, если там лежит неотправленный текст. ОБЯЗАТЕЛЬНО подключить перед selfshot |
| gui-input | Управление мышью/клавиатурой (move, click, type, press keys) в GUI-приложениях |
| helper | Локальные ИИ-помощники: разовый вызов по API (`curl /api/chat`, готовность = выход процесса) и интерактивный tmux-чат; делегирование подзадач, параллельная работа |
| main-house | Запуск окружения MAIN-HOUSE (tmux-сессия с окнами control-center/ollama-logs/work/ollama-cloud/ollama-cpu): полный перезапуск или создание окон. Выполнить в начале каждого диалога |
| mcp-mcp | Custom TUI fork со встроенным MCP (stdio + streamable HTTP) через `~/.ollama/mcp.json`. Hot reload без рестарта: `/mcp reload` |
| mcp | Встроенный MCP (stdio + streamable HTTP) через `~/.ollama/mcp.json`. Готовые конфигурации серверов — в `docs/<server_name>/mcp.json` |
| model-boot-switch | Смена/запуск другой модели оркестратора (апгрейд кванта, смена бэкенда): Modelfile → `ollama create` → тест → boot-скрипт + перезапуск |
| mouse-click | ЛКМ-клик по координатам X Y экрана (`xdotool`, `scripts/click.py`) — после selfshot/помощника с сеткой |
| ollama-model | Запуск локального TUI-окна MAIN-HOUSE с фильтром по имени модели (одна команда → готовое окно) |
| ollama-safe-call | Безопасный вызов локальных Ollama-моделей: каждый вызов в фоне + polling, не рвётся bash-лимитом 180s |
| ollama-watch | Центр контроля №2: живой поток логов `ollama.service` (journalctl -f). Автоматически поднимается в окне MAIN-HOUSE:ollama-logs вместе с main-house |
| quant-cascade | Каскад квантов: эскалация iq3→iq4/q5/q8 на сложной задаче и ОБЯЗАТЕЛЬНАЯ деградация обратно; при переходе выше — num_ctx ≤ 16384 |
| raise-orchestrator | Перезапуск оркестратора (ollama TUI): убить старую tmux-сессию → поднять заново → отправить задачу из tasks.md |
| save-session | Память + самовозобновление (self-restart): чекпоинты перед рискованными шагами, выход из зацикливания, работает для любой модели и из любого каталога |
| screenshot | Скриншоты рабочего стола/окон и визуальная проверка результата |
| selfshot | Отправить самому себе скриншот экрана в tmux-сессию с задачей на анализ (саморефлексия, верификация GUI); сначала активировать enterwatch |
| show-image | Отправка изображения в собственное TUI-терминал оркестратора: следующий ход приходит со скриншотом, без нового окна |
| skill-creator | Создание и улучшение скиллов (SKILL.md), помощь с установкой |
| tmux | Управление интерактивными сессиями (ollama, REPL, TUI): защита от гонок, зависаний и искажения контекста |
| tmux-helper | Приоритетные помощники: облачные/локальные ИИ через ollama TUI в окнах MAIN-HOUSE. Одна команда `helper-start`; можно запустить несколько параллельно |
| webq | Штатный локальный веб-поиск и чтение страниц (DDG/Bing via curl), без API-ключей. Default для интернет-поиска |
| work | Интерактивное рабочее окно MAIN-HOUSE:work — чистый login-shell; поднимается автоматически вместе с main-house, всегда последнее |

## Структура

```
<скилл>/<SKILL.md>            # 20 скиллов — копируются в ~/.ollama/skills/
find, grep                    # обёртки-команды (find→fdfind, grep→ripgrep), архив копий; рабочие версии — в Скрипты_ИИ/
enterwatch_old_*/             # архив старых версий enterwatch
Промты ИИ/                    # Modelfile'ы и куски промтов для моделей оркестратора/помощников
├── Modelfile_orchestrator_promt, _naked, _self-reflection, orchestrator-helper_promt ...
└── Куски/                    #   отдельные блоки (Дипсик.txt и др.)
Скрипты_ИИ/                   # скрипты оркестратора (не в ~/.ollama/skills/)
├── browser_chat/             #   автоскрипты browser-chat: full_cycle.sh, open_url.sh, scroll_capture.sh,
│                             #   copy_vision.sh, win_fix.sh, save_session.sh; sessions/, urls/, archive/
├── find, grep               #   обёртки-команды (find→fdfind, grep→ripgrep)
├── clip_hold.py  focus_consolidate.sh  ollama_console.sh
├── quant_switch.sh  restart_self.sh  show_image.sh
└── top_words.py
Базы знаний/                  # заметки и лонг-мемория (vb-ollama-long-memory), инструкции, архив
Modelfile_qwen38_orchestrator_promt_2   # Modelfile оркестратора (qwen3.8, базовый квант iq3_xxs)
```

## Установка

- Скиллы: скопировать каждый каталог в `~/.ollama/skills/`. (Архивные папки вида `*_old_*` — не скиллы, копировать не нужно.)
- Обёртки `find`, `grep`: поставить нужную версию из `Скрипты_ИИ/find|grep` в PATH (зависимости: `fdfind`/`fd`, `ripgrep`).
- Скрипт веб-поиска: `webq/webq.sh` → `~/.local/bin/webq` (`chmod +x`). Зависимости: `w3m`, `lynx`, `python3`; API-ключи не нужны.
- `Скрипты_ИИ/` — по необходимости, в рабочие пути оркестратора (не в `~/.ollama/skills/`).

## Лицензия

Apache License 2.0 (см. LICENSE).
