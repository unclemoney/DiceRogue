---
title: Agent Quick-Start Guide
description: Fast reference for activating and using DiceRogue Copilot agents
---

# DiceRogue Copilot Agents - Quick Start Guide

## TL;DR

**Seven specialized agents** for DiceRogue Godot development:

1. **@godot-scene-architecture** – Scene design, components, autoloads, plugins (5 skills)
2. **@godot-ui-ux** – UI layouts, themes, pixel-art scaling (2 skills)
3. **@godot-game-systems** – 170+ items, scoring, dice, challenges (4 skills)
4. **@godot-data-resources** – Resource creation, difficulty, preload registries (3 skills)
5. **@godot-testing-bot** – Bot strategies, test scenes, validation (3 skills)
6. **@godot-code-generation** – Item scaffolding, dependency wiring (2 skills)
7. **@godot-debugging-analysis** – Circular deps, state debugging (2 skills)

**How to use**:
```
@godot-scene-architecture
Help me design a reusable inventory system.
```

---

## Agent Cheat Sheet

### Godot Scene Architecture Agent
**Best for**: Scene structure, modularity, composition, architecture decisions
**5 Skills**: Component Architecture, Autoload & Global Systems, Plugin Architecture, Resource-Driven Data, Scene Decomposition

| When to Ask | Skill | Example |
|-------------|-------|---------|
| Make behavior reusable | Component Architecture | "How do I make this system reusable?" |
| Global services & managers | Autoload Systems | "Should this be autoload or component?" |
| Editor tools & plugins | Plugin Architecture | "Create an editor workflow plugin" |
| Move config out of code | Resource-Driven Data | "How do I externalize this data?" |
| Refactor large scenes | Scene Decomposition | "Break up this 50-node scene" |

---

### Godot UI/UX Agent
**Best for**: UI layouts, responsive design, themes, pixel-art scaling
**2 Skills**: Layout Review, Theme Generation

| When to Ask | Skill | Example |
|-------------|-------|---------|
| Layout broken/stretching | Layout Review | "Fix my responsive UI" |
| Consistent button/panel styles | Theme Generation | "Create theme for shop UI" |

---

### Godot Game Systems Agent
**Best for**: 170+ game items, scoring mechanics, dice logic
**4 Skills**: Game Item Scaffolding, Scoring Evaluation, Dice Mod System, Challenge & Chore Design

| When to Ask | Skill | Example |
|-------------|-------|---------|
| Create new PowerUp/Consumable | Game Item Scaffolding | "Generate scaffolding for [item]" |
| Debug Yahtzee/scoring | Scoring Evaluation | "Why is [category] scoring wrong?" |
| Dice models & effects | Dice Mod System | "Design dice modification for [effect]" |
| Game challenges & goals | Challenge Design | "Design difficulty-balanced challenge" |

---

### Godot Data & Resources Agent
**Best for**: Resource creation, difficulty progression, item registries
**3 Skills**: Resource Data Creation, Difficulty & Unlock System, Registry & Preload Pattern

| When to Ask | Skill | Example |
|-------------|-------|---------|
| Create Resource classes | Resource Data Creation | "Scaffold typed Resource for [item]" |
| Design progression system | Difficulty & Unlock | "Set up difficulty 1-10 progression" |
| Organize item preloads | Registry Pattern | "Organize 50 preload statements" |

---

### Godot Testing & Bot Agent
**Best for**: Bot strategies, test scene creation, automated validation
**3 Skills**: Bot Testing & Strategy, Test Scene Creation, Automated Validation

| When to Ask | Skill | Example |
|-------------|-------|---------|
| Design bot AI/heuristics | Bot Strategy | "Create [strategy] bot player" |
| Create test scenarios | Test Scene Creation | "Set up test for [system]" |
| Detect regressions | Automated Validation | "Create baseline & detect changes" |

---

### Godot Code Generation Agent
**Best for**: Item scaffolding, signal wiring, bulk refactoring
**2 Skills**: Item System Scaffolding, Dependency Management & Wiring

| When to Ask | Skill | Example |
|-------------|-------|---------|
| Generate 100+ items fast | Item Scaffolding | "Create 5 PowerUps from list" |
| Wire signals between systems | Dependency Wiring | "Connect GameController to managers" |

---

### Godot Debugging & Analysis Agent
**Best for**: Architecture analysis, circular dependencies, state debugging
**2 Skills**: Circular Dependency Analysis, State Logic & Debugging

| When to Ask | Skill | Example |
|-------------|-------|---------|
| Find circular dependencies | Circular Dep Analysis | "Analyze GameController coupling" |
| Debug state machines | State Logic Debugging | "Trace dice state transitions" |

---

## Quick Examples

### Example 1: Scene Architecture Decision
**Question**: "I need a Consumable system. Should it be a scene, component, or resource?"

**Invoke**: `@godot-scene-architecture`

**Agent Response** will include:
- Trade-offs of each approach
- DiceRogue pattern recommendation
- Code example
- Integration with game systems

### Example 2: Autoload Design
**Question**: "I'm building a ChoresManager. How should I structure it to avoid tight coupling?"

**Invoke**: `@godot-scene-architecture autoload-systems`

**Agent Response** will include:
- Signal-based communication pattern
- Public API definition
- Initialization order
- How to connect scenes without tight coupling

### Example 3: UI Layout Problem
**Question**: "Here's my panel hierarchy... [paste tree]. The VBoxContainers aren't spacing right."

**Invoke**: `@godot-ui-ux layout-review`

**Agent Response** will include:
- Container recommendations
- Anchor/size flag fixes
- Spacing rules
- Code snippet with corrected layout

### Example 4: Theme Consistency
**Question**: "I need to create consistent button styles. What's the proper theme structure?"

**Invoke**: `@godot-ui-ux theme-generation`

**Agent Response** will include:
- DiceRogue color palette
- 9-slice texture requirements
- Button state definitions (normal, hover, pressed, disabled)
- Theme.tres code snippet

---

## Activation Methods

### Method 1: Direct Invocation (Recommended)
Type agent name in chat:
```
@godot-scene-architecture
How do I make this component reusable?
```

### Method 2: Keyword Activation
Ask a question with activation keywords:
```
Should I use inheritance or composition for this behavior?
(Agent detects "composition" keyword → activates automatically)
```

### Method 3: File Context
Open a file and ask a question:
- Open `Scripts/Game/my_system.gd` → Scene Architecture activates
- Open `Scenes/UI/my_panel.tscn` → UI/UX activates

### Method 4: Skill-Specific
Invoke with specific skill:
```
@godot-scene-architecture resource-driven-data
How should I structure my item data as resources?
```

---

## Common Workflows

### Workflow: Build a New System

**Step 1: Architecture Decision**
```
@godot-scene-architecture
I'm building a [NEW SYSTEM]. What's the recommended architecture?
```
→ Get composition pattern, component breakdown

**Step 2: Understand Signals**
```
What signals should each component emit?
```
→ Get signal design pattern

**Step 3: Test Structure**
```
How should I test this architecture before integrating with GameController?
```
→ Get test-scene recommendations

**Step 4: Integrate**
```
How do I wire this into GameController?
```
→ Get integration pattern

---

### Workflow: Refactor Messy Scene

**Step 1: Analyze**
```
@godot-scene-architecture scene-decomposition
Here's my scene tree: [paste]. It's hard to maintain.
```
→ Get decomposition analysis

**Step 2: Plan**
```
Which parts should become separate scenes?
```
→ Get modular design

**Step 3: Implement**
```
Show me how to refactor the root script to coordinate these scenes.
```
→ Get coordinator pattern

**Step 4: Update Tests**
```
How do I update my test scene to verify this new structure?
```
→ Get test-verification steps

---

### Workflow: Debug UI Layout

**Step 1: Describe Issue**
```
@godot-ui-ux
My HUD is clipping on narrow screens. Here's the hierarchy:
[paste or describe]
```
→ Get issue diagnosis

**Step 2: Get Solution**
```
How should I fix the anchors and containers?
```
→ Get corrected layout

**Step 3: Apply & Verify**
```
Can you show me the corrected code?
```
→ Get implementation code

---

## Tips & Tricks

### ✅ Do This

- **Be specific**: "I have 5 dice that need to track health separately" vs "I need health"
- **Share context**: Paste scene trees, code snippets, or describe structure
- **Ask follow-ups**: "Why would I use signals here?" → deeper understanding
- **Request code**: "Show me a GDScript example" → concrete implementation
- **Test first**: Create a test scene and verify architecture before full integration
- **Reference DiceRogue patterns**: "Like PowerUp and Consumable do..." → agent gets context

### ❌ Don't Do This

- **Generic questions**: "How do I make scenes?" → too broad
- **Non-Godot frameworks**: "Can I use this with Unity?" → agents are Godot-specific
- **Ask for multiple unrelated things**: Keep questions focused
- **Ignore project standards**: Agent knows DiceRogue conventions; don't fight them
- **Assume assets exist**: Tell agent what textures/sounds you have available

### 🚀 Pro Tips

1. **Chain questions**: Start broad, then ask specifics
2. **Copy-paste code**: Show failing code, ask how to fix
3. **Reference project**: Mention Challenge, PowerUp, etc. → agent uses correct patterns
4. **Test first**: Ask "How would I test this component?" → better design
5. **Version control**: Commit after agent refactoring to see diff clearly

---

## When to Use Which Agent

| Situation | Agent | Skill |
|-----------|-------|-------|
| "Should this be reusable?" | Scene Arch | Component Arch |
| "My scene is too complex" | Scene Arch | Scene Decomposition |
| "How do I make this global?" | Scene Arch | Autoload Systems |
| "How do I store game data?" | Scene Arch | Resource-Driven Data |
| "I need an editor tool" | Scene Arch | Plugin Architecture |
| "My UI stretches weird" | UI/UX | Layout Review |
| "I need consistent styling" | UI/UX | Theme Generation |
| "Pixel-art scaling issues" | UI/UX | Theme Generation |
| "Buttons don't look right" | UI/UX | Theme Generation |

---

## Common Follow-Up Questions

After agent responds, good follow-ups include:

1. **"Why?"** - Understand the reasoning
2. **"Show me code"** - See implementation
3. **"How do I test this?"** - Verify it works
4. **"How does this integrate with [existing system]?"** - Cross-system impact
5. **"What's the trade-off?"** - Understand costs
6. **"Can you refactor [code] to follow this pattern?"** - Apply pattern

---

## Integration with DiceRogue

### Key Systems Agents Know About

- **GameController** – Main lifecycle manager, activation pattern for new features
- **PlayerEconomy** – Money, progression (reset method, properties)
- **ChoresManager** – Task tracking
- **ChannelManager** – Dice channel state
- **Challenge/Debuff/PowerUp/Consumable** – Core game systems (all Resource-based)
- **ScoreCard** – Scoring display and animation
- **TweenFX** – Animation addon (available for effects)

### Project Conventions Agents Follow

- Godot 4.4.1 (no older versions)
- GDScript (no C#)
- Tabs for indentation
- No ternary operators
- @export and @onready prefixes
- class_name on all scripts except autoloads
- Pixel-art at 1×, UI at 3× scale
- Signal-based communication preferred
- Test scenes in Tests/ directory

---

## Troubleshooting

### "Agent not responding"
**Solution**: Type agent name explicitly: `@godot-scene-architecture`

### "Agent gives generic answers"
**Solution**: Include more context. Instead of "How do I make a system?" say "I'm making a Health system used by player, enemies, and bosses. How should I design it?"

### "Response doesn't reference DiceRogue"
**Solution**: Mention "in DiceRogue" or reference existing systems (Challenge, PowerUp, etc.)

### "Code example has errors"
**Solution**: 
1. Copy the code
2. Ask: "There's an error here: [error message]. How do I fix it?"
3. Agent can see context and provide accurate fix

---

## Next Steps

1. **Try Example 1**: Ask agent about scene architecture
2. **Read AGENTS.md**: Full registry and details
3. **Check SETUP_VERIFICATION.md**: Verify agents are working
4. **Bookmark this guide**: Quick reference for prompts
5. **Give feedback**: Let team know what works/doesn't work

---

**Questions?** Check:
- [AGENTS.md](./AGENTS.md) – Full agent & skill documentation
- [copilot-instructions.md](./copilot-instructions.md) – Project standards
- [DiceRogue README](../../../README.md) – Project overview

**Last Updated**: March 6, 2026
