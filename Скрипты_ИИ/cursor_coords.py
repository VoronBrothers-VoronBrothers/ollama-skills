#!/usr/bin/env python3
"""Показывает координаты курсора рядом с ним. Ctrl+C для остановки."""
import tkinter as tk

OFFSET = 24  # смещение от курсора, чтобы не перекрывать

def make_overlay():
    root = tk.Tk()
    root.attributes("-topmost", True)
    root.overrideredirect(True)  # без рамки и в taskbar
    root.configure(bg="#1a1a2e")

    label = tk.Label(
        root, text="x: - y: -",
        font=("DejaVu Sans Mono", 13),
        fg="#00ff88", bg="#1a1a2e"
    )
    label.pack(padx=6, pady=3)

    def update():
        x = root.winfo_pointerx()
        y = root.winfo_pointery()
        # смещаемся вправо-вниз от курсора
        px = min(x + OFFSET, 1920 - 140)
        py = min(y + OFFSET, 1080 - 36)
        root.geometry(f"+{px}+{py}")
        label.config(text=f"x: {x}  y: {y}")
        root.after(50, update)

    root.update_idletasks()
    update()
    root.mainloop()

if __name__ == "__main__":
    make_overlay()
