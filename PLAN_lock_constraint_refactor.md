# Plan: Lock Constraint Chore & Unlock Condition Refactor

## 1. Problem Statement

The current `LOCK_DICE` chore (`ChoreData.TaskType.LOCK_DICE`) is over-simplistic: it counts how many dice are locked at the moment a roll completes. This has no strategic depth — players either lock dice or they don't. It does not interact with scoring, turns, or the core Yahtzee loop in any meaningful way.

Additionally, a bug was discovered during exploration: `_count_locked_dice()` is called in `_handle_post_scoring_effects()` **after** `set_all_dice_disabled()` has run. `Dice.set_state(DISABLED)` explicitly sets `is_locked = false`, so the post-scoring check always returns `0`. Lock-dice chores currently only work because a separate `_check_lock_dice_chore()` runs after roll completion (before scoring), which is inconsistent with how all other chore types are checked.

## 2. Goal

Replace the single-moment `LOCK_DICE` system with a **turn-window constraint system** that tracks:
- **Cumulative score** achieved over a specified number of turns
- **Total lock actions** performed over those same turns

This enables rich objectives like:
- *"Score 50 points over the next 3 turns while locking no more than 1 die"* (Easy)
- *"Score 100 points over 6 turns without locking any dice"* (Mid)
- *"Score 150 points over 4 turns while locking at least 2 dice every turn"* (Hard — creative extension)

## 3. Architecture

### 3.1 New Core Tracker: `Scripts/Core/lock_constraint_tracker.gd`

A lightweight stateful tracker owned by `GameController`. It records per-turn aggregates and evaluates whether a fixed window satisfies the constraints.

```gdscript
class_name LockConstraintTracker

var _start_turn: int
var _turn_window: int
var _max_locked_dice: int      # -1 = no max limit
var _min_locked_dice: int      # -1 = no min limit (creative extension)
var _min_score: int
var _turn_records: Array[Dictionary] = []  # { "turn": int, "score": int, "lock_count": int }

func setup(start_turn: int, turn_window: int, min_score: int, max_locked: int = -1, min_locked: int = -1) -> void
func record_turn(turn: int, score: int, lock_count: int) -> void
func is_satisfied() -> bool
func is_expired(current_turn: int) -> bool
func get_progress_summary() -> String   # e.g. "Score: 34/50 | Locks: 1/1"
func reset() -> void
```

**Why a dedicated class?** Separation of concerns. `GameController` already exceeds 5,400 lines. Constraint window logic (sliding aggregates, expiration) deserves its own unit-testable class.

### 3.2 Turn History in GameController

`GameController` will maintain `_turn_history: Array[Dictionary]` (reset each round). After every scoring event it appends:
```gdscript
_turn_history.append({
    "turn": turn_tracker.current_turn,
    "score": _score,
    "lock_count": _lock_actions_this_turn
})
```

`_lock_actions_this_turn` is incremented in `_on_die_locked()` and reset in `_on_turn_started()`. This is more reliable than inspecting `die.is_locked` after dice have been disabled.

### 3.3 Two Check Modes

| Context | Window Type | Checked By |
|---------|-------------|------------|
**Chores** | Fixed: starts when the chore is assigned, spans exactly `turn_window` turns | `GameController` after each scoring event against the active tracker |
**Unlocks** | Sliding: any contiguous `turn_window` within the current round/game | `UnlockCondition.is_satisfied()` scanning `_turn_history` from `game_stats` |

## 4. File-by-File Changes

### 4.1 `Scripts/Core/lock_constraint_tracker.gd` — NEW
Create the tracker class described in 3.1.

### 4.2 `Scripts/Managers/ChoreData.gd`
- **Add** `TaskType.LOCK_CONSTRAINT = 7` (new enum entry)
- **Keep** `LOCK_DICE = 5` enum value to avoid breaking saved resources, but remove all library entries that use it
- **Add** `@export var additional_params: Dictionary = {}` to hold:
  - `"turn_window"`: int (default 3)
  - `"max_locked_dice"`: int (default 0)
  - `"min_locked_dice"`: int (default -1, optional creative extension)
- **Update** `check_completion()`:
  ```gdscript
  TaskType.LOCK_CONSTRAINT:
      var tracker = context.get("lock_constraint_tracker")
      return tracker != null and tracker.is_satisfied()
  ```
- **Update** doc comments for `context` parameter

### 4.3 `Scripts/Core/unlock_condition.gd`
- **Add** `ConditionType.LOCK_CONSTRAINT = 18`
- **Update** `is_satisfied()`:
  ```gdscript
  ConditionType.LOCK_CONSTRAINT:
      var turn_window = additional_params.get("turn_window", 3)
      var max_locked = additional_params.get("max_locked_dice", 0)
      var min_score = target_value
      var history = game_stats.get("turn_history", [])
      # Sliding window check
      for i in range(history.size() - turn_window + 1):
          var window = history.slice(i, i + turn_window)
          var total_score = 0
          var total_locked = 0
          for turn in window:
              total_score += turn.get("score", 0)
              total_locked += turn.get("lock_count", 0)
          if total_score >= min_score and total_locked <= max_locked:
              return true
      return false
  ```
- **Update** `get_formatted_description()`:
  ```gdscript
  ConditionType.LOCK_CONSTRAINT:
      var turn_window = additional_params.get("turn_window", 3)
      var max_locked = additional_params.get("max_locked_dice", 0)
      if max_locked == 0:
          return "Score %d+ points over %d turns without locking dice" % [target_value, turn_window]
      else:
          return "Score %d+ points over %d turns while locking no more than %d dice" % [target_value, turn_window, max_locked]
  ```

### 4.4 `Scripts/Core/game_controller.gd`
- **Add** vars:
  ```gdscript
  var _turn_history: Array[Dictionary] = []
  var _lock_actions_this_turn: int = 0
  var _active_lock_tracker: LockConstraintTracker = null
  ```
- **Update** `_on_die_locked()`:
  ```gdscript
  func _on_die_locked(die) -> void:
      _lock_actions_this_turn += 1
      Statistics.track_dice_lock()
  ```
- **Update** `_on_turn_started()`:
  ```gdscript
  func _on_turn_started() -> void:
      _lock_actions_this_turn = 0
      dice_hand.set_all_dice_rollable()
  ```
- **Update** `_handle_post_scoring_effects()` (after score assignment, before disabling dice — or append to history immediately after scoring):
  ```gdscript
  # Record turn data BEFORE disabling dice
  _turn_history.append({
      "turn": turn_tracker.current_turn if turn_tracker else 0,
      "score": _score,
      "lock_count": _lock_actions_this_turn
  })

  # If an active lock-constraint chore is in progress, feed the tracker
  if _active_lock_tracker:
      _active_lock_tracker.record_turn(turn_tracker.current_turn, _score, _lock_actions_this_turn)
      if _active_lock_tracker.is_satisfied():
          # Complete the chore via the normal context path
          var context = { ... , "lock_constraint_tracker": _active_lock_tracker }
          chores_manager.check_task_completion(context)
      elif _active_lock_tracker.is_expired(turn_tracker.current_turn):
          # Optional: fail/rotate the chore since the window closed unsatisfied
          chores_manager.rotate_task()  # or mark failed
          _active_lock_tracker = null
  ```
- **Update** `_start_new_round()` or `_on_round_started()`: reset `_turn_history.clear()`
- **Update** `_check_lock_dice_chore()`: deprecate or remove (no longer needed)
- **Connect** to `ChoresManager.task_selected`: when the new task is `LOCK_CONSTRAINT`, instantiate and setup `_active_lock_tracker`

### 4.5 `Scripts/Managers/chores_manager.gd`
- Ensure `task_selected` signal fires with the selected `ChoreData` so `GameController` can initialize the tracker
- `rotate_task()` or `fail_current_task()` may need a new signal so `GameController` knows to clear `_active_lock_tracker`

### 4.6 `Scripts/Managers/chore_tasks_library.gd`
Remove these obsolete tasks:
- `lock_three_dice`
- `lock_four_dice`
- `lock_all_dice`

Add new `LOCK_CONSTRAINT` tasks (using `additional_params`):

| ID | Name | Description | Difficulty | Reward | turn_window | max_locked_dice | min_score |
|---|---|---|---:|---|---|---|---:|
| `soft_touch` | Soft Touch | Score 50 points over 3 turns locking no more than 1 die | EASY | $5 | 3 | 1 | 50 |
| `steady_hand` | Steady Hand | Score 75 points over 3 turns without locking any dice | EASY | $10 | 3 | 0 | 75 |
| `controlled_risk` | Controlled Risk | Score 100 points over 4 turns locking no more than 2 dice | EASY | $15 | 4 | 2 | 100 |
| `iron_discipline` | Iron Discipline | Score 150 points over 5 turns locking no more than 1 die | HARD | $35 | 5 | 1 | 150 |
| `free_agent` | Free Agent | Score 200 points over 6 turns without locking any dice | HARD | $65 | 6 | 0 | 200 |
| `lockdown_artist` | Lockdown Artist | Score 120 points over 3 turns locking at least 2 dice per turn | HARD | $50 | 3 | -1 | 120 |

*Note: `lockdown_artist` uses the creative `min_locked_dice` extension.*

### 4.7 `Scripts/Managers/progress_manager.gd`
- Populate `current_game_stats["turn_history"]` from `GameController` before unlock checks
- Add/update unlock conditions for items thematically tied to dice-locking strategy

**Proposed unlock condition additions/changes:**

| Item ID | Type | Proposed New Condition | Old Condition |
|---|---|---|---|
| `lock_and_load` | PowerUp | `LOCK_CONSTRAINT` / target 75 / window 3 / max_locked 2 | `CHORE_COMPLETIONS` / 2 |
| `high_roller` | Mod | `LOCK_CONSTRAINT` / target 100 / window 4 / max_locked 0 | `SCORE_POINTS` / 350 |

*Question for user: which specific items should migrate to `LOCK_CONSTRAINT` unlocks?*

### 4.8 `Docs/unlock_conditions.md`
- Correct all stale entries (e.g., `lock_and_load` currently documented as `EARN_MONEY` 50 but is actually `CHORE_COMPLETIONS` 2)
- Add new `LOCK_CONSTRAINT` entries
- Remove references to obsolete `LOCK_DICE` chore logic

### 4.9 Challenge Scripts — Bug Fixes (discovered during audit)
- `Scripts/Challenge/pts_150_roll_score_minus_one.gd`: fix misleading log `"Lock dice debuff enabled"` → `"Roll score minus one debuff enabled"`
- `Scripts/Challenge/pts_200_disable_two_debuff.gd`: fix misleading log `"Lock dice debuff enabled"` → `"Disabled twos debuff enabled"`
- `Scripts/Challenge/pts300_no_debuff_resource.tres`: remove stale `debuff_ids = ["lock_dice"]` since the script no longer applies it

### 4.10 `Scripts/UI/debug_panel.gd`
Add debug commands:
- `lock_constraint_force_complete` — immediately satisfies the active tracker
- `lock_constraint_advance_turns N` — simulates N scoring turns with configurable score/lock counts
- `lock_constraint_show_history` — prints `_turn_history` to console

## 5. Test Plan

### 5.1 New Test Scene: `Tests/LockConstraintChoreTest.tscn`
- Isolated scene with `GameController`, `DiceHand`, `ChoresManager`, `TurnTracker`
- UI panel showing:
  - Active chore name + description
  - Live tracker progress (`Score: X/Y | Locks: A/B`)
  - Turn history table
  - Buttons: "Simulate Score + Lock", "Simulate Score No Lock", "Advance Turn", "Force Satisfy"
- Validates that:
  - Tracker starts when a `LOCK_CONSTRAINT` chore is assigned
  - Tracker records score and lock counts per turn
  - Chore completes exactly when window constraints are met
  - Chore fails/rotates when window expires unsatisfied

### 5.2 Unit Tests (via test scene scripts)
- `test_lock_tracker_satisfied()` — feed known data, assert `is_satisfied()`
- `test_lock_tracker_expired()` — feed data that misses score target, assert `is_expired()` after window
- `test_sliding_window_unlock()` — populate `game_stats.turn_history`, assert `UnlockCondition.LOCK_CONSTRAINT` evaluates correctly

## 6. Open Questions for User

1. **Which items should get `LOCK_CONSTRAINT` unlock conditions?**
   None of the existing unlock conditions directly reference dice locking. Should we repurpose any thematically-linked items (e.g., `lock_and_load`, `high_roller`) to use the new condition type, or only add it for brand-new items?

2. **Lock count semantics:**
   The plan interprets "locking 1 dice" as **1 lock action total across the window** (incremented each time `_on_die_locked` fires). Should it instead mean "maximum dice in locked state at any moment" or "unique dice locked"?

3. **Unlock window semantics:**
   Should unlock conditions use a **sliding window** (any N consecutive turns in the round) or a **fixed window from round start**? Sliding is more natural for achievements; fixed is simpler to code.

4. **Should the old `LOCK_DICE` enum and checks be fully deleted or just deprecated?**
   Saved games with active `LOCK_DICE` chores would break if the enum value is reused. Keeping the enum value but removing library entries is safest.

## 7. Creative Extensions (Optional Post-MVP)

- **Minimum lock constraints**: "Score X over Y turns while locking *at least* Z dice each turn." Rewards aggressive locking strategies and synergizes with `lock_and_load` PowerUp.
- **Per-roll instead of per-turn**: "Across your next 5 rolls, lock no more than 2 dice and score 60 points." Changes Yahtzee pacing from turn-based to roll-based micro-challenges.
- **Streak constraints**: "3 consecutive turns with 0 locks and 20+ score each." Adds streak tension similar to existing score streaks.
- **Risk/reward chores**: "Score 100 points over 2 turns. You may lock up to 3 dice, but each lock reduces the target by 10." Dynamic target adjustment.

## 8. Execution Order (Suggested)

1. Create `lock_constraint_tracker.gd` and its test script
2. Update `ChoreData.gd` (new TaskType + additional_params)
3. Update `GameController.gd` (turn history + lock action counter + tracker wiring)
4. Update `ChoresManager.gd` (signal flow for tracker lifecycle)
5. Update `chore_tasks_library.gd` (replace old tasks with new ones)
6. Update `UnlockCondition.gd` (new ConditionType + sliding window logic)
7. Update `progress_manager.gd` (turn_history in game_stats + any item unlock changes)
8. Fix challenge script bugs (misleading logs + stale resource)
9. Update `unlock_conditions.md`
10. Add debug panel commands
11. Build `LockConstraintChoreTest.tscn`
12. Run tests and iterate
