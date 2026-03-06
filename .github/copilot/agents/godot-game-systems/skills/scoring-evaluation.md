---
skillName: Scoring & Evaluation
agentId: godot-game-systems
activationKeywords:
  - scoring
  - evaluation
  - yahtzee
  - category
  - bonus
  - wildcard
  - score_evaluator
  - points
filePatterns:
  - Scripts/Core/score_evaluator.gd
  - Scripts/Game/scorecard.gd
  - Scripts/Core/dice.gd
examplePrompts:
  - How do I score [category] with color dice?
  - Why is my Bonus Yahtzee scoring twice?
  - Design scoring for [custom category]
  - How do wildcard combinations affect scoring?
---

# Skill: Scoring & Evaluation

## Purpose
Debug, design, and improve DiceRogue's Yahtzee-based scoring system. Handles category logic, special bonuses, wildcard complications, and scoring edge cases. References score_evaluator.gd patterns and known issues.

## When to Use
- Debugging why scoring doesn't match expected behavior
- Designing new scoring categories or bonuses
- Understanding wildcard combination limits
- Fixing Bonus Yahtzee double-counting issues
- Optimizing scoring performance
- Adding color bonus effects to categories

## Inputs
- Current scoring behavior description
- Expected behavior / desired outcome
- Category type(s) involved (standard Yahtzee categories, color bonuses)
- Relevant dice values or mods
- Optional: Code snippet showing current logic

## Outputs
- Root cause analysis of scoring issue
- Corrected scoring logic with explanation
- Code snippet showing fix
- Test cases to prevent regression
- References to score_evaluator.gd or scorecard.gd relevant sections

## Behavior
- Explain standard Yahtzee scoring rules first
- Map to DiceRogue's category system (ones, twos, etc.)
- Handle special cases (Yahtzee, Bonus Yahtzee, wildcards)
- Account for color bonus effects (Green money, Red additive, Purple multiplier)
- Reference known Bonus Yahtzee split-logic issue
- Suggest test cases for validation

## Constraints
- Focus on scoring logic only (not UI or visual feedback)
- Warning: Wildcard combinations limited to 100 (hardcoded cap)
- Known issue: Bonus Yahtzee logic split between ScoreEvaluator + Scorecard (fragile)
- Do not modify scoring without test cases
- Follow DiceRogue rounding/truncation rules

## DiceRogue Scoring System

### Standard Yahtzee Categories
1. **Ones-Sixes**: Sum of matching pip values
2. **Three of a Kind**: Sum all dice if 3+ same
3. **Four of a Kind**: Sum all dice if 4+ same
4. **Full House**: 25 points if 3+2 pattern
5. **Small Straight**: 30 points if consecutive (4 dice)
6. **Large Straight**: 40 points if all consecutive
7. **Yahtzee**: 50 points if all 5 dice same
8. **Chance**: Sum all dice (no restrictions)
9. **Wildcard**: Sum all dice (flexible category)

### Special Scoring Rules

**Bonus Yahtzee**:
- First Yahtzee: 50 points
- Additional Yahtzees: 300 points each
- **Issue**: Split logic prevents double-counting (fragile)

**Wildcard Combinations**:
- Wildcards on dice generate multiple scoring options
- Limited to 100 combinations max (hardcoded)
- Warning if limit exceeded

**Color Bonus Effects**:
- **Green Die**: Converts to money value (1 die = 5 money)
- **Red Die**: Additive bonuses (1 die = +5 to category)
- **Purple Die**: Multipliers (1 die = ×1.1 to category)
- **Same Color Bonus**: 50 extra points if all dice same color
- **Rainbow Bonus**: 100 extra points if all 5 colors present

### Score Evaluator Code Pattern

Located in `Scripts/Core/score_evaluator.gd`:

```gdscript
func evaluate_category(dice_values: Array, category: String) -> int:
    match category:
        "ones":
            return sum_if_value(dice_values, 1)
        "twos":
            return sum_if_value(dice_values, 2)
        # ... etc
        "yahtzee":
            if all_same(dice_values):
                return 50
        "three_of_a_kind":
            if count_max(dice_values) >= 3:
                return sum(dice_values)
    return 0

func get_all_possible_scores(dice_values: Array) -> Dictionary:
    # Returns all valid categories with scores
    # Wildcard complications can create 100+ combinations
    pass
```

## Example Prompt
"Why is my Bonus Yahtzee sometimes scoring 300 and sometimes 50? It should only be 300 on subsequent Yahtzees."

## Example Output
- Root cause: Split logic in ScoreEvaluator and Scorecard
- ScoreEvaluator calculates raw Yahtzee (50)
- Scorecard adds Bonus Yahtzee (300) if not first
- Fix: Verify scorecard tracks "first Yahtzee already used"
- Test case: Apply 2 Yahtzees, verify 50 + 300 = 350 total
