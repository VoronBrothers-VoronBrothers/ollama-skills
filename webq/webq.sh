#!/usr/bin/env bash
# webq — локальный веб-поиск/чтение через w3m (проходит бот-чек DDG)
set -euo pipefail
enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(" ".join(sys.argv[1:])))' "$@"; }
case "${1:-}" in
  ""|-h|--help) echo "webq search 'запрос' — выдача; webq get <URL> — текст; webq top 'запрос' N — N ссылок"; exit 0;;
esac
cmd=$1; shift
case $cmd in
  search) w3m -dump "https://html.duckduckgo.com/html/?q=$(enc "$@")" ;;
  get)    out=$(w3m -dump "$1" 2>&1) || true
         if [[ -z ${out//} || ${#out} -lt 80 || $out == *"not in gzip format"* ]]; then lynx -dump "$1"; else printf '%s\n' "$out"; fi ;;
  top)    n=${2:-3}; enc "$1" | { read -r q; w3m -dump "https://html.duckduckgo.com/html/?q=$q" | grep '^●' | sed 's/^● //' | head -n "$n"; } ;;
  *) echo "webq: unknown cmd '$cmd'" >&2; exit 1;;
esac
