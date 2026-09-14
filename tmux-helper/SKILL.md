---
name: tmux-helper
description: "Приоритетные помощники. Облачные/локальные ИИ-помощники через ollama TUI в окнах MAIN-HOUSE. Запуск готового облачного помощника — одна команда `helper-start`; можно запустить несколько параллельно."
---

# tmux-helper

Облачный (или локальный) ИИ-помощник = отдельное окно `MAIN-HOUSE:helper_N` с запущенным TUI `ollama`.
Параллельные помощники — разные окна, изолированы.

## Ключевая команда: `helper-start`

Одна команда — готовое облачное меню моделей (курсор на последней видимой строке):

```bash
helper-start
```

Что делает скрипт внутри:

1. Находит следующий свободный номер (`helper_1`, `helper_2`, …) по существующим окнам.
2. Создаёт окно, запускает `ollama` TUI (Enter).
3. Стрелка вправо → фильтр `cloud`.
4. Ждёт появления списка cloud-моделей (retry до 8 с).
5. `PageDown` — курсор на последней видимой строке.

Вывод: имя окна + кадр (`capture-pane`). После этого окно **готово к выбору модели**.

Целевое target для send-keys / capture: `MAIN-HOUSE:helper_N`.

## Выбор модели (2 команды)

После `helper-start` курсор на последней видимой строке cloud-списка.

```bash
# Если нужная модель — последняя видимая: просто Enter
tmux send-keys -t MAIN-HOUSE:helper_1 C-m

# Если нужна другая: прокрутить и выбрать
tmux send-keys -t MAIN-HOUSE:helper_1 PageUp        # вверх по списку
tmux capture-pane -pt MAIN-HOUSE:helper_1 | grep -v '^[[:space:]]*$'   # проверить где курсор
tmux send-keys -t MAIN-HOUSE:helper_1 Up            # точная навигация (Up/Down)
tmux send-keys -t MAIN-HOUSE:helper_1 C-m          # Enter — выбрать модель, открыть чат
```

После Enter открывается **чат** с выбранной облачной моделью.

## Отправка задачи и чтение ответа

```bash
# 1. Написать задачу (literal — безопасно для спец. символов)
tmux send-keys -l -t MAIN-HOUSE:helper_1 'Текст задачи'
sleep 0.3
tmux send-keys -t MAIN-HOUSE:helper_1 C-m

# 2. Читать ответ frame-capture (retry до появления текста ответа)
for i in $(seq 1 30); do
    OUT=$(tmux capture-pane -pt MAIN-HOUSE:helper_1 | grep -v '^[[:space:]]*$')
    [ ${#OUT} -gt 200 ] && break       # порог — ответ длиннее ~200 символов
    sleep 1
done
echo "$OUT"
```

Порог и число попыток подстраивай под объём задачи. Для коротких ответов достаточно `sleep 5` + один capture.

## Закрытие помощника

Когда задача выполнена:

```bash
tmux kill-window -t MAIN-HOUSE:helper_N
```

Окна `helper_*` не переиспользуются — каждый запуск создаёт новое с авто-номером.

## Правила

| Правило | Зачем |
|---|---|
| Окно `MAIN-HOUSE:control-center` (idx 0) не трогать | Занято enterwatch + логами, send-keys туда запрещены |
| Каждый помощник = своё окно `helper_N` | Изоляция; параллельная работа без конфликтов |
| Ввод текста только через `send-keys -l … C-m` | `-l` (literal) экранирует спец. символы |
| Чтение — frame-capture с retry | TUI асинхронный; без retry уловишь пустой кадр или половину ответа |
| После каждого GUI-шага проверь кадр | Убедись что курсор/список там, где ждёшь (особенно при выборе модели) |
| `helper-start` завершён → окно готово | Не дублируй шаги вручную; скрипт уже сделал PageDown и фильтр cloud |

## Быстрый пример (полный цикл)

```bash
# 1. Запустить помощника
helper-start
# Вывод: "helper_1 готов: MAIN-HOUSE:helper_1 (курсор после PageDown)" + кадр

# 2. Выбрать последнюю видимую модель (Enter)
tmux send-keys -t MAIN-HOUSE:helper_1 C-m
sleep 2

# 3. Отправить задачу
tmux send-keys -l -t MAIN-HOUSE:helper_1 'Что такое tmux? Ответь в одном абзаце.'
sleep 0.3
tmux send-keys -t MAIN-HOUSE:helper_1 C-m

# 4. Подождать и прочитать ответ
sleep 6
tmux capture-pane -pt MAIN-HOUSE:helper_1 | grep -v '^[[:space:]]*$'

# 5. Закрыть окно (когда больше не нужен)
tmux kill-window -t MAIN-HOUSE:helper_1
```
