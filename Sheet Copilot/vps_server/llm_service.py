import json
import httpx
from config import config
from prompts import SYSTEM_PROMPT

class LLMService:
    @staticmethod
    async def generate_response(prompt: str, context: str = "", provider: str = "gemini") -> dict:
        provider = provider.lower()
        full_user_prompt = f"User Request: {prompt}\nContext: {context}"
        
        if provider == "deepseek":
            return await LLMService._call_deepseek(full_user_prompt)
        else:
            return await LLMService._call_gemini(full_user_prompt)

    @staticmethod
    async def _call_gemini(user_prompt: str) -> dict:
        api_key = config.GEMINI_API_KEY
        if not api_key:
            raise ValueError("GEMINI_API_KEY is not configured on the VPS server.")
            
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={api_key}"
        
        payload = {
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": f"{SYSTEM_PROMPT}\n\n{user_prompt}"}]
                }
            ],
            "generationConfig": {
                "response_mime_type": "application/json",
                "temperature": 0.2
            }
        }
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            data = resp.json()
            
            raw_text = data['candidates'][0]['content']['parts'][0]['text']
            return json.loads(raw_text)

    @staticmethod
    async def _call_deepseek(user_prompt: str) -> dict:
        api_key = config.DEEPSEEK_API_KEY
        if not api_key:
            raise ValueError("DEEPSEEK_API_KEY is not configured on the VPS server.")
            
        url = "https://api.deepseek.com/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt}
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.2
        }
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()
            
            raw_text = data['choices'][0]['message']['content']
            return json.loads(raw_text)
