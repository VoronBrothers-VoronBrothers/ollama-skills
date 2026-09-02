#!/usr/bin/env python3
"""Перевод текста из английской раскладки в русскую.

Использование:
  eng2ru ghbdtn          # печатает: привет
  echo ghbdtn | eng2ru   # из stdin
  -u                     # обратное: русский -> английский
"""
import sys

RUS = "йцукенгшщзхъфывапролджэячсмитьбю."
EN  = "qwaszxedcrfvtgbyhnujm,"
UP  = "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ"

def eng2ru(s: str) -> str:
    out = []
    for ch in s:
        idx = EN.find(ch.lower())
        if idx != -1:
            out.append(RUS[idx].upper() if ch.isupper() else RUS[idx])
        else:
            out.append(ch)
    return "".join(out)

def ru2eng(s: str) -> str:
    out = []
    for ch in s:
        idx = RUS.find(ch.lower())
        if idx == -1:
            idx = UP.find(ch)
        if idx == -1:
            out.append(ch)
        else:
            out.append(EN[idx].upper() if ch.isupper() else EN[idx])
    return "".join(out)

if __name__ == "__main__":
    if "-u" in sys.argv:
        func, args = ru2eng, [a for a in sys.argv[1:] if a != "-u"]
    else:
        func, args = eng2ru, sys.argv[1:]
    text = " ".join(args) if args else sys.stdin.read().rstrip("\n")
    print(func(text))
