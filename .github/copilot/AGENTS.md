---
title: DiceRogue Copilot Agents Registry
description: Index of all specialized agents and skills for Godot development in DiceRogue
lastUpdated: "2026-03-06"
---

# DiceRogue Copilot Agents & Skills Registry

This file provides a complete index of all specialized agents and skills available for the DiceRogue project. Each agent is designed for a specific domain of Godot 4.4.1 development.

## Quick Navigation

- [Agents Summary](#agents-summary)
- [Godot Scene Architecture Agent](#godot-scene-architecture-agent)
- [Godot UI/UX Agent](#godotui-ux-agent)
- [Godot Game Systems Agent](#godot-game-systems-agent)
- [Godot Data & Resources Agent](#godot-data--resources-agent)
- [Godot Testing & Bot Agent](#godot-testing--bot-agent)
- [Godot Code Generation Agent](#godot-code-generation-agent)
- [Godot Debugging & Analysis Agent](#godot-debugging--analysis-agent)
- [How to Invoke Agents](#how-to-invoke-agents)
- [Integration with Project](#integration-with-project)

---

## Agents Summary

| Agent | Purpose | Skills Count | File Patterns |
|-------|---------|--------------|---------------|
| **Godot Scene Architecture** | Clean, scalable scene design and composition | 5 | `**/*.gd`, `**/*.tscn` |
| **Godot UI/UX** | UI/UX design, layouts, themes, pixel-art scaling | 2 | `**/UI/**/*.gd`, `**/UI/**/*.tscn` |
| **Godot Game Systems** | 170+ game items, scoring, dice mechanics, challenges | 4 | `Scripts/PowerUps/*.gd`, `Scripts/Core/*.gd` |
| **Godot Data & Resources** | Resource creation, difficulty/unlock, preload registries | 3 | `Resources/Data/**/*.gd`, `Resources/Data/**/*.tres` |
| **Godot Testing & Bot** | Bot strategies, test scenes, automated validation | 3 | `Scripts/Bot/*.gd`, `Tests/**/*.gd`, `Tests/**/*.tscn` |
| **Godot Code Generation** | Item scaffolding, dependency wiring, bulk refactoring | 2 | `Scripts/PowerUps/*.gd`, `Scripts/Managers/*.gd` |
| **Godot Debugging & Analysis** | Circular deps, state debugging, architecture analysis | 2 | `Scripts/Game/*.gd`, `Scripts/Managers/*.gd` |

---

## Godot Scene Architecture Agent

**Location**: `.github/copilot/agents/godot-scene-architecture/`

**Description**: Specialist in designing clean, scalable, and reusable scene architectures for Godot 4.4.1. Focuses on composition, modularity, maintainability, and avoiding architectural anti-patterns.

**Primary Use Cases**:
- Designing reusable scene hierarchies
- Refactoring monolithic scenes
- Deciding between inheritance vs composition
- Autoload design and initialization
- Plugin architecture for editor tools
- Data-driven asset design

**Applies To**: `**/*.gd`, `**/*.tscn` (general Godot code)

### Linked Skills

#### 1. **Component Architecture** · `component-architecture.md`
- **Purpose**: Design reusable, composition-based components
- **When to use**: Behavior needs to be reused across scenes, unsure about inheritance vs composition
- **Activation keywords**: `component`, `reusable`, `composition`, `modular`
- **File patterns**: `Scripts/**/*.gd`, `Scenes/**/*.tscn`

#### 2. **Autoload & Global Systems** · `autoload-systems.md`
- **Purpose**: Design clean, maintainable global services and singletons
- **When to use**: Designing audio managers, save systems, event buses, configuration managers
- **Activation keywords**: `autoload`, `global`, `singleton`, `service`, `manager`
- **File patterns**: `Scripts/Game/*.gd`, `Scripts/Managers/*.gd`
- **Key Projects**: GameController, PlayerEconomy, ChoresManager, ChannelManager

#### 3. **Plugin Architecture** · `plugin-architecture.md`
- **Purpose**: Create Godot Editor plugins, custom inspectors, and workflow automation
- **When to use**: Building editor plugins, custom inspectors, automating tasks
- **Activation keywords**: `plugin`, `editor`, `tool`, `inspector`, `gizmo`, `addon`
- **File patterns**: `addons/**/*.gd`, `Scripts/Editor/*.gd`

#### 4. **Resource-Driven Data** · `resource-driven-data.md`
- **Purpose**: Design data pipelines using Godot Resources, move config out of code
- **When to use**: Externalizing game data, designing custom Resource classes, data serialization
- **Activation keywords**: `resource`, `data`, `configuration`, `tres`, `serialization`
- **File patterns**: `Resources/Data/*.tres`, `Scripts/Core/*.gd`, `Scripts/Game/*.gd`
- **Key Resources**: Challenge, Debuff, PowerUp, Consumable, Dice configs, Themes

#### 5. **Scene Decomposition** · `scene-decomposition.md`
- **Purpose**: Analyze and break down complex scenes into modular components
- **When to use**: Refactoring large scenes, identifying unnecessary nesting, creating reusable sub-scenes
- **Activation keywords**: `decompose`, `refactor`, `hierarchy`, `nesting`, `modular`, `reuse`
- **File patterns**: `Scenes/**/*.tscn`
- **Project Structure**: Challenge/, Consumable/, Controller/, Debuff/, Dice/, Effects/, Managers/, Mods/, PowerUp/, ScoreCard/, Shop/, Tracker/, UI/

---

## Godot UI/UX Agent

**Location**: `.github/copilot/agents/godot-ui-ux/`

**Description**: Specialist in designing, evaluating, and improving UI/UX inside Godot 4.4.1. Focuses on Control nodes, themes, responsive layouts, and pixel-art UI constraints.

**Primary Use Cases**:
- Designing responsive UI layouts
- Debugging layout issues (stretching, clipping, misalignment)
- Creating reusable UI components (buttons, panels, menus)
- Theming and design system consistency
- Pixel-art UI scaling and crisp-edge techniques

**Applies To**: `**/UI/**/*.gd`, `**/UI/**/*.tscn` (UI-specific scenes)

### Linked Skills

#### 1. **Layout Review** · `layout-review.md`
- **Purpose**: Analyze Control hierarchies and optimize layout structure
- **When to use**: Layout breaking on certain resolutions, UI looks messy, need responsive design
- **Activation keywords**: `layout`, `ui`, `hierarchy`, `spacing`, `responsive`, `container`
- **File patterns**: `Scenes/UI/**/*.tscn`, `Scenes/UI/**/*.gd`
- **DiceRogue Standards**:
  - Base pixel scale: 1×
  - UI scale: 3× integer multiples for crisp rendering
  - Min resolution: 240p
  - Containers preferred over manual positioning
  - All controls styled via `Resources/UI/theme.tres`

#### 2. **Theme Generation** · `theme-generation.md`
- **Purpose**: Create advanced, production-ready UI themes with design tokens
- **When to use**: Building new themes, consistent styling across controls, pixel-art UI design
- **Activation keywords**: `theme`, `styling`, `colors`, `fonts`, `design_system`, `texture`
- **File patterns**: `Resources/UI/**/*.tres`, `Resources/UI/**/*.gd`
- **DiceRogue Color Palette**:
  - Primary Blue: #2C5AA0
  - Gold: #D4A840
  - Red: #C84545
  - Light Gray: #E8E6E1
  - Dark Gray: #3A3A3A

---

## Godot Game Systems Agent

**Location**: `.github/copilot/agents/godot-game-systems/`

**Description**: Specialist in DiceRogue's 170+ game items (PowerUps, Consumables, Challenges, Debuffs), scoring system, and game mechanics. Handles Yahtzee category logic, dice state machines, color effects, and challenge design.

**Primary Use Cases**:
- Design and debug PowerUps, Consumables, Challenges
- Understand Yahtzee scoring rules and Bonus Yahtzee mechanics
- Debug dice modification system and color effects
- Design difficulty-balanced challenges
- Analyze item synergies and combinations

**Applies To**: `Scripts/PowerUps/*.gd`, `Scripts/Consumable/*.gd`, `Scripts/Challenge/*.gd`, `Scripts/Core/score_evaluator.gd`, `Scripts/Dice/dice.gd`

### Linked Skills

1. **Game Item Scaffolding** - Generate boilerplate for new items (PowerUp, Consumable, Challenge, Debuff)
2. **Scoring Evaluation** - Debug Yahtzee categories, Bonus Yahtzee logic, wildcard combinations
3. **Dice Mod System** - Design dice modifications, state machine (ROLLABLE→ROLLED→LOCKED→DISABLED), color effects
4. **Challenge & Chore Design** - Design progression challenges, difficulty 1-10 balancing, goal tracking

---

## Godot Data & Resources Agent

**Location**: `.github/copilot/agents/godot-data-resources/`

**Description**: Specialist in DiceRogue's data architecture. Manages Resource creation, difficulty/unlock progression, and preload registry patterns. Handles 125+ PowerUps, 45+ Consumables, 20+ Challenges with dual-file pattern (GDScript class + .tres file).

**Primary Use Cases**:
- Create typed Resource classes (.gd) and resource files (.tres)
- Design difficulty ratings (1-10 scale) and unlock conditions
- Organize preload registries in managers (30-50 items per manager)
- Detect circular dependencies in registries
- Manage progression system mappings to Statistics

**Applies To**: `Resources/Data/**/*.gd`, `Resources/Data/**/*.tres`, `Scripts/Core/unlockable_item.gd`, `Scripts/Managers/*.gd`

### Linked Skills

1. **Resource Data Creation** - Create typed Resources with @export properties and .tres files
2. **Difficulty & Unlock System** - Design 1-10 difficulty ratings, stat-based/chapter-based/item-based unlocks
3. **Registry & Preload Pattern** - Organize bulk preloads, O(1) lookup, circular dependency detection

---

## Godot Testing & Bot Agent

**Location**: `.github/copilot/agents/godot-testing-bot/`

**Description**: Specialist in DiceRogue's 50+ test scenes and bot testing infrastructure. Designs bot strategies (aggressive, conservative, balanced, synergy-focused, adaptive), creates isolated test scenarios, and automates validation through baseline comparison.

**Primary Use Cases**:
- Create test scenes for components and systems
- Design bot decision-making heuristics
- Set up baseline performance metrics
- Detect regressions through automated comparison
- Create scenario tests (Bonus Yahtzee bug, color effects, etc.)

**Applies To**: `Scripts/Bot/*.gd`, `Tests/**/*.gd`, `Tests/**/*.tscn`

### Linked Skills

1. **Bot Testing & Strategy** - Design bot heuristics, decision-making, performance metrics
2. **Test Scene Creation** - Set up isolated test scenarios with print-based assertions
3. **Automated Validation** - Create performance baselines, detect regressions

---

## Godot Code Generation Agent

**Location**: `.github/copilot/agents/godot-code-generation/`

**Description**: Specialist in automating repetitive code tasks. Generates boilerplate for 170+ items in 2 minutes instead of 30, automates signal wiring between managers, and accelerates onboarding.

**Primary Use Cases**:
- Scaffold new PowerUps, Consumables, Challenges, Debuffs
- Bulk-generate items from design document
- Wire signals between GameController and managers
- Resolve NodePath exports and dependencies
- Accelerate team onboarding

**Applies To**: `Scripts/PowerUps/*.gd`, `Scripts/Managers/*.gd`, `Scripts/Consumable/*.gd`, `Scripts/Challenge/*.gd`

### Linked Skills

1. **Item System Scaffolding** - Generate boilerplate for new items (30 min → 2 min per item)
2. **Dependency Management & Wiring** - Auto-wire signals, verify circular deps, generate connection patterns

---

## Godot Debugging & Analysis Agent

**Location**: `.github/copilot/agents/godot-debugging-analysis/`

**Description**: Specialist in architecture analysis and debugging complex state logic. Detects circular dependencies, traces state machine transitions, and debugs timing/ordering issues in game systems.

**Primary Use Cases**:
- Detect circular dependencies before refactoring
- Trace dice state transitions (ROLLABLE→ROLLED→LOCKED→DISABLED)
- Debug signal timing issues
- Validate game state invariants
- Propose safe architectural refactorings

**Applies To**: `Scripts/Game/game_controller.gd`, `Scripts/Managers/*.gd`, `Scripts/Dice/dice.gd`, `Scripts/Core/*.gd`

### Linked Skills

1. **Circular Dependency Analysis** - Visualize dependency graphs, detect cycles, propose safe refactors
2. **State Logic & Debugging** - Trace state transitions, detect invalid transitions, debug signal timing

---

### Method 1: Mention Agent in Chat (Recommended)
```
@godot-scene-architecture How should I structure my inventory system?
```

### Method 2: Invoke Specific Skill
```
@godot-scene-architecture component-architecture: Make this behavior reusable
```

### Method 3: File Context Activation
Simply open or edit files matching the agent's file patterns, and the agent will activate automatically:
- Scene Architecture: Any `.gd` or `.tscn` file
- UI/UX: UI-specific files in `Scenes/UI/`

### Method 4: Use Activation Keywords
When discussing topics with keywords, the agent context may activate:
- "Help me decompose this scene" → Scene Architecture
- "How do I fix this layout?" → UI/UX

---

## Integration with Project

### Project Standards Reference
All agents incorporate DiceRogue coding standards from `.github/copilot-instructions.md`:
- **GDScript 4.4.1** target version
- **Tabs** for indentation (never spaces)
- **PascalCase** for classes/nodes, **snake_case** for methods
- **@export** and **@onready** prefixes required
- **No ternary operators** (use if/else instead)
- **class_name** everywhere except autoloads
- **Autoload scripts** should NOT have class_name
- **GameController** activation pattern for new features
- **Tab colors** for worksheet styling

### Project Structure
Agents understand DiceRogue's directory organization:
```
Scenes/
  Challenge/, Consumable/, Controller/, Debuff/, Dice/,
  Effects/, Managers/, Mods/, PowerUp/, ScoreCard/,
  Shop/, Tracker/, UI/
Scripts/
  Bot/, Challenge/, Consumable/, Core/, Debuff/, Dice/,
  Editor/, Effects/, Game/, Managers/, Mods/, PowerUps/,
  Round/, Shaders/, Shop/, UI/
Resources/
  Art/, Audio/, Data/, Font/, UI/
Tests/
  (Test scenes for verification)
```

### Test-Driven Workflow
Agents support DiceRogue's test methodology:
1. Create test scenes in `Tests/`
2. Run: `& "Godot_v4.4.1-stable.exe" --path "project" Tests/MyTest.tscn`
3. Verify game logic without full scene setup
4. Agents help design test-friendly architectures

---

## Troubleshooting

### Agent Not Activating
1. Use `@agent-name` explicitly to invoke
2. Check if you're in a matching file pattern
3. Include activation keywords in your question
4. Verify agent YAML frontmatter is present

### Skill Not Responding
1. Check activation keywords in skill file
2. Verify file pattern matches your current file
3. Explicitly mention the skill name in your prompt
4. Check for typos in agent name

### Claude Issues
- **Type errors**: Check `global_script_class_cache.cfg` for class_name registration
- **Sync issues**: Restart GDScript language server or Godot editor
- **Tool restrictions**: Verify agent has correct MCP tools specified

---

## Adding New Agents

To create a new agent:

1. **Create folder**: `.github/copilot/agents/agent-name/`
2. **Add `agent.md`**: Use template provided in agent files (include YAML frontmatter)
3. **Create `skills/` folder**: Place skill files here
4. **Add skills**: Each skill file needs YAML frontmatter and frontmatter
5. **Register in AGENTS.md**: Add entry to this file
6. **Test**: Verify agent activates with test prompts

---

## Resources

- [Godot 4.4.1 Docs](https://docs.godotengine.org/en/stable/index.html)
- [DiceRogue Copilot Instructions](./../copilot-instructions.md)
- [Project Readme](../../../README.md)

---

**Last Updated**: March 6, 2026  
**Maintained By**: DiceRogue Development Team  
**Format**: YAML frontmatter + Markdown
