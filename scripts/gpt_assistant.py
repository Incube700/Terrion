import openai
import os

openai.api_key = os.getenv("OPENAI_API_KEY")

response = openai.ChatCompletion.create(
  model="gpt-4",
  messages=[
    {"role": "system", "content": "Ты — AI-помощник по разработке игры Terrion."},
    {"role": "user", "content": "Проанализируй README и предложи улучшения."}
  ]
)

print(response.choices[0].message.content)
