#!/usr/bin/env bash
# ============================================================
#  quant_switch.sh — КАСКАД КВАНТОВ оркестратора (эскалация/деградация)
#
#  Базовый квант (default, сюда возвращаемся после сложной задачи):
#    iq3 → модель qwen3.8-orchestrator:latest, boot ollama_console.sh
#  Эскалированные (не оставлять надолго!):
#    iq4/q5/q8 → qwen3.8-orchestrator-<tag> + ollama_console_<tag>.sh
#
#  Использование:
#    quant_switch.sh status              # что сейчас: BOOT / модель / существует ли
#    quant_switch.sh switch [tag]        # iq3(=default) | iq4 | q5 | q8 — настроить всё
#    quant_switch.sh restart             # self-restart (state.md обязателен; см. save-session)
# ============================================================
set -euo pipefail

ROOT="/home/voron/Документы/VB-ollama"
PROMPTS="$ROOT/Промты ИИ"
SCRIPTS="$ROOT/Скрипты_ИИ"
RESTART="$SCRIPTS/restart_self.sh"
SRC_MF="$PROMPTS/Modelfile_qwen38_orchestrator_promt_2"
BASE_CON="$SCRIPTS/ollama_console.sh"

die() { echo "ОШИБКА: $*" >&2; exit 1; }

tag_of() { # tag -> FROM-строка / имя модели / console-скрипт
  case "$1" in
    iq3|base) FROM_L="orcarouter/Qwen3.8-27B-Uncensored:iq3_xxs"; MODEL="qwen3.8-orchestrator"; CON="$BASE_CON"; MF="$SRC_MF" ;;
    iq4)  FROM_L="orcarouter/Qwen3.8-27B-Uncensored:iq4_xs";   MODEL="qwen3.8-orchestrator-iq4"; CON="$SCRIPTS/ollama_console_iq4.sh"; MF="$PROMPTS/Modelfile_qwen38_orchestrator_iq4" ;;
    q5)   FROM_L="orcarouter/Qwen3.8-27B-Uncensored:q5_K_M";    MODEL="qwen3.8-orchestrator-q5";  CON="$SCRIPTS/ollama_console_q5.sh";  MF="$PROMPTS/Modelfile_qwen38_orchestrator_q5" ;;
    q8)   FROM_L="orcarouter/Qwen3.8-27B-Uncensored:q8_0";      MODEL="qwen3.8-orchestrator-q8";  CON="$SCRIPTS/ollama_console_q8.sh";  MF="$PROMPTS/Modelfile_qwen38_orchestrator_q8" ;;
    *) die "неизвестный tag '$1' (допустимо: iq3 base iq4 q5 q8)" ;;
  esac
}

cmd_status() {
  local boot model
  boot="$(grep -m1 '^BOOT=' "$RESTART" | sed 's/^BOOT=//; s/"//g')"
  boot="${boot//\$ROOT/$ROOT}"
  model="$(grep -m1 'xdotool type.*orchestrator' "$boot" 2>/dev/null | sed "s/.*\"\(qwen3[^\"]*\)\".*/\1/" || true)"
  echo "BOOT в restart_self.sh: $boot"
  echo "модель, которую заведёт TUI: ${model:-<не распознано>}"
  if ollama list 2>/dev/null | awk '{print $1}' | sed 's/:latest$//' | grep -qx "${model:-__нет__}"; then
    echo "статус модели: СУЩЕСТВУЕТ"
  else
    echo "статус модели: НЕТ В OLLAMA (BOOT битый, self-restart упадёт на выборе модели)"
  fi
}

cleanup_stale() { # target-tag: после switch подчищаем хвосты ВСЕХ тегов, кроме target
  #    (модель + Modelfile + console-скрипт — то, что создал этот скрипт).
  #    ШАБЛОНЫ SRC_MF и BASE_CON не трогаются никогда.
  local t
  for t in iq4 q5 q8; do
    [ "$t" = "$1" ] && continue
    tag_of "$t"
    case "$MODEL" in qwen3.8-orchestrator) die "cleanup пытается удалить БАЗОВУЮ модель — баг" ;; esac
    if [ "$MF" = "$SRC_MF" ] || [ "$CON" = "$BASE_CON" ]; then die "cleanup пытается удалить ШАБЛОН — баг"; fi
    if ollama list 2>/dev/null | awk '{print $1}' | sed 's/:latest$//' | grep -qx "$MODEL"; then
      ollama rm "${MODEL}:latest" >/dev/null && echo "подчищено: модель ${MODEL}:latest"
    fi
    if [ -f "$MF" ]; then  rm "$MF";  echo "подчищено: $MF";   fi
    if [ -f "$CON" ]; then rm "$CON"; echo "подчищено: $CON";   fi
  done
}

cmd_switch() {
  local tag="${1:-iq3}"
  tag_of "$tag"
  echo "== Каскад квантов: ${tag} → модель $MODEL =="

  # 1) Modelfile: для эскалированных генерируем свежую копию из SRC (prompt всегда синхронный)
  if [ "$tag" != "iq3" ] && [ "$tag" != "base" ]; then
    sed -E 's|^FROM |# FROM |' "$SRC_MF" > "$MF"
    sed -i "s|^# FROM ${FROM_L}\$|FROM ${FROM_L}|" "$MF"
    grep -q "^FROM ${FROM_L}$" "$MF" || die "не удалось раскомментировать FROM в $MF"
    echo "Modelfile: $MF (FROM ${FROM_L#*:})"
  fi

  # 2) ollama create (только если модели нет — не трогаем существующую)
  if ollama list 2>/dev/null | awk '{print $1}' | sed 's/:latest$//' | grep -qx "$MODEL"; then
    echo "модель уже существует — пропускаю create"
  else
    ollama create "$MODEL:latest" -f "$MF" >/dev/null
    echo "создана модель $MODEL:latest"
  fi

  # 3) console-скрипт (копия base с подменой имени модели)
  if [ "$CON" != "$BASE_CON" ] && [ ! -f "$CON" ]; then
    cp "$BASE_CON" "$CON"
    sed -i "s|\"qwen3\.8-orchestrator\"|\"$MODEL\"|" "$CON"
    echo "создан console-скрипт $CON"
  fi

  # 4) BOOT в restart_self.sh (точечный sed по строке ^BOOT=)
  sed -i "s|^BOOT=.*|BOOT=\"$CON\"|" "$RESTART"
  echo "BOOT → $CON"

  # 5) Подчистка хвостов: удаляем артефакты всех тегов, кроме активного target
  cleanup_stale "$tag"
  tag_of "$tag" # вернём глобалы после цикла в cleanup
  echo "== готово. Дальше: обновить state.md (квант=$tag) и quant_switch.sh restart =="
}

cmd_restart() {
  [ -s "$(dirname "$RESTART")/../Папка заданий для AI/state.md" ] || die "state.md пуст/нет — restart_self.sh откажет"
  rm -f "$ROOT/Папка заданий для AI/.restart_count"
  setsid bash "$RESTART" </dev/null >/tmp/restart_$(date +%Y%m%d_%H%M%S).log 2>&1 &
  echo "restart запущен (лог /tmp/restart_*.log, последний)"
}

case "${1:-status}" in
  status)  cmd_status ;;
  switch)  shift; cmd_switch "${1:-iq3}" ;;
  restart) cmd_restart ;;
  *) die "команды: status | switch [tag] | restart" ;;
esac
