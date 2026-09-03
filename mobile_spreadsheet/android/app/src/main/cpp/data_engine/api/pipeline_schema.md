# ETL Engine V2 - Pipeline JSON Schema [FROZEN]

This document defines the strict, frozen JSON schema that the `PipelineValidator` enforces. The AI Planner MUST generate JSON exactly matching this schema.

## Core Schema
Every pipeline MUST be a JSON object containing a `steps` array.

```json
{
  "steps": [
    // Step Objects
  ]
}
```

## Step Object Schema
Every step object MUST contain a `type` string corresponding to a registered plugin in `PipelineRegistry`.

```json
{
  "type": "StepName",
  // Additional step-specific configuration keys...
}
```

## Registered Step Types & Configurations

### `Filter`
Filters the dataset based on a rule.
- `column` (integer): The 0-indexed column to evaluate.
- `rule` (object): The rule definition.

Example:
```json
{
  "type": "Filter",
  "column": 0,
  "rule": {
    "type": "Equals",
    "value": "John Doe"
  }
}
```

## AI Generation Constraints
- Do not add undocumented keys.
- Do not attempt to execute steps not listed above.
- If a step fails, the `TransactionEngine` will automatically roll back all changes.
