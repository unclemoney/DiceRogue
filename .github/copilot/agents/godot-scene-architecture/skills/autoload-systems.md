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

## Example Prompt
“Should my inventory system be an autoload or a component?”

## Example Output
- A recommended architecture
- Example autoload script
- Integration examples for multiple scenes