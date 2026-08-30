#!/usr/bin/env bash
# grep -> ripgrep wrapper
# Real GNU grep kept at /bin/grep for fallback / reference.
set -euo pipefail

# Список поддерживаемых grep опций для getopt:
# С двоеточием (:) — опции, требующие аргумента.
SHORT_OPTS="aAbBcC:D:d:e:E:f:Fg:G:HhiI:Ll:m:nNoO:p:PqrsS:tTuUvVwWxXy:Z"
LONG_OPTS="extended-regexp,basic-regexp,fixed-strings,perl-regexp,regexp:,file:,ignore-case,word-regexp,line-regexp,no-messages,revert-match,version,help,count,matching-files,files-without-match,line-number,with-filename,no-filename,label:,only-matching,quiet,silent,binary-files:,text,directories:,recursive,dereference-recursive,include:,exclude:,exclude-from:,exclude-dir:,line-buffered,buffer-size:,with-gap,color:,colour:,context:,after-context:,before-context:,group-separator:,no-group-separator,initial-tab,null,data-binary-equal,text-binary-detect,invert-match,max-count:,max-depth:,null-data"

# Парсим аргументы через getopt для разделения склеенных флагов (например, -ivn)
PARSED=$(getopt --options="$SHORT_OPTS" --longoptions="$LONG_OPTS" --name "$0" -- "$@")
eval set -- "$PARSED"

out=()
pat_done=0

while true; do
  case "$1" in
    # Опции движка — rg использует PCRE2 по умолчанию, игнорируем несовместимые
    -E|--extended-regexp|-G|--basic-regexp|-P|--perl-regexp)
      shift ;;
      
    -F|--fixed-strings)
      out+=("-F")
      shift ;;

    # Паттерн из аргумента
    -e|--regexp)
      out+=("-e" "$2")
      pat_done=1
      shift 2 ;;

    # Паттерн из файла
    -f|--file)
      out+=("-f" "$2")
      pat_done=1
      shift 2 ;;

    # Регистронезависимый поиск
    -i|--ignore-case)
      out+=("-i")
      shift ;;

    # Только полные слова
    -w|--word-regexp)
      out+=("--word-regexp")
      shift ;;

    # Только полные строки
    -x|--line-regexp)
      out+=("--line-regexp")
      shift ;;

    # Инвертирование匹配
    -v|--invert-match|--revert-match)
      out+=("-v")
      shift ;;

    # Номера строк
    -n|--line-number)
      out+=("-n")
      shift ;;

    # Без номеров строк
    -N|--no-line-number)
      out+=("-N")
      shift ;;

    # Только совпадения
    -o|--only-matching)
      out+=("-o")
      shift ;;

    # Тихий режим
    -q|--quiet|--silent)
      out+=("-q")
      shift ;;

    # Подавление ошибок
    -s|--no-messages)
      out+=("--no-messages")
      shift ;;

    # Контекст — все три опции требуют аргумент
    -C|--context)
      shift
      # getopt может вставить '--' перед аргументом
      if [ "$1" = "--" ]; then shift; fi
      out+=("-C" "$1")
      shift ;;

    -A|--after-context)
      shift
      # getopt может вставить '--' перед аргументом
      if [ "$1" = "--" ]; then shift; fi
      out+=("-A" "$1")
      shift ;;

    -B|--before-context)
      shift
      # getopt может вставить '--' перед аргументом
      if [ "$1" = "--" ]; then shift; fi
      out+=("-B" "$1")
      shift ;;

    # Количество совпадений
    -c|--count)
      out+=("--count")
      shift ;;

    # Файлы с совпадениями
    -l|--files-with-matches|--matching-files)
      out+=("--files-with-matches")
      shift ;;

    # Файлы без совпадений
    -L|--files-without-match)
      out+=("--files-without-match")
      shift ;;

    # Рекурсивный поиск (rg по умолчанию рекурсивен)
    -r|-R|--recursive|--dereference-recursive)
      # rg по умолчанию ищет рекурсивно, ничего не нужно добавлять
      shift ;;

    # Директории
    -d|--directories)
      case "$2" in
        recurse)
          # rg по умолчанию рекурсивен
          shift 2 ;;
        read|skip)
          shift 2 ;;
        *)
          shift 2 ;;
      esac ;;

    # Вывод имён файлов
    -H|--with-filename)
      out+=("--with-filename")
      shift ;;

    -h|--no-filename)
      out+=("--no-filename")
      shift ;;

    # Бинарные файлы
    -a|--text|--binary-files=text)
      out+=("-a")
      shift ;;

    --binary-files)
      case "$2" in
        text)
          out+=("-a")
          ;;
        without-match)
          out+=("--files-without-match")
          ;;
        binary)
          out+=("--no-text")
          ;;
      esac
      shift 2 ;;

    # Цвет
    --color|--colour)
      case "${2:-always}" in
        always|yes|force)
          out+=("--color=always")
          shift 2 ;;
        never|no)
          out+=("--color=never")
          shift 2 ;;
        auto|tty|if-tty)
          out+=("--color=auto")
          shift 2 ;;
        *)
          out+=("--color=$2")
          shift 2 ;;
      esac ;;

    --no-color|--no-colour)
      out+=("--color=never")
      shift ;;

    # Максимальное количество совпадений
    -m|--max-count)
      out+=("-m" "$2")
      shift 2 ;;

    # Максимальная глубина
    --max-depth)
      out+=("--max-depth" "$2")
      shift 2 ;;

    # Исключения и включения
    --include)
      out+=("-g" "*$2*")
      shift 2 ;;

    --exclude)
      out+=("-g" "!*$2*")
      shift 2 ;;

    --exclude-dir)
      out+=("--glob" "!**/$2/**")
      shift 2 ;;

    --exclude-from)
      out+=("--ignore-file" "$2")
      shift 2 ;;

    # Разделитель групп
    --group-separator)
      out+=("--field-match-separator" "$2")
      shift 2 ;;

    --no-group-separator)
      out+=("--no-field-match-separator")
      shift ;;

    # Null-разделитель
    -Z|--null)
      out+=("--null")
      shift ;;

    --null-data)
      out+=("--null-data")
      shift ;;

    # Версия и помощь
    --version|-V)
      echo "grep wrapper around ripgrep"
      echo "Using: $(rg --version | head -1)"
      exit 0 ;;

    --help)
      echo "Usage: grep [OPTIONS] PATTERN [FILE...]"
      echo "This is a wrapper around ripgrep (rg) that mimics grep interface."
      echo ""
      echo "Common options:"
      echo "  -i, --ignore-case       Ignore case distinctions"
      echo "  -v, --invert-match      Select non-matching lines"
      echo "  -w, --word-regexp       Match whole words only"
      echo "  -x, --line-regexp       Match whole lines only"
      echo "  -F, --fixed-strings     Interpret pattern as fixed strings"
      echo "  -E, -G, -P              Ignored (rg uses PCRE2 by default)"
      echo "  -e, --regexp=PATTERN    Specify pattern"
      echo "  -f, --file=FILE         Get patterns from file"
      echo "  -c, --count             Count matching lines"
      echo "  -l, --files-with-matches List files with matches"
      echo "  -L, --files-without-match List files without matches"
      echo "  -n, --line-number       Show line numbers"
      echo "  -o, --only-matching     Show only matching parts"
      echo "  -q, --quiet, --silent   Suppress all output"
      echo "  -s, --no-messages       Suppress error messages"
      echo "  -r, -R, --recursive     Recursive search"
      echo "  -C, -A, -B NUM          Context lines"
      echo "  --color[=WHEN]          Color output"
      echo "  -m, --max-count=NUM     Limit matches per file"
      echo "  --max-depth=NUM         Limit directory depth"
      echo "  -Z, --null              Use NUL as line separator"
      echo ""
      echo "For full rg options, see: rg --help"
      exit 0 ;;

    # Конец опций
    --)
      shift
      break ;;

    # Неизвестные опции — пробуем передать как есть
    -*)
      out+=("$1")
      shift ;;

    *)
      break ;;
  esac
done

# Обработка оставшихся позиционных аргументов (паттерн и файлы/директории)
for arg in "$@"; do
  if [ "$pat_done" = 0 ]; then
    # Первый позиционный аргумент — паттерн
    out+=("-e" "$arg")
    pat_done=1
  else
    # Остальные — файлы или директории
    out+=("$arg")
  fi
done

# Если паттерн не был указан, это ошибка
if [ "$pat_done" = 0 ]; then
  echo "grep: missing pattern" >&2
  echo "Try 'grep --help' for more information." >&2
  exit 2
fi

exec rg "${out[@]}"
