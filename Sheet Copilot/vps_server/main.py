from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional
from config import config
from llm_service import LLMService

app = FastAPI(
    title="Sheet Copilot VPS AI Server",
    description="VPS AI Agent supporting Gemini and DeepSeek for Table Sheets App",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class CopilotRequest(BaseModel):
    prompt: str = Field(..., description="User prompt or speech transcription")
    context: Optional[str] = Field("", description="Metadata or cell range context")
    provider: Optional[str] = Field("gemini", description="AI provider: 'gemini' or 'deepseek'")

@app.get("/health")
def health_check():
    return {
        "status": "online",
        "service": "Sheet Copilot VPS AI Server",
        "default_provider": config.DEFAULT_PROVIDER,
        "providers_available": {
            "gemini": bool(config.GEMINI_API_KEY),
            "deepseek": bool(config.DEEPSEEK_API_KEY)
        }
    }

@app.post("/api/v1/copilot/chat")
async def copilot_chat(req: CopilotRequest):
    try:
        provider = req.provider or config.DEFAULT_PROVIDER
        result = await LLMService.generate_response(
            prompt=req.prompt,
            context=req.context or "",
            provider=provider
        )
        return {
            "success": True,
            "provider_used": provider,
            "data": result
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=config.PORT, reload=True)
