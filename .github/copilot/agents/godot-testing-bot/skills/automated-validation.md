---
skillName: Automated Validation
agentId: godot-testing-bot
activationKeywords:
  - validation
  - automated
  - regression
  - baseline
  - compare
  - qa
  - check
filePatterns:
  - Tests/**/*.gd
  - Scripts/Bot/bot_report_writer.gd
examplePrompts:
  - Create baseline for [system]
  - Compare current output to baseline
  - Detect regressions in [behavior]
  - Set up automated validation for [mechanic]
---

# Skill: Automated Validation

## Purpose
Enable automated testing through comparison of current output against known baselines. Detects regressions, validates behavior consistency, and streamlines QA through automated validation patterns.

## When to Use
- Establishing baseline behavior for new system
- Detecting regressions after code changes
- Running repeated tests to catch flaky behavior
- Comparing bot performance across strategy changes
- Validating game balance across multiple runs
- Automating QA checks for continuous testing

## Inputs
- System to validate
- Baseline output or expected behavior
- Validation criteria (exact match, within tolerance, etc.)
- Optional: Previous baseline for comparison

## Outputs
- Baseline file with expected output
- Validation script comparing current to baseline
- Regression report highlighting differences
- Suggestions for acceptance/revision

## Behavior
- Store baseline output (score, decisions, state)
- Compare current run to baseline
- Generate diff report with anomalies
- Support tolerance ranges (e.g., ±10% acceptable)
- Flag regressions for investigation
- Enable batch validation across multiple runs

## Constraints
- Baselines must be reproducible
- Random elements must be seeded for consistency
- Tolerance ranges must be reasonable
- Regression reports must be actionable
- Comparisons must complete in reasonable time

## DiceRogue Automated Validation Pattern

### Baseline Storage
```gdscript
# Save baseline after first successful run
const BASELINE_SCORING = {
    "ones": 3,
    "twos": 6,
    "threes": 9,
    # ... all categories
    "total": 63,
    "yahtzee_count": 0,
}

const BASELINE_BOT_PERFORMANCE = {
    "strategy": "aggressive",
    "total_score": 182,
    "yahtzees": 1,
    "categories_used": 12,
    "decisions": 42,
}
```

### Comparison Script Pattern
```gdscript
extends Node
class_name ValidationComparator

func compare_to_baseline(current: Dictionary, baseline: Dictionary, tolerance: float = 0.1) -> Dictionary:
    var differences: Array = []
    
    for key in baseline:
        var expected = baseline[key]
        var actual = current.get(key, null)
        
        if actual == null:
            differences.append({
                "key": key,
                "expected": expected,
                "actual": "MISSING",
                "status": "FAIL"
            })
        elif typeof(actual) == typeof(expected):
            var diff = calc_difference(actual, expected, tolerance)
            if diff["status"] != "PASS":
                differences.append(diff)
    
    return {
        "total_checks": baseline.size(),
        "passed": baseline.size() - differences.size(),
        "failed": differences.size(),
        "differences": differences,
    }

func calc_difference(actual, expected, tolerance: float) -> Dictionary:
    if expected is float or expected is int:
        var percent_diff = abs((actual - expected) / float(expected))
        var is_pass = percent_diff <= tolerance
        return {
            "expected": expected,
            "actual": actual,
            "percent_diff": percent_diff * 100,
            "status": "PASS" if is_pass else "REGRESSION"
        }
    else:
        return {
            "expected": expected,
            "actual": actual,
            "status": "PASS" if actual == expected else "REGRESSION"
        }

func generate_report(comparison: Dictionary) -> String:
    var report = "\n=== Regression Report ===\n"
    report += "Passed: %d/%d\n" % [comparison["passed"], comparison["total_checks"]]
    
    if comparison["failed"] > 0:
        report += "REGRESSIONS:\n"
        for diff in comparison["differences"]:
            report += "  ✗ %s: expected %s, got %s\n" % [diff["key"], diff["expected"], diff["actual"]]
    else:
        report += "✓ NO REGRESSIONS DETECTED\n"
    
    return report
```

### Baseline Validation Workflow

1. **Establish Baseline**:
   - Run system once
   - Verify output is correct
   - Save as baseline

2. **Run Current Test**:
   - Execute same test/scenario
   - Capture current output

3. **Compare to Baseline**:
   - Run comparison
   - Identify anomalies

4. **Decision**:
   - No diff → Code was safe
   - Expected diff → Intentional change (update baseline)
   - Unexpected diff → Regression found (investigate)

### Common Validation Scenarios

**Dice Behavior Baseline**:
```gdscript
const BASELINE_DICE_ROLL = {
    "random_seed": 12345,
    "rolls": [3, 4, 1, 5, 2],  # Expected for this seed
}

func validate_dice_deterministic() -> void:
    randomize(12345)  # Set seed
    var actual_rolls = []
    for i in range(5):
        actual_rolls.append(randi() % 6 + 1)
    
    var result = comparator.compare_to_baseline(
        {"rolls": actual_rolls},
        BASELINE_DICE_ROLL
    )
    print(comparator.generate_report(result))
```

**Bot Performance Baseline**:
```gdscript
const BASELINE_BOT_AGGRESSIVE = {
    "total_score": 185,  # ±10 acceptable
    "yahtzees": 1,
    "high_category_usage": 0.4,  # 40% of decisions
}

func validate_bot_strategy() -> void:
    var bot = create_bot("aggressive")
    var results = run_bot_game(bot)
    
    var comparison = comparator.compare_to_baseline(
        results,
        BASELINE_BOT_AGGRESSIVE,
        0.1  # ±10% tolerance
    )
    print(comparator.generate_report(comparison))
```

**Scoring Consistency Baseline**:
```gdscript
const BASELINE_SCORING_RULES = {
    "ones_sum": 3,      # 3 ones = 3 points
    "yahtzee": 50,      # All same = 50 points
    "full_house": 25,   # 3+2 pattern = 25 points
}

func validate_scoring_rules() -> void:
    var dice = [1, 1, 1, 0, 0]  # 3 ones
    var score = evaluate_ones(dice)
    
    assert_equal(score, 3, "Ones scoring is correct")
```

## Example Prompt
"Create baseline for aggressive bot performance, then detect regressions if strategy code changes"

## Example Output
Baseline file with expected metrics:
```
Aggressive Bot Baseline (100 runs average):
- Total Score: 185 ±10 (acceptable range: 175-195)
- Yahtzees: 1.2 ±0.5
- High Value Categories: 40%
- Decision Quality: 92%
```

After code change, validation report:
```
=== Regression Report ===
Passed: 9/10
REGRESSIONS:
  ✗ total_score: expected 185, actually 162 (12% below baseline)
  ⚠ yahtzees: expected 1.2, actually 0.8 (33% below baseline)

ACTION: Investigate scoring heuristic - bot is choosing lower-value categories
```
