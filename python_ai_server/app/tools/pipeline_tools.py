from .registry import Tool, registry

def execute_build_pipeline(explanation: str, plan_summary: str, pipeline: dict):
    # This tool doesn't execute anything on the server.
    # It simply collects the structured output to return to the Flutter app!
    return {
        "action": "HALT_AND_RETURN",
        "data": {
            "explanation": explanation,
            "plan_summary": plan_summary,
            "pipeline": pipeline
        }
    }

build_pipeline_tool = Tool(
    name="build_pipeline",
    description="Constructs the spreadsheet pipeline JSON to be executed by the C++ engine. Call this tool to finalize the user's request.",
    parameters={
        "type": "object",
        "properties": {
            "explanation": {
                "type": "string",
                "description": "Clear, friendly explanation of what you are going to do in Hindi/Urdu/English"
            },
            "plan_summary": {
                "type": "string",
                "description": "Short 1-line step summary (e.g., 'Filter Column A for +91 numbers')"
            },
            "pipeline": {
                "type": "object",
                "description": "The exact pipeline JSON containing steps",
                "properties": {
                    "steps": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string"},
                                "column": {"type": "integer"},
                                "rule": {"type": "object"}
                            },
                            "required": ["type"]
                        }
                    }
                },
                "required": ["steps"]
            }
        },
        "required": ["explanation", "plan_summary", "pipeline"]
    },
    execute=execute_build_pipeline
)

registry.register(build_pipeline_tool)
