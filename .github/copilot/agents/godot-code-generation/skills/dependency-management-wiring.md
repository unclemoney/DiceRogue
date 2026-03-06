---
skillName: Dependency Management & Wiring
agentId: godot-code-generation
activationKeywords:
  - dependency
  - wiring
  - connect
  - wire_signals
  - reference
  - NodePath
  - resolve
filePatterns:
  - Scripts/Game/game_controller.gd
  - Scripts/Managers/*.gd
  - Scripts/Core/*.gd
examplePrompts:
  - Wire signals between [source] and [target]
  - Resolve NodePath for [component]
  - Check dependencies for circular refs
  - Set up manager communication for [systems]
---

# Skill: Dependency Management & Wiring

## Purpose
Automate node/signal wiring and dependency resolution. Prevents wiring mistakes, detects circular dependencies, and ensures consistent signal connection patterns across systems.

## When to Use
- Wiring signals between systems
- Adding new manager to GameController
- Setting up NodePath exports
- Checking for circular dependencies before deployment
- Bulk-updating connections after refactoring
- Documenting dependency graph

## Inputs
- Source node (emitter of events)
- Target node (receiver of events)
- Signal name to connect
- Callback method on target
- Optional: Verify circular dependency

## Outputs
- Signal connection code (ready to copy)
- Dependency graph (ASCII or visual)
- Circular dependency warnings
- Integration suggestions

## Behavior
- Generate signal wiring patterns
- Verify methods exist before suggesting wiring
- Detect circular dependency chains
- Support both direct connects and deferred connects
- Provide fallback patterns (get_node_or_null)
- Document signal flow for debugging

## Constraints
- Must verify method signatures before suggesting wire
- Cannot guarantee runtime types (use get_node_or_null)
- Circular dependencies must be reported, not silently accepted
- NodePath must be exported and configurable
- Wiring code must follow DiceRogue patterns

## DiceRogue Wiring Patterns

### Signal Connection Pattern

**Standard Wiring** (in _ready()):
```gdscript
@onready var scoring_system = get_node("ScoringSystem")
@onready var ui_manager = get_node("UIManager")

func _ready() -> void:
	# Connect game events
	scoring_system.score_calculated.connect(_on_score_calculated.bindv([]))
	scoring_system.yahtzee_achieved.connect(_on_yahtzee_achieved.bindv([]))
	
	# Connect UI updates
	game_controller.turn_changed.connect(_on_turn_changed.bindv([]))
```

**With Null Guard** (safer for optional components):
```gdscript
@onready var effects_manager = get_node_or_null("EffectsManager")

func _ready() -> void:
	if effects_manager:
		effects_manager.effect_played.connect(_on_effect_played.bindv([]))
```

**Deferred Connection** (for manager registration):
```gdscript
func register_manager(manager: Node) -> void:
	var signal_name = "something_happened"
	if manager.has_signal(signal_name):
		manager.get_signal(signal_name).connect(_on_manager_event.bindv([manager]))
```

### Manager Wiring Template

```gdscript
extends Node
class_name MyManager

signal something_changed(data: Dictionary)
signal error_occurred(message: String)

@onready var game_controller = get_parent()  # Assume GameController is parent
@onready var other_manager = get_node("../OtherManager")  # Sibling

func _ready() -> void:
	# Wait for GameController ready
	await get_tree().process_frame
	
	_setup_connections()

func _setup_connections() -> void:
	# Connect outbound signals (this manager → others)
	something_changed.connect(_on_my_change.bindv([]))
	
	# Connect inbound signals (others → this manager)
	if game_controller and game_controller.has_signal("round_started"):
		game_controller.round_started.connect(_on_round_started.bindv([]))
	
	if other_manager:
		other_manager.state_updated.connect(_on_other_state_updated.bindv([]))

## Called when something changes
## Side-effects: Propagates change to all subscribed systems
func _on_my_change() -> void:
	# Handle change
	pass

## Called when other manager's state updates
func _on_other_state_updated(new_state: Dictionary) -> void:
	# React to external change
	pass
```

### NodePath Pattern

For external references, always use @export NodePath:

```gdscript
extends Node
class_name UIPanel

@export var game_controller_path: NodePath
@export var score_display_path: NodePath

@onready var game_controller = get_node_or_null(game_controller_path)
@onready var score_display = get_node_or_null(score_display_path)

func _ready() -> void:
	if not game_controller:
		push_error("GameController not assigned in inspector")
		return
	
	if game_controller.has_signal("score_changed"):
		game_controller.score_changed.connect(_on_score_changed.bindv([]))
```

**Setup in Inspector**:
- Select UIPanel node
- Drag GameController to "Game Controller Path"
- Drag ScoreDisplay to "Score Display Path"

### Circular Dependency Detection

**Pattern to Avoid**:
```
GameController
  ↓ (emits, connects to)
PowerUpManager
  ↓ (emits, connects back to)
GameController  ← CIRCULAR!
```

**Safe Pattern**:
```
GameController
  ↓ (emits game events)
PowerUpManager (listens only, doesn't emit back)
  ↓ (emits internal events)
EffectsManager
  → (both listen to GameController)
```

**Detection Heuristic**:
- If A connects to B, AND B connects to A → Circular
- If A→B→C→A → Circular chain

## Example Prompt
"Generate wiring code to connect GameController's 'round_started' signal to all managers, with null safety"

## Example Output

```gdscript
# In GameController._ready():
func _setup_manager_connections() -> void:
	# Wire all managers to game events
	var managers = [
		power_up_manager,
		consumable_manager,
		debuff_manager,
		challenge_manager,
	]
	
	for manager in managers:
		if manager:
			if has_signal("round_started") and manager.has_method("on_round_started"):
				round_started.connect(manager.on_round_started.bindv([]))
		else:
			print("Warning: Manager not initialized")

# Dependency graph (OK - no circles):
GameController (root)
├─ PowerUpManager ✓
├─ ConsumableManager ✓
├─ DebuffManager ✓
├─ ChallengeManager ✓
└─ ScoringSystem ✓
   └─ (all listen-only, no back-connections)

Result: ✓ Safe to deploy - no circular dependencies detected
```
