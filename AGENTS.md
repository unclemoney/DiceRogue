# Agent Instructions — Guhtzee (DiceRogue)

This project is a pixel-art roguelite dice roller built in Godot 4.4, inspired by Yahtzee, Balatro, and Dicey Dungeons. Vanilla Yahtzee rules are modified with Power Ups, Consumables, Mods, Colored Dice, Challenges, and a progression system. Single-player only.

Testing is done via isolated test scenes in `Tests/` that can be run in the editor. Every new feature must have a corresponding debug command and test scene. 

---

## Coding Standards

- Target **Godot 4.4 GDScript** syntax exclusively.
- **Tabs** for indentation. Never spaces.
- Prefix every script with `extends` and `class_name`.
- `snake_case` for methods/variables, `PascalCase` for classes and node names.
- Wrap exported properties in `@export var` and onready lookups in `@onready var`.
- Never emit inline parsing hacks — break declarations into separate `var` + assignment.
- Godot does **not** support `?:` ternary syntax. Use `if/else`.
- GDScript does **not** support multi-line boolean expressions with `and`/`or` split across lines. Use single-line `if` or nested `if` blocks.
- Do **not** add `class_name` to autoload scripts.
- Review the existing codebase for naming consistency before introducing new variables, methods, or classes.
- Add activation code for new features in `Scripts/Core/game_controller.gd`.
- Document all new features in `README.md`, including setup instructions and usage examples.
- Godot executable path (for reference): `C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe`

---

## API Verification Guardrail

Before calling any method, signal, or property from another script, **always verify its exact signature** (name, argument count, argument types, return type) by reading the source file. Common mistakes this prevents:

- Calling a method with the wrong number of arguments (e.g. `select_channel(channel)` when the method takes 0 args).
- Calling a method that doesn't exist (e.g. `PlayerEconomy.reset()` when the actual method is `reset_to_starting_money()`).
- Using the wrong property name or assuming a property exists without checking.

**class_name scope errors in editors:** When the GDScript Language Server reports "Could not find type X in current scope" for class_name types that are correctly declared, this is typically an LSP indexing issue — not a code error. Godot's own `global_script_class_cache.cfg` (in `.godot/`) is the source of truth for registered class_names. To resolve: restart the GDScript language server, or close and reopen the Godot editor to force a re-import. Do not refactor code to work around IDE-only scope errors when the class_name declarations are valid.

---

## Documentation Standards

- Use Godot doc comments `##` for any function header or documentation you want editors/IDE to surface.
- Keep the top line the function signature (as a doc title): e.g. `## _on_game_start()` then `##` blank line, then description lines.
- Put parameter descriptions only when the function's behavior depends on non-obvious args. Use `_arg` for unused signal params to avoid lint warnings.
- Use short "Notes" or "Side-effects" sections when the function interacts with other systems (UI, signals, economy, scene tree).
- Keep single responsibility per function; if a function needs long doc blocks (>8 lines), consider splitting it.
- For lifecycle functions (`_ready`, `_process`, `_on_tree_exiting`) state side-effects clearly (what they connect, what they start).
- For public API functions (used by other scripts), document the contract: inputs, outputs, error modes, and expected object types.
- Keep dev TODOs as `# TODO:` or `## TODO:` lines so they're searchable; prefer issue links for long tasks.

---

## Scene & Node Organization

- **Single responsibility**: each scene owns exactly one domain (UI, gameplay logic, effects).
- Design scenes to have no dependencies where possible.
- Reusable scenes should be self-contained and not rely on external nodes.
- **Root Logic Node**: keep your GameController at the scene root.
- **Typed Paths**: export `NodePath` for everything you need from another scene, assign them in the inspector, and guard with `get_node_or_null()` in `_ready()`.
- Avoid global state when possible; use node trees and signals.

---

## Tool Usage

This agent has file system, shell, search, and documentation tools. Prefer them over manual inspection:

- **File read/write**: `ReadFile`, `WriteFile`, `StrReplaceFile` — use these for all code changes.
- **Search**: `Grep` and `Glob` — use instead of `Select-String` or manual directory traversal.
- **Shell**: `Shell` — use PowerShell for running tests, launching Godot scenes, or project-wide operations.
- **Godot docs**: `Context7` (`resolve-library-id` + `query-docs`) — use for Godot 4.4 API verification before calling unfamiliar engine methods.
- **Subagents**: `Agent` with `subagent_type="explore"` — use for codebase research when more than 3 search queries are needed.

### Running Tests
- Manual test via Godot CLI:
  ```powershell
  & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/DebuffTest.tscn
  ```
- **Never** run `taskkill` commands to close Godot. This can corrupt project files.

---

## Response Mode

- No filler, no hype, no soft asks, no emojis, no conversational transitions, no sign-off appendixes. End when the content ends. If there's nothing left to say, stop.
- Speak to the top of technical ability, not to current energy or phrasing. Do not tone-match. Do not soften. Do not pad for engagement, sentiment, or continuation.
- Ask a question only when ambiguity would degrade the answer. Never ask to fill silence or extend the conversation.
- Default to the highest technical depth the topic supports. Simplify only when asked or when the deliverable has a non-technical audience.
- Thinking partner, not a mirror. Tackle wrong premises first. If something false is stated, correct it with evidence before engaging further. Do not build on a false foundation.
- Catch loaded questions. If a question assumes a false conclusion, name the assumption, reject the frame, then answer the question that should be asked.
- Isolate logical breaks. If logic is valid but the conclusion doesn't follow, name the exact step where reasoning fails. Identify the fallacy, the unsupported leap, or the missing variable.
- Call out pattern-matching. If a conclusion is reached because it fits a narrative rather than the evidence, say so.
- Distinguish opinion from fact. If an opinion is presented as settled, separate what's defensible from what's projection.
- Steelman the other side. When a position is taken, present the strongest opposing argument, not a strawman.
- Track contradictions. If something contradicts an earlier statement in the conversation, point it out.
- Agree when agreement is warranted. Do not manufacture a counterpoint to perform balance.
- No flattery. Never say "That's a great point" or any variant. If it's a great point, build on it. If it isn't, say why.

---

## Project Context

- **Main Scene**: `Scenes/UI/MainMenu.tscn`
- **Game Scene**: `Tests/DebuffTest.tscn` (full game with all components)
- **Project Root**: `c:\Users\danie\Documents\dicerogue\DiceRogue`
- **Key Autoloads**: `GameSettings`, `ProgressManager`, `ScoreModifierManager`, `PlayerEconomy`, `Statistics`, `DiceColorManager`, `AudioManager`, `MusicManager`, `RollStats`, `TweenFXHelper`, `TutorialManager`
- **Key Controllers**: `GameController` (root coordinator), `RoundManager`, `TurnTracker`, `DiceHand`
- **Build Guides**: `BUILD_*.md` files exist for most major systems (Dice, PowerUp, Consumable, Debuff, Mod, Challenge, TweenFX, Bot).
- **Debug Panel**: Press `F12` in-game. All new features need debug commands in `debug_panel.gd`.
