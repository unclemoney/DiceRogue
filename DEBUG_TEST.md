# Debug Test Documentation

This document outlines best practices for creating effective debug tests in the DiceRogue project, based on successful patterns from tests like `bonus_separation_test.gd`, `BonusDoubleCountingTest`, and other debugging scenarios.

## Test Structure Standards

### File Organization
- **Location**: Place all test files in the `Tests/` directory
- **Naming Convention**: `[feature]_test.gd` for scripts, `[Feature]Test.tscn` for scenes
- **Scene Structure**: Create simple scenes with minimal UI for result display

### Test Scene Structure
```gdscript
extends Control

# Test components
@onready var scorecard = $Scorecard  # If testing scorecard functionality
@onready var results_label = $VBoxContainer/ResultsLabel

func _ready():
	print("\n=== [TEST NAME] ===")
	await get_tree().process_frame  # Wait for scene readiness
	run_test_sequence()
```

### Core Test Patterns

#### 1. State Setup and Validation
```gdscript
func test_feature():
	print("\n--- Test: [Specific Feature] ---")
	
	# Step 1: Record initial state
	var initial_value = target_system.get_value()
	print("Initial state:", initial_value)
	
	# Step 2: Perform test action
	target_system.perform_action()
	
	# Step 3: Record final state
	var final_value = target_system.get_value()
	print("Final state:", final_value)
	
	# Step 4: Validate results
	validate_results(initial_value, final_value)
```

#### 2. Multiple Assertion Validation
```gdscript
func validate_results(before, after):
	var condition_1 = (after.property_a == expected_value_a)
	var condition_2 = (after.property_b == expected_value_b)
	var condition_3 = (calculated_difference == expected_difference)
	
	print("\n=== RESULTS ===")
	print("Condition 1 (property A):", condition_1)
	print("Condition 2 (property B):", condition_2) 
	print("Condition 3 (difference):", condition_3)
	
	if condition_1 and condition_2 and condition_3:
		print("✓ PASS: All conditions met")
		update_results("PASS: Test completed successfully")
	else:
		print("✗ FAIL: One or more conditions failed")
		update_results("FAIL: Test failed - see details above")
```

## Test Categories and Patterns

### Scoring System Tests
**Purpose**: Validate score calculation, bonus handling, and category assignment
**Key Elements**:
- Test both base scoring and modified scoring scenarios
- Verify separation of base scores from bonus points
- Test edge cases (first Yahtzee, bonus Yahtzees, invalid combinations)

**Example Pattern**:
```gdscript
func test_scoring_scenario():
	# Setup known dice combination
	var test_dice: Array[int] = [5, 5, 5, 5, 5]
	
	# Calculate expected vs actual
	var expected_score = 25  # Base score for 5s
	var actual_score = scorecard.evaluate_category("fives", test_dice)
	
	# Validate and report
	assert_equal(expected_score, actual_score, "Fives category score")
```

### PowerUp Integration Tests
**Purpose**: Verify PowerUp activation, effects, and cleanup
**Key Elements**:
- Test PowerUp activation conditions
- Verify effect application
- Confirm proper cleanup after use

### Signal and Event Tests
**Purpose**: Validate signal emission and handler execution
**Key Elements**:
- Connect to signals before testing
- Track signal emissions and parameters
- Verify handler side effects

### UI Integration Tests
**Purpose**: Validate UI updates and user interaction flows
**Key Elements**:
- Test UI state changes
- Verify display formatting
- Check responsive behavior

## Debugging Output Standards

### Print Statement Guidelines
1. **Test Boundaries**: Use clear delimiters
   ```gdscript
   print("\n=== TEST NAME ===")
   print("\n--- Sub-test: Specific Feature ---")
   ```

2. **State Documentation**: Always print before/after states
   ```gdscript
   print("Before:", initial_state)
   print("After:", final_state)
   print("Expected:", expected_state)
   ```

3. **Result Formatting**: Use consistent pass/fail indicators
   ```gdscript
   print("✓ PASS: Description of success")
   print("✗ FAIL: Description of failure")
   ```

### UI Result Display
Create labels that show test results in the scene:
```gdscript
func update_results(text: String):
	if results_label:
		if results_label.text == "":
			results_label.text = text
		else:
			results_label.text += "\n" + text
```

## Common Test Patterns by System

### ScoreCard Tests
- **Initial State**: Record all score dictionaries
- **Action**: Perform scoring operation
- **Validation**: Check category scores, totals, and bonus tracking
- **Cleanup**: Reset scorecard if needed for multiple tests

### Statistics/Logbook Tests
- **Setup**: Clear existing logs
- **Action**: Trigger loggable events
- **Validation**: Check log entries, formatting, and data accuracy

### PowerUp/Consumable Tests
- **Activation**: Verify conditions for activation
- **Effect**: Test the actual effect on game state
- **Deactivation**: Confirm proper cleanup

### Manager System Tests
- **State Tracking**: Test singleton state management
- **Signal Flow**: Verify signal propagation
- **Resource Management**: Check resource allocation/deallocation

## Error Handling and Edge Cases

### Common Edge Cases to Test
1. **Null/Empty States**: Test with no data
2. **Boundary Values**: Test minimum and maximum values
3. **Invalid Input**: Test with malformed or out-of-range data
4. **Timing Issues**: Test rapid successive operations
5. **State Conflicts**: Test conflicting operations

### Error Recovery Patterns
```gdscript
func test_error_recovery():
	# Setup error condition
	create_error_condition()
	
	# Attempt recovery
	var recovery_successful = system.attempt_recovery()
	
	# Validate system state after recovery
	assert_system_stable()
```

## Test Execution Guidelines

### Manual Test Execution
Use the provided Godot path for manual testing:
```powershell
& "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/[TestName].tscn
```

### Automated Test Patterns
For tests that can run without user interaction:
```gdscript
func _ready():
	run_all_tests()
	# Auto-close after delay for automated runs
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
```

## Documentation Requirements

### Test Documentation
Each test file should include:
1. **Purpose**: What the test validates
2. **Setup Requirements**: Any special scene setup needed
3. **Expected Behavior**: What should happen
4. **Known Issues**: Any current limitations

### Result Documentation
Test results should be:
1. **Clear**: Obvious pass/fail indicators
2. **Detailed**: Specific failure reasons
3. **Actionable**: Include next steps for failures

## Example Test Template

```gdscript
extends Control

## [test_name]_test.gd
## Test to verify [specific functionality]
## Expected: [describe expected behavior]

@onready var target_system = $TargetSystem
@onready var results_label = $VBoxContainer/ResultsLabel

func _ready():
	print("\n=== [TEST NAME] TEST ===")
	await get_tree().process_frame
	test_main_functionality()

func test_main_functionality():
	print("\n--- Test: [Specific Feature] ---")
	
	# Setup
	var initial_state = record_initial_state()
	
	# Action
	perform_test_action()
	
	# Validation
	var final_state = record_final_state()
	validate_results(initial_state, final_state)

func record_initial_state() -> Dictionary:
	return {"key": "value"}

func perform_test_action():
	# Test-specific action
	pass

func record_final_state() -> Dictionary:
	return {"key": "value"}

func validate_results(before: Dictionary, after: Dictionary):
	var success = (after["key"] == expected_value)
	
	if success:
		print("✓ PASS: Test completed successfully")
		update_results("PASS: [Description]")
	else:
		print("✗ FAIL: [Specific failure reason]")
		update_results("FAIL: [Description]")

func update_results(text: String):
	if results_label:
		if results_label.text == "":
			results_label.text = text
		else:
			results_label.text += "\n" + text
```

## Best Practices Summary

1. **Always test one specific thing per test function**
2. **Use descriptive test and function names**
3. **Document expected vs actual behavior clearly**
4. **Include both positive and negative test cases**
5. **Test cleanup and reset functionality**
6. **Use consistent formatting and output patterns**
7. **Include setup instructions in test documentation**
8. **Validate all side effects, not just primary results**