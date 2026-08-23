#!/usr/bin/env python3
"""Находит Y ряда иконок (copy/like/share) последнего ответа DeepSeek.
Съёмка: spectacle -b -f -n -o (ВАЖЕН флаг -b, иначе GUI). Выводит центр Y или FAIL."""
import subprocess, sys, tempfile, os
import PIL.Image as Image

tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
try:
    subprocess.run(["spectacle","-b","-f","-n","-o",tmp.name], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    im = Image.open(tmp.name).convert("L")
    w,h = im.size; px = im.load()
    if w < 1920 or h < 1080: print("FAIL: неfullscreen снимок", w, "x", h); sys.exit(1)

    # колонка copy-иконки x715..735; ищем яркие кластеры (тёмная тема DeepSeek)
    runs=[]; s=None
    for y in range(400, 940):
        ink = any(px[x,y]>150 for x in range(715,736))
        if ink and s is None: s=y
        elif not ink and s is not None: runs.append((s,y-1)); s=None
    cands=[r for r in runs if 8<=r[1]-r[0]+1<=25]
    if not cands: print("FAIL: ряд иконок не найден"); sys.exit(1)
    # Если последний run — подпись "Copy" (рядом с иконкой <30px), берём предыдущий
    if len(cands)>=2 and cands[-1][0]-cands[-2][1] < 30:
        r = cands[-2]
    else:
        r = cands[-1]
    y = (r[0]+r[1])//2
    print(y)
finally:
    try:
        os.unlink(tmp.name)
    except OSError:
        pass
