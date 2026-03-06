---
skillName: Autoload & Global Systems
agentId: godot-scene-architecture
activationKeywords:
  - autoload
  - global
  - singleton
  - service
  - manager
filePatterns:
  - Scripts/Game/*.gd
  - Scripts/Managers/*.gd
examplePrompts:
  - Should this be an autoload or a component?
  - How do I design a clean global service?
  - How do I reduce coupling in my autoloads?
---

# Skill: Autoload & Global Systems

## Purpose
Design clean, maintainable global systems using Godot’s autoload (singleton) mechanism. This skill helps the agent determine when global state is appropriate, how to structure it, and how to avoid common pitfalls such as overuse or tight coupling.

## When to Use
- The user asks whether a system should be an autoload or a scene component.
- The user wants to design global services (audio manager, save system, event bus, config manager).
- The user reports issues with global state, initialization order, or cross‑scene communication.
- The user wants to refactor monolithic autoloads into modular services.

## Inputs
- Description of the system or behavior needing global access.
- Optional: existing autoload scripts or scene structures.

## Outputs
- A recommended autoload structure (single file or multiple services).
- GDScript examples for clean, modular global systems.
- Signal‑based communication patterns to reduce coupling.
- Initialization and lifecycle recommendations.
- Warnings about overuse and alternatives when appropriate.

## Behavior
- Suggest autoloads only when global access is truly needed.
- Encourage service‑oriented design (AudioService, SaveService, EventBus).
- Recommend minimal, well‑defined public APIs.
- Use signals for decoupled communication.
- Provide examples of how scenes interact with autoloads.
- Explain trade-offs between autoloads, components, and dependency injection.

## Constraints
- Focus exclusively on Godot 4.4.1.
- Avoid speculative features or non-Godot patterns.
- Do not enforce autoload usage unless the user requests it.
## DiceRogue Autoload Pattern

DiceRogue autoloads should NOT have `class_name` (per project standard).
Key autoloads in the project:
- **GameController** (main lifecycle manager)
- **PlayerEconomy** (money, progression state)
- **ChoresManager** (task/challenge tracking)
- **ChannelManager** (dice channel state)

When designing new autoloads:
1. Keep public API minimal and signal-driven
2. Emit signals for state changes (UI listens, doesn't query)
3. Avoid coupling to UI or scene nodes
4. Use signal-based communication with scenes
5. Initialize in `_ready()`, connect in `_enter_tree()`

Example pattern:
```gdscript
extends Node

signal state_changed(new_state)

func set_state(new_state):
    state_changed.emit(new_state)
```
## Example Prompt
“Should my inventory system be an autoload or a component?”

## Example Output
- A recommended architecture
- Example autoload script
- Integration examples for multiple scenes