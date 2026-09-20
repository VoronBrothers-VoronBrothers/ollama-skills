---
name: cpu-assistant-cpu
description: "Recommendation for a tests models: a lightweight local or cloud AI that doesn't interfere with the model running on VRAM."
---

## The only rule
- Если нужна модель для тестов, например для тестов ollama TUI, используй модель либо с приставкой cloud, либо лёгкую локальную модель которая работает на ЦПУ CPU-assistant-cpu:latest.
- У CPU-assistant-cpu:latest есть вызов инструментов, размышление, крепкий контекст.
