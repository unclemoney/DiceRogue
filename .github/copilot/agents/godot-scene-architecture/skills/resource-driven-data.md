---
skillName: Resource-Driven Data
agentId: godot-scene-architecture
activationKeywords:
  - resource
  - data
  - configuration
  - tres
  - serialization
  - export
filePatterns:
  - Resources/Data/*.tres
  - Scripts/Core/*.gd
  - Scripts/Game/*.gd
examplePrompts:
  - How do I make this data-driven instead of hardcoded?
  - How do I design a custom Resource class?
  - How should I structure game item data?
---

# Skill: Resource-Driven Data

## Purpose
Design clean, scalable data pipelines using Godot’s Resource system (.tres/.res). This skill helps the agent create reusable data assets, custom Resource classes, and data‑driven architectures that separate logic from configuration.

## When to Use
- The user wants to move configuration or game data out of scripts.
- The user needs reusable data assets (items, abilities, levels, UI configs).
- The user wants to design custom Resource classes.
- The user asks how to serialize, load, or manage data cleanly.

## Inputs
- Description of the data or system to be externalized.
- Optional: existing scripts or data structures.

## Outputs
- A recommended data structure using Resources.
- GDScript examples for custom Resource classes.
- Suggestions for editor-friendly inspectors and metadata.
- Loading, caching, and serialization patterns.
- Optional integration with autoloads or components.

## Behavior
- Encourage separation of data and logic.
- Recommend custom Resource classes for structured data.
- Suggest editor-friendly patterns (export variables, enums, arrays).
- Provide examples of loading and caching resources.
- Explain trade-offs between Resources, JSON, and autoloads.
- Suggest folder structures for data assets.

## Constraints
- Focus exclusively on Godot 4.4.1 Resource systems.
- Avoid speculative features or non-Godot data formats unless requested.
- Do not enforce a specific data pipeline unless the user requests it.
## DiceRogue Data Resources

DiceRogue's game systems heavily use Resources:
- **Challenge, Debuff, PowerUp, Consumable**: All inherit from Resource
- **Dice configurations**: Color, behavior, modifiers
- **Theme resources**: UI styling in `Resources/UI/theme.tres`

When designing Resources for DiceRogue:
1. Extend `Resource` and use `class_name`
2. Mark properties as `@export` for inspector editing
3. Use custom icons (16x16 PNG in Resources/Data/)
4. Preload common resources in autoloads
5. Version resources if they'll evolve over time

Example resource structure:
```gdscript
extends Resource
class_name ItemConfig

@export var item_name: String
@export var description: String
@export var rarity: int = 1
```

Store in `Resources/Data/` by category (Items/, Challenges/, etc.)
## Example Prompt
“I want all my items to be data-driven instead of hardcoded.”

## Example Output
- Custom ItemResource.gd example
- Example .tres files
- Integration with inventory or UI systems