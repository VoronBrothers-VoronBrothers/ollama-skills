"""Qwen3.8-27B LoRA — Финальная защищенная версия (24.10.2026).

Стратегия: Обучение на микро-датасете (66 примеров) методом "Быстрого касания".
Защита от коллапса (Alignment Collapse): зажатый ранг LoRA (r=4), ограничение шагов (1 эпоха),
шум в эмбеддингах (NEFTune) и сглаживание целевых меток (Label Smoothing).

Память: 16 GB VRAM + RAM (hybrid). Перед запуском обязательно выгрузить Ollama из GPU!
Запуск: venv/bin/python train_27b.py [путь-к-dataset.jsonl]
"""
import sys

# Добавляем недостающий импорт для встроенных механизмов Transformers
from unsloth import FastModel
from transformers import EarlyStoppingCallback
from datasets import load_dataset
from trl import SFTConfig, SFTTrainer
from trl.chat_template_utils import qwen3_8_training_chat_template

# Если путь не передан аргументом, берем дефолтный
DATASET = sys.argv[1] if len(sys.argv) > 1 else "../№3 Создание датасета/dataset.jsonl"

# --- 1. ЗАГРУЗКА МОДЕЛИ (Hybrid: GPU + RAM) ----------------------------------
model, tokenizer = FastModel.from_pretrained(
    model_name="unsloth/Qwen3.8-27B-unsloth-bnb-4bit",
    max_seq_length=256, # Короткий контекст экономит VRAM и ускоряет шаги
    load_in_4bit=True,   # Квантование базовой модели для экономии памяти
    device_map="auto",
    max_memory={0: "14GiB", "cpu": "56GiB"}, # Защита GPU от вылета по OOM
    offload_layers="auto",
    offload_folder="./offload_weights",
)

# --- 2. НАСТРОЙКА LORA (Ранг зажат под микро-датасет) ------------------------
model = FastModel.get_peft_model(
    model,
    r=4,           # Низкий ранг (емкость) — главный щит против зазубривания 66 примеров
    lora_alpha=8,  # Стандартное масштабирование весов (2 * r) для мягкого внедрения знаний
    lora_dropout=0.0, # Обязательно 0.0 для Unsloth (иначе отключатся быстрые Triton-ядра)
    finetune_vision_layers     = False,
    finetune_language_layers   = True,
    finetune_attention_modules = True,
    finetune_mlp_modules       = True,
)

# --- 3. ПОДГОТОВКА ДАТАСЕТА И ШАБЛОНА ----------------------------------------
# Автоматически делим 66 примеров: 85% на обучение, 15% (около 10 примеров) на скрытый тест
raw_dataset = load_dataset("json", data_files=DATASET, split="train")
split_dataset = raw_dataset.train_test_split(test_size=0.15, seed=42)

# Достаем чистый текстовый токенизатор, отключая VLM (мультимодальную) ветку
text_tok = tokenizer.tokenizer if hasattr(tokenizer, "tokenizer") else tokenizer

# Новый шаблон TRL 2026: сам изолирует reasoning_content в <think> блоки
# и автоматически маскирует loss на мыслях и ответах ассистента.
text_tok.chat_template = qwen3_8_training_chat_template

# --- 4. ОБУЧЕНИЕ С АВТОМАТИЧЕСКИМ СЛЕЖЕНИЕМ И РЕГУЛЯРИЗАЦИЕЙ -----------------
trainer = SFTTrainer(
    model=model,
    processing_class=text_tok,
    train_dataset=split_dataset["train"],  # Учим модель на основной части
    eval_dataset=split_dataset["test"],    # Проверяем адекватность на скрытом тесте

    # Авто-стоппер: прервет обучение, если скрытый тест (eval_loss) начнет расти
    callbacks=[EarlyStoppingCallback(
        early_stopping_patience=2,
        early_stopping_threshold=0.01,  # улучшение меньше 0.01 не считается

    )],

    args=SFTConfig(
        assistant_only_loss=True, # Loss считается ТОЛЬКО на ответах (и мыслях) ассистента
        dataset_num_proc=1,        # Строго 1 поток, чтобы системный oom-killer не убил RAM (>62ГБ)
        max_length=256,
        per_device_train_batch_size=1,
        gradient_accumulation_steps=4, # Эффективный батч = 4 (1 * 4). Одно обновление весов каждые 4 строки.

        # Математика шагов: для 56 тренировочных строк 1 эпоха — это ~14 шагов.
        # Даем лимит в 50 шагов (около 3.5 эпох), но авто-стоппер остановит процесс раньше, если нужно.
        max_steps=50,
        #num_train_epochs=2,       # переключение на эпохи
        warmup_steps=3,            # Плавный разогрев LR за 3 шага (адаптировано под короткий трек)
        learning_rate=2e-4,        # Золотой стандарт скорости обучения LoRA для Unsloth
        logging_steps=1,           # Выводим метрики на каждом шаге, чтобы сразу видеть аномалии
        optim="adamw_8bit",        # 8-битный оптимизатор AdamW для жесткой экономии VRAM
        output_dir="./outputs_qwen38",
        report_to="none",          # Отключаем отправку логов в сторонние облачные сервисы

        # --- Инструменты контроля и авто-валидации на лету ---
        eval_strategy="steps",       # Запускать скрытый тест по шагам
        eval_steps=3,                # Проверяем адекватность модели каждые 3 шага
        save_strategy="steps",       # Сохраняем промежуточные точки для отката
        save_steps=3,

        #eval_strategy="epoch",      # Оценка в конце каждой эпохи
        #save_strategy="epoch",      # Сохранение чекпоинта в конце каждой эпохи

        save_total_limit=1,          # На диске всегда лежит только 1 — самый лучший чекпоинт
        load_best_model_at_end=True, # После остановки автоматически вернуть в память лучшую точку
        metric_for_best_model="eval_loss",
        greater_is_better=False,     # Лучшая модель — та, у которой ошибка (loss) меньше всего

        # --- Математическая регуляризация (Универсальный щит) ---
        neftune_noise_alpha=5.0,     # Добавляет микро-шум в эмбеддинги. Модель учит СМЫСЛ, а не буквы.
        weight_decay=0.01,           # Штраф за раздувание весов. Удерживает стабильность LoRA-матриц. Универсальность: 100%
        max_grad_norm=1.0,           # Срезает пики градиентов, защищая от математического взрыва (NaN).Универсальность: 100%
        packing=False,               # Выключено. Склеивание коротких сессий ломает маскировку loss.
        label_smoothing_factor=0.1,  # Запрещает модели зубрить токены на 100%. Оставляет 10% на сомнения.
    ),
)

# Запуск процесса. Теперь он полностью под контролем автоматики.
unsloth_train(trainer)

# В эту папку запишется идеально сбалансированный адаптер
model.save_pretrained("./lora_out")
tokenizer.save_pretrained("./lora_out")
print("\n[УСПЕХ] Идеальный адаптер сохранен в: ./lora_out")
