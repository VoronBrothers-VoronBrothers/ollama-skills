#!/usr/bin/env bash
# scroll_capture.sh <сессия-dir> — серия скринов длинного ответа со скроллом.
# Логика: сначала прокрутить к ВЕРХУ ответа (колесо up ~40 раз), потом серия:
#   скрин → колесо down на шаг → до тех пор пока hash не изменится (конец) или N кадров.
# Результат: <dir>/frame_001.png ... frame_NNN.png (+ full.png — склейка по вертикали).
set -euo pipefail
DIR=${1:-sessions/$(date +%Y%m%d_%H%M%S)}
mkdir -p "$DIR"

WIN=""
while read -r w; do
  cls=$({ xprop -id "$w" WM_CLASS 2>/dev/null || true; } | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
  [ "$cls" = "google-chrome" ] && WIN=$w
done < <(xdotool search --name "")
[ -n "$WIN" ] || { echo "нет браузера"; exit 1; }

# Камера: только область контента (без сайдбара и поля ввода)
CROP="480,100,1440,980"   # x,y,w,h в full-res
xdotool windowactivate --sync "$WIN"
# Курсор в контент — колесо пойдёт на нужный контейнер
xdotool mousemove 960 400

# --- 1) К началу: много colup ---
for _ in $(seq 1 40); do xdotool click 4 || true; sleep 0.05; done
sleep 0.5

# --- 2) Серия вниз до конца (каждый проход увеличивает i — нет бесконечного цикла) ---
prev=""
i=1
while [ $i -le 30 ]; do
  s=$(mktemp /tmp/sc_XXXX.png)
  if ! spectacle -b -f -n -o "$s" 2>/dev/null; then
    rm -f "$s"; i=$((i+1)); continue
  fi
  python3 -c "
from PIL import Image
im=Image.open('$s').convert('RGB')
im.crop((480,100,1440,980)).save('$DIR/frame_' + format($i, '03d') + '.png')
" || { rm -f "$s"; i=$((i+1)); continue; }
  rm -f "$s"
  h=$(md5sum "$DIR/frame_$(printf '%03d' "$i").png" | cut -c1-16)
  # Если два кадра подряд совпали — дошли до конца (или начал скролл)
  if [ "$h" = "$prev" ]; then
    rm -f "$DIR/frame_$(printf '%03d' "$i").png"
    break
  fi
  prev=$h
  xdotool click 5; sleep 0.2
  i=$((i+1))
done

# --- 3) Склейка в tall PNG ---
python3 -c "
from PIL import Image
import glob, sys
frames = sorted(glob.glob('$DIR/frame_*.png'))
if not frames: sys.exit(1)
imgs = [Image.open(f) for f in frames]
w = max(im.width for im in imgs)
out = Image.new('RGB', (w, sum(im.height for im in imgs)))
y = 0
for im in imgs:
    out.paste(im, (0, y)); y += im.height
# Сжатие по высоте: уменьшаем в 2 раза если >1500px
if out.height > 1500:
    out = out.resize((out.width//2, out.height//2))
out.save('$DIR/full.png')
print('frames:', len(frames), '->', '$DIR/full.png', out.size)
"
