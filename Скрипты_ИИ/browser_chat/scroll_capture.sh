#!/usr/bin/env bash
# scroll_capture.sh <сессия-dir> — серия скринов длинного ответа со скроллом.
# Логика: сначала прокрутить к ВЕРХУ ответа (колесо up ~40 раз), потом серия:
#   скрин → колесо down на шаг → до тех пор пока hash не изменится (конец) или N кадров.
# Результат: <dir>/frame_001.png ... frame_NNN.png (+ full.png — склейка по вертикали).
set -e
DIR=${1:-sessions/$(date +%Y%m%d_%H%M%S)}
mkdir -p "$DIR"

WIN=""
for w in $(xdotool search --name ""); do
  cls=$(xprop -id "$w" WM_CLASS 2>/dev/null | sed 's/WM_CLASS(STRING) = //' | cut -d, -f1 | tr -d '"')
  [ "$cls" = "google-chrome" ] && WIN=$w
done
[ -z "$WIN" ] && { echo "нет браузера"; exit 1; }

# Камера: только область контента (без сайдбара и поля ввода)
CROP="480,100,1440,980"   # x,y,w,h в full-res
xdotool windowactivate --sync $WIN
# Курсор в контент — колесо пойдёт на нужный контейнер
xdotool mousemove 960 400

# --- 1) К началу: много colup ---
for i in $(seq 1 40); do xdotool click 4; sleep 0.05; done
sleep 0.5

# --- 2) Серия вниз до конца ---
prev=""
i=1
while [ $i -le 30 ]; do
  s=$(mktemp /tmp/sc_XXXX.png); spectacle -b -f -n -o "$s" 2>/dev/null || true
  python3 -c "
from PIL import Image
im=Image.open('$s').convert('RGB')
im.crop((480,100,1440,980)).save('$DIR/frame_$(printf %03d $i).png')
"
  h=$(md5sum "$DIR/frame_$(printf %03d $i).png" | cut -c1-16)
  # Если два кадра подряд совпали — дошли до конца (или начал скролл)
  [ "$h" = "$prev" ] && { rm -f "$DIR/frame_$(printf %03d $i).png"; break; }
  prev=$h
  xdotool click 5; sleep 0.12
  i=$((i+1))
done

# --- 3) Склейка в tall PNG ---
python3 -c "
from PIL import Image
import glob, os
frames = sorted(glob.glob('$DIR/frame_*.png'))
if not frames: exit()
imgs = [Image.open(f) for f in frames]
w = max(im.width for im in imgs)
h = sum(im.height for im in imgs)
out = Image.new('RGB', (w, h))
y = 0
for im in imgs:
    out.paste(im, (0, y)); y += im.height
# Сжатие по высоте: уменьшаем в 2 раза если >1500px
if out.height > 1500:
    out = out.resize((out.width//2, out.height//2))
out.save('$DIR/full.png')
print('frames:', len(frames), '->', '$DIR/full.png', out.size)
"
