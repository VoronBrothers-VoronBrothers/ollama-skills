import sys
import re
from collections import Counter

def main():
    if len(sys.argv) != 2:
        return
    try:
        with open(sys.argv[1], 'r', encoding='utf-8') as f:
            text = f.read()
    except (FileNotFoundError, OSError):
        return
    words = re.findall(r'\b[a-zA-Zа-яА-ЯёЁ]+\b', text.lower())
    if not words:
        return
    counter = Counter(words)
    most_common = sorted(counter.items(), key=lambda x: (-x[1], x[0]))[:5]
    for word, count in most_common:
        print(f"{word}: {count}")

if __name__ == "__main__":
    main()
