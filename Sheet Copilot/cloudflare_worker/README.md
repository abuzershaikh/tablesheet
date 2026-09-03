# Sheet Copilot Cloudflare Worker (Whisper STT)

Speech-to-Text worker using `@cf/openai/whisper-large-v3-turbo` on Cloudflare Workers AI.

## Deployment

1. Install Wrangler globally or locally:
   ```bash
   npm install
   ```
2. Login to Cloudflare:
   ```bash
   npx wrangler login
   ```
3. Deploy to Cloudflare Workers:
   ```bash
   npx wrangler deploy
   ```
4. Copy the published URL (e.g., `https://sheet-copilot-whisper-stt.<subdomain>.workers.dev`) and set it in your Flutter app's Copilot settings.
