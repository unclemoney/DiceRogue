---
skillName: Plugin Architecture
agentId: godot-scene-architecture
activationKeywords:
  - plugin
  - editor
  - tool
  - inspector
  - gizmo
  - addon
filePatterns:
  - addons/**/*.gd
  - Scripts/Editor/*.gd
examplePrompts:
  - How do I create a custom editor plugin?
  - How do I build a custom inspector for this resource?
  - How do I automate this repetitive editor task?
---

# Skill: Plugin Architecture

## Purpose
Help the user design and implement Godot Editor plugins using the EditorPlugin API. This skill supports building custom inspectors, dock panels, gizmos, tools, and workflow automation that integrate cleanly with the Godot editor.

## When to Use
- The user wants to create or refactor a Godot editor plugin.
- The user needs custom inspectors, property drawers, or editor tools.
- The user wants to automate repetitive tasks or enforce project conventions.
- The user reports issues with plugin lifecycle, tool scripts, or editor integration.

## Inputs
- Description of the desired plugin functionality.
- Optional: existing plugin code or folder structure.

## Outputs
- A recommended plugin folder structure.
- GDScript examples using EditorPlugin, EditorInspectorPlugin, or EditorProperty.
- Lifecycle guidance (enter_tree, exit_tree, _handles, _edit).
- Suggestions for custom UI, dock panels, or inspectors.
- Best practices for tool scripts and editor-only logic.

## Behavior
- Provide clean, modular plugin structures.
- Explain how to register and unregister custom types.
- Recommend when to use tool scripts vs editor plugins.
- Suggest UI patterns for editor docks and inspectors.
- Warn about common pitfalls (e.g., tool scripts running in-game).
- Provide examples of plugin metadata and config files.

## Constraints
- Focus exclusively on Godot 4.4.1 editor APIs.
- Avoid speculative features or non-Godot tooling.
- Do not modify project-specific editor workflows unless requested.
## DiceRogue Plugin Context

DiceRogue has existing plugins in `addons/`:
- **gdai-mcp-plugin-godot**: MCP integration for code assistance
- **resource_viewer**: Visual resource inspection
- **TweenFX**: Animation tween utility addon

When building new plugins:
1. Place in `addons/plugin-name/`
2. Include `plugin.cfg` with metadata
3. Use `EditorPlugin` or `EditorInspectorPlugin` appropriately
4. Keep tool scripts separate from runtime scripts
5. Test with: `& "Godot_v4.4.1-stable.exe" --path "project" --editor`
## Example Prompt
“I want a plugin that auto-generates collision shapes for imported sprites.”

## Example Output
- Plugin folder structure
- EditorPlugin example code
- Integration instructions