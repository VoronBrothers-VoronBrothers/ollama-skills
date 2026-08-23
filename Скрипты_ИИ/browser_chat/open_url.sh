#!/usr/bin/env bash
# open_url.sh <url-файл> | open_url.sh "https://..."
set -e
URL=${1:-deepseek}
[[ "$URL" == http* ]] || URL=$(cat "$(dirname "$0")/urls/$URL.txt" 2>/dev/null)
[ -z "$URL" ] && { echo "нет URL: $URL"; exit 1; }
# если браузер есть — открыть вкладкой, если нет — запустить
if ! xdotool search --name "" | while read w; do xprop -id $w WM_CLASS 2>/dev/null; done | grep -q google-chrome; then
  setsid google-chrome "$URL" >/dev/null 2>&1 & disown
  sleep 3
fi
echo "открываю: $URL"
