from typing import Callable, Dict, Any, List

class Tool:
    def __init__(self, name: str, description: str, parameters: Dict[str, Any], execute: Callable):
        self.name = name
        self.description = description
        self.parameters = parameters
        self.execute = execute

    def to_openai_format(self):
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": self.parameters
            }
        }

class ToolRegistry:
    def __init__(self):
        self._tools: Dict[str, Tool] = {}

    def register(self, tool: Tool):
        self._tools[tool.name] = tool

    def get_tool(self, name: str) -> Tool:
        return self._tools.get(name)

    def get_all_tools(self) -> List[Tool]:
        return list(self._tools.values())

    def execute_tool(self, name: str, kwargs: Dict[str, Any]) -> Any:
        tool = self.get_tool(name)
        if not tool:
            raise ValueError(f"Tool {name} not found")
        return tool.execute(**kwargs)

registry = ToolRegistry()
