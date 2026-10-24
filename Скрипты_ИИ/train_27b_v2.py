"""Qwen3.8-27B LoRA — лаконичный формат (24.10.2026).

Датасет: chatml-jsonl от convert_v2.py (колонка messages; у assistant может быть
reasoning_content — TRL training-шаблон Qwen3.8 сам оборачивает его в think-блок
и маскирует loss на thinking + answer).

Память: 16 GB VRAM + RAM (hybrid). Перед запуском выгрузить ollama из GPU.
Важно: dataset_num_proc=1 — иначе oom-killer убьёт процесс (>62 ГБ системы).

Запуск: venv/bin/python train_27b.py [путь-к-dataset.jsonl]

loss
Для чат-данных часто сходится к 0.5–1.5, а для инструкций — к 0.3–0.8.
"""
import sys

from unsloth import FastModel
from datasets import load_dataset
from trl import SFTConfig, SFTTrainer
from trl.chat_template_utils import qwen3_8_training_chat_template

DATASET = sys.argv[1] if len(sys.argv) > 1 else "../№3 Создание датасета/dataset.jsonl"

# --- Загрузка модели (hybrid: GPU + RAM) -------------------------------------
model, tokenizer = FastModel.from_pretrained(
    model_name="unsloth/Qwen3.8-27B-unsloth-bnb-4bit",
    max_seq_length=256,
    load_in_4bit=True,
    device_map="auto",
    max_memory={0: "14GiB", "cpu": "56GiB"},
    offload_layers="auto",
    offload_folder="./offload_weights",
)

# --- LoRA ---------------------------------------------------------------------
model = FastModel.get_peft_model(
    model,
    r=4, lora_alpha=8, lora_dropout=0.0,
    finetune_vision_layers     = False,
    finetune_language_layers   = True,
    finetune_attention_modules = True,
    finetune_mlp_modules       = True,
)

# --- Датасет ------------------------------------------------------------------
dataset = load_dataset("json", data_files=DATASET, split="train")

# Qwen3.8 отдаёт Processor; даём чистый текстовый токенйзер (отключает VLM-ветку).
text_tok = tokenizer.tokenizer if hasattr(tokenizer, "tokenizer") else tokenizer

# Training-шаблон TRL: содержит {% generation %} теги → loss считается
# корректно на thinking + answer для всех примеров (с reasoning_content и без).
text_tok.chat_template = qwen3_8_training_chat_template

# --- Настройки обучения -------------------------------------------------------
trainer = SFTTrainer(
    model=model,
    processing_class=text_tok,
    train_dataset=dataset,
    args=SFTConfig(
        assistant_only_loss=True,
        dataset_num_proc=1,
        max_length=256,
        per_device_train_batch_size=1,
        gradient_accumulation_steps=4,
        max_steps=25,
        warmup_steps=3,
        learning_rate=2e-4,
        logging_steps=1,
        optim="adamw_8bit",
        output_dir="./outputs_qwen38",
        report_to="none",

        # --- Новые защитные механизмы TRL / Unsloth против переобучения ---
        neftune_noise_alpha=5.0,     # Добавляет шум в эмбеддинги, спасает от зазубривания триггеров
        weight_decay=0.01,           # Штрафует за слишком большие веса адаптера (стабилизирует r=32) [2] Универсальность: 100%
        max_grad_norm=1.0,           # Жестко контролирует grad_norm, не давая ему взрываться [2] Универсальность: 100%
        packing=False,               # Отключаем упаковку, чтобы TRL корректно маскировал loss на коротких сессиях
        # --- Вот этот предохранитель не даст лоссу упасть в ноль ---
        label_smoothing_factor=0.1,  # Запрещает модели зубрить токены на 100%
    ),
)

trainer.train()

model.save_pretrained("./lora_out")
tokenizer.save_pretrained("./lora_out")
print("Сохранено: ./lora_out")

'''

packing=False

• Универсальность: Универсален для коротких контекстов и сложных масок loss.
• Почему: Упаковка (packing=True) склеивает множество коротких диалогов в один большой блок длиной в max_length (например, 4096 токенов), чтобы GPU не простаивал на пустых паддингах.
• Когда выключать (оставлять False): Как в вашем случае, когда вы используете max_length=256 (он и так крошечный, упаковывать нечего) или когда вы используете точечные маски ошибок типа assistant_only_loss вместе с тегами рассуждений <think>. В упаковке TRL иногда сбоит и начинает считать loss там, где не должен. Поэтому для ваших задач False — идеальный и безопасный выбор.



neftune_noise_alpha=5.0 (Главное исключение!)

• Универсальность: Универсален ТОЛЬКО для SFT (короткие/средние датасеты инструкций), но противопоказан для Continuous Pre-training.
• Почему это работает на инструкциях: На датасетах до 10 000 примеров этот шум — спасение. Он искусственно размывает точные формулировки, заставляя модель улавливать смысл промпта, а не зазубривать его.
• Когда его нужно ОТКЛЮЧАТЬ (neftune_noise_alpha=None):
	1. При дообучении на сырые факты (Continued Pre-training): Если вы загружаете в модель устав компании, точные технические спецификации, новые законы или код, вам не нужен шум. Модель обязана запомнить новые факты, названия и синтаксис с абсолютной точностью. Шум NEFTune будет ей только мешать.
	2. На гигантских датасетах (от 50 000+ примеров): Когда данных очень много, модель физически не сможет их зазубрить — разнообразие примеров само по себе сработает как естественный регулятор. Шум в таком случае просто затянет время сходимости модели.


0.1 ставить всегда?

Нет, label_smoothing_factor=0.1 нельзя ставить всегда. Это мощное лекарство от переобучения, но применять его нужно строго по назначению.
Если вы оставите этот параметр включенным для всех типов обучения, вы можете сильно ухудшить качество ответов модели на других задачах.
Вот простое руководство, когда этот параметр необходим, а когда он противопоказан:

❌ Когда 0.1 ставить НЕЛЬЗЯ (Оставляем по умолчанию 0.0):

1. Дообучение на точные знания и факты (Continued Pre-training): Если вы загружаете в модель документацию, базу знаний, законы, новые биографии или медицинские справочники. Сглаживание заставит модель сомневаться в точных формулировках, датах и именах, что приведет к галлюцинациям.
2. Обучение программированию и разметке (Coding / JSON / XML): Для кода важна абсолютная точность. Если модель должна вывести }, ] или тег </think>, а сглаживание заставит её сомневаться на 10%, она начнет путать синтаксис, и вы получите невалидный код.
3. Большие сбалансированные датасеты (от 5 000+ примеров): На больших объемах данных модель защищена от переобучения естественным образом за счет разнообразия текстов. Сглаживание здесь просто замедлит обучение и сделает ответы модели менее уверенными и более «размытыми».

'''
