# AI Agent Tools

From now on, all new AI Agent (Copilot) tools must be created in this folder to maintain a clean and modular architecture. 

## Folder Structure
```
tools/
  ├── copilot_tool.dart                 # The base abstract class every tool must implement
  ├── README.md                         # This file
  ├── text_to_columns/                  # Each tool gets its own separate folder
  │   └── text_to_columns_tool.dart     # The tool implementation
  └── format_column/
      └── format_column_tool.dart
```
