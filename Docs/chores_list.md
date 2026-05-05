# Chore Tasks Reference

All chore tasks available in the ChoreTasksLibrary, organized by difficulty and reward tier.

## Difficulty System

| Difficulty | Meter Reduction | Description |
|------------|----------------|-------------|
| EASY       | -10            | Simple tasks — score in a category, use an item, lock 3 dice |
| HARD       | -30            | Specific combos — full house with specific triples, specific yahtzees, lock 4-5 dice |

## Reward Scale

Chores now pay variable rewards based on actual in-game difficulty:

| Tier | Reward | Description |
|------|--------|-------------|
| Very Easy | $5 | Trivial tasks — score upper 1-3, use item, scratch, lock 3 dice |
| Easy | $15 | Common tasks — score upper 4-6, any upper/lower, 3-kind, chance |
| Medium | $35 | Moderate tasks — 4-kind, full house, straights, lock 4 dice, specific full houses |
| Hard | $65 | Difficult tasks — any yahtzee, specific 4-kind, lock all 5 dice |
| Very Hard | $100 | Extreme tasks — specific value yahtzees (all 1s, all 2s, etc.) |

---

## Very Easy Tasks ($5, Meter -10)

### Upper Section Scoring
| ID | Name | Description |
|----|------|-------------|
| `score_ones` | Score Ones | Score in the Ones category |
| `score_twos` | Score Twos | Score in the Twos category |
| `score_threes` | Score Threes | Score in the Threes category |

### Utility
| ID | Name | Description |
|----|------|-------------|
| `use_consumable` | Use Item | Use any consumable item |
| `scratch_score` | Take Zero | Scratch a category (score 0) |
| `lock_three_dice` | Lock Three | Lock at least 3 dice |

---

## Easy Tasks ($15, Meter -10)

### Upper Section Scoring
| ID | Name | Description |
|----|------|-------------|
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
| `three_kind_ones` | Triple Ones | Score Three of a Kind with 1s |

---

## Medium Tasks ($35, Meter -10 or -30)

### Lower Section (Specific)
| ID | Name | Description |
|----|------|-------------|
| `score_four_kind` | Four of a Kind | Score a Four of a Kind |
| `score_full_house` | Full House | Score a Full House |
| `score_small_straight` | Small Straight | Score a Small Straight |
| `score_large_straight` | Large Straight | Score a Large Straight |

### Full House (Specific Triples)
| ID | Name | Description |
|----|------|-------------|
| `full_house_ones` | Full House (Ones) | Score Full House with three 1s |
| `full_house_twos` | Full House (Twos) | Score Full House with three 2s |
| `full_house_threes` | Full House (Threes) | Score Full House with three 3s |
| `full_house_fours` | Full House (Fours) | Score Full House with three 4s |
| `full_house_fives` | Full House (Fives) | Score Full House with three 5s |
| `full_house_sixes` | Full House (Sixes) | Score Full House with three 6s |

### Three of a Kind (Specific Values)
| ID | Name | Description |
|----|------|-------------|
| `three_kind_sixes` | Triple Sixes | Score Three of a Kind with 6s |
| `three_kind_fives` | Triple Fives | Score Three of a Kind with 5s |

### Dice Locking
| ID | Name | Description |
|----|------|-------------|
| `lock_four_dice` | Lock Four | Lock at least 4 dice |

---

## Hard Tasks ($65, Meter -30)

### Yahtzee Tasks
| ID | Name | Description |
|----|------|-------------|
| `roll_yahtzee` | Roll Yahtzee! | Roll a Yahtzee (5 of a kind) |

### Four of a Kind (Specific Values)
| ID | Name | Description |
|----|------|-------------|
| `four_kind_sixes` | Quad Sixes | Score Four of a Kind with 6s |
| `four_kind_fives` | Quad Fives | Score Four of a Kind with 5s |
| `four_kind_ones` | Quad Ones | Score Four of a Kind with 1s |

### Dice Locking
| ID | Name | Description |
|----|------|-------------|
| `lock_all_dice` | Full Lock | Lock all 5 dice |

---

## Very Hard Tasks ($100, Meter -30)

### Specific Yahtzee Tasks
| ID | Name | Description |
|----|------|-------------|
| `yahtzee_ones` | Yahtzee of Ones | Roll a Yahtzee with all 1s |
| `yahtzee_twos` | Yahtzee of Twos | Roll a Yahtzee with all 2s |
| `yahtzee_threes` | Yahtzee of Threes | Roll a Yahtzee with all 3s |
| `yahtzee_fours` | Yahtzee of Fours | Roll a Yahtzee with all 4s |
| `yahtzee_fives` | Yahtzee of Fives | Roll a Yahtzee with all 5s |
| `yahtzee_sixes` | Yahtzee of Sixes | Roll a Yahtzee with all 6s |

---

## Chore Flow

1. Player scores → goof-off meter increments by 1
2. When a chore completes or expires → **ChoreSelectionPopup** appears at turn end
3. Player chooses EASY (meter -10) or HARD (meter -30) — each chore shows its reward
4. New chore becomes active with 20-roll expiration timer
5. If meter reaches max → Mom is triggered

## End-of-Round Rewards

At the end of each round, the player receives the sum of all chore rewards completed during that round. There is no longer a flat $50 per chore — easy chores pay as little as $5, while extreme chores like a specific Yahtzee pay $100.

## Expiration

- Chores expire after 20 rolls if not completed
- Expiration timer shown in hover tooltip on ChoreUI
- Text turns **red** when fewer than 5 rolls remain
