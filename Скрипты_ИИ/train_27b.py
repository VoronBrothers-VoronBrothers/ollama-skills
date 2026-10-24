"""Qwen3.8-27B LoRA — лаконичный формат (24.10.2026, FastModel).

Датасет: chatml-jsonl от convert_v2.py (колонка messages; у assistant может быть
reasoning_content — шаблон Qwen сам оборачивает его в think-блок). Рендер чат-
шаблона и маскирование loss на ответ assistant TRL делает под капотом.
(Колонка "text" из render_text.py — альтернатива, но для неё assistant_only_loss
TRL не поддерживает: loss был бы на всей строке.)

Память: 16 GB VRAM + RAM (hybrid-рецепт). Перед запуском выгрузить ollama из GPU.
Важно: dataset_num_proc=1 — иначе TRL форкает 8 копий скрипта с моделями в RAM,
и oom-killer убивает процесс (проверено 24.10: 5×~15 ГБ > 62 ГБ системы).

Запуск: venv/bin/python train_27b.py [путь-к-dataset.jsonl]
"""
import sys

# FastModel — обёртка Unsloth над transformers/peft; импортировать ПЕРВЫМ,
# чтобы её патчи (fp8, компиляция, offload) успели налезть на trl и torch.
from unsloth import FastModel            # первым — до trl/transformers (оптимизации Unsloth)

# load_dataset — читает jsonl в объект datasets.Dataset (HuggingFace).
from datasets import load_dataset

# SFTConfig/SFTTrainer — TRL: настраивает и ведёт обучение (батчи, оптимизатор, loss).
from trl import SFTConfig, SFTTrainer

DATASET = sys.argv[1] if len(sys.argv) > 1 else "../№3 Создание датасета/dataset.jsonl"

# --- Загрузка модели ---------------------------------------------------------
model, tokenizer = FastModel.from_pretrained(
    model_name="unsloth/Qwen3.8-27B-unsloth-bnb-4bit",   # квантованная 4-bit версия (влезает в 16 GB)
    max_seq_length=256,                    # длина твоих примеров; подними при росте датасета
    load_in_4bit=True,                     # веса хранятся в 4-битном кванте (экономия VRAM/RAM)
    device_map="auto",                     # hybrid: часть слоёв на GPU, остаток — в RAM (+offload)
    max_memory={0: "14GiB", "cpu": "56GiB"},  # потолок GPU; RAM — сколько можно занять
    offload_layers="auto",                 # Unsloth сам решает, что вынести в RAM (эмбеддинги + слои)
    offload_folder="./offload_weights",     # куда писать слои, не влезающие никуда (диск)
)

# --- LoRA: вместо 27B параметров учим только маленькие матрицы ---------------
model = FastModel.get_peft_model(
    model, r=32, lora_alpha=64, lora_dropout=0.0,   # rank/alpha — размерность и масштаб LoRA-вставок
    finetune_vision_layers     = False,             # визуальную часть не трогаем (модель текстовая)
    finetune_language_layers   = True,              # учим языковую часть целиком
    finetune_attention_modules = True,              # вставляем LoRA во внимательность
    finetune_mlp_modules       = True,)             # и в MLP-блоки

# --- Датасет ------------------------------------------------------------------
dataset = load_dataset("json", data_files=DATASET, split="train")   # jsonl → датасет (раздел train)

# Эксплуатируем модель в medium (без system-инструкции) — учим в том же режиме.
# MEDIUM подсовывается каждому примеру как аргумент чат-шаблона при рендере.
MEDIUM = {"chat_template_kwargs": {"reasoning_effort": "medium"}}
dataset = dataset.map(lambda _: MEDIUM)

# Qwen3.8 отдаёт Processor; любой processor trainer считает VLM-режимом.
# Дадим чистый текстовый токенйзер: отключится VLM-ветка (assistant_only_loss
# заработает) и строки не будут глотаться как base64-изображения (фикс K3).
text_tok = tokenizer.tokenizer if hasattr(tokenizer, "tokenizer") else tokenizer

# --- Настройки обучения -------------------------------------------------------
trainer = SFTTrainer(
    model=model,                  # модель с LoRA-вставками
    processing_class=text_tok,    # текстовый токенйзер (см. фикс выше)
    train_dataset=dataset,        # данные для обучения
    args=SFTConfig(
        assistant_only_loss=True,          # loss только на ответе assistant, не на промпте
        dataset_num_proc=1,                # ТОКЕНИЗАЦИЯ 1-м процессом: при >1 TRL форкает копии скрипта с моделями в RAM → oom-killer (62 ГБ системы)
        max_length=256,                    # максимум длины примера; длиннее — режется
        per_device_train_batch_size=1,     # 1 пример за шаг (VRAM не позволяет больше)
        gradient_accumulation_steps=4,     # накопить градиенты по 4 шагам ≈ батч из 4
        warmup_steps=10,                   # 10 первых шагов — медленно разгоняем learning rate
        learning_rate=2e-4,                # шаг обучения (для LoRA можно смелее)
        logging_steps=1,                   # loss по строке на шаг — как в GUI
        optim="adamw_8bit",                # оптимизатор AdamW в 8-бит (экономия RAM)
        output_dir="./outputs_qwen38",      # куда писать логи/чекпоинты
        report_to="none",                  # ничего не отправлять наружу (wandb и т.п.)
    ),
)

trainer.train()                          # само обучение

model.save_pretrained("./lora_out")      # сохранить ТОЛЬКО LoRA-веса (~маленький файл)
tokenizer.save_pretrained("./lora_out")  # + токенйзер рядом — для загрузки в ollama/transformers
print("Сохранено: ./lora_out")
