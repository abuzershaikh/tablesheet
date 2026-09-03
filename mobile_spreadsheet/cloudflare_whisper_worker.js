/**
 * Cloudflare Worker: Pure Whisper Audio Transcription Worker
 * Deployed for: Table Sheets Mobile App Voice Copilot
 * 
 * Features:
 * - Pure Audio-to-Text Transcription via Whisper
 * - Supports Cloudflare Workers AI (@cf/openai/whisper)
 * - Supports Groq / OpenAI Whisper API Key fallback
 * - CORS enabled for mobile app requests
 */

export default {
  async fetch(request, env, ctx) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    // Health Check
    if (request.method === 'GET') {
      return new Response(JSON.stringify({ 
        status: 'online', 
        service: 'Pure Whisper Audio Transcription Worker',
        model: '@cf/openai/whisper'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed. Send POST request with audio file.' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    try {
      let audioBytes;

      const contentType = request.headers.get('content-type') || '';
      if (contentType.includes('multipart/form-data')) {
        const formData = await request.formData();
        const file = formData.get('file') || formData.get('audio');
        if (!file) {
          return new Response(JSON.stringify({ error: 'No audio file found in form data' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        audioBytes = await file.arrayBuffer();
      } else {
        audioBytes = await request.arrayBuffer();
      }

      if (!audioBytes || audioBytes.byteLength === 0) {
        return new Response(JSON.stringify({ error: 'Empty audio payload received' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      let transcriptionText = '';

      // 1. Primary: Cloudflare Workers AI Whisper Model
      if (env.AI) {
        const aiResponse = await env.AI.run('@cf/openai/whisper', {
          audio: [...new Uint8Array(audioBytes)],
        });
        transcriptionText = aiResponse.text || aiResponse.vtt || '';
      } 
      // 2. Fallback: Groq / OpenAI Whisper API
      else if (env.GROQ_API_KEY || env.OPENAI_API_KEY) {
        const apiKey = env.GROQ_API_KEY || env.OPENAI_API_KEY;
        const apiUrl = env.GROQ_API_KEY 
          ? 'https://api.groq.com/openai/v1/audio/transcriptions'
          : 'https://api.openai.com/v1/audio/transcriptions';

        const bodyForm = new FormData();
        const blob = new Blob([audioBytes], { type: 'audio/m4a' });
        bodyForm.append('file', blob, 'voice_recording.m4a');
        bodyForm.append('model', env.GROQ_API_KEY ? 'whisper-large-v3' : 'whisper-1');

        const apiRes = await fetch(apiUrl, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${apiKey}` },
          body: bodyForm,
        });

        const resData = await apiRes.json();
        transcriptionText = resData.text || '';
      } else {
        return new Response(JSON.stringify({ 
          error: 'No Workers AI binding [env.AI] or GROQ_API_KEY / OPENAI_API_KEY secret configured.' 
        }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      return new Response(JSON.stringify({
        success: true,
        text: transcriptionText.trim(),
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });

    } catch (err) {
      return new Response(JSON.stringify({ success: false, error: err.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  },
};
