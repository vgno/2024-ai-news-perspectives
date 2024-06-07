import os
from pathlib import Path

import dotenv
import fire
import pandas as pd
import requests


def run_model(model, prompt, article, conflict, perspective_a, perspective_b):
    url = f"{os.getenv('VG_AI_API_URL')}/v1/services/text-to-schema"

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {os.getenv('VG_AI_API_KEY')}",
    }

    body = {
        "model": model,
        "systemPrompt": prompt.format(
            conflict=conflict, perspective_a=perspective_a, perspective_b=perspective_b
        ),
        "text": article["TEXT"],
        "schema": {
            "type": "object",
            "properties": {
                "perspective": {
                    "type": "string",
                    "description": f"The perspective that is promoted. One of 'neutral', '{perspective_a}', '{perspective_b}'.",
                    "enum": ["neutral", perspective_a, perspective_b],
                },
                "explanation": {
                    "type": "array",
                    "description": "Explanation of your assessment",
                    "items": {"type": "string"},
                },
            },
        },
    }

    result = requests.post(url, headers=headers, json=body)
    result.raise_for_status()

    return result.json()


def main():
    models = [
        "google-vertex-gemini-1.5-pro-preview-0409",
        "gpt-4o",
        "gpt-4-turbo",
        "bedrock-anthropic.claude-3-opus-20240229-v1:0",
    ]
    prompt = Path("prompt.txt").read_text()
    articles = pd.read_json("./data/articles.jsonl", lines=True)
    result = []

    for article in articles.to_dict(orient="records"):
        for model in models:
            print(
                f"Running {model} with {article['CONTENT_ID']}: {article['CONTENT_TITLE']}..."
            )

            response = run_model(
                model,
                prompt,
                article,
                conflict="Israel/Gaza",
                perspective_a="israeli",
                perspective_b="palestinian",
            )

            result.append(
                {
                    "id": article["CONTENT_ID"],
                    "title": article["CONTENT_TITLE"],
                    "rater": model,
                    "perspective": response["result"]["perspective"],
                    "explanation": "\n".join(response["result"]["explanation"]),
                }
            )

            pd.DataFrame(result).to_csv("data/classification.csv", index=False)


if __name__ == "__main__":
    dotenv.load_dotenv()
    fire.Fire(main())
