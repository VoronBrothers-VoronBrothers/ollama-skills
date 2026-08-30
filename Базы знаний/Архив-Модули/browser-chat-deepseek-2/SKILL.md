---
name: browser-chat-deepseek
description: "Живой многоходовый диалог с DeepSeek через Chrome + x11-агента: вопрос → скопировать ответ → прочитать → уточнить. Алгоритм цикла + подготовка сессии (--start-maximized). Использовать, когда нужно вести диалог с моделью в браузере."
---

# browser-chat-deepseek: подготовка Chrome с DeepSeek чатом

Скилл = проверка окружения + запуск/восстановление Chrome на весь экран
(https://chat.deepseek.com/). Работу с полем ввода (тип/Enter/копирование)
делает агент — см. /home/voron/Документы/VB-ollama/GitHub ollama and others/Цель - зрение, с нажатием кнопок, вводом текста/ `x11-agent`, рецепт «DeepSeek чат».

## Алгоритм диалога (ЦЕЛЬ, база)

Смысл всего = **живой многоходовый диалог**, а не спам заготовок. Каждый мой
сообщение — ответ модели на предыдущее. Цикл:

1. **Вопрос.** Запускаю агента короткой задачей: «click поле ввода → type
   '<вопрос>' → press enter → done», лимит 3-4 шага.
2. **Пауза.** `sleep` ~8 сек (модель думает, ответ печатается). Если вопрос
   сложный — больше.
3. **Копировать ответ.** Отдельный запуск агента: «scroll до конца → НИЖНЯЯ
   кнопка копирования (два квадратика под всем сообщением) → done», лимит 5-6.
4. **Прочитать.** `DISPLAY=:0 xclip -selection clipboard -o`. Я реально читаю
   текст ответа.
5. **Решить.** По содержанию ответа решаю: уточняющий вопрос / следующий
   вопрос / завершить. Иду в пункт 1.

Правила:
- Каждый этап — **отдельный короткий запуск** агента (3-6 шагов, лимит ≤ 25).
  Не гнать много действий в одном «слепом» запуске — я должен видеть и читать
  промежуточные результаты.
- НЕ слать подряд заготовленные сообщения без чтения ответов (антипример:
  «Тест 1..6» — это спам, не диалог).
- Ответ копировать ВСЕГДА нижней кнопкой после scroll до конца — иначе
  улетит только кусок/код-блок.

## Запуск Chrome (проверено 2026-08-27)

```bash
export DISPLAY=:0
pgrep -x chrome >/dev/null || { google-chrome --start-maximized https://chat.deepseek.com/ >/dev/null 2>&1 & sleep 8; }
```

- **Запускать ТОЛЬКО через `--start-maximized`** — окно занимает весь экран
  (0,0 / 1920x1024 = весь экран за вычетом нижней панели, MAXIMIZED_VERT+HORIZ) поверх панели.
  `--kiosk` и `--start-fullscreen` дают урезанные окна (1920x1024 / 1920x992 @0,32) — не использовать.
- Если Chrome уже жив, но окно DeepSeek не найдено: `xdotool search --onlyvisible --name "DeepSeek"`.

## Проверочные проверки (одним блоком, до запуска агента)

```bash
export DISPLAY=:0
# 1) Агент готов?
python3 -c "import ollama, PIL, pyautogui" && echo OK_PACKAGES
pgrep -f "[x]11_agent.py" >/dev/null && echo "AGENT_BUSY" || echo OK_NO_AGENT
# 2) Своя консоль ИИ (должна висеть поверх всего — НЕ мешать кликам агента)
kwid=$(xdotool search --onlyvisible --name "Konsole" | xargs -I{} sh -c 'test $(xdotool getwindowgeometry {} | grep -c Geometry) -eq 1 && echo {}' | head -1)
for w in $(xdotool search --onlyvisible ""); do n=$(xdotool getwindowname $w 2>/dev/null); [ -n "$n" ] && echo "WIN: $w | $n | $(xdotool getwindowgeometry $w 2>/dev/null | tr '\n' ' ')"; done
# KEEP-ON-TOP окна (потенциальные перекрытия):
for w in $(xdotool search --onlyvisible ""); do st=$(xprop -id $w _NET_WM_STATE 2>/dev/null); case "$st" in *STAYS_ON_TOP*|*_ABOVE*) echo "KEEP-ON-TOP: $w";; esac; done
```

Ожидаемый результат: `OK_PACKAGES`, `OK_NO_AGENT`, окно Chrome «DeepSeek - ...
Google Chrome» @0,0 1920x1024 и единственный KEEP-ON-TOP — консоль ИИ
(Ollama/Konsole) в правом верхнем углу. Если своё окно уехало:
`xdotool windowmove <wid> 1520 251; xdotool windowsize <wid> 383 229`.

## Окрас экрана (1920x1080, KDE X11)

| Окно | Позиция | Размер | Примечание |
|---|---|---|---|
| Desktop | 0,0 | 1920x1080 | фон |
| DeepSeek — Google Chrome | 0,0 | **1920x1024** | `--start-maximized`, поверх панели |
| plasmashell (панель) | 0,1024 | 1920x56 | снизу |
| Консоль ИИ «~ : ollama — Konsole» | 1520,251 | 383x229 | **STAYS_ON_TOP** — зона x∈[1520,1903], y∈[251,480] агенту НЕ кликать |

Зоны для агента: поле ввода DeepSeek — центр низa, ~y∈[830,1000]; кнопки
копирования под сообщениями — слева от центра. Не пересекаются с консолей ИИ.

## Дальше

Агент: клик в поле ввода → type → Enter (проверено: сообщение уходит в ту же
чат-сессию, новый чат не создаётся). Копирование ответа: ВСЕГДА scroll до конца
→ НИЖНЯЯ кнопка «два квадратика» под всем сообщением → читать буфер:
`DISPLAY=:0 xclip -selection clipboard -o`. Подробности — скилл `x11-agent`.
