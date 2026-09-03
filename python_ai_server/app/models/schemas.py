from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List

class ChatRequest(BaseModel):
    prompt: str
    context: str = ""
    provider: str = "gemini"

class CopilotResponse(BaseModel):
    success: bool
    provider_used: str
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
