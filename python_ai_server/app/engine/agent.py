import os
import json
import requests
from typing import Dict, Any
from app.tools.registry import registry
from app.engine.prompts import SYSTEM_PROMPT
import google.generativeai as genai

class AgentEngine:
    def __init__(self, provider: str):
        self.provider = provider.lower()
        
    def run(self, prompt: str, context: str = "") -> Dict[str, Any]:
        if self.provider == "deepseek":
            return self._run_deepseek(prompt, context)
        else:
            return self._run_gemini(prompt, context)

    def _run_deepseek(self, prompt: str, context: str) -> Dict[str, Any]:
        api_key = os.environ.get("DEEPSEEK_API_KEY", "")
        if not api_key:
            raise ValueError("DEEPSEEK_API_KEY is not set.")
            
        url = "https://api.deepseek.com/chat/completions"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        tools = [t.to_openai_format() for t in registry.get_all_tools()]
        
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Context: {context}\nRequest: {prompt}"}
        ]
        
        # Agent Loop
        for _ in range(5):  # Max 5 tool iterations
            payload = {
                "model": "deepseek-chat",
                "messages": messages,
                "tools": tools,
                "temperature": 0.2
            }
            response = requests.post(url, headers=headers, json=payload)
            response.raise_for_status()
            res_data = response.json()
            message = res_data["choices"][0]["message"]
            messages.append(message)
            
            if message.get("tool_calls"):
                for tool_call in message["tool_calls"]:
                    func_name = tool_call["function"]["name"]
                    kwargs = json.loads(tool_call["function"]["arguments"])
                    
                    # Execute tool natively in Python
                    try:
                        result = registry.execute_tool(func_name, kwargs)
                        if isinstance(result, dict) and result.get("action") == "HALT_AND_RETURN":
                            return result["data"]
                            
                        messages.append({
                            "role": "tool",
                            "tool_call_id": tool_call["id"],
                            "content": json.dumps(result)
                        })
                    except Exception as e:
                        messages.append({
                            "role": "tool",
                            "tool_call_id": tool_call["id"],
                            "content": f"Error executing tool: {str(e)}"
                        })
            else:
                # If no tool calls but model replied, just break
                break
                
        raise ValueError("Agent failed to build a pipeline within the iteration limit.")

    def _run_gemini(self, prompt: str, context: str) -> Dict[str, Any]:
        api_key = os.environ.get("GEMINI_API_KEY", "AQ.Ab8RN6JDRkKe50hOOgmF02yQoXh-ckneP3JyYiZOIRX3uXbijQ")
        if not api_key:
            raise ValueError("GEMINI_API_KEY is not set.")
            
        genai.configure(api_key=api_key)
        
        tools = [{"function_declarations": [
            {
                "name": t.name,
                "description": t.description,
                "parameters": t.parameters
            } for t in registry.get_all_tools()
        ]}]
        
        model = genai.GenerativeModel(
            'gemini-1.5-pro',
            system_instruction=SYSTEM_PROMPT,
            tools=tools
        )
        
        chat = model.start_chat()
        
        # Agent Loop
        message = f"Context: {context}\nRequest: {prompt}"
        for _ in range(5):
            response = chat.send_message(message)
            
            # Check for tool calls
            if response.parts and hasattr(response.parts[0], 'function_call') and response.parts[0].function_call:
                fc = response.parts[0].function_call
                func_name = fc.name
                kwargs = {k: v for k, v in fc.args.items()}
                
                try:
                    result = registry.execute_tool(func_name, kwargs)
                    if isinstance(result, dict) and result.get("action") == "HALT_AND_RETURN":
                        return result["data"]
                        
                    # Format for gemini tool response
                    message = {
                        "function_response": {
                            "name": func_name,
                            "response": {"result": result}
                        }
                    }
                except Exception as e:
                    message = {
                        "function_response": {
                            "name": func_name,
                            "response": {"error": str(e)}
                        }
                    }
            else:
                break
                
        raise ValueError("Agent failed to build a pipeline within the iteration limit.")
