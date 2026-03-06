---
skillName: State Logic & Debugging
agentId: godot-debugging-analysis
activationKeywords:
  - state
  - debug
  - state_machine
  - trace
  - logic
  - step_through
  - breakpoint
filePatterns:
  - Scripts/Dice/dice.gd
  - Scripts/Core/*.gd
  - Scripts/Game/game_controller.gd
examplePrompts:
  - Debug why dice state is stuck in [state]
  - Trace state transitions for [system]
  - Why isn't [signal] firing?
  - Step through state machine
---

# Skill: State Logic & Debugging

## Purpose
Debug state machines and complex game logic through state tracing, timeline analysis, and structured debugging. Helps identify off-by-one errors, missed signals, and state transition bugs.

## When to Use
- State machine stuck in wrong state
- Signal not firing at expected time
- Scoring logic producing wrong results
- Reroll logic behaving unexpectedly
- Item interactions not triggering
- Timing issues (events firing out of order)

## Inputs
- System with state issue (dice, round, game)
- Expected behavior description
- Current buggy behavior
- Optional: state transition logs

## Outputs
- State transition timeline
- Signal fire timeline
- Logic error identification
- Reproduction steps
- Debugging suggestions

## Behavior
- Trace state machine transitions
- Log signals as they fire
- Identify timing/ordering issues
- Attach breakpoint suggestions
- Verify state invariants
- Suggest debug print locations

## Constraints
- Cannot modify live game during debug (unless using Godot debugger)
- Must use print-based logging (no framework dependencies)
- State machines must be clearly defined (extend StateMachine or equivalent)

## DiceRogue State Machines

### Dice State Machine

**State Enum** (in `dice.gd`):
```gdscript
enum DICE_STATE {
	ROLLABLE,     # Can be rerolled
	ROLLED,       # Just rolled, unlocked
	LOCKED,       # Player locked this die
	DISABLED,     # Cannot be used (Debuff effect)
}
```

**State Transitions**:
```
ROLLABLE
  ├─ (throw) → ROLLED
  └─ (disable) → DISABLED

ROLLED
  ├─ (lock) → LOCKED
  ├─ (unlock) → ROLLABLE
  ├─ (throw) → ROLLED
  └─ (disable) → DISABLED

LOCKED
  ├─ (unlock) → ROLLABLE
  ├─ (throw - ignored) → LOCKED [BUG!]
  └─ (disable) → DISABLED

DISABLED
  ├─ (enable) → ROLLABLE
  ├─ (throw - fails) → DISABLED
  └─ (lock - invalid) → DISABLED
```

**Known Issue - Throw While Locked**:
```
BUG: If player throws while die is locked:
  Expected: Do nothing, stay LOCKED
  Actual: ???

DEBUG TRACE:
1. Die state: LOCKED
2. Player clicks "Throw"
3. throw() called on locked die
4. Result: State changed to ROLLED (WRONG!)
   → Die should have stayed LOCKED

FIX: Check state before rolling
```

### Round State Machine

**Round Flow**:
```
START_ROUND
  ├─ (setup) → ROLLING
  ├─ signal: round_started

ROLLING
  ├─ (throw) → ROLLED
  ├─ (reroll check) → decision point

ROLLED
  ├─ (select category) → SELECTING
  ├─ (reroll available) → ROLLING

SELECTING
  ├─ (category chosen) → SCORING
  ├─ signal: category_selected

SCORING
  ├─ (score calculated) → SCORE_DISPLAY
  ├─ signal: score_calculated

SCORE_DISPLAY
  ├─ (animation done) → END_ROUND
  ├─ (shop offer) → SHOP

SHOP / END_ROUND
  ├─ signal: round_ended
  └─ → START_ROUND (next round)
```

## Debugging Patterns

### Pattern 1: State Trace Logging

**Add Debug Output**:
```gdscript
extends Node
class_name DiceDebugger

var previous_state: int = -1
var state_changes: Array = []

func _on_state_changed(old_state: int, new_state: int) -> void:
	var old_name = DICE_STATE.keys()[old_state]
	var new_name = DICE_STATE.keys()[new_state]
	
	print("[%.2f] Dice state: %s → %s" % [Time.get_ticks_msec() / 1000.0, old_name, new_name])
	
	state_changes.append({
		"timestamp": Time.get_ticks_msec(),
		"from": old_name,
		"to": new_name,
	})
	
	# Detect invalid transitions
	if not is_valid_transition(old_state, new_state):
		print("  ⚠️ INVALID: Cannot go from %s to %s" % [old_name, new_name])

func is_valid_transition(from: int, to: int) -> bool:
	var valid_transitions = {
		ROLLED: [LOCKED, ROLLABLE, DISABLED],
		LOCKED: [ROLLABLE, DISABLED],
		# ... etc
	}
	return valid_transitions[from].has(to)
```

**Usage**:
```gdscript
# In dice.gd
func set_state(new_state: int) -> void:
	if new_state == current_state:
		return
	
	debugger._on_state_changed(current_state, new_state)
	current_state = new_state
	state_changed.emit(current_state)
```

**Output**:
```
[0.50] Dice state: ROLLABLE → ROLLED
[0.55] Dice state: ROLLED → LOCKED
[0.60] Dice state: LOCKED → ROLLABLE
[0.60] ⚠️ INVALID: Cannot go from LOCKED to ROLLING
```

### Pattern 2: Signal Fire Timeline

**Trace Signal Emissions**:
```gdscript
extends Node
class_name SignalTracer

var signal_log: Array = []

func trace_signal(emitter: Object, signal_name: String, label: String = "") -> void:
	if not emitter.has_signal(signal_name):
		print("Signal not found: %s.%s" % [emitter.name, signal_name])
		return
	
	var signal_obj = emitter.get_signal(signal_name)
	signal_obj.connect(func():
		print("[%.3f] Signal: %s%s" % [
			Time.get_ticks_msec() / 1000.0,
			signal_name,
			" (%s)" % label if label else ""
		])
		signal_log.append({
			"timestamp": Time.get_ticks_msec(),
			"signal": signal_name,
			"label": label
		})
	)

func print_timeline() -> void:
	print("\n=== Signal Timeline ===")
	for entry in signal_log:
		print("%s: %s" % [entry["timestamp"], entry["signal"]])
```

**Usage**:
```gdscript
func _ready() -> void:
	tracer.trace_signal(game, "round_started", "Game")
	tracer.trace_signal(scoring_system, "score_calculated", "Scoring")
	tracer.trace_signal(ui, "display_updated", "UI")
```

### Pattern 3: Invariant Checking

**Verify State Constraints**:
```gdscript
func validate_game_state() -> Dictionary:
	var errors: Array = []
	
	# Check: Total dice must equal 5
	if dice_list.size() != 5:
		errors.append("Expected 5 dice, got %d" % dice_list.size())
	
	# Check: No more than 1 die in DISABLED state
	var disabled_count = dice_list.filter(func(d): return d.state == DISABLED).size()
	if disabled_count > 1:
		errors.append("Too many disabled dice: %d" % disabled_count)
	
	# Check: Score cannot be negative
	if current_score < 0:
		errors.append("Score is negative: %d" % current_score)
	
	# Check: Used categories unique
	var used_cats = used_categories
	if used_cats.size() != used_cats.get_unique_indices().size():
		errors.append("Duplicate categories used")
	
	return {
		"valid": errors.is_empty(),
		"errors": errors
	}
```

**Called on suspicious state**:
```gdscript
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_debug"):
		var validation = validate_game_state()
		if not validation["valid"]:
			print("⚠️ INVALID STATE:")
			for error in validation["errors"]:
				print("  - %s" % error)
```

## Debugging Examples

### Bug: Dice Won't Roll Second Time

**Symptoms**:
- First throw works (ROLLABLE → ROLLED)
- Player locks die (LOCKED)
- Player clicks throw again
- Die doesn't reroll

**Investigation**:
```gdscript
# Enable state tracing
[0.50] Dice state: ROLLABLE → ROLLED
[0.60] Die clicked (locked)
[0.61] Dice state: ROLLED → LOCKED
[0.70] Throw button clicked
[0.71] ⚠️ Throw called on LOCKED die - check logic

# Check throw() method
func throw() -> void:
	if current_state != ROLLABLE:  # ← BUG!
		print("Cannot throw, state=%s" % current_state)
		return
```

**Fix**:
```gdscript
# Check if LOCKED, unlock first
func throw() -> void:
	if current_state == LOCKED:
		set_state(ROLLABLE)
	
	if current_state != ROLLABLE:
		return
	
	# Roll the die
	set_state(ROLLED)
```

### Bug: Signal Never Fires

**Symptoms**:
- UI never updates when scoring completes
- print("Score calculated") never prints

**Investigation**:
```gdscript
# Trace signal
tracer.trace_signal(scoring_system, "score_calculated")

# Result: Nothing printed
→ Signal never emitted

# Check ScoringSystem code
func calculate_score() -> void:
	var result = get_score()
	# Missing: score_calculated.emit(result)  ← BUG!
	return result
```

**Fix**:
```gdscript
func calculate_score() -> int:
	var result = get_score()
	score_calculated.emit(result)  # ← Add this
	return result
```

## Example Prompt
"Debug why dice state changes from LOCKED directly to ROLLED instead of going through ROLLABLE"

## Example Output

**Timeline of State Transitions**:
```
[Expected Sequence]
1. Initial: ROLLABLE
2. Player throws: ROLLABLE → ROLLED
3. Player locks: ROLLED → LOCKED
4. Player clicks reroll button: LOCKED → ROLLABLE (unlock first)
5. Player throws again: ROLLABLE → ROLLED

[Actual Sequence - BUG]
1. Initial: ROLLABLE
2. Player throws: ROLLABLE → ROLLED
3. Player locks: ROLLED → LOCKED
4. Player clicks reroll button: LOCKED → ROLLED (direct!)
   ⚠️ INVALID TRANSITION

[Root Cause]
In throw() method on locked die:
- Direct state change to ROLLED without checking if locked
- Should transition through ROLLABLE first

[Fix]
Add unlock check in throw():
if current_state == LOCKED:
    set_state(ROLLABLE)
set_state(ROLLED)
```
