# Unlock Conditions Reference

This file lists every PowerUp, Consumable, Mod, and Colored Dice feature registered by `ProgressManager` along with its `UnlockCondition` type and target value.

> Source: `Scripts/Managers/progress_manager.gd` (default registrations)

## PowerUps

| ID | Name | Condition | Target | Description |
|---|---:|---|---:|---|
| step_by_step | Step By Step | COMPLETE_GAME | 1 | Upper section scores get +6 |
| extra_dice | Extra Dice | SCORE_POINTS | 10 | Start with an extra die |
| extra_rolls | Extra Rolls | COMPLETE_GAME | 1 | Get additional roll attempts |
| evens_no_odds | Evens No Odds | SCORE_POINTS | 50 | Additive bonus for even dice |
| foursome | Foursome | SCORE_POINTS | 100 | Bonus for four of a kind |
| chance520 | Chance 520 | ROLL_YAHTZEE | 1 | Bonus for chance category |
| full_house_bonus | Full House Fortune | SCORE_POINTS | 150 | Full house scoring bonus |
| upper_bonus_mult | Upper Bonus Multiplier | SCORE_POINTS | 200 | Multiplies upper bonus |
| bonus_money | Bonus Money | EARN_MONEY | 50 | Earn extra money per round |
| consumable_cash | Consumable Cash | EARN_MONEY | 100 | Gain money from PowerUps |
| money_multiplier | Money Multiplier | EARN_MONEY | 150 | Multiplies money earned |
| money_well_spent | Money Well Spent | EARN_MONEY | 200 | Convert money to score |
| highlighted_score | Highlighted Score | SCORE_POINTS | 250 | Bonus for highlighted categories |
| yahtzee_bonus_mult | Yahtzee Bonus Multiplier | ROLL_YAHTZEE | 2 | Multiplies Yahtzee bonuses |
| pin_head | Pin Head | ROLL_STRAIGHT | 2 | Bonus for specific dice patterns |
| perfect_strangers | Perfect Strangers | ROLL_STRAIGHT | 3 | Bonus for diverse dice |
| randomizer | Randomizer | USE_CONSUMABLES | 5 | Random bonus effects |
| wild_dots | Wild Dots | CUMULATIVE_YAHTZEES | 5 | Special die face effects |
| the_consumer_is_always_right | The Consumer Is Always Right | USE_CONSUMABLES | 10 | Consumable synergies |
| green_monster | Green Monster | EARN_MONEY | 300 | Green dice bonuses |
| red_power_ranger | Red Power Ranger | SCORE_POINTS | 300 | Red dice bonuses |
| green_slime | Green Slime | EARN_MONEY | 50 | Doubles green dice probability |
| red_slime | Red Slime | SCORE_POINTS | 100 | Doubles red dice probability |
| purple_slime | Purple Slime | ROLL_YAHTZEE | 1 | Doubles purple dice probability |
| blue_slime | Blue Slime | CUMULATIVE_YAHTZEES | 10 | Doubles blue dice probability |
| lower_ten | Lower Ten | SCORE_POINTS | 150 | Lower section scores get +10 points |
| different_straights | Different Straights | ROLL_STRAIGHT | 2 | Straights can have one gap of 1 |
| plus_thelast | Plus The Last | SCORE_POINTS | 250 | Adds last score to current score |
| allowance | Allowance | COMPLETE_GAME | 1 | Grants $100 when challenge completes |
| ungrounded | Ungrounded | CUMULATIVE_YAHTZEES | 15 | Prevents all debuffs |
| shop_rerolls | Shop Rerolls | EARN_MONEY | 75 | Shop rerolls always cost $25 |
| tango_and_cash | Tango & Cash | SCORE_POINTS | 150 | +$10 for every odd die scored |
| even_higher | Even Higher | EARN_MONEY | 200 | +1 additive per even die scored |
| money_bags | Money Bags | CUMULATIVE_YAHTZEES | 3 | Score multiplier based on current money |
| failed_money | Failed Money | COMPLETE_GAME | 2 | +$25 for each failed hand at round end |
| roll_efficiency | Roll Efficiency | COMPLETE_GAME | 1 | +N to scores (N = rolls used) |
| dice_diversity | Dice Diversity | SCORE_POINTS | 75 | +$5 per unique dice value scored |
| chore_champion | Chore Champion | COMPLETE_GAME | 2 | Chores are 2x more effective |
| lock_and_load | Lock & Load | EARN_MONEY | 50 | +$3 for each die locked |
| pair_paradise | Pair Paradise | SCORE_POINTS | 100 | Pair bonuses based on pattern |
| extra_coupons | Extra Coupons | EARN_MONEY | 200 | Hold 2 additional consumables (5 max) |
| purple_payout | Purple Payout | EARN_MONEY | 75 | Earn $3 per purple die when scoring |
| mod_money | Mod Money | COMPLETE_GAME | 2 | Earn $8 per modded die when scoring |
| blue_safety_net | Blue Safety Net | EARN_MONEY | 150 | Halves blue dice penalties |
| chore_sprint | Chore Sprint | SCORE_POINTS | 120 | Chore completions reduce goof-off by 10 |
| straight_triplet_master | Straight Triplet Master | ROLL_STRAIGHT | 3 | Score large straight in 3 categories |
| modded_dice_mastery | Modded Dice Mastery | USE_CONSUMABLES | 4 | +10 per modded die when scoring |
| debuff_destroyer | Debuff Destroyer | ROLL_YAHTZEE | 2 | Removes random debuff when sold |
| challenge_easer | Challenge Easer | COMPLETE_CHANNEL | 5 | All challenge targets reduced by 20% |
| azure_perfection | Azure Perfection | CUMULATIVE_YAHTZEES | 3 | Blue dice always multiply |
| rainbow_surge | Rainbow Surge | COMPLETE_CHANNEL | 10 | 2x multiplier when 4+ dice colors present |
| lucky_streak | Lucky Streak | COMPLETE_CHANNEL | 3 | Increased chance of rolling pairs (NOT IMPLEMENTED) |
| steady_progress | Steady Progress | COMPLETE_CHANNEL | 5 | +5 points to all lower section scores (NOT IMPLEMENTED) |
| combo_king | Combo King | COMPLETE_CHANNEL | 8 | Bonus multiplier for consecutive scoring (NOT IMPLEMENTED) |
| channel_champion | Channel Champion | COMPLETE_CHANNEL | 12 | Double points in favorite category (NOT IMPLEMENTED) |
| grand_master | Grand Master | COMPLETE_CHANNEL | 15 | All scoring categories get +10% (NOT IMPLEMENTED) |
| dice_lord | Dice Lord | COMPLETE_CHANNEL | 20 | Start each round with one guaranteed Yahtzee (NOT IMPLEMENTED) |

## Consumables

| ID | Name | Condition | Target | Description |
|---|---:|---|---:|---|
| quick_cash | Quick Cash | EARN_MONEY | 25 | Gain instant money |
| any_score | Any Score | SCORE_POINTS | 25 | Score dice in any category |
| score_reroll | Score Reroll | COMPLETE_GAME | 2 | Reroll after scoring |
| one_extra_dice | One Extra Dice | SCORE_POINTS | 75 | Add one die temporarily |
| three_more_rolls | Three More Rolls | COMPLETE_GAME | 3 | Get three extra rolls |
| double_existing | Double Existing | SCORE_POINTS | 100 | Double a scored category |
| double_or_nothing | Double Or Nothing | SCORE_POINTS | 150 | Risk/reward scoring |
| power_up_shop_num | Power Up Shop Number | EARN_MONEY | 75 | More PowerUps in shop |
| the_pawn_shop | The Pawn Shop | EARN_MONEY | 100 | Trade items for money |
| empty_shelves | Empty Shelves | USE_CONSUMABLES | 3 | Clear shop for new items |
| the_rarities | The Rarities | USE_CONSUMABLES | 5 | Access to rare items |
| visit_the_shop | Visit The Shop | COMPLETE_CHANNEL | 3 | Open the shop during active play |
| add_max_power_up | Add Max Power Up | USE_CONSUMABLES | 7 | Increase PowerUp limit |
| random_power_up_uncommon | Random Uncommon Power Up | USE_CONSUMABLES | 8 | Get random uncommon PowerUp |
| green_envy | Green Envy | EARN_MONEY | 150 | Green dice effects |
| go_broke_or_go_home | Go Broke Or Go Home | EARN_MONEY | 200 | All-in money strategy |
| poor_house | Poor House | EARN_MONEY | 250 | Low money benefits |
| free_chores | Free Chores | COMPLETE_GAME | 1 | Reduces goof-off meter by 30 points |
| all_chores | All Chores | COMPLETE_GAME | 3 | Clears goof-off meter completely |
| one_free_mod | One Free Mod | USE_CONSUMABLES | 5 | Grants 1 free random dice mod |
| dice_surge | Dice Surge | COMPLETE_CHANNEL | 2 | Grants +2 temporary dice for 3 turns |
| stat_cashout | Stat Cashout | CUMULATIVE_YAHTZEES | 3 | Earn $10/yahtzee and $5/full house this run |
| upper_section_boost | Upper Section Boost | COMPLETE_CHANNEL | 3 | Upgrades all 6 upper categories by one level |
| lower_section_boost | Lower Section Boost | COMPLETE_CHANNEL | 4 | Upgrades all 7 lower categories by one level |
| score_streak | Score Streak | SCORE_POINTS | 500 | Score multiplier grows over 3 turns |
| score_amplifier | Score Amplifier | SCORE_POINTS | 400 | Doubles your next category score |
| bonus_collector | Bonus Collector | EARN_MONEY | 500 | Grants $35 if upper bonus achieved |
| ones_upgrade | Ones Upgrade | SCORE_POINTS | 50 | Upgrade Ones category level |
| twos_upgrade | Twos Upgrade | SCORE_POINTS | 75 | Upgrade Twos category level |
| threes_upgrade | Threes Upgrade | SCORE_POINTS | 100 | Upgrade Threes category level |
| fours_upgrade | Fours Upgrade | SCORE_POINTS | 125 | Upgrade Fours category level |
| fives_upgrade | Fives Upgrade | SCORE_POINTS | 150 | Upgrade Fives category level |
| sixes_upgrade | Sixes Upgrade | SCORE_POINTS | 175 | Upgrade Sixes category level |
| three_of_a_kind_upgrade | Three of a Kind Upgrade | SCORE_POINTS | 200 | Upgrade Three of a Kind category level |
| four_of_a_kind_upgrade | Four of a Kind Upgrade | SCORE_POINTS | 250 | Upgrade Four of a Kind category level |
| full_house_upgrade | Full House Upgrade | SCORE_POINTS | 300 | Upgrade Full House category level |
| small_straight_upgrade | Small Straight Upgrade | ROLL_STRAIGHT | 3 | Upgrade Small Straight category level |
| large_straight_upgrade | Large Straight Upgrade | ROLL_STRAIGHT | 5 | Upgrade Large Straight category level |
| yahtzee_upgrade | Yahtzee Upgrade | CUMULATIVE_YAHTZEES | 8 | Upgrade Yahtzee category level |
| chance_upgrade | Chance Upgrade | SCORE_POINTS | 350 | Upgrade Chance category level |
| all_categories_upgrade | Master Upgrade | COMPLETE_CHANNEL | 10 | Upgrade ALL categories by one level |
| channel_bonus | Channel Bonus | COMPLETE_CHANNEL | 3 | Gain $50 per completed channel |
| reroll_master | Reroll Master | COMPLETE_CHANNEL | 5 | Gain 2 extra rerolls this round |
| lucky_seven | Lucky Seven | COMPLETE_CHANNEL | 8 | All dice become 1-7 range this round |
| ultimate_reroll | Ultimate Reroll | COMPLETE_CHANNEL | 15 | Reroll all dice up to 5 times |

## Mods

| ID | Name | Condition | Target | Description |
|---|---:|---|---:|---|
| even_only | Even Only | SCORE_POINTS | 200 | Forces die to only roll even numbers |
| odd_only | Odd Only | SCORE_POINTS | 200 | Forces die to only roll odd numbers |
| gold_six | Gold Six | ROLL_YAHTZEE | 2 | Sixes count as wilds |
| five_by_one | Five by One | CUMULATIVE_YAHTZEES | 12 | All dice show 1 or 5 |
| three_but_three | Three But Three | ROLL_STRAIGHT | 4 | Dice avoid rolling 3s |
| wild_card | Wild Card | USE_CONSUMABLES | 10 | Random special effects on each roll |
| high_roller | High Roller | SCORE_POINTS | 350 | Dice tend toward high values |
| channel_veteran | Channel Veteran | COMPLETE_CHANNEL | 5 | Start with +$25 per channel completed (NOT IMPLEMENTED) |
| precision_roller | Precision Roller | COMPLETE_CHANNEL | 12 | First roll each turn is always 4+ (NOT IMPLEMENTED) |

## Colored Dice Features

| ID | Name | Condition | Target | Description |
|---|---:|---|---:|---|
| green_dice | Green Dice | SCORE_POINTS | 100 | Unlocks green colored dice (earn money) |
| red_dice | Red Dice | SCORE_POINTS | 150 | Unlocks red colored dice (score bonus) |
| purple_dice | Purple Dice | SCORE_POINTS | 200 | Unlocks purple colored dice (score multiplier) |
| blue_dice | Blue Dice | SCORE_POINTS | 250 | Unlocks blue colored dice (complex effects) |

---

If you'd like, I can also:

-+- Save a CSV copy at `Docs/unlock_conditions.csv`.
-+- Add links from each item to its resource file (`Scripts/PowerUps/*.tres`, `Scripts/Consumable/*.tres`, `Scripts/Mods/*.tres`).
