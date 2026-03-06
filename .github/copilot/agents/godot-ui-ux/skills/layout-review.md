---\nskillName: Layout Review\nagentId: godot-ui-ux\nactivationKeywords:\n  - layout\n  - ui\n  - hierarchy\n  - spacing\n  - responsive\n  - container\nfilePatterns:\n  - Scenes/UI/**/*.tscn\n  - Scenes/UI/**/*.gd\nexamplePrompts:\n  - Review my UI layout for issues\n  - Why is my VBoxContainer stretching weirdly?\n  - How should I structure this screen?\n---\n\n# Skill: Layout Review

## Purpose
Analyze Godot Control node hierarchies and provide clear, actionable recommendations to improve layout structure, spacing, responsiveness, and maintainability. This skill helps the agent diagnose common UI issues and propose optimized alternatives.

## When to Use
- The user provides a Control hierarchy (text, screenshot description, or scene snippet).
- The user reports layout issues such as stretching, clipping, misalignment, or inconsistent spacing.
- The user asks for a cleaner or more scalable UI structure.
- The user wants to refactor an existing UI scene.

## Inputs
- A textual representation of a node tree (indented list, Godot scene snippet, or description).
- Optional context about desired behavior, target resolutions, or pixel-art constraints.

## Outputs
- A rewritten, optimized node hierarchy using Godot’s Control and Container nodes.
- Explanations of layout issues and why they occur.
- Recommendations for anchors, size flags, margins, and container usage.
- Optional code snippets for theme overrides or layout fixes.

## Behavior
- Identify unnecessary nesting and propose simpler structures.
- Recommend appropriate containers (VBoxContainer, HBoxContainer, GridContainer, MarginContainer, etc.).
- Suggest consistent spacing, alignment, and responsive layout rules.
- Highlight anti-patterns such as:
  - Overuse of Control nodes without containers
  - Conflicting anchors and size flags
  - Manual positioning where containers should be used
  - Pixel-art scaling issues
- Provide rationale for each recommendation.
- When multiple solutions exist, present 2–3 options with trade-offs.

## Constraints
- Focus exclusively on Godot 4.4.1 UI systems.
- Avoid speculative features or non-Godot frameworks.
- Do not modify project-specific design systems unless requested.
## DiceRogue UI Layout Standards

DiceRogue is a pixel-art game with strict layout rules:
- **Base scale**: 1× (pixel-perfect art)
- **UI scale**: 3× integer multiples for crisp text/buttons
- **Screen resolution**: 240p minimum, responsive to 4:3 and 16:9
- **Theme**: All controls styled via `Resources/UI/theme.tres`
- **Containers**: HBoxContainer, VBoxContainer, GridContainer for responsive layouts

When reviewing DiceRogue layouts:
1. Verify all containers use proper size flags (SHRINK_CENTER, EXPAND_FILL)
2. Check anchor_left/right/top/bottom for responsive positioning
3. Ensure no hardcoded positions (use margins + containers instead)
4. Confirm custom fonts scale at 3× without blurring
5. Validate keyboard/gamepad focus order (focus_next path)
6. Test on 240×160 and 960×640 viewport sizes

Anti-patterns for pixel-art UI:
- Fractional scaling (use integer multiples only)
- Hardcoded positions instead of containers
- Anchors without size flags
- Unscaled 9-slice borders
## Example Prompt
“Here’s my current UI layout. It stretches weirdly on 4:3 screens. Can you review it?”

## Example Output
- A cleaned-up node tree
- Explanation of layout issues
- Suggested container replacements
- Anchor and size flag recommendations