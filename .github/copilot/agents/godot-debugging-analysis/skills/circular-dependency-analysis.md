---
skillName: Circular Dependency Analysis
agentId: godot-debugging-analysis
activationKeywords:
  - circular
  - circularity
  - dependency
  - cycle
  - refactor
  - decouple
  - coupling
filePatterns:
  - Scripts/Game/game_controller.gd
  - Scripts/Managers/*.gd
  - Scripts/Core/*.gd
examplePrompts:
  - Analyze dependencies in [system]
  - Find circular references in codebase
  - How to decouple [A] from [B]?
  - Propose refactor to break [circular pattern]
---

# Skill: Circular Dependency Analysis

## Purpose
Detect and visualize circular dependencies that create tight coupling and fragility. Provides dependency graphs, risk assessment, and safe refactoring strategies for breaking cycles.

## When to Use
- Architecture review before major refactor
- Debugging hard-to-trace bugs
- Preparing code for team review
- Optimizing for maintainability
- On-boarding new developer (explain architecture)
- Performance analysis (cycles indicate tight coupling)

## Inputs
- Root node/script to analyze
- Optional: Specific system to focus on
- Optional: Depth limit (trace N levels deep)

## Outputs
- Dependency graph (ASCII or Mermaid)
- Circular dependency paths identified
- Risk assessment (high/medium/low coupling)
- Refactoring recommendations
- Safe decoupling patterns

## Behavior
- Trace signal connections and method calls
- Build directed graph of dependencies
- Detect strongly connected components (cycles)
- Assess coupling impact (how many paths affected)
- Suggest architectural patterns to break cycles
- Verify refactoring safety

## Constraints
- Cannot statically analyze dynamic calls (runtime resolution)
- Preload analysis can be exhaustive in large projects
- Graph visualization limited to ~30 nodes (beyond that, focus on hotspots)
- Recommendations assume signal-driven architecture

## DiceRogue Known Circular Patterns

### Pattern 1: GameController Focal Point (Medium Risk)

**Current Structure**:
```
GameController (root)
  ├─ connects to: PowerUpManager, ScoringSystem, UIManager
  ├─ emits events: round_started, score_changed, turn_ended
  ├─ **receives events from**: PowerUpManager, ScoringSystem (?)
  └─ CYCLE RISK: If managers emit back to GameController
```

**Dependency Graph**:
```
GameController
├─→ (emits to) PowerUpManager
├─→ (emits to) ScoringSystem
├─→ (emits to) UIManager
│
├─← (receives from?) ScoringSystem.score_changed
│   └─ RISK: If ScoringSystem reads GameController.current_score
│
└─← (receives from?) PowerUpManager.state_changed
    └─ RISK: If PowerUpManager modifies GameController state directly
```

**Risk Analysis**:
- ⚠️ **Medium**: GameController is single point of failure
- If managers need to query back: creates upward dependency
- If managers modify GameController state directly: tight coupling
- Refactoring one manager requires understanding all connections

**Safe Pattern**:
```
GameController (orchestrator - emit only)
├─→ PowerUpManager (listens passively, emits own events)
├─→ ScoringSystem (listens passively, emits own events)
└─→ UIManager (listens passively)

Signal Flow: One-way (GameController → Managers → UI)
```

### Pattern 2: Bonus Yahtzee Split Logic (High Risk)

**Current Issue**:
- `ScoreEvaluator.gd`: Calculates base Yahtzee (50 pts)
- `Scorecard.gd`: Applies Bonus Yahtzee bonus (300 pts extra if not first)
- **Problem**: Logic split across 2 files, different update timing

**Dependency Cycle**:
```
ScoreEvaluator
├─ has: Yahtzee detection logic
├─ emits: yahtzee_detected
│
Scorecard
├─ listens: yahtzee_detected
├─ has: Bonus logic (300 pt bonus)
└─ **calls back to**: ScoreEvaluator? to verify first Yahtzee?
```

**Bug Scenario**:
1. First Yahtzee: ScoreEvaluator awards 50, Scorecard adds 300 (correct: 350)
2. Second Yahtzee: ScoreEvaluator awards 50, Scorecard checks "is first?" incorrectly
3. Result: Double-counting or missing bonus

**Risk Assessment**:
- 🔴 **High**: Logic split creates maintenance burden
- Changes in one file require understanding other file
- Timing bugs (which calculates first?) hard to trace
- Test coverage must test both files in coordination

**Safe Refactor**:
```
Consolidate into Single ScoringStrategy:
├─ YahtzeeScoringStrategy
│  ├─ Detect Yahtzee
│  ├─ Check if first
│  ├─ Calculate: 50 + (300 if first else 0)
│  └─ Return total
│
├─ Called once from ScoringSystem
└─ No split logic = no bugs
```

### Pattern 3: Preload Manager Coupling (Low-Medium Risk)

**Current Structure**:
```
PowerUpManager preloads all PowerUp classes
  └─ Creates hard dependency on every PowerUp script

If any PowerUp has syntax error:
  GameController fails to start (preload fails)
  → Cascading failure
```

**Dependency Chain**:
```
GameController
  └─ PowerUpManager
     └─ preload all 125+ PowerUps
        └─ If any PowerUp has error
           → Whole manager loads fail
           → GameController fails
```

**Risk**: Medium (builds can fail due to single item)
**Safe Pattern**: Lazy loading for non-essential items

## Refactoring Recommendations

### 1. Break GameController Coupling

**Current** (Tightly Coupled):
```gdscript
# Bad: PowerUpManager needs to know about GameController
func apply_powerup(powerup: PowerUp) -> void:
	game_controller.current_score += powerup.bonus  # Upward dependency!
	game_controller.active_powerups.append(powerup)
```

**Better** (Signal-Driven):
```gdscript
# Good: Emit signal, let others listen
func apply_powerup(powerup: PowerUp) -> void:
	powerup_activated.emit(powerup)
	# GameController listens and updates its own state

# In GameController:
power_up_manager.powerup_activated.connect(func(powerup):
	current_score += powerup.bonus
)
```

### 2. Consolidate Split Logic

**Current** (Split):
```gdscript
# ScoreEvaluator
func evaluate_yahtzee(dice) -> int:
	return 50  # Base Yahtzee

# Scorecard
func record_yahtzee() -> void:
	var base = score_evaluator.evaluate_yahtzee(dice)
	var bonus = 300 if is_first_yahtzee else 0
	total = base + bonus
```

**Better** (Unified):
```gdscript
class_name YahtzeeStrategy

func evaluate(dice, is_first_yahtzee: bool) -> int:
	if not is_yahtzee(dice):
		return 0
	
	var base = 50
	var bonus = 300 if is_first_yahtzee else 0
	return base + bonus  # Single responsibility

# Called once:
var score = YahtzeeStrategy.evaluate(dice, is_first)
```

### 3. Lazy Loading for Items

**Current** (Eager - all at startup):
```gdscript
const ALL_POWERUPS = {
	"power_up_1": preload("..."),
	"power_up_2": preload("..."),
	# 123 more...
}
```

**Better** (Lazy - when needed):
```gdscript
var powerup_cache: Dictionary = {}

func get_powerup(name: String) -> PowerUp:
	if not powerup_cache.has(name):
		powerup_cache[name] = load("res://Scripts/PowerUps/%s.gd" % name)
	return powerup_cache[name].new()
```

## Example Prompt
"Analyze circular dependencies in GameController and recommend a safe refactor to decouple PowerUpManager"

## Example Output

```
=== Circular Dependency Analysis ===

Root: GameController

DEPENDENCY GRAPH:
GameController (orchestrator)
├─→ [emit] PowerUpManager
│   └─← [listen] powerup_activated (OK - one-way)
├─→ [emit] ScoringSystem
│   └─← [listen] score_calculated (OK - one-way)
└─→ UIManager
    └─ (no back-connection) ✓

CIRCLES DETECTED: 0

COUPLING ASSESSMENT:
- GameController upward dependencies: 0 ✓ (good)
- Manager upward dependencies: 0 ✓ (good)
- Tight coupling risk: Low ✓
- Safe to refactor: Yes

RECOMMENDATIONS:
✓ Current architecture is safe
✓ No changes required
→ Consider lazy-loading for 125+ PowerUps to reduce startup time
```

REFACTOR EXAMPLE (if cycle found):
```
Before: A → B → C → A
After:  A → B → C  +  shared Signal Bus
```
