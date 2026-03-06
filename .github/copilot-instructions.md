# Copilot Instructions
Dearest Copilot,

This project is game made with the Godot Engine, and it uses GitHub Copilot to assist with coding. Below are the instructions and guidelines for using Copilot effectively in this project.

We are making a pixel-art, rouge-lite dice roller game based off of the vanilla rules of Yahtzee.  Vanilla rules will be modified with Power Ups, and Consumables which will be locked behind a progression system.  The game will be played in a single player mode, with the player rolling dice to complete objectives and complete Challenges.

Testing will be done by creating simple test scenes that can be run in the editor.  These test scenes will be used to verify that the game logic is working as expected, and to ensure that the game is fun to play.

This game takes its inspiration from the following games: Balatro, Dicey Dungeons, and Yahtzee.  

## Coding Standards
- Always target Godot 4.4 GDScript syntax.
- Use tabs for indentation—never spaces.
- Prefix every script with its extends and class_name.
- Follow snake_case for methods/vars, PascalCase for classes/nodes.
- Wrap exported properties in @export var and onready lookups in @onready var.
- Never emit inline parsing hacks—break declarations into separate var + assignment.
- Provide detailed steps for setting up complex scenes or systems in the Godot editor, when applicable.
- Godot does not support ternary operator syntax with the question mark ?: use if/else statements instead.
- GDScript doesn't support multi-line boolean expressions with and/or operators split across lines.  Use single line if statements or nested if statements instead.
- Review the code base to ensure consitency with existing variables, methods, and class names, and to follow proper syntax to ensure we do not introduce any parsing errors.
- Remember to add activation code for new features in game_controller.gd.
- Do not add class_name to scripts that are only used as Autoloads.
- Document all new features in the README.md file, including setup instructions and usage examples.
- Godot installation folder: "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe".
- Update the README.md file to reflect any new features or changes made to the project structure.
- Autoload scripts should not have class_name declarations.
- When applicable be sure to use the godot-tools MCP server tools.

## Item Creation & Unlock System
**CRITICAL**: Every item (PowerUp, Consumable, Challenge, Debuff, Color Dice Mod, etc.) must register in the unlock system.

**Required Steps for Every New Item**:
1. **Create the item class** (.gd file extending proper base class)
2. **Create UnlockCondition Resource** (.tres file defining when item unlocks)
3. **Register in manager** (add to appropriate Manager's preload dictionary)
4. **Verify unlock integration** (test that item unlocks when condition is met)

**No item is complete without unlock system integration.** This ensures:
- Items are properly gated by difficulty
- Player progression is tracked correctly
- Shop and reward systems work with item availability
- Items appear in the correct game progression phases

## API Verification Guardrail
Before calling any method, signal, or property from another script, **always verify its exact signature** (name, argument count, argument types, return type) by reading the source file.  Common mistakes this prevents:
- Calling a method with the wrong number of arguments (e.g. `select_channel(channel)` when the method takes 0 args).
- Calling a method that doesn't exist (e.g. `PlayerEconomy.reset()` when the actual method is `reset_to_starting_money()`).
- Using the wrong property name or assuming a property exists without checking.

**class_name scope errors in VS Code:** When the GDScript Language Server reports "Could not find type X in current scope" for class_name types that are correctly declared, this is typically an LSP indexing issue—not a code error.  Godot's own `global_script_class_cache.cfg` (in `.godot/`) is the source of truth for registered class_names.  To resolve: restart the GDScript language server, or close and reopen the Godot editor to force a re-import.  Do not refactor code to work around IDE-only scope errors when the class_name declarations are valid.

## Documentation Standards
- Use Godot doc comments ## for any function header or documentation you want editors/IDE to surface.
- Keep the top line the function signature (as a doc title): e.g. ## _on_game_start() then ## blank line, then description lines.
- Put parameter descriptions only when the function's behavior depends on non-obvious args. Use _arg for unused signal params to avoid lint warnings.
- Use short “Notes” or “Side-effects” sections when the function interacts with other systems (UI, signals, economy, scene tree).
- Keep single responsibility per function; if a function needs long doc blocks (>8 lines), consider splitting it.
- For lifecycle functions (_ready, _process, _on_tree_exiting) state side-effects clearly (what they connect, what they start).
- For public API functions (used by other scripts), document the contract: inputs, outputs, error modes, and expected object types.
- Keep dev TODOs as # TODO: or ## TODO: lines so they’re searchable; prefer issue links for long tasks.


## Scene & Node Organization
- Single responsibility: each scene owns exactly one domain (UI, gameplay logic, effects).
- If at all possible, you should design scenes to have no dependencies.
- Reusable scenes should be self-contained and not rely on external nodes.
- Root Logic Node: keep your GameController at the scene root.
- Typed Paths: export NodePaths for everything you need from another scene, assign them in the inspector, and guard with get_node_or_null() in _ready().
- Avoid Global State when possible and use node trees and signals.

## Command Examples
- When suggesting search commands on Windows, do not use `grep`. 
Instead, use PowerShell's `Select-String` cmdlet. 
- Run a manual test: & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/DebuffTest.tscn
- NEVER run taskkill commands to close Godot.  This can corrupt the project files.