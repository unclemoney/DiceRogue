---
skillName: Test Scene Creation
agentId: godot-testing-bot
activationKeywords:
  - test
  - test_scene
  - unit_test
  - integration_test
  - create_test
  - test_setup
  - assertion
filePatterns:
  - Tests/**/*.gd
  - Tests/**/*.tscn
examplePrompts:
  - Create a test scene for [system]
  - Set up test wiring for [component]
  - How do I validate this behavior in a test?
  - Generate test scene for dice behavior
---

# Skill: Test Scene Creation

## Purpose
Create isolated test scenes for component verification, game mechanics validation, and system integration testing. Provides templates for test scene structure, assertion setup, and validation patterns.

## When to Use
- Creating first test for new system
- Setting up integration test for multiple systems
- Need reproducible test scenario
- Want isolated testing of one component
- Investigating bug through test reproduction
- Regression testing after refactor

## Inputs
- System/component to test
- Assertions/checks needed (pass/fail conditions)
- Setup requirements (initial state, game objects)
- Optional: Known good baseline output

## Outputs
- Complete test scene .tscn file
- Test script (.gd) with setup and assertions
- Documentation of test goal and expected behavior
- Running instructions
- Integration with BotTest infrastructure

## Behavior
- Create minimal, self-contained test scenes
- Implement clear setup/validation flow
- Use print-based assertions (DiceRogue convention)
- Enable manual verification of results
- Support both automated (BotTest) and manual runs
- Document test purpose and expected output

## Constraints
- Tests must be runnable standalone
- Cannot depend on external state
- Must use print-based assertions (not framework-dependent)
- No modifications to game state beyond test
- Tests must complete in reasonable time (~10 seconds)

## DiceRogue Test Scene Patterns

### Test Scene Structure
```
Test Scene
├── Control (Root)
│   ├── GameSetup.gd (script - setup logic)
│   ├── GameController (node - game state)
│   ├── TestOutputPanel (RichTextLabel - results display)
│   └── TestContent (VBoxContainer - test-specific nodes)
```

### Test Scene Script Pattern
```gdscript
extends Control

@onready var game_controller = get_node("GameController")
@onready var output = get_node("TestOutputPanel")

var test_results: Dictionary = {
    "passed": 0,
    "failed": 0,
}

func _ready() -> void:
    print("\n=== Test: [TestName] ===")
    setup_test()
    run_test()
    print_results()

func setup_test() -> void:
    # Initialize game state
    # Create test objects
    # Configure systems
    pass

func run_test() -> void:
    # Execute test logic
    # Make assertions
    pass

func assert_equal(actual, expected, message: String) -> void:
    if actual == expected:
        print("✓ PASS: %s" % message)
        test_results["passed"] += 1
    else:
        print("✗ FAIL: %s (got %s, expected %s)" % [message, actual, expected])
        test_results["failed"] += 1

func print_results() -> void:
    var total = test_results["passed"] + test_results["failed"]
    print("\nResults: %d/%d passed" % [test_results["passed"], total])
    if test_results["failed"] == 0:
        print("✓ ALL TESTS PASSED")
    else:
        print("✗ %d tests failed" % test_results["failed"])
```

### Test Categories

**1. Component Tests** (50+ existing):
- Test one system in isolation
- Example: BueDiceTest.tscn tests dice behavior only
- File: `Tests/[ComponentName]Test.tscn`

**2. Integration Tests** (5-10):
- Test multiple systems working together
- Example: BlueDiceIntegrationTest.tscn (dice + scoring + UI)
- File: `Tests/[Systems]IntegrationTest.tscn`

**3. Scenario Tests** (10+):
- Test specific game scenarios
- Example: BonusDoubleCountingTest.tscn (Bonus Yahtzee bug)
- File: `Tests/[Scenario]Test.tscn`

**4. Bot Strategy Tests** (BotTest.tscn):
- Run full game with bot player
- File: `Tests/BotTest.tscn`

### Assertion Patterns

**Simple Comparison**:
```gdscript
assert_equal(dice.value, 6, "Dice should show 6")
```

**Boolean Check**:
```gdscript
func assert_true(condition: bool, message: String) -> void:
    if condition:
        print("✓ PASS: %s" % message)
    else:
        print("✗ FAIL: %s" % message)

assert_true(dice.is_locked, "Die should be locked")
```

**Array Comparison**:
```gdscript
func assert_array_equal(actual: Array, expected: Array, message: String) -> void:
    if actual == expected:
        print("✓ PASS: %s" % message)
    else:
        print("✗ FAIL: %s" % message)
        print("  Expected: %s" % [expected])
        print("  Got:      %s" % [actual])

assert_array_equal(dice_values, [1, 1, 1, 1, 1], "All dice should be 1")
```

## Example Prompt
"Create a test scene that verifies dice color effects (Green money, Red additive, Purple multiplier)"

## Example Output
- Complete test scene hierarchy
- Test script with setup (arrange dice) → verification (check effects)
- Print-based assertions for each effect type
- Expected output documentation
- Instructions: "Run Tests/ColorEffectsTest.tscn and check console output"

Expected output example:
```
=== Test: Color Effects ===
✓ PASS: Green die adds 5 money (1 die = 5)
✓ PASS: Red die adds 5 additive (1 die = +5)
✓ PASS: Purple die multiplies by 1.1 (1 die = ×1.1)
✓ PASS: Same color bonus (50 pts for 5 green dice)
✓ PASS: Rainbow bonus (100 pts for all 5 colors)

Results: 5/5 passed
✓ ALL TESTS PASSED
```
