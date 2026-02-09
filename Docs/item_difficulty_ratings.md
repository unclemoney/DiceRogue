# Item Difficulty Ratings

All unlockable items organized by difficulty rating (1-10).
Difficulty scales with item power level — stronger items require harder unlock conditions.

## Difficulty Rating Scale

| Rating | Tier | Typical Unlock Requirements |
|--------|------|-----------------------------|
| 1 | Starter | Play 1 game, reach round 1 |
| 2 | Beginner | Play 3 games, score 50+ |
| 3 | Novice | Win 1 game, complete 3 challenges |
| 4 | Intermediate | Win 3 games, complete 5 challenges, category thresholds |
| 5 | Skilled | Score 200+, play 15 games, chore completions |
| 6 | Advanced | Category score thresholds, win 10 games |
| 7 | Expert | Win 15+ games, complete 20+ challenges |
| 8 | Master | Complete 8+ channels, 50+ chore completions |
| 9 | Mythic | Complete 10+ channels, advanced thresholds |
| 10 | Ultimate | Complete 15+ channels, high category scores |

---

## Unlock Condition Types

| Type | Description |
|------|-------------|
| `GAMES_PLAYED` | Total games played across all profiles |
| `GAMES_WON` | Total games won |
| `HIGH_SCORE` | Achieve a score ≥ threshold in a single game |
| `TOTAL_SCORE` | Cumulative score across all games |
| `CHALLENGES_COMPLETED` | Total challenges completed |
| `ROUNDS_SURVIVED` | Survive N rounds in a single game |
| `REACH_ROUND` | Reach a specific round number |
| `COMPLETE_CHANNEL` | Complete N different TV channels |
| `SCORE_THRESHOLD_CATEGORY` | **NEW** — Score ≥ threshold in a specific Yahtzee category |
| `CHORE_COMPLETIONS` | **NEW** — Complete N chores total (cumulative or single-game) |

---

## Category Score Thresholds

Used by `SCORE_THRESHOLD_CATEGORY` condition. Values based on category averages:

| Category | Threshold | Notes |
|----------|-----------|-------|
| ones | 4 | Adjust after playtesting |
| twos | 8 | Adjust after playtesting |
| threes | 12 | Adjust after playtesting |
| fours | 16 | Adjust after playtesting |
| fives | 20 | Adjust after playtesting |
| sixes | 24 | Adjust after playtesting |
| three_of_a_kind | 18 | Adjust after playtesting |
| four_of_a_kind | 22 | Adjust after playtesting |
| full_house | 28 | Adjust after playtesting |
| small_straight | 35 | Adjust after playtesting |
| large_straight | 45 | Adjust after playtesting |
| yahtzee | 50 | Adjust after playtesting |
| chance | 25 | Adjust after playtesting |

---

## Items by Difficulty

### Difficulty 1 — Starter
| Type | ID | Name |
|------|----|------|
| PowerUp | `extra_dice` | Extra Dice |
| PowerUp | `extra_rolls` | Extra Rolls |
| Consumable | `random_power_up_uncommon` | Random Power Up (Uncommon) |

### Difficulty 2 — Beginner
| Type | ID | Name |
|------|----|------|
| PowerUp | `full_house_bonus` | Full House Bonus |
| PowerUp | `straight_bonus` | Straight Bonus |
| PowerUp | `bonus_money` | Bonus Money |
| Consumable | `green_envy` | Green Envy |
| Consumable | `the_rarities` | The Rarities |

### Difficulty 3 — Novice
| Type | ID | Name |
|------|----|------|
| PowerUp | `yahtzee_master` | Yahtzee Master |
| PowerUp | `lucky_reroll` | Lucky Reroll |
| Consumable | `ones_upgrade` | Ones Upgrade |
| Consumable | `twos_upgrade` | Twos Upgrade |
| Consumable | `threes_upgrade` | Threes Upgrade |
| Consumable | `dice_surge` | Dice Surge |

### Difficulty 4 — Intermediate
| Type | ID | Name |
|------|----|------|
| PowerUp | `combo_king` | Combo King |
| PowerUp | `second_chance` | Second Chance |
| PowerUp | `score_doubler` | Score Doubler |
| Consumable | `fours_upgrade` | Fours Upgrade |
| Consumable | `fives_upgrade` | Fives Upgrade |
| Consumable | `sixes_upgrade` | Sixes Upgrade |
| Consumable | `poor_house` | Poor House |
| Mod | `loaded_ones` | Loaded Ones |
| Mod | `loaded_twos` | Loaded Twos |

### Difficulty 5 — Skilled
| Type | ID | Name |
|------|----|------|
| PowerUp | `double_or_nothing` | Double or Nothing |
| PowerUp | `triple_threat` | Triple Threat |
| Consumable | `three_of_a_kind_upgrade` | Three of a Kind Upgrade |
| Consumable | `four_of_a_kind_upgrade` | Four of a Kind Upgrade |
| Consumable | `stat_cashout` | Stat Cashout |
| Consumable | `score_streak` | Score Streak |
| Mod | `loaded_threes` | Loaded Threes |
| Mod | `loaded_fours` | Loaded Fours |
| Colored Dice | `blue_dice` | Blue Dice |

### Difficulty 6 — Advanced
| Type | ID | Name |
|------|----|------|
| PowerUp | `randomizer` | Randomizer |
| PowerUp | `streak_master` | Streak Master |
| Consumable | `full_house_upgrade` | Full House Upgrade |
| Consumable | `small_straight_upgrade` | Small Straight Upgrade |
| Consumable | `upper_section_boost` | Upper Section Boost |
| Consumable | `score_amplifier` | Score Amplifier |
| Mod | `loaded_fives` | Loaded Fives |
| Mod | `loaded_sixes` | Loaded Sixes |
| Colored Dice | `red_dice` | Red Dice |
| Colored Dice | `green_dice` | Green Dice |

### Difficulty 7 — Expert
| Type | ID | Name |
|------|----|------|
| PowerUp | `three_more_rolls` | Three More Rolls |
| PowerUp | `golden_dice` | Golden Dice |
| PowerUp | `score_reroll` | Score Reroll |
| Consumable | `large_straight_upgrade` | Large Straight Upgrade |
| Consumable | `chance_upgrade` | Chance Upgrade |
| Consumable | `bonus_collector` | Bonus Collector |
| Consumable | `go_broke_or_go_home` | Go Broke or Go Home |
| Mod | `heavy_hitter` | Heavy Hitter |
| Colored Dice | `purple_dice` | Purple Dice |

### Difficulty 8 — Master
| Type | ID | Name |
|------|----|------|
| PowerUp | `score_shield` | Score Shield |
| PowerUp | `double_existing` | Double Existing |
| Consumable | `yahtzee_upgrade` | Yahtzee Upgrade |
| Consumable | `empty_shelves` | Empty Shelves |
| Consumable | `the_pawn_shop` | The Pawn Shop |
| Consumable | `one_extra_dice` | One Extra Dice |
| Consumable | `lucky_seven` | Lucky Seven |
| Mod | `precision_roller` | Precision Roller |
| Colored Dice | `gold_dice` | Gold Dice |

### Difficulty 9 — Mythic
| Type | ID | Name |
|------|----|------|
| PowerUp | `auto_scorer` | Auto Scorer |
| Consumable | `all_categories_upgrade` | Master Upgrade |
| Consumable | `lower_section_boost` | Lower Section Boost |
| Mod | `wild_card` | Wild Card |

### Difficulty 10 — Ultimate
| Type | ID | Name |
|------|----|------|
| PowerUp | `jackpot` | Jackpot |
| Consumable | `ultimate_reroll` | Ultimate Reroll |
| Mod | `score_magnet` | Score Magnet |

---

## Save Version Migration

- **Version 1 (legacy)**: Old save format without chore tracking or category scores.
- **Version 2 (current)**: Adds `total_chores_completed`, `total_chores_completed_easy`, `total_chores_completed_hard`, `category_scores`, and `save_version` field.
- Old v1 profiles are detected on load, user is notified, then profiles are deleted and recreated fresh.
