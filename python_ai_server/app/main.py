from fastapi import FastAPI
from app.api import chat_router, stt_router

app = FastAPI(title="Sheet Copilot Python VPS Server (Agentic Tool Calling)")

@app.get("/")
def health_check():
    return {"status": "online", "service": "Sheet Copilot Agent Engine"}

app.include_router(chat_router.router)
app.include_router(stt_router.router)
