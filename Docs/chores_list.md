# Chore Tasks Reference

All chore tasks available in the ChoreTasksLibrary, organized by difficulty.

## Difficulty System

| Difficulty | Meter Reduction | Description |
|------------|----------------|-------------|
| EASY       | -10            | Simple tasks — score in a category, use an item, lock 3 dice |
| HARD       | -30            | Specific combos — full house with specific triples, specific yahtzees, lock 4-5 dice |

---

## EASY Tasks (Meter -10)

### Upper Section Scoring
| ID | Name | Description |
|----|------|-------------|
| `score_ones` | Score Ones | Score in the Ones category |
| `score_twos` | Score Twos | Score in the Twos category |
| `score_threes` | Score Threes | Score in the Threes category |
| `score_fours` | Score Fours | Score in the Fours category |
| `score_fives` | Score Fives | Score in the Fives category |
| `score_sixes` | Score Sixes | Score in the Sixes category |
| `score_any_upper` | Upper Score | Score in any upper section category |

### Lower Section (Generic)
| ID | Name | Description |
|----|------|-------------|
| `score_three_kind` | Three of a Kind | Score a Three of a Kind |
| `score_chance` | Score Chance | Score in the Chance category |
| `score_any_lower` | Lower Score | Score in any lower section category |

### Utility
| ID | Name | Description |
|----|------|-------------|
| `use_consumable` | Use Item | Use any consumable item |
| `scratch_score` | Take Zero | Scratch a category (score 0) |
| `lock_three_dice` | Lock Three | Lock at least 3 dice |

---

## HARD Tasks (Meter -30)

### Lower Section (Specific)
| ID | Name | Description |
|----|------|-------------|
| `score_four_kind` | Four of a Kind | Score a Four of a Kind |
| `score_full_house` | Full House | Score a Full House |
| `score_small_straight` | Small Straight | Score a Small Straight |
| `score_large_straight` | Large Straight | Score a Large Straight |

### Yahtzee Tasks
| ID | Name | Description |
|----|------|-------------|
| `roll_yahtzee` | Roll Yahtzee! | Roll a Yahtzee (5 of a kind) |
| `yahtzee_ones` | Yahtzee of Ones | Roll a Yahtzee with all 1s |
| `yahtzee_twos` | Yahtzee of Twos | Roll a Yahtzee with all 2s |
| `yahtzee_threes` | Yahtzee of Threes | Roll a Yahtzee with all 3s |
| `yahtzee_fours` | Yahtzee of Fours | Roll a Yahtzee with all 4s |
| `yahtzee_fives` | Yahtzee of Fives | Roll a Yahtzee with all 5s |
| `yahtzee_sixes` | Yahtzee of Sixes | Roll a Yahtzee with all 6s |

### Full House (Specific Triples)
| ID | Name | Description |
|----|------|-------------|
| `full_house_ones` | Full House (Ones) | Score Full House with three 1s |
| `full_house_twos` | Full House (Twos) | Score Full House with three 2s |
| `full_house_threes` | Full House (Threes) | Score Full House with three 3s |
| `full_house_fours` | Full House (Fours) | Score Full House with three 4s |
| `full_house_fives` | Full House (Fives) | Score Full House with three 5s |
| `full_house_sixes` | Full House (Sixes) | Score Full House with three 6s |

### Three/Four of a Kind (Specific Values)
| ID | Name | Description |
|----|------|-------------|
| `three_kind_sixes` | Triple Sixes | Score Three of a Kind with 6s |
| `three_kind_fives` | Triple Fives | Score Three of a Kind with 5s |
| `three_kind_ones` | Triple Ones | Score Three of a Kind with 1s |
| `four_kind_sixes` | Quad Sixes | Score Four of a Kind with 6s |
| `four_kind_fives` | Quad Fives | Score Four of a Kind with 5s |
| `four_kind_ones` | Quad Ones | Score Four of a Kind with 1s |

### Dice Locking (Advanced)
| ID | Name | Description |
|----|------|-------------|
| `lock_four_dice` | Lock Four | Lock at least 4 dice |
| `lock_all_dice` | Full Lock | Lock all 5 dice |

---

## Chore Flow

1. Player scores → goof-off meter increments by 1
2. When a chore completes or expires → **ChoreSelectionPopup** appears at turn end
3. Player chooses EASY (meter -10) or HARD (meter -30)
4. New chore becomes active with 20-roll expiration timer
5. If meter reaches max → Mom is triggered

## Expiration

- Chores expire after 20 rolls if not completed
- Expiration timer shown in hover tooltip on ChoreUI
- Text turns **red** when fewer than 5 rolls remain
