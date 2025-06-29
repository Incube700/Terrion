# scripts/gpt_assistant.py

from openai import OpenAI
import os

# Получаем ключ из переменной окружения
api_key = os.environ.get("OPENAI_API_KEY")
if not api_key:
    raise ValueError("OPENAI_API_KEY is not set in environment variables.")

# Инициализируем клиента
client = OpenAI(api_key=api_key)

# Формируем сообщение
response = client.chat.completions.create(
    model="gpt-4",  # можно заменить на gpt-3.5-turbo при необходимости
    messages=[
        {"role": "system", "content": "Ты ассистент, помогающий вести проект разработки RTS-игры 'TERRION'."},
        {"role": "user", "content": "Составь список задач на следующую неделю для улучшения боевой системы."}
    ]
)

# Выводим ответ
print("Ответ от GPT:")
print(response.choices[0].message.content)
