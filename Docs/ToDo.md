# Dice Rogue — Development Todo

## How to Write a Task
- One task = one action. Split big items.
- Start with a priority tag.
- Add a system tag if it crosses systems.
- If you cannot act on it today, tag it `NEEDS-DETAIL` and add a `Clarify:` bullet.
- Completed tasks move to the archive at the bottom. Do not delete them.

## Tag Legend

### Priority
- `P0-Critical` — Crash or game-breaker. Fix now.
- `P1-Major` — Broken feature or bad balance. Fix this week.
- `P2-Minor` — Polish and cosmetic. Fix when P0 and P1 are clear.
- `NEEDS-DETAIL` — Too vague to code. Rewrite before starting.

### System
- `SYS:Gameplay` — Scoring, dice, challenges, debuffs, buffs, synergies, mods.
- `SYS:Chore` — Goof-off meter, mom, grounding, sass, chore progression.
- `SYS:Shop` — Purchases, economy, coupons, pogs, consumables, powerups, colored dice.
- `SYS:UI` — Panels, animations, tooltips, fonts, buttons, hover states, icons.
- `SYS:Audio` — Music layers, sound effects, loops.
- `SYS:Save` — New game, continue, profiles, resets, game over, cross-round state.
- `SYS:Debug` — Debug panel, test scenes, validation tools, inspector fields.

---

## SYS:Gameplay — Core Gameplay & Balance

- [X] `P0-Critical` The Division debuff is not dividing scores. Missing signal.
- [X] `P0-Critical` The Division debuff is not dividing scores when it's a different category.  Example: division works on 6s if there is a Blue 6, but if I score in the 1's category it multiplies.  This violates the Blue Dice Rules and the Division rule.
- [X] `P0-Critical` Red Power Ranger not adding unless there is a red dice present.
- [ ] `P0-Critical` Odds only mod rolled a 2. Can't reproduce at the moment.
- [X] `P1-Major` Groundings occur in Mall Zone 2 at the start of every round. They should only trigger on Sass or Chore failures.
- [X] `P1-Major` Add a Powerful Teachers Pet BUFF. Add extra money rewards.
- [X] `P1-Major` Remove Debuffs and Buffs on challenge complete.
- [X] `P1-Major` Window Shopping Debuff is useless. Redesign to Hail Satan
- [ ] `P1-Major` Best Hand calculated 426 for Chance. Player selected small straight and still got 426. Hand logic is wrong.
- [X] `P1-Major` Cartridge Tilt ignores the locked dice part of the increase dice.
- [ ] `P1-Major` Abstinance debuff needs to be checked. Verify it works as designed.
- [X] `P1-Major` Upgrade 5's still showing in d4. d4 should not show 5's upgrades.
- [X] `P1-Major` On a d4 Run, unlisted categories appear in best hand. Hide them.
- [X] `P1-Major` d4 needs to replace 5's and Large Straight with Even, Odd, Full House, and Fours+. These need upgrade coupons. Only offer them during a d4 run.
- [X] `P1-Major` No limit on available items to carry over. Enforce only the number limit.
- [X] `P1-Major` Mods are blocking dice face. Dice faces are not readable.
- [X] `P2-Minor` Red Power Ranger PowerUp adding an extra label to the top of the screen, this needs to be removed.
- [ ] `P2-Minor` Need an indicator for Synergies. Players cannot see when synergies trigger.
- [ ] `P2-Minor` Challenge or Debuff that makes powerups expire after 3 rounds.
- [ ] `NEEDS-DETAIL` Better score balance for each round needed. Test this.
  - Clarify: Which rounds feel wrong? Higher or lower scores? What is the target?
- [ ] `NEEDS-DETAIL` Play PowerUp for double acting feature for one turn per round?
  - Clarify: Is this a new powerup idea or a change to an existing one? Which powerup?

## SYS:Chore — Chore System & Mom

- [ ] `P1-Major` Mom Dialog and reward should match. They currently do not align.
- [X] `P1-Major` Chores should be filtered by the dice set being used. d4 runs should not show d6 chores.
- [ ] `P1-Major` Chore Champion should also update rewards.
- [X] `P2-Minor` Mom Panel bounce-in is too harsh. Soften the animation.

## SYS:Shop — Shop & Economy

- [ ] `P2-Minor` Make lock item screens easier to read.

## SYS:UI — UI / UX & Animation

- [ ] `P1-Major` Mall Map Fan Out still rough. Mall Zone 1 shows "coming up" instead of "completed". Mall Zone 2 shows correctly.
- [ ] `P2-Minor` Challenge UI needs less alpha in the background.
- [ ] `P2-Minor` Update Challenge Icons.
- [ ] `P2-Minor` Shockwave animations can also be applied to buttons that need to be pressed or chosen.
- [ ] `P2-Minor` Click on the Mall Zone upper left to bring up the mall map. Show coming challenges.
- [ ] `P2-Minor` Texture Progress Bars need to be reworked. Make them consistent across the game.
- [X] `P2-Minor` Add commas for scores. Use e-notation for higher numbers.
- [X] `P2-Minor` Mom Panel bounce-in is too harsh. Soften the animation.

## SYS:Save — Save, Load & State Management

- [ ] `NEEDS-DETAIL` Weird things going on with Continue or New Game. Not seen again. Need more info.
  - Clarify: What screen? What error? What state was the game in?

## SYS:Debug — Debug & Testing Tools

- [X] `P1-Major` Add a current dice state to the debug panel. 
- [ ] `P1-Major`Something weird happens and 2 dice are disabled after a Mom check-in in Mall Zone 2.

## Plan Prompts
> Clear this section and use it for design documents, zone plans, and balance spreadsheets.
> 
> Template:
> - **Goal:**
> - **Systems affected:**
> - **Risks:**
> - **Test plan:**

---

# Juicy Editor
> Separate tool. Project 98% complete. No active tasks.

---

# Completed Archive

## Game Balance — Completed
- [X] G and PG Synergies are being activated in a strange way with 3g and 2pg. Shouldn't happen.
- [X] More Mom interactions. Balance needed if a player only uses color dice. Rep not increasing enough.
- [X] Mom Panels need to stay one consistent size.
- [X] Vary the check in. If a check in doesn't happen during the round, have a 50/50 chance for a between visit.
- [X] A scratch should always be a scratch no matter the additive powerups, unless you have the protective powerup.
- [X] Update Powerup names and name length.
- [X] Chore reduction needs to be balanced with chore difficulty.
- [X] Chore max level needs consistency.
- [X] Next Round Info Panel doesn't need to display the active chore.
- [X] Challenges for the next round and debuffs not lining up with what is actually displayed.
- [X] End of round Money — Empty Categories should only give $5 for each empty.
- [X] PowerUp Shop Items need to show mom approval levels.
- [X] The PowerUp add the last score is too powerful.
- [X] Chores don't really progress fast enough, especially if you win the round in 1 shot.
- [X] Chores progress with each roll by 1. Should non-approved powerups increase it by +xx each time?

## Testing — Completed
- [X] Debug Panel doesn't have a way to test MODS.
- [X] Add a square for the Buff.
- [X] Mom Appearances still in the middle of the Shopping round. Remove them.
- [X] Change SHOP to whatever Mallzone you are in.
- [X] New Locking system needs work.
- [X] Move Sass Challenges to the CHORE_UI and not the debuff UI.
- [X] The Piggy Bank should not be reset across Zones.
- [X] Create Pogs for PowerUps.
- [X] Rename SHOP TABS — POGS, COUPONS, MODS, COLORS, VIPS.
- [X] All Fonts need to be homogenized.
- [X] DICE SURGE SEEMED TO LAST TOO LONG? Checked.
- [X] Update animation location for animations involving scores and money for power up locations.
- [X] Upper Bonus — does it increase? Establish a proper countdown.
- [X] New Round Details in Round two: Debuffs listed are not actually active. Traced source.
- [X] If we complete a chore at the end of the round, we don't need a chore selector anymore.
- [X] Upgrade Dice color or lock dice details — maybe a texture that says keep.
- [X] Console container, the activate button is too big and spills over and gets clipped.
- [X] Challenge container spills out over the corners with the background.
- [X] Fix Chore Details and progress meter. Add details to the panel or hover tooltip.
- [X] Round Winner Stats — You Win! Needs Panel background, and more stats: rolls, consumables used, etc.
- [X] Update Carry-Over Panel — too hard to see checkbox, add background, border glow.
- [X] Mom Panels need theme updates.
- [X] Fix Container hover tooltips.
- [X] Show Sell value of items inside the sell button.
- [X] Replica of duplicated powerup isn't scoring — at least with just the money spent additive. Replica should also change state when activated and able to sell.
- [X] Show what color dice are already owned — maybe a stat bar in the shop UI.
- [X] Allow Shop Expansion up to 6. Add scroll buttons in the shop if more than 3. Don't allow shop expansion after 6 to be used again.
- [X] PowerUp fan out is not showing hover tooltips. They are under other items. Set z to higher.
- [X] GameUI buttons need to be reset for proper size and ensure they are in the correct spot. Add a nice shader for them.
- [X] 2 Challenges active, but only one icon visible.
- [X] Challenges might not be properly removed or properly activated at the beginning of a round.
- [X] Going to main menu from the pause screen causes a crashing error: Invalid access to property or key 'process_frame' on a base object of type 'null instance'.
- [X] Debug panel not all buttons function — ie synergy which needs to be tested.
- [X] Update Debuff Icons.
- [X] Update labels from channels to zones.
- [X] Update All buttons to use the Reroll shader and logic, but different colors.
- [X] Cap Points above to 100 points above.
- [X] Give added cash from powerups at the end of the round in the info panel.
- [X] Debug: Consumable once used, did not show a spine after purchasing a new one.
- [X] The title needs that interactive element.
- [X] Channel Selector needs to be changed to a mall map, with mall region — mostly cosmetic.
- [X] Mods cause dice to disappear, but it's fine when sold.
- [X] Upgrade Shop Item UI.
- [X] +/- is hard to select, and the score needs to update after a selection is made — best hand etc.
- [X] Console UI Upgrade — change over to VIP cards.

## Features — Completed
- [X] Synergy visual indicators — translucent background glow on compact PowerUp slots and halo ring on fan-out cards (rating color for matching sets, animated rainbow for Rainbow Bonus), fan-view synergy summary banner, and "SYNERGY!" popup on activation.
- [X] Update music so that if layers with drum solos and fills get followed by a crash layer automatically. Add a crash layer.
- [X] New round needs to visually show what the debuffs are going to be.
- [X] Beginning game setup: remote control splash, tv turns on with the background, chore setup, then Next Round or Shop buttons fly up in its own panel, then when the round starts, the score cards come bouncing in.
- [X] Get rid of the money thing that is under the corkboard.
- [X] Make the removal of power ups a dramatic ripping away, especially with Mom, or melting items or temporary ones. Open fan out, rip one away, and have it spin off like the dice, rotating.
- [X] Update PowerUp sell and consumable use animations.
- [X] Make a splash screen showing the intro into the remote control panel, two color panel like the carpet background, remote flies in.
- [X] Chore screen needs swoop in animations, bounce, less jarring of a transition.
- [X] Sound on button enter at round end.
- [X] Music needs to be updated, create a longer loop with more chord variation in the base layer, but add more subtle movement layers on top sooner.
- [X] Sound effect update for: Button clicks, Money, Fan Outs, Sell, Use, Mouse In and Out, Shake sounds, Have consecutive click sounds increase in tone, New tab selection.
- [X] Update Shop Tabs — can we animate them?
- [X] Can we create more interesting tabs?
- [X] Force Powerups to be always open first.
- [X] Prevent the random challenges from selecting two of the same in a row.
- [X] Custom mouse icons.
- [X] Get rid of lock dice chores, change to only lock xx dice during a turn, with no locks on a score being the hardest, but remove these from the chores.
- [X] Need a save game state.
- [X] Custom animations for Guhtzee.
- [X] Channel can select a gaming system that grants a unique power up for the round: Game Boy, NES, SNES, Genesis etc. Gives a boost to the game in later rounds.
- [X] At the beginning of each round show a Panel that displays the round challenge. Quick transition animation.
- [X] Powerup Idea: Duplicate 1 random powerup after 1 round.
- [X] Need to erase profile, so in the right click panel, add an erase option, and apply theme to the panel.
- [X] What about removing your blockbuster card to stop you from buying more powerups as a grounding/debuff?
- [X] Update Debuff, with a different background .png.
- [X] Update Score Card UI by increasing the size of everything slightly, and create a proper border and title.
- [X] Create new challenges that are 1/2/3 difficulty, and then randomly pick challenges in a 1/1/2/2/3/3 fashion, and better scale the ever increasing scores.
- [X] Make the chore complete more obvious.
- [X] Right click to unlock all dice quickly.
- [X] UI to show upcoming challenges, like a calendar in our postit UI fan out.
- [X] Build an editor to review all consumables, power ups, mods, color dice: cost, rarity, rating, etc.
- [X] Update the ShopUI to look like a shelf from Blockbuster, a newspaper, a POG collection, etc, as well as locked items.
- [X] Update Challenge UI to be more obvious about the goal.
- [X] Update Dice UI.
- [X] Give a bonus for finishing the round Early. Give bonus cash for each empty category you have.
- [X] Once shop button is pressed, create a round over dialog box showing bonus money, and round stats, and after OK is clicked then enter the Shop.
- [X] Add Negative animations for any item or debuff that causes that.
- [X] Refactor Dice Area. Create a well defined area for dice to be rolled in, determine the maximum amount of dice allowed.
- [X] Create several new animations with variations.
- [X] When next turn is clicked, sweep dice off screen, and have Roll button glow.
- [X] A cork board with post it notes.
- [X] Have Chores change randomly after XX rolls, give a notification of a change visually.
- [X] If you haven't done enough chores when mom shows up, she will be mad and take something away.

## Bugs — Completed
- [X] Disabled 2's should add a red shader to the 2's dice face.
- [X] High Roller Mod not rerolling dice, but is rolling normally.
- [X] Music not progressing beyond the basic loop — something about the progression system.
- [X] Check the fail states in the gaming console test scene, sometimes 2 sometimes 3.
- [X] Retrigger celebration happens after XX turns playing in free mode, also not seen again, need more info.
- [X] Not sure if scorecard levels reset, it appears they did when they shouldn't — it might just be the label. Seems to be just the labels, upgrades are acting properly.
- [X] Did the colored dice maintain across the next round when preserved — seems to not be working.
- [X] Costly Reroll debug not showing up in the groundings.
- [X] Update powerup positions, and their size so we can fit all the powerups on the shelf.
- [X] Atari label should change to indicate it's different states or being reset across rounds.
- [X] Chore: use any consumable item did to work when an item was used.
- [X] When we start a new game after Game Over, we need to reset the Money as well.
- [X] After Finishing a round, in continual playing mode, we should disable Next Round, otherwise we miss out on the Shop and end of round goodies.
- [X] Keep fixing UI issues.
- [X] We need to make sure to disable the Next Turn and Roll buttons after entering the SHOP.
- [X] NES is not working at all.
- [X] Add Shader background to console shop.
- [X] Spamming buttons causes items not to return to their original position.
- [X] Double Score score selection period doesn't work in between rolls, this should be useable anytime, as long as there is at least 1 score on the scorecard.
- [X] 4,2,1,3,5 with 2 mods gold 6, and color dice didn't manually score a lg straight, gave me 2 points for red dice, but not lg straight.
- [X] New game on new channel doesn't unregister all powerups properly, extra dice still appearing. Need to also change turn and rounds to --, maybe have channel displayed on the TV.
- [X] Need to make sure that the colored dice is actually being scored, green dice that shouldn't count are being scored especially in the upper section.
- [X] Red dice is being triggered twice.
- [X] One Extra Dice Consumable does not grant extra dice, once dice surge is fixed, this should be fixed next.
- [X] Dice Surge not revoking the extra dice after XX turns.
- [X] Invalid access to property or key 'roll_cost' on a base object of type 'Node (CostlyRollDebuff)'.
- [X] Dice Surge used before the challenge started caused a celebration to happen, indicating the challenge had been won, so we need to limit when dice surge can be used.
- [X] Empty Shelves Consumable does not unregister after 1 use, and continues to multiply.
- [X] Scorecard levels are reset for the next channel, but the labels haven't been reset.
- [X] Shop expansions should reset to its original number when new channel starts a new game.
- [X] The profile name seemed to randomly duplicate from player one to player two.
- [X] Auto score doesn't always put in the displayed category, usually because of an upgrades or other mults, how to handle this?
- [X] Shop UI and Coupon Z order needs to be fixed.
- [X] Reset reroll cost after the next round.
- [X] Limit the number of coupons to 3 at a time, have the label update.
- [X] End of Game shouldn't take you to the shop, but send you back to the channel selector.
- [X] Owning the extra rolls powerup isn't properly reset for the next game.
- [X] Validate earning money unlocks items.
- [X] The unlockeditemspanel takes a long time to popup, seems to be working better.
- [X] Money Multiplier PU isn't responding as expected, validate in new PowerUpValidationTest.
- [X] Purchase Colored Dice needs to be fixed: purchase to activate the colored dice, and once active leave active for the entire game, and then reset when a new game begins.
- [X] Going to next channel needs to reset all of the stats, money, powerups, and consumables.
- [X] Have the Game Over immediately appear when roll we arrive at roll 0, don't allow to press next turn. Disable that button.
- [X] When selecting Next Round, we also want to display the End of Round Stats Panel.
- [X] New Round needs to also reset the scorecard levels.
- [X] Bonus Yahtzee didn't score manually selecting Upper Section category.
- [X] Make some of the locked items based on the number of chores completed and the number of channels completed.
- [X] We started a new round from the channel selector, then pressing the next round button sends us into round 2 when we should stay in round 1.
- [X] Can press shop more than once.
- [X] Disabled Dice and Locked Dice need to be different. Disabled 2's should not score 2s, but locked dice should be allowed to score. This causes a game crashing bug in Lockdown challenge. It seems that lockdown is working but all dice are disabled for some reason.
- [X] Step By Step not behaving as expected, or only when 6s are scored.
- [X] Setup game over conditions for when the round is at 13, the rolls are 0 and the goal hasn't been satisfied.
- [X] If you get grounded, Mom's mood should automatically shift to negative.
- [X] If Roll is disabled, we should not flash it.
- [X] Invalid call. Nonexistent function 'has_node' in base 'SceneTree'. Trigger_mom_check.
- [X] After Going to Next Round, the Scorecard was still locked, but pressing next turn unlocked it after the first hand, make sure Next Round unlocks the scorecard for manual scoring.

## Refactor — Completed
- [X] Have the background react to the channel number, increase velocity and change color.
- [X] Initial selection of Channel will allow the selection of all and up to the latest completed Channel numbers, adding a starting channel will add bonus starting money.
- [X] Chore difficulty will provide different cash rewards, Easy $10, Hard $50, etc.
- [X] Coupons need to not have the two letter tag above them.
- [X] Fanning out scenes should readjust spine positions when one is sold to recenter everything, be more reactive to the scene, and do we want to change the icon size — test for 9, currently capped at 7.
- [X] Do we want to change the challenge reward to scale up, have it set with the challenge manager.
- [X] General balance, unlock fewer items in the first game, balance money earned — 25 per unused category is too much, let's try 10 next.
- [X] Failed money needs more cash — like 50; same with full house fortune.
- [X] Better chore progression for goof off.
- [X] Unlocks can't have more than 3 straights in a game, if chance is scored, let's adjust that.
- [X] Unlock item progress needs updating. Build more unlock conditions: Score at least XX in XXX category. Complete 1,2,3, chores in a game, and overall.
- [X] Update the Chores system. Show countdown to next chore, on pass or fail, show a dialog that chooses two types easy or hard. Group chores into two types EASY/HARD. Add chore level.
- [X] Shop UI needs updating, everything is slightly off, and the shelf UI is ugly.
- [X] VCR needs to be bigger, showing a whole line for money to indicate updates and have space for more money, everything else can widen and scale down.
- [X] Change Title labels for PowerUp and Consumable to Smart Word Wrap, consumable_icon, _apply_card_info_style, title_width, Change Label to RichText and Animate as needed.
- [X] Money Well Spent too powerful, can stack up fast, either scale or increase amount spent.
- [X] Create more challenges, add a challenge level, and then have the round manager randomly select the next challenge from the appropriate levels.
- [X] Add Reward to the Post it Notes, When hovering over the spine, show the challenge data description, also add this description to a post it note.
- [X] Add Gained reward to the end of round stats panel with animation.
- [X] Add allowance for completing chores.
- [X] We should add scaling difficulty as time progresses, like progressing through the cable channels.
- [X] Corkboard UI needs titles and a title panel above each section, Goof off meter needs to be made to look better, like a hand drawn bar chart.
- [X] Goof-off meter needs to be go to scale down as difficulty increases.
- [X] Upper Section Bonus should scale with the game so that we don't set the bar too low each round, and do we want to force the player to fill the entire section to achieve it.

## Juicy Editor — Completed
- [X] When opening a document from a shortcut, it opens a new window, but dragging the shortcut only opens the default file and not the link.
  - Updated title-fit numbers — at 13px the font advance is exactly 8px/char and the usable band is ~125px:
  - Max: 15 characters (16 chars probably still fits — only ~6px of slack either way).
  - Over the limit (9): Random Uncommon Power-Up (24), Upgrade Lg. Straight (20), Upgrade Sm. Straight (20), Go Broke or Go Home (19), Lower Section Boost (19), Upper Section Boost (19), Upgrade Full House (18), Add Power Up Slot (17), Double or Nothing (17).
