"""Qwen3.8-27B LoRA — лаконичный формат (24.10.2026).

Датасет: chatml-jsonl от convert_v2.py (колонка messages; у assistant может быть
reasoning_content — TRL training-шаблон Qwen3.8 сам оборачивает его в think-блок
и маскирует loss на thinking + answer).

Память: 16 GB VRAM + RAM (hybrid). Перед запуском выгрузить ollama из GPU.
Важно: dataset_num_proc=1 — иначе oom-killer убьёт процесс (>62 ГБ системы).

Запуск: venv/bin/python train_27b.py [путь-к-dataset.jsonl]
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
    r=16, lora_alpha=16, lora_dropout=0.0,
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
        warmup_steps=10,
        learning_rate=1e-4,
        logging_steps=1,
        optim="adamw_8bit",
        output_dir="./outputs_qwen38",
        report_to="none",
    ),
)

trainer.train()

model.save_pretrained("./lora_out")
tokenizer.save_pretrained("./lora_out")
print("Сохранено: ./lora_out")
