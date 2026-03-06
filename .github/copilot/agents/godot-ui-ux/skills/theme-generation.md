---\nskillName: Theme Generation\nagentId: godot-ui-ux\nactivationKeywords:\n  - theme\n  - styling\n  - colors\n  - fonts\n  - design_system\n  - texture\nfilePatterns:\n  - Resources/UI/**/*.tres\n  - Resources/UI/**/*.gd\nexamplePrompts:\n  - Generate a theme for my UI\n  - How do I build a consistent design system?\n  - Create button styles for pixel-art\n---\n\n# Skill: Theme Generation

## Purpose
Create advanced, production-ready Godot 4.4.1 UI themes that support consistent styling, responsive layouts, pixel-art constraints, and reusable design tokens. This skill helps the agent generate theme structures, style classes, and asset mappings while prompting the user for any missing visual resources.

## When to Use
- The user wants a new theme.tres or a theme overhaul.
- The user needs consistent styling across buttons, panels, labels, inputs, HUD elements, or custom controls.
- The user is building a pixel-art UI and needs crisp scaling and texture-based styles.
- The user wants a design system with typography, spacing, color tokens, and reusable style classes.
- The user provides art assets or requests guidance on what assets to create.

## Inputs
- Optional: color palette, typography choices, spacing scale, icon sizes, pixel-art scale.
- Optional: art assets such as 9-slice textures, icons, or sprite sheets.
- Optional: references or screenshots of desired style.
- If inputs are missing, the skill must ask targeted questions to gather them.

## Outputs
- A structured theme plan including:
  - Color tokens (primary, secondary, accent, background, surface, error, success).
  - Typography scale (UI, title, caption, monospace).
  - Spacing system (4/8/12/16 or pixel-art multiples).
  - Control style classes (Button, Panel, LineEdit, CheckBox, ScrollContainer, etc.).
  - Pixel-art scaling rules when relevant.
- Godot 4.x theme resource snippets (GDScript or .tres examples).
- Asset requirements list (e.g., 9-slice borders, hover/pressed textures, icon sizes).
- Optional: suggestions for reusable custom controls.

## Behavior
- Ask the user for missing assets or design tokens before generating a final theme.
- Provide multiple style directions when appropriate (flat, textured, pixel-art, skeuomorphic).
- Use Godot’s theme override system correctly, including StyleBoxFlat, StyleBoxTexture, and font overrides.
- Recommend consistent spacing and typography scales.
- For pixel-art UIs, enforce integer scaling and crisp edges.
- For non-pixel-art UIs, recommend vector-friendly or scalable approaches.
- Explain trade-offs between different theme structures.
- When generating theme code, keep it modular and easy to maintain.

## Constraints
- Focus exclusively on Godot 4.4.1 theme systems.
- Do not assume assets exist; always prompt for missing textures or icons.
- Avoid speculative features or non-Godot frameworks.
- Do not override project-specific design systems unless the user requests it.
## DiceRogue Theme System

DiceRogue maintains a master theme in `Resources/UI/theme.tres`:
- **Color tokens**: Primary (dice blue), secondary (gold), accent (red for debuffs)
- **Typography**: Smaller for labels, larger for titles (all pixel-art fonts)
- **9-slice borders**: Standard edge size for all panels (e.g., 4px)
- **Controls styled**: Button, Panel, LineEdit, CheckBox, ItemList, VBoxContainer
- **Spacing system**: All margins/separation use multiples of 4px or 8px

When generating or modifying DiceRogue themes:
1. Use `StyleBoxTexture` for 9-slice pixel-art borders (NOT flat colors)
2. Create separate states for Button: normal, hover, pressed, disabled
3. Set font sizes to +6/+8/+10 (relative to base 8px pixel font)
4. Test at 1× scale in editor before deploying
5. All textures in `Resources/UI/` organized by component (buttons/, panels/, icons/)

DiceRogue color palette:
- **Primary Blue**: #2C5AA0 (dice active)
- **Gold**: #D4A840 (points, highlights)
- **Red**: #C84545 (debuffs, errors)
- **Light Gray**: #E8E6E1 (backgrounds, disabled)
- **Dark Gray**: #3A3A3A (text, borders)

Asset file naming: `button_normal.png`, `panel_9slice.png`, `icon_consumable.png`
## Example Prompt
“I want a clean sci-fi theme with neon accents. I have some 9-slice panel textures but no button textures yet.”

## Example Output
- A theme structure with color tokens and typography.
- A list of required button textures and recommended sizes.
- A suggested 9-slice layout for buttons.
- A theme.tres snippet showing how to apply the assets.