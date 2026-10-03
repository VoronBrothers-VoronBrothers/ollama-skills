#!/usr/bin/env python3
"""Воркер: рисует плашку с координатами мыши. Не вызывать напрямую."""
import tkinter as tk

# Размер красного уголка (индикатор точной точки клика)
HOTSPOT = 12


def main():
    win = tk.Tk()
    win.attributes("-topmost", True)
    win.overrideredirect(True)

    # Плашка: Canvas вместо Label — чтобы нарисовать красный уголок
    canvas = tk.Canvas(
        win, width=170, height=32,
        bg="#1a1a2e", highlightthickness=0
    )
    canvas.pack(padx=6, pady=3)

    # Красный квадратик в левом верхнем углу — «горячая точка»
    rect_id = canvas.create_rectangle(
        1, 1, HOTSPOT + 1, HOTSPOT + 1,
        fill="#ff2222", outline=""
    )

    label_id = canvas.create_text(
        HOTSPOT + 8, 16, anchor="w",
        text="x: -  y: -",
        font=("DejaVu Sans Mono", 13),
        fill="#00ff88"
    )

    def update():
        x = win.winfo_pointerx()
        y = win.winfo_pointery()
        px = min(x + 6, 1920 - 182)
        py = min(y + 6, 1080 - 48)
        win.geometry(f"+{px}+{py}")
        canvas.itemconfig(label_id, text=f"x: {x}  y: {y}")
        canvas.tag_raise(rect_id)  # держим квадратик на переднем плане
        win.after(50, update)

    win.update_idletasks()
    update()
    win.mainloop()


if __name__ == "__main__":
    main()
