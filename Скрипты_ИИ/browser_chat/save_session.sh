#!/usr/bin/env bash
# save_session.sh <вопрос> <скрин-ответа.png>
# Сохраняет: sessions/<timestamp>/question.txt, answer.png, meta.json
set -e
Q=${1:-unknown}
IMG=${2:-/tmp/resp_view.png}
DIR="sessions/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DIR"
echo "$Q" > "$DIR/question.txt"
cp "$IMG" "$DIR/answer.png" 2>/dev/null || true
cat > "$DIR/meta.json" <<JSON
{"question": "$Q", "timestamp": "$(date -I)", "image": "answer.png"}
JSON
echo "сохранено: $DIR"
