import openai, os
from dotenv import load_dotenv

load_dotenv(".openai.env")
openai.api_key = os.getenv("OPENAI_API_KEY")

def load_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

readme = load_file("README.md")
context = load_file("AI_CONTEXT.md")

prompt = f"""Ты — ИИ-архитектор игры. Вот описание проекта и текущие задачи:

README:
{readme}

Контекст:
{context}

Что ты можешь предложить улучшить или реализовать следующим шагом?
"""

response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[{"role": "user", "content": prompt}]
)

with open("AI_RESPONSES.md", "a", encoding="utf-8") as f:
    f.write("\n\n---\n\n" + response.choices[0].message.content + "\n")
