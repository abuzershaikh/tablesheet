# Sheet Copilot VPS AI Server

Python FastAPI server designed to run on a VPS to handle AI requests for Table Sheets.
Supports **Gemini** and **DeepSeek**.

## How to Run on VPS

1. Clone or copy `vps_server` folder to your VPS.
2. Create `.env` file:
   ```bash
   cp .env.example .env
   ```
3. Edit `.env` with your `GEMINI_API_KEY` and `DEEPSEEK_API_KEY`.
4. Run locally or with Docker:
   ```bash
   # Using Docker
   docker build -t sheet-copilot-vps .
   docker run -d -p 8000:8000 --env-file .env sheet-copilot-vps

   # Using Python directly
   pip install -r requirements.txt
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```
