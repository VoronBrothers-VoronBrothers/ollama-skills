#!/usr/bin/env bash
# open_url.sh <url-файл> | open_url.sh "https://..."
# Открывает URL НОВЫМ TAB'ом в существующем инстансе google-chrome
# (или стартует браузер, если его нет). Точный WM_CLASS — не substring!
set -euo pipefail
URL=${1:-deepseek}
[[ "$URL" == http* ]] || URL=$(cat "$(dirname "$0")/urls/$URL.txt" 2>/dev/null || true)
[ -n "$URL" ] || { echo "нет URL: ${1:-}"; exit 1; }

# Точное совпадение WM_CLASS google-chrome (google-chrome-stable = VPN, не наш)
have_chrome=0
while read -r w; do
  cls=$({ xprop -id "$w" WM_CLASS 2>/dev/null || true; } | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
  [ "$cls" = "google-chrome" ] && { have_chrome=1; break; }
done < <(xdotool search --name "")

setsid google-chrome "$URL" >/dev/null 2>&1 &
[ $have_chrome -eq 0 ] && echo "браузер не был запущен — стартовал с этим URL" || echo "открываю вкладку: $URL"
