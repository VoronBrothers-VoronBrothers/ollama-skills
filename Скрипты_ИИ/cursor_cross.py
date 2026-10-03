#!/usr/bin/env python3
"""Оверлей координат курсора со смещением."""
import tkinter as tk

def main():
    win = tk.Tk()
    win.attributes("-topmost", True)
    win.overrideredirect(True)

    label = tk.Label(
        win, text="x: -  y: -",
        font=("DejaVu Sans Mono", 13),
        fg="#00ff88", bg="#1a1a2e"
    )
    label.pack(padx=6, pady=3)

    def update():
        x = win.winfo_pointerx()
        y = win.winfo_pointery()
        px = min(x + 6, 1920 - 150)
        py = min(y + 6, 1080 - 36)
        win.geometry(f"+{px}+{py}")
        label.config(text=f"x: {x}  y: {y}")
        win.after(50, update)

    win.update_idletasks()
    update()
    win.mainloop()

if __name__ == "__main__":
    main()
