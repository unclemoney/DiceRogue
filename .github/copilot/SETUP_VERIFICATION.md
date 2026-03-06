---
title: Agent Setup & Verification Guide
description: Steps to verify and troubleshoot agent and skill registration
---

# Agent Setup & Verification Checklist

Use this guide to verify that all agents and skills are properly configured and working with VS Code's Copilot extension.

## ✅ File Structure Verification

Check that all required files exist:

```
.github/copilot/
├── copilot-instructions.md          (main project instructions)
├── AGENTS.md                        (agent registry)
├── agents/
│   ├── godot-scene-architecture/
│   │   ├── agent.md                 (✓ enhanced with YAML)
│   │   └── skills/
│   │       ├── autoload-systems.md              (✓ updated)
│   │       ├── component-architecture.md       (✓ updated)
│   │       ├── plugin-architecture.md          (✓ updated)
│   │       ├── resource-driven-data.md         (✓ updated)
│   │       └── scene-decomposition.md          (✓ updated)
│   ├── godot-ui-ux/
│   │   ├── agent.md                 (✓ enhanced with YAML)
│   │   └── skills/
│   │       ├── layout-review.md                (✓ updated)
│   │       └── theme-generation.md            (✓ updated)
│   ├── godot-game-systems/          (NEW)
│   │   ├── agent.md                 (✓ new with full YAML)
│   │   └── skills/
│   │       ├── game-item-scaffolding.md         (✓ new)
│   │       ├── scoring-evaluation.md            (✓ new)
│   │       ├── dice-mod-system.md               (✓ new)
│   │       └── challenge-chore-design.md        (✓ new)
│   ├── godot-data-resources/        (NEW)
│   │   ├── agent.md                 (✓ new with full YAML)
│   │   └── skills/
│   │       ├── resource-data-creation.md        (✓ new)
│   │       ├── difficulty-unlock-system.md      (✓ new)
│   │       └── registry-preload-pattern.md      (✓ new)
│   ├── godot-testing-bot/           (NEW)
│   │   ├── agent.md                 (✓ new with full YAML)
│   │   └── skills/
│   │       ├── bot-testing-strategy.md          (✓ new)
│   │       ├── test-scene-creation.md           (✓ new)
│   │       └── automated-validation.md          (✓ new)
│   ├── godot-code-generation/       (NEW)
│   │   ├── agent.md                 (✓ new with full YAML)
│   │   └── skills/
│   │       ├── item-system-scaffolding.md       (✓ new)
│   │       └── dependency-management-wiring.md  (✓ new)
│   └── godot-debugging-analysis/    (NEW)
│       ├── agent.md                 (✓ new with full YAML)
│       └── skills/
│           ├── circular-dependency-analysis.md  (✓ new)
│           └── state-logic-debugging.md         (✓ new)
```

**Status**: ✓ All 7 agents with 19 skills (7 original + 12 new)

---

## ✅ YAML Frontmatter Verification

### Agents Should Have
```yaml
---
agentName: [name]
agentDescription: [description]
applyTo:
  - "**/*.gd"
  - patterns: [keywords]
tools:
  - name: [tool_name]
linkedSkills:
  - [skill_file]
projectStandards: [references]
---
```

**Status**: ✓ All 7 agents updated (both original + 5 new)
- godot-scene-architecture/agent.md
- godot-ui-ux/agent.md
- godot-game-systems/agent.md (NEW)
- godot-data-resources/agent.md (NEW)
- godot-testing-bot/agent.md (NEW)
- godot-code-generation/agent.md (NEW)
- godot-debugging-analysis/agent.md (NEW)

### Skills Should Have
```yaml
---
skillName: [name]
agentId: [parent_agent]
activationKeywords: [keywords]
filePatterns: [patterns]
examplePrompts: [examples]
---
```

**Status**: ✓ All 19 skills have YAML frontmatter (7 original + 12 new)

**Original Skills (7)**:
- autoload-systems.md
- component-architecture.md
- plugin-architecture.md
- resource-driven-data.md
- scene-decomposition.md
- layout-review.md
- theme-generation.md

**New Skills (12)**:
- game-item-scaffolding.md
- scoring-evaluation.md
- dice-mod-system.md
- challenge-chore-design.md
- resource-data-creation.md
- difficulty-unlock-system.md
- registry-preload-pattern.md
- bot-testing-strategy.md
- test-scene-creation.md
- automated-validation.md
- item-system-scaffolding.md
- dependency-management-wiring.md
- circular-dependency-analysis.md
- state-logic-debugging.md

---

## ✅ Content Requirements

### Each Agent Must Define

- [x] **Role**: Clear one-sentence purpose
- [x] **Core Responsibilities**: 3-5 main duties
- [x] **Strengths**: What it excels at
- [x] **Limitations**: What it avoids
- [x] **Interaction Style**: How it communicates
- [x] **Example Tasks**: Real use cases
- [x] **Project-Specific Context**: DiceRogue integration
- [x] **Tool Specifications**: Which MCP tools it uses
- [x] **Linked Skills**: Array of child skills

**Status**: ✓ Complete for both agents

### Each Skill Must Define

- [x] **Purpose**: Clear one-sentence goal
- [x] **When to Use**: Activation conditions
- [x] **Inputs**: What user provides
- [x] **Outputs**: What agent delivers
- [x] **Behavior**: How it approaches problems
- [x] **Constraints**: What it avoids
- [x] **Project Context**: DiceRogue-specific patterns
- [x] **Example Prompt**: Sample user query
- [x] **Example Output**: What to expect

**Status**: ✓ Complete for all 7 skills

---

## ✅ DiceRogue Integration

### Project Standards Referenced
- [x] Godot 4.4.1 target version
- [x] GDScript conventions (tabs, snake_case, PascalCase)
- [x] @export and @onready requirements
- [x] No ternary operators rule
- [x] class_name requirements (including autoload exceptions)
- [x] GameController activation pattern
- [x] Tab color styling

### Project Context Embedded
- [x] Game type: Pixel-art roguelike dice roller (Yahtzee-based)
- [x] Key systems: Challenge, Debuff, PowerUp, Consumable, Dice
- [x] Scene organization structure documented
- [x] Test methodology (Tests/ directory)
- [x] Color palette (Blue #2C5AA0, Gold #D4A840, Red #C84545, etc.)
- [x] UI scale rules (1× pixel-perfect, 3× UI scale)
- [x] File organization (Resources/, Scenes/, Scripts/, Tests/)

**Status**: ✓ Fully integrated

---

## ✅ Verification Steps

### Step 1: Verify Folder Structure
```powershell
# Test that all files exist
Test-Path ".github/copilot/AGENTS.md"                              # Should be True
Test-Path ".github/copilot/agents/godot-scene-architecture/agent.md"  # Should be True
Test-Path ".github/copilot/agents/godot-scene-architecture/skills/" -PathType Container  # Should be True
```

### Step 2: Verify YAML Frontmatter
```powershell
# Check that agent file has frontmatter
Select-String -Path ".github/copilot/agents/godot-scene-architecture/agent.md" -Pattern "^---$" | Select-Object -First 1
# Should show line with "---"

# Check skill file has frontmatter
Select-String -Path ".github/copilot/agents/godot-scene-architecture/skills/component-architecture.md" -Pattern "skillName:" 
# Should show "skillName: Component Architecture"
```

### Step 3: Test Agent Activation (in VS Code)
1. Open a `.gd` file in Scenes/ or Scripts/
2. In chat, type: `@godot-scene-architecture`
3. Verify agent appears in autocomplete
4. Ask a question: *"How should I structure a reusable component?"*
5. Agent should respond with architecture guidance

### Step 4: Test Skill Activation
1. Open a file matching skill pattern (e.g., Scenes/UI/MyPanel.tscn)
2. Ask: *"Review this UI layout for issues"*
3. Verify layout-review skill activates (UI/UX agent)
4. Look for references to DiceRogue UI standards in response

### Step 5: Verify Tool Access
Ask a prompt that requires file reading:
```
@godot-scene-architecture: Review Scripts/Game/game_controller.gd and suggest improvements
```
Agent should:
- Read the file successfully
- Provide analysis
- Reference DiceRogue patterns
- Suggest concrete changes

---

## ⚠️ Common Issues & Solutions

### Issue: Agent Not Appearing in Autocomplete
**Solution**:
1. Verify YAML frontmatter exists and is valid
2. Check agentName field is not empty
3. Restart VS Code
4. Clear VS Code cache: `rm -r ~/.vscode-server` (on server) or `rm -r ~/.config/Code` (Linux)

### Issue: Skills Not Activating
**Solution**:
1. Verify skill file has YAML frontmatter with `skillName:` and `agentId:`
2. Check `filePatterns:` matches current file
3. Add activation keywords to prompt
4. Verify parent agent has `linkedSkills:` array

### Issue: "Could not find type X in current scope"
**Solution**:
- This is a VS Code LSP indexing issue, not an actual problem
- GDScript class_name declarations are correct
- Restart GDScript language server: Cmd+Shift+P → Restart Language Servers
- Close and reopen Godot editor to force reimport

### Issue: Agent References Wrong Tools
**Solution**:
1. Check `tools:` section in agent YAML frontmatter
2. Verify tool names match available MCP tools
3. Common tools: `godot-tools`, `read_file`, `replace_string_in_file`
4. If using custom tools, ensure they're registered in workspace

---

## 📋 Maintenance Checklist

### Monthly Tasks
- [ ] Verify all agent/skill files still exist
- [ ] Check YAML frontmatter is valid in all files
- [ ] Confirm DiceRogue project standards in copilot-instructions.md haven't changed
- [ ] Test agents with recent project code for accuracy

### When Adding New Features
- [ ] Update relevant agent or create new agent
- [ ] Add/update skills to handle new domain
- [ ] Update AGENTS.md registry
- [ ] Add DiceRogue-specific examples to skill docs
- [ ] Test agent with sample project code

### When Project Changes
- [ ] Update project context in agent descriptions
- [ ] Revise skill examples if workflow changes
- [ ] Update file patterns if directory structure changes
- [ ] Verify tool specifications still match available tools

---

## 📚 Quick Reference

### Agent Invocation Syntax
```
@godot-scene-architecture              # Main agent
@godot-scene-architecture component-architecture  # Specific skill
```

### Keywords for Auto-Activation
```
Scene Architecture: component, architecture, autoload, composition, plugin, resource
UI/UX: layout, ui, theme, styling, pixel-art, responsive
```

### Tools Available to All Agents
```
read_file              - Read source files
replace_string_in_file - Edit files
grep_search            - Search files for patterns
semantic_search        - AI semantic codebase search
godot-tools            - Godot scene/script inspection
```

---

## ✨ Next Steps

1. **Verify Setup**: Run verification steps above
2. **Test Agents**: Ask a few test questions in VS Code
3. **Iterate**: Feedback on agents and skills will improve accuracy
4. **Document**: Add findings to project knowledge base
5. **Expand**: Create new agents for other project domains as needed

---

**Setup Status**: ✓ Complete  
**Last Verified**: March 6, 2026  
**Next Review**: April 6, 2026
