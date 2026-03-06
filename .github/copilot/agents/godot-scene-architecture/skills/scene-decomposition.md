---
skillName: Scene Decomposition
agentId: godot-scene-architecture
activationKeywords:\n  - decompose\n  - refactor\n  - hierarchy\n  - nesting\n  - modular\n  - reuse\nfilePatterns:\n  - Scenes/**/*.tscn\nexamplePrompts:\n  - How should I break up this large scene?\n  - This scene has too many responsibilities\n  - How do I make this scene reusable?\n---\n\n# Skill: Scene Decomposition

## Purpose
Analyze complex Godot scenes and break them into clean, reusable, maintainable components. This skill helps the agent identify unnecessary nesting, duplicated logic, and opportunities for composition or modularization.

## When to Use
- The user provides a large or messy scene tree.
- The user wants to refactor a scene into smaller, reusable parts.
- The user asks whether a feature should be a child node, a separate scene, or a component.
- The user reports difficulty maintaining or extending a scene.

## Inputs
- A scene tree (text, screenshot description, or .tscn snippet).
- Optional: description of intended behavior or reuse goals.

## Outputs
- A proposed decomposition strategy.
- A rewritten scene hierarchy with modular components.
- Explanations of why certain nodes should be separated or composed.
- Suggestions for reusable scenes, autoloads, or custom resources.
- Optional GDScript examples for clean API boundaries.

## Behavior
- Identify deep nesting and propose flattening strategies.
- Suggest reusable sub-scenes for repeated UI or gameplay elements.
- Recommend composition over inheritance when appropriate.
- Highlight duplicated logic and propose shared components.
- Explain trade-offs between splitting scenes vs keeping them unified.
- Provide clear, indented scene trees for the proposed structure.

## Constraints
- Focus exclusively on Godot 4.4.1 scene and node systems.
- Avoid speculative features or non-Godot frameworks.
- Do not override project-specific architecture unless requested.
## DiceRogue Scene Organization

DiceRogue scenes organized by domain in `Scenes/`:
- **Challenge/**: Challenge configuration scenes
- **Consumable/**: Consumable effect scenes
- **Controller/**: Game controller root scene
- **Debuff/**: Debuff application and feedback scenes
- **Dice/**: Individual dice configurations and rolling
- **Effects/**: Visual effects (TweenFX animations)
- **Managers/**: Manager autoload scenes
- **Mods/**: Mod application scenes
- **PowerUp/**: Power-up configuration scenes
- **ScoreCard/**: Scoring display and animation
- **Shop/**: Shop UI and selection
- **Tracker/**: Stat tracking UI
- **UI/**: General UI components

When decomposing scenes:
1. Each scene should own one domain or responsibility
2. Design scenes to have zero dependencies where possible
3. Use signal-based communication between scenes
4. Keep UI scenes self-contained in `Scenes/UI/`
5. Use test scenes in `Tests/` to verify decomposition

Anti-patterns to avoid:
- Scene with game logic + UI mixed together
- Deep 10+ level nesting
- Scenes that require external node paths to function
- God scenes that orchestrate multiple systems
## Example Prompt
“Here’s my player scene. It has movement, health, inventory, and animation all in one place. How should I break this up?”

## Example Output
- A modular scene structure
- Component suggestions (HealthComponent, InventoryComponent, etc.)
- Rationale for each separation