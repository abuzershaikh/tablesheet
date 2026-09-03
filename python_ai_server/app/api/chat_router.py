from fastapi import APIRouter, HTTPException
from app.models.schemas import ChatRequest, CopilotResponse
from app.engine.agent import AgentEngine

router = APIRouter()

@router.post("/api/v1/copilot/chat", response_model=CopilotResponse)
def chat_endpoint(request: ChatRequest):
    try:
        engine = AgentEngine(provider=request.provider)
        result_data = engine.run(prompt=request.prompt, context=request.context)
        return CopilotResponse(
            success=True,
            provider_used=request.provider.lower(),
            data=result_data
        )
    except Exception as e:
        return CopilotResponse(
            success=False,
            provider_used=request.provider.lower(),
            error=str(e)
        )
