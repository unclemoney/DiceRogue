# Skill: Component Architecture

## Purpose
Design reusable, composition-based components for Godot 4.x that encapsulate behavior cleanly and can be attached to multiple scenes. This skill helps the agent create modular systems that avoid inheritance bloat and duplicated logic.

## When to Use
- The user wants reusable behavior across multiple scenes.
- The user is unsure whether to use inheritance or composition.
- The user wants to convert monolithic scripts into modular components.
- The user asks for clean API boundaries between systems.

## Inputs
- A description of the behavior or system to modularize.
- Optional: existing scripts or scene structures.

## Outputs
- A proposed component design (node-based or script-based).
- GDScript examples for reusable components.
- Recommendations for signals, events, and data flow.
- Suggestions for custom resources when appropriate.
- Integration examples showing how scenes attach and use components.

## Behavior
- Favor composition over inheritance unless inheritance is clearly superior.
- Use signals for decoupled communication between components.
- Recommend clean, minimal public APIs for each component.
- Suggest autoloads only when global state or services are required.
- Provide examples of how components attach to scenes and interact.
- Explain trade-offs between node-based and script-based components.

## Constraints
- Focus exclusively on Godot 4.4.1.
- Avoid speculative features or non-Godot patterns.
- Do not enforce a specific architecture unless the user requests it.

## Example Prompt
“I want enemies, NPCs, and the player to all use the same Health system. How should I build it?”

## Example Output
- A HealthComponent.gd example
- Signal-based damage and death handling
- Integration examples for multiple scenes