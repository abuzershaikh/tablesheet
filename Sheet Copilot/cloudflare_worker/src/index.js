const SYSTEM_PROMPT = `You are Sheet Copilot, an expert AI assistant embedded inside an enterprise spreadsheet application.
Your task is to understand user requests (in English, Hindi, Urdu, or Hinglish) regarding spreadsheet operations, data cleaning, filtering, sorting, and transformation.

CRITICAL INSTRUCTION:
You MUST call the 'build_pipeline' tool to execute the user's request.
VALID PIPELINE STEP TYPES (FROZEN C++ SCHEMA):
1. "Filter"
   - column: 0-indexed integer column index (e.g. Column A is 0, Column B is 1)
   - rule: Object containing filter rule. Supported rule types:
     - "Equals", "NotEquals", "Contains", "StartsWith", "EndsWith", "GreaterThan", "LessThan"
`;

const TOOLS = [
  {
    type: "function",
    function: {
      name: "build_pipeline",
      description: "Build a data processing pipeline with a sequence of steps to transform, filter, or clean the spreadsheet.",
      parameters: {
        type: "object",
        properties: {
          explanation: {
            type: "string",
            description: "Clear, friendly explanation of what you are going to do in Hindi/Urdu/English"
          },
          plan_summary: {
            type: "string",
            description: "Short 1-line step summary (e.g., 'Filter Column A for +91 numbers')"
          },
          pipeline: {
            type: "object",
            properties: {
              steps: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    type: { type: "string", enum: ["Filter"] },
                    column: { type: "integer" },
                    rule: {
                      type: "object",
                      properties: {
                        type: { type: "string", enum: ["Equals", "NotEquals", "Contains", "StartsWith", "EndsWith", "GreaterThan", "LessThan"] },
                        value: { type: "string" }
                      },
                      required: ["type", "value"]
                    }
                  },
                  required: ["type", "column", "rule"]
                }
              }
            },
            required: ["steps"]
          }
        },
        required: ["explanation", "plan_summary", "pipeline"]
      }
    }
  }
];

const GEMINI_TOOLS = [
  {
    functionDeclarations: [TOOLS[0].function]
  }
];

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
      });
    }

    const jsonHeaders = {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    };

    // Health Check Endpoint
    if (request.method === "GET" && (pathname === "/health" || pathname === "/")) {
      return new Response(JSON.stringify({
        status: "online",
        service: "Sheet Copilot Cloudflare Worker AI Engine (Function Calling Enabled)",
        models: ["whisper-large-v3-turbo", "gemini-1.5-pro", "deepseek-chat", "glm-4.7-flash"],
      }), { headers: jsonHeaders });
    }

    if (request.method !== "POST") {
      return new Response(JSON.stringify({ error: "Only POST requests allowed" }), {
        status: 405,
        headers: jsonHeaders,
      });
    }

    try {
      // -------------------------------------------------------------
      // ROUTE 1: AI Copilot Chat Endpoint (/api/v1/copilot/chat)
      // -------------------------------------------------------------
      if (pathname.includes("/chat") || pathname.includes("/copilot")) {
        const body = await request.json();
        const prompt = body.prompt || "";
        const context = body.context || "";
        const provider = (body.provider || "glm").toLowerCase();

        if (!prompt) {
          return new Response(JSON.stringify({ error: "Prompt is required" }), {
            status: 400,
            headers: jsonHeaders,
          });
        }

        let aiResult;
        if (provider === "deepseek") {
          aiResult = await handleDeepSeek(prompt, context, env);
        } else if (provider === "gemini") {
          aiResult = await handleGemini(prompt, context, env);
        } else {
          // Default to GLM
          aiResult = await handleGLM(prompt, context, env);
        }

        return new Response(JSON.stringify({
          success: true,
          provider_used: provider,
          data: aiResult,
        }), { headers: jsonHeaders });
      }

      // -------------------------------------------------------------
      // ROUTE 2: Whisper Speech-to-Text Transcription (/transcribe)
      // -------------------------------------------------------------
      let audioBuffer;
      const contentType = request.headers.get("content-type") || "";

      if (contentType.includes("multipart/form-data")) {
        const formData = await request.formData();
        const file = formData.get("file") || formData.get("audio");
        if (!file) {
          return new Response(JSON.stringify({ error: "No audio file provided in form data" }), {
            status: 400,
            headers: jsonHeaders,
          });
        }
        audioBuffer = await file.arrayBuffer();
      } else {
        audioBuffer = await request.arrayBuffer();
      }

      if (!audioBuffer || audioBuffer.byteLength === 0) {
        return new Response(JSON.stringify({ error: "Empty audio payload" }), {
          status: 400,
          headers: jsonHeaders,
        });
      }

      const inputBinary = {
        audio: new Uint8Array(audioBuffer)
      };
      
      const response = await env.AI.run("@cf/openai/whisper-large-v3-turbo", inputBinary);

      return new Response(JSON.stringify({
        success: true,
        text: response.text || "",
        vtt: response.vtt || null,
      }), { headers: jsonHeaders });

    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: jsonHeaders,
      });
    }
  },
};

// -------------------------------------------------------------
// Gemini Helper (Tool Calling)
// -------------------------------------------------------------
async function handleGemini(prompt, contextStr, env) {
  const apiKey = env.GEMINI_API_KEY || "";
  if (!apiKey) {
    return await handleGLM(prompt, contextStr, env);
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=${apiKey}`;
  const fullPrompt = `${SYSTEM_PROMPT}\n\nUser Request: ${prompt}\nContext: ${contextStr}`;

  const resp = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: fullPrompt }] }],
      tools: GEMINI_TOOLS,
      toolConfig: {
        functionCallingConfig: {
          mode: "ANY", // Forces Gemini to call a tool
          allowedFunctionNames: ["build_pipeline"]
        }
      },
      generationConfig: {
        temperature: 0.2,
      },
    }),
  });

  if (!resp.ok) {
    throw new Error(`Gemini API Error: ${resp.status} ${resp.statusText}`);
  }

  const data = await resp.json();
  try {
    const call = data.candidates[0].content.parts[0].functionCall;
    if (call && call.name === "build_pipeline") {
      return call.args;
    }
  } catch (e) {
    // Fallback if structure is missing
  }
  
  throw new Error("Gemini failed to invoke tool call.");
}

// -------------------------------------------------------------
// DeepSeek Helper (Tool Calling)
// -------------------------------------------------------------
async function handleDeepSeek(prompt, contextStr, env) {
  const apiKey = env.DEEPSEEK_API_KEY || "";
  if (!apiKey) {
    return await handleGLM(prompt, contextStr, env);
  }

  const url = "https://api.deepseek.com/chat/completions";
  const fullPrompt = `User Request: ${prompt}\nContext: ${contextStr}`;

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: fullPrompt },
      ],
      tools: TOOLS,
      tool_choice: { type: "function", function: { name: "build_pipeline" } },
      temperature: 0.2,
    }),
  });

  if (!resp.ok) {
    throw new Error(`DeepSeek API Error: ${resp.status} ${resp.statusText}`);
  }

  const data = await resp.json();
  const toolCall = data.choices[0]?.message?.tool_calls?.[0];
  if (toolCall && toolCall.function && toolCall.function.name === "build_pipeline") {
    return JSON.parse(toolCall.function.arguments);
  }

  throw new Error("DeepSeek failed to invoke tool call.");
}

// -------------------------------------------------------------
// GLM-4.7-Flash Helper (Tool Calling via Cloudflare Workers AI)
// -------------------------------------------------------------
async function handleGLM(prompt, contextStr, env) {
  if (!env.AI) {
    throw new Error("Cloudflare Workers AI binding missing.");
  }

  const messages = [
    { role: "system", content: SYSTEM_PROMPT },
    { role: "user", content: `User Request: ${prompt}\nContext: ${contextStr}` },
  ];

  const response = await env.AI.run("@cf/zai-org/glm-4.7-flash", { 
    messages,
    tools: TOOLS
  });
  
  let toolCall;
  if (response.tool_calls && response.tool_calls.length > 0) {
    toolCall = response.tool_calls[0];
  } else if (response.choices && response.choices.length > 0 && response.choices[0].message.tool_calls) {
    toolCall = response.choices[0].message.tool_calls[0];
  }

  if (toolCall && toolCall.function && toolCall.function.name === "build_pipeline") {
    // Cloudflare AI run might return arguments as object or string
    let args = toolCall.function.arguments;
    if (typeof args === "string") {
       try { args = JSON.parse(args); } catch(e) {}
    }
    return args;
  }
  
  // Fallback: Model might have just answered in text (which shouldn't happen with tools, but just in case)
  let text = response.response || (response.choices && response.choices[0].message.content) || "{}";
  text = text.replace(/```json/g, "").replace(/```/g, "").trim();
  try {
    return JSON.parse(text);
  } catch (e) {
    throw new Error("GLM failed to invoke tool call or generate valid JSON.");
  }
}
