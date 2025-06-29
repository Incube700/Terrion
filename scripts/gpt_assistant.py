name: GPT Assistant

import openai, os
from dotenv import load_dotenv

load_dotenv(".openai.env")
openai.api_key = os.getenv("OPENAI_API_KEY")
on:
  workflow_dispatch:

jobs:
  gpt_assistant_job:
    runs-on: ubuntu-latest
    env:
      OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}

    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: 3.11
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run GPT Assistant
        run: python scripts/gpt_assistant.py
