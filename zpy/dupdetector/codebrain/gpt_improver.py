import os

try:
    from openai import OpenAI
    client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    GPT_AVAILABLE = True
except:
    GPT_AVAILABLE = False


def improve_group_with_gpt(func_codes):
    """
    GPT sees multiple functions and produces a better unified version
    """

    if not GPT_AVAILABLE:
        return None

    try:
        joined = "\n\n".join(func_codes)

        prompt = f"""
You are a senior Python engineer.

You are given multiple duplicate or similar functions.

Your task:
- Merge them into ONE improved function
- Preserve behavior
- Simplify logic
- Improve readability
- Remove redundancy

Return ONLY the final function.

Functions:
{joined}
"""

        response = client.chat.completions.create(
            model="gpt-5.3",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.2
        )

        return response.choices[0].message.content.strip()

    except Exception:
        return None
