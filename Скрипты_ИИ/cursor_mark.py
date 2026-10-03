#!/usr/bin/env python3
"""Оверлей: координаты курсора + крестик при клике + маркеры истории (60 сек)."""
import tkinter as tk
from Xlib.display import Display
from Xlib import X
import threading, queue

# --- Настройки ---
MARKER_LIFETIME = 60_000  # мс
COLORS = [
    "#ff4444", "#44ff44", "#4488ff", "#ffaa00", "#ff44ff",
    "#ffff44", "#44ffff", "#ff8844", "#88ff44", "#ff4488",
]

class App:
    def __init__(self):
        self.root = tk.Tk()
        self.root.attributes("-topmost", True)
        self.root.overrideredirect(True)
        self.root.configure(bg="#1a1a2e")

        self.label = tk.Label(
            self.root, text="x: -  y: -",
            font=("DejaVu Sans Mono", 13),
            fg="#00ff88", bg="#1a1a2e"
        )
        self.label.pack(padx=6, pady=3)

        self.click_count = 0
        self.markers = []  # список (window, id) активных маркеров
        self.cross_win = None

        # Xlib для детекта кликов
        self.display = Display()
        self.root_window = self.display.screen().root
        self.root_window.change_attributes(event_mask=X.ButtonPress | X.ButtonRelease)

    def update_coords(self):
        x = self.root.winfo_pointerx()
        y = self.root.winfo_pointery()
        px = min(x + 24, 1920 - 150)
        py = min(y + 24, 1080 - 36)
        self.root.geometry(f"+{px}+{py}")
        self.label.config(text=f"x: {x}  y: {y}")
        self.root.after(50, self.update_coords)

    def show_cross(self, cx, cy):
        """Показать крестик в точке клика."""
        if self.cross_win and self.cross_win.winfo_exists():
            self.cross_win.destroy()
        w = tk.Tk()
        w.attributes("-topmost", True)
        w.overrideredirect(True)
        canvas = tk.Canvas(w, width=24, height=24, bg="systemTransparent", highlightthickness=0)
        c = 12
        canvas.create_line(c-10, c, c+10, c, fill="#ff0000", width=2)
        canvas.create_line(c, c-10, c, c+10, fill="#ff0000", width=2)
        canvas.pack()
        w.geometry(f"+{cx-12}+{cy-12}")
        self.cross_win = w

    def hide_cross(self):
        if self.cross_win and self.cross_win.winfo_exists():
            self.cross_win.destroy()
            self.cross_win = None

    def add_marker(self, cx, cy):
        """Добавить кружок-маркер с номером. Живёт 60 сек."""
        self.click_count += 1
        n = self.click_count
        color = COLORS[(n - 1) % len(COLORS)]

        w = tk.Tk()
        w.attributes("-topmost", True)
        w.overrideredirect(True)
        canvas = tk.Canvas(w, width=36, height=36, bg="systemTransparent", highlightthickness=0)
        r = 16
        c = 18
        canvas.create_oval(c-r, c-r, c+r, c+r, fill=color, outline="#ffffff", width=2)
        canvas.create_text(c, c, text=str(n), fill="#ffffff", font=("DejaVu Sans Mono", 14, "bold"))
        canvas.pack()
        w.geometry(f"+{cx-18}+{cy-18}")

        self.markers.append(w)

        # Удалить через 60 сек
        def remove():
            if w.winfo_exists():
                w.destroy()
            if w in self.markers:
                self.markers.remove(w)
        w.after(MARKER_LIFETIME, remove)

    def listen_clicks(self):
        """Отдельный поток: слушает ButtonPress/Release через Xlib."""
        while True:
            try:
                event = self.display.next_event()
                if event.type == X.ButtonPress and event.detail in (1, 2, 3):
                    cx, cy = event.root_x, event.root_y
                    self.root.after(0, lambda c=(cx, cy): self._on_press(*c))
                elif event.type == X.ButtonRelease:
                    self.root.after(0, self.hide_cross)
            except Exception:
                break

    def _on_press(self, cx, cy):
        self.show_cross(cx, cy)
        self.add_marker(cx, cy)

    def run(self):
        # Поток для Xlib-событий
        t = threading.Thread(target=self.listen_clicks, daemon=True)
        t.start()
        self.update_coords()
        self.root.mainloop()


if __name__ == "__main__":
    App().run()
