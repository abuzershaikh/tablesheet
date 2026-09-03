import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    PORT: int = int(os.getenv("PORT", "8000"))
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    DEEPSEEK_API_KEY: str = os.getenv("DEEPSEEK_API_KEY", "")
    DEFAULT_PROVIDER: str = os.getenv("DEFAULT_PROVIDER", "gemini").lower()

config = Config()
