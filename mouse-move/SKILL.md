---
name: mouse-move
description: Точное наведение мыши по координатам. Плашка + программная проверка. Без клика (клик = скилл mouse-click).
---

# Наведение мыши

Этот скилл **только двигает курсор**. Клик — отдельный скилл `mouse-click`.

## Вызов

```bash
python3 ~/.ollama/skills/mouse-move/scripts/run.py X Y [delay_ms] [--tolerance N]
```

| Параметр | Значение | По умолчанию |
|----------|----------|--------------|
| `X Y` | Целевые координаты (обязательно) | — |
| `delay_ms` | Пауза после движения, мс | 80 |
| `--tolerance N` | Допустимое отклонение в verify, px | 3 |

## Что делает по шагам

1. **ensure-overlay** — поднимает плашку курсора (если не запущена)
2. **get-cursor** — печатает где был курсор до движения
3. **move-to** — `xdotool mousemove X Y` + пауза
4. **verify** — перечитывает позицию, сверяет с целью, печатает OK или DRIFT

## Примеры

```bash
# Навести на (800 450)
python3 ~/.ollama/skills/mouse-move/scripts/run.py 800 450

# Навести с большей паузой и точностью 1px
python3 ~/.ollama/skills/mouse-move/scripts/run.py 800 450 200 --tolerance 1
```

## Управление пайплайном

Файл `scripts/pipeline.json` — список шагов, порядок и вкл/выкл:

```json
[
  {"name": "ensure-overlay", "enabled": true},
  {"name": "get-cursor",     "enabled": true},
  {"name": "move-to",        "enabled": true},
  {"name": "verify",         "enabled": true}
]
```

Чтобы отключить шаг — `"enabled": false`. Чтобы добавить — создать `plugins/имя.py` и дописать строку. Порядок = порядок в списке.

## Визуальная проверка

Если нужно убедиться что курсор на правильном элементе — сделай selfshot (скилл selfshot-2). Плашка будет видна на снимке. После selfshot плашка гаснет — не страшно, следующий `run.py` поднимет её обратно.

## После наведения

Когда курсор на месте → вызывай `mouse-click`:
```bash
python3 ~/.ollama/skills/mouse-click/scripts/click.py X Y 0
```
(delay=0 — мы уже на месте, докатываться не надо)
