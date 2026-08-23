#!/usr/bin/env python3
# clip_hold.py <текст> [сек] — держит текст в CLIPBOARD на заданное время
import sys, time
from PyQt5 import QtWidgets
app = QtWidgets.QApplication(sys.argv)
txt = sys.argv[1]
secs = int(sys.argv[2]) if len(sys.argv) > 2 else 15
app.clipboard().setText(txt)
t0 = time.time()
while time.time() - t0 < secs:
    app.processEvents()
    time.sleep(0.05)
