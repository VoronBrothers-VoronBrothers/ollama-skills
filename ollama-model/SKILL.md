---
name: ollama-model
description: Launch a local ollama TUI helper in MAIN-HOUSE filtered by model name. Use when user wants to run a specific local model (e.g. "запусти gemma", "открой qwen в окне"). One command — ready window with model list.
---

# ollama-model

Локальный ИИ-помощник = отдельное окно `MAIN-HOUSE:ollama_N` с запущенным TUI `ollama`, отфильтрованным по имени модели.
Параллельные помощники — разные окна, изолированы.

## Ключевая команда: `ollama-model <model_name>`

Одна команда — готовое окно с фильтром по указанной модели (курсор на последней видимой строке):

```bash
ollama-model gemma
ollama-model qwen3-cod
ollama-model ornith-1.5
```

> Точное название модели (с тегом) можно узнать: `ollama list`

Что делает скрипт внутри:

1. Находит следующий свободный номер (`ollama_1`, `ollama_2`, …) по существующим окнам.
2. Создаёт окно, запускает `ollama` TUI (Enter).
3. Стрелка вправо → навигация в список моделей.
4. Вводит имя модели как фильтр (`send-keys -l`).
5. Ждёт появления списка (retry до 8 с).
6. `PageDown` — курсор на последней видимой строке.

Вывод: имя окна + кадр (`capture-pane`). После этого окно **готово к выбору модели**.

Целевой target для send-keys / capture: `MAIN-HOUSE:ollama_N`.

## Выбор модели (2 команды)

После `ollama-model` курсор на последней видимой строке отфильтрованного списка.

```bash
# Если нужная модель — последняя видимая: просто Enter
tmux send-keys -t MAIN-HOUSE:ollama_1 C-m

# Если нужна другая: прокрутить и выбрать
tmux send-keys -t MAIN-HOUSE:ollama_1 PageUp        # вверх по списку
tmux capture-pane -pt MAIN-HOUSE:ollama_1 | grep -v '^[[:space:]]*$'   # проверить где курсор
tmux send-keys -t MAIN-HOUSE:ollama_1 Up            # точная навигация (Up/Down)
tmux send-keys -t MAIN-HOUSE:ollama_1 C-m          # Enter — выбрать модель, открыть чат
```

После Enter открывается **чат** с выбранной локальной моделью.

## Очистка контекста: `/new`

Между задачами **обязательно** чисти контекст, отправляя `/new`:

```bash
tmux send-keys -l -t MAIN-HOUSE:ollama_1 '/new'
sleep 0.3
tmux send-keys -t MAIN-HOUSE:ollama_1 C-m
sleep 1
```

Без этого предыдущий диалог остаётся в контексте и искажает ответы на новые задачи.

После `/new` надпись `full access enabled` внизу исчезает — это **нормальное поведение**, модели всё равно доступны инструменты.

## Отправка задачи и чтение ответа

```bash
# 0. (если не первая задача) очистить контекст
tmux send-keys -l -t MAIN-HOUSE:ollama_1 '/new'
sleep 0.3
tmux send-keys -t MAIN-HOUSE:ollama_1 C-m
sleep 1

# 1. Написать задачу (literal — безопасно для спец. символов)
tmux send-keys -l -t MAIN-HOUSE:ollama_1 'Текст задачи'
sleep 0.3
tmux send-keys -t MAIN-HOUSE:ollama_1 C-m

# 2. Читать ответ frame-capture (retry до появления текста ответа)
for i in $(seq 1 30); do
    OUT=$(tmux capture-pane -pt MAIN-HOUSE:ollama_1 | grep -v '^[[:space:]]*$')
    [ ${#OUT} -gt 200 ] && break       # порог — ответ длиннее ~200 символов
    sleep 1
done
echo "$OUT"
```

Порог и число попыток подстраивай под объём задачи. Для коротких ответов достаточно `sleep 5` + один capture.

## Закрытие помощника

Когда задача выполнена:

```bash
tmux kill-window -t MAIN-HOUSE:ollama_N
```

Окна `ollama_*` не переиспользуются — каждый запуск создаёт новое с авто-номером.

## Правила

| Правило | Зачем |
|---|---|
| Окно `MAIN-HOUSE:control-center` (idx 0) не трогать | Занято enterwatch + логами, send-keys туда запрещены |
| Каждый помощник = своё окно `ollama_N` | Изоляция; параллельная работа без конфликтов |
| Ввод текста только через `send-keys -l … C-m` | `-l` (literal) экранирует спец. символы |
| Чтение — frame-capture с retry | TUI асинхронный; без retry уловишь пустой кадр или половину ответа |
| После каждого GUI-шага проверь кадр | Убедись что курсор/список там, где ждёшь (особенно при выборе модели) |
| `ollama-model` завершён → окно готово | Не дублируй шаги вручную; скрипт уже сделал PageDown и фильтр |
| Между задачами — `/new` | Чистит контекст; без этого предыдущий диалог искажает новые ответы |
| Модель из `ollama list` не отображается в TUI при фильтре → использовать другую модель, которая отображается | Некоторые модели TUI просто не показывает; не трать время на отладку — выбери альтернативу |

## Разница с tmux-helper

| | tmux-helper (`helper-start`) | ollama-model |
|---|---|---|
| Фильтр | фиксированный "cloud" | произвольный текст из аргумента |
| Назначение | облачные модели (orcarouter) | локальные/любые по имени |
| Окна | `helper_N` | `ollama_N` |

## Быстрый пример (полный цикл)

```bash
# 1. Запустить помощника с моделью gemma
ollama-model gemma
# Вывод: "ollama_1 готов: MAIN-HOUSE:ollama_1 (фильтр: gemma, курсор после PageDown)" + кадр

# 2. Выбрать последнюю видимую модель (Enter)
tmux send-keys -t MAIN-HOUSE:ollama_1 C-m
sleep 2

# 3. (для второй и последующих задач) очистить контекст
# tmux send-keys -l -t MAIN-HOUSE:ollama_1 '/new'
# sleep 0.3
tmux send-keys -t MAIN-HOUSE:ollama_1 C-m
sleep 1

# 4. Отправить задачу
tmux send-keys -l -t MAIN-HOUSE:ollama_1 'Что такое tmux? Ответь в одном абзаце.'
sleep 0.3
tmux send-keys -t MAIN-HOUSE:ollama_1 C-m

# 5. Подождать и прочитать ответ
sleep 6
tmux capture-pane -pt MAIN-HOUSE:ollama_1 | grep -v '^[[:space:]]*$'

# 6. Закрыть окно (когда больше не нужен)
tmux kill-window -t MAIN-HOUSE:ollama_1
```
