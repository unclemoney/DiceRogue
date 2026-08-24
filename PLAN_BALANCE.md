# PLAN_BALANCE.md — DiceRogue Balance & Progression Plan

Status: APPROVED (grilling complete). Phases 0–4 execute in order, each with its own confirmation before code/data changes.

## Settled Decisions (from grilling)

1. **Measure first.** No number changes until a bot-driven baseline exists.
2. **Primary metric: score-growth ceiling.** Player score growth stays on a defined curve; win rate and unlock pacing are secondary checks.
3. **Balatro model.** Late-game scoring explosion is the fantasy. No capping/dampening of player multipliers; scale targets to meet player growth.
4. **Target curve is bot-derived.** Median achievable score per channel from the realistic climb; each channel target = margin% of that median. The margin is the difficulty knob.
5. **Realistic climb for measurement.** Bot plays channel 1→20 with cumulative progression (`reset_between_runs=false`). Floor/ceiling runs are sanity bounds only.
6. **Mom pressure is opt-in.** Difficulty lives in score targets, not Mom.
7. **Rebel path payouts (all four):** exclusive rebel loot pool, rebellion buffs scaling with risk, faster progression unlocks, higher-risk shop economy.
8. **Equal EV, different texture (amended per Branch 5b):** net EV/win-rate parity required between paths; raw scores may differ and the rebel target premium compensates.
9. **Unlock pacing: steady drip.** ~80% of the content pool unlocked by channel 15; legendaries are the long tail.
10. **Scope: unrestricted.** Data-first where possible; nothing off-limits.

## Grilling Outcomes (open branches, resolved)

- **Branch 1 — Margin curve:** rising linear, **65% of median bot score at ch1 → 90% at ch20** (≈ +1.32pp/channel: `margin_c = 0.65 + 0.25·(c−1)/19`). Endpoints re-anchored against Phase 0 win rates (target ≈80% bot win rate at ch1, ≈50% at ch20).
- **Branch 2 — EV parity band:** **±7.5%**, hard fail at ±10%. Arms: 30 climbs `always_comply`, 30 `always_sass`, 15 `tactical`; adaptive top-up to 60/arm if the confidence interval exceeds the band. Parity judged as win-rate/progression parity of each path against its own curve (not raw-score parity).
- **Branch 3 — Unlock retune:** keep all condition types; recalibrate `target_value`s from Phase 0 firing data onto a difficulty→channel schedule (diff 1–2→ch1–3, 3–4→ch4–7, 5–6→ch8–11, 7–8→ch12–15, 9→ch15–17, 10→ch18–20). Convert a condition to `COMPLETE_CHANNEL` only if its firing channel is uncalibratable (CV > 0.5 across climbs). Fix the `lower_section_boost` duplicate-id bug (`progress_manager.gd` diff-7 vs diff-9 registrations).
- **Branch 4 — Punishment caps:** confiscation ≤2 PowerUps/visit (highest-rated first); Mom debuffs ≤2/visit and ≤3 Mom-active at once; mod removal ≤1/visit; fines = min(flat, 25% of current money); permanent dice-color wipe stays tier-5-only. Enforced in code in `MomLogicHandler` plus `.tres` param tweaks (tier_05 `remove_mod` count 2→1, `max_count` param on confiscation entries).
- **Branch 5 — Rebellion scaling:** separate rebel target curve, applied as a **per-round premium by current Rep tier**: `final_target × (1 + premium[get_rep_tier()])`, `premium[0] = 0`; premiums for tiers 1–4 derived from the Phase 0 sass/comply per-channel median gap. Visible in UI. Containment lever order if the parity band breaks: (a) `MAX_BONUS_ROLLS`, (b) `BASE_SCORE_BONUS`, (c) `MAX_STACKS`, (d) rebel shop pricing, (e) comply-side rewards — never core multipliers or the base target curve.

## Key Codebase Facts

- Round target composition (`game_controller.gd:4176-4196`): `base = RoundDifficultyConfig.target_score_override if > 0 else ChallengeData goal`, then `scaled = base × goal_score_multiplier` (`channel_manager.gd:105`). Single seam for both the Phase 1 migration and the Rep premium.
- Scoring pipeline: `ceil((base + additives) × multipliers)` — multiplicative; late-channel variance is wide, justifying the non-flat margin curve.
- Bot harness: `mom_policy` supports all needed arms; reports are JSON; `reset_between_runs=false` carries progression. `channel_min/max` currently picks a *random* channel in range per run — a sequential climb mode (play current channel, advance on win) must be verified/added in Phase 0.
- Content pool: ~146 unlockables (75 PowerUps, 52 consumables −1 duplicate, 9 mods, 5 dice colors, 6 consoles). 80% by ch15 = ~117 items. ~36 items (25%) are channel-gated (deterministic); ~110 stat-gated items have flat thresholds that score/money inflation will fire earlier than intended.
- Punishment table today: confiscation unbounded (all R+NC-17 PowerUps, permanent, +1 debuff per NC-17), tier 5 draws 2 entries, fines flat $50–$300.
- Rebellion buff (`Scripts/Debuff/rebellion_buff.gd`): ×(1+0.15·stacks) score, max ×1.45, +1/+2 bonus rolls/turn, round-scoped.
- Rep is run-scoped, resets each game (`progress_manager.gd:819`) — hence per-round premium application, not game-start.

---

## Phase 0 — Baseline measurement

Bot configs (new, `Resources/Data/BotConfigs/`):
- `climb_tone_weighted.tres` — ch1–20 sequential climb, `reset_between_runs=false`, `mom_policy=tone_weighted`, 30 climbs. **Primary baseline** (median source).
- `climb_comply.tres` / `climb_sass.tres` — same, `always_comply` / `always_sass`, 30 climbs each. EV parity + rebel premium derivation.
- `floor_fresh.tres` (`reset_between_runs=true`, 10 runs) and `ceiling_unlocked.tres` (all unlocks pre-granted, 10 runs) — sanity bounds only.
- Timing calibration: log wall-clock of the first climb; if 30/arm exceeds the compute budget, reduce arms per the Branch 2 adaptive rule and record why.

Report fields to add (`Scripts/Bot/bot_statistics.gd`, `bot_report_writer.gd`, hooks in `bot_controller.gd`, possible new `BotConfig.gd` fields incl. climb mode):
- Per run: channel, rounds reached, **per-round final score vs target**, win/loss, arm, Rep tier at each round start, rebellion buff stacks/uptime per round, punishment events (tier, entries drawn, caps applied), unlocks fired (item_id, channel, game index), money earned/spent.
- Aggregate: median per-round score per channel per arm; win rate per channel per arm; unlock firing-channel distribution per item; sass/comply median ratio by Rep tier (premium table).

**Files:** `Scripts/Bot/{bot_statistics.gd, bot_report_writer.gd, bot_controller.gd, BotConfig.gd, bot_profile.gd}`, `Resources/Data/BotConfigs/*.tres` (5 new).
**Verify:** one climb per arm completes; report contains non-null medians for 20 channels × 6 rounds × 3 arms; timing logged.

### Phase 0 — COMPLETED 2026-07-30 (verification run: 1 climb per arm + floor + ceiling)

Infrastructure delivered and verified:
- **BotConfig:** `unlock_all_items`, `advance_on_loss`, `early_shop_chance` added; `speed_multiplier` now actually applied to `Engine.time_scale`; headless runs auto-quit after writing the report.
- **Natural progression:** bot mirrors the player flow (`mark_channel_completed`, `end_game_tracking`) so unlocks fire naturally; per-attempt progression reset (fresh player per climb); real player profiles backed up/restored.
- **Report fields:** per-round score+target, Rep tier per round, rebellion buff stacks per round, Mom punishment events (new `mom_consequences_applied` signal on GameController), unlocks fired. Aggregate `balance` block: per-channel/per-round medians, win rates, rep-tier score samples, unlock drip (`unlocked_by_channel`), Mom tier counts.
- **Harness bugs fixed en route:** phantom-1s dice locking (bot read dice mid-stagger), GameController manager paths broken in `Tests/BotTest.tscn` (Mom/shop/consumables never ran in bot scene — rewired via exported path overrides), per-round score recorded as 0 on won rounds (signal fired after scorecard reset).

Verification results (1 climb each, ~14–28 min per 20-channel climb at 10×):
- All 20 channels × 6 rounds sampled in every arm; Mom tier distribution diverges by arm as designed (sass: tiers 4–5 appear; comply: mostly −1/1).
- Wins: floor 1, tone_weighted 6, sass 7, comply 8, ceiling 10. Bot collapses at ch12+ under current targets (ch20 r1 target = 100,000).
- **Drip @ch15: 67–71% across climb arms** (target 80% — confirms Phase 3 retune needed). Ceiling 0% (correct: nothing to fire).
- **Timing calibration:** ~25 min/climb → full 30-climb baseline per arm ≈ 12.5 h sequential; recommend running the 3 arms as 3 parallel Godot processes (~12.5 h wall total) or overnight sequential.
- **Target seam note for Phase 1:** ch1 uses `.tres` `target_score_override`; ch2+ live targets come from challenge-definition scores × `goal_score_multiplier`. Migration must standardize this.

### ⚠️ First baseline CONTAMINATED — re-measurement required (2026-07-31)

The 2026-07-31 baseline (and the first Phase 1 migration derived from it) was invalidated by two cross-attempt state leaks in the bot's `_reset_game_state`:
1. **Colored dice purchases never cleared** — purple multipliers accumulated across all 600 runs/attempts, inflating late-attempt scores ~100× (ch3 r1 median read 28k; honest value ~500).
2. **Rebellion Rep never reset between games** — rep accumulated across the 20 games of each climb attempt, skewing sass escalation and rep-tier samples.

The first migration's targets were unbootstrappable (0% win rate everywhere in verification — targets encoded the inflated equilibrium, unreachable from a cold start). Channel `.tres` files were restored from backup. Leaks fixed in `_reset_game_state` (now clears `DiceColorManager` purchases and calls `ProgressManager.reset_rep()`); tutorial fix added (`tutorial_completed=true` on progression reset — bot can't play the scripted tutorial, which had also corrupted attempt-1 ch1–2 data).

**Clean re-baseline launched 2026-07-31** (30 climbs × 3 arms, parallel). Sanity probe confirmed: no cross-attempt score inflation; cold ch1–6 r1 scores ~0–1300. Phase 1 target derivation must use ONLY the clean baseline reports.

### ⚠️ Baseline #2 ALSO contaminated — evaluator counter (2026-08-03)

Baseline #2's score data was invalidated by a third harness bug: `ScoreEvaluatorSingleton._evaluation_count` (`score_evaluator.gd:247-250`) is a process-global anti-runaway guard that returns 0 for all evaluations after 1000 calls. It is only reset by UI preview flows (`score_card_ui.gd:1104`), which fire unreliably in headless bot runs. The bot evaluates ~1000+/game, so processes degraded into permanent zero-scoring at unpredictable points (ch1–2 zero medians in baseline #2; ch5+ zeros in baseline #1; ch3+ zeros in probes).

Fix: bot resets the counter every turn (`bot_controller._play_single_turn`). Probe after fix: 16 runs, zero zero-runs, stable honest scores (50–235 cold r1). **Baseline #3 launched 2026-08-03.** Only baseline #3+ reports are valid for target derivation. Note: baselines #1/#2 remain valid ONLY for Mom-event mechanics (punishment tiers, rep deltas), not for scores, unlock drip, or EV.

### ⚠️ Baseline #3 ALSO contaminated — autoload/manager accumulators (2026-08-04)

Verification of the baseline-3-derived migration failed (0% win rate ch3+; targets unbootstrappable). Forensics found the remaining cross-game inflation sources, all fixed in `_reset_game_state`:
1. `PlayerEconomy.piggy_bank_savings` — persists across games by design; bot never reset it.
2. `Statistics.consumables_used` — session-global, feeds `TheConsumerIsAlwaysRight`'s multiplier; never reset anywhere.
3. `mod_persistence_map` — bought mods re-applied to newly spawned dice every game (`_on_dice_spawned`); bot cleared only `active_mods`.
4. `dice_hand.dice_count` — never reset (yahtzeed_dice/great_exchange/extra_dice raised it permanently).
5. **`SynergyManager` rating counts** — THE DOMINANT LEAK: `synergy_G_sets`/`synergy_PG_sets` additives grew with every powerup ever bought (+650/turn by attempt 8, thousands by attempt 30); nothing called `SynergyManager.reset()`.
6. Gaming console combo counter (insurance fix; no console purchases observed).

Probe after all fixes: ch3 r1 scores flat across 8 attempts (69–611, pure variance). **Baseline #4 launched 2026-08-04** against the ORIGINAL (playable) channel targets, restored from backup — the first migration's inflated targets remain in git history only; re-derivation must use baseline #4+ reports. Real-game notes for later phases: piggy savings and `Statistics.consumables_used` may also inflate real long sessions; SynergyManager likely has the same reset gap in the real new-game flow (worth auditing separately — NOT changed as part of this work).

### Phase 0 — FULL BASELINE COMPLETED 2026-07-31 (30 climbs × 3 arms, 600 runs each)

All arms finished clean (EXIT 0), reports:
`bot_report_{tone_weighted,always_comply,always_sass}_2026-07-31T*.json` in `user://bot_reports/`.

Headline findings (tone_weighted arm unless noted):
- **Current difficulty curve is inverted-chaotic:** ch1 3% win rate (tutorial interference, see below), ch2 0%, ch3–12 77–100%, ch13–16 73–87%, ch17 47%, ch18 30%, ch19 20%, ch20 0%. Median final scores: ~28k (ch3) → ~1.9M (ch9–12, the explosion) → collapse at 17+.
- **ch1–2 median round-1 score = 0 (29/30 runs):** fresh profiles trigger `TutorialManager`, which the bot can't play; it fights the scripted flow and scores 0. Fix: set `tutorial_completed=true` in `_reset_progression` (bot measures balance, not the tutorial). ch1–2 medians from this baseline are tutorial-corrupted and must not drive Phase 1 targets.
- **Recorded target ≠ win condition for many challenges:** ch17 r1 median score 389k vs recorded target 30k yet only 47% win — non-score challenge goals (wildcard/triple_threat/etc.) dominate late channels. Phase 1 must make the recorded target the actual win condition.
- **EV parity raw read (sass vs comply win-rate delta per channel):** inside ±7.5% on 18/20 channels; outliers ch3 (+13% sass) and ch17 (−13% sass). Pre-tuning state.
- **Mom tier distribution by arm:** sass → tiers 3/4/5 = 152/86/247 events; comply → 62/22/50. Punishment pressure measurably higher on sass, as designed.
- **Rep tiers (sass arm):** 1612/917/259/9 rounds at tiers 1–4 — premium derivation data exists but is thin at tier 4.
- **Unlock drip: 74–76% by ch15** (all arms) vs 80% target → Phase 3 retune confirmed.

## Phase 1 — Target curve + migration

- `margin_c = 0.65 + 0.25·(c−1)/19`. `target_{c,r} = round(margin_c × median_{c,r})` from the tone_weighted arm, written as absolute `target_score_override` per round; `goal_score_multiplier` normalized to 1.0 on the scaled-target path so override × multiplier = intended value.
- Rebel premiums stored in new `Resources/Data/Balance/balance_tuning.tres` (script `Scripts/Data/balance_tuning.gd`): `premium[0..4]`, premium[0]=0, tiers 1–4 from the Phase 0 sass/comply median gap. Applied at round start in `game_controller.gd` target computation; surfaced in challenge UI as a visible modifier.
- Migration tool `Scripts/Editor/retarget_channels.gd` (headless) reads the Phase 0 report and rewrites `channel_01..20.tres`; regenerate `CHANNELS_REFERENCE.md` with its existing generator.

**Files:** `Resources/Data/Channels/channel_01..20.tres`, `Scripts/Editor/retarget_channels.gd` (new), `Scripts/Data/balance_tuning.gd` + `.tres` (new), `Scripts/Managers/channel_manager.gd` (premium hook), `Scripts/Core/game_controller.gd` (round-start premium + UI data), `Scripts/UI/challenge_ui.gd` / `corkboard_ui.gd` (premium display), `Tests/channel_manager_test.gd` (updated expectations), `CHANNELS_REFERENCE.md`.
**Verify:** channel manager test passes; tone_weighted re-climb win rate ≈80% ch1 / ≈50% ch20 (±10pp); effective targets within ±2% of margin×median.

## Phase 2 — Mom EV parity + punishment caps

- A/B: comply vs sass arms re-run on Phase 1 targets; pass = per-channel win-rate delta ≤7.5% (fail >10%), channels-completed-per-climb delta ≤7.5%; tactical arm as monotonicity check.
- Caps in `Scripts/Core/mom_logic_handler.gd`: confiscation `max_count=2` (highest-rated first), ≤2 debuffs/visit, ≤3 Mom-sourced debuffs active, fine = min(flat, 25% of money). `.tres` updates: tier_05 `remove_mod` count 2→1, `max_count` params on confiscation entries.
- Lever order if band breached: (a) `MAX_BONUS_ROLLS`, (b) `BASE_SCORE_BONUS`, (c) `MAX_STACKS` (`rebellion_buff.gd`), (d) rebel shop pricing, (e) tier_00 reward pools.

**Files:** `Scripts/Core/mom_logic_handler.gd`, `Resources/Data/Mom/Punishments/tier_02..05.tres` (+ `tier_00_reward.tres` only if lever (e)), `Scripts/Debuff/rebellion_buff.gd` (only if levers a–c), `Tests/mom_punishment_caps_test.gd` (new).
**Verify:** caps test asserts worst-case visit ≤2 PUs / ≤2 debuffs / ≤1 mod / fine ≤25% money; A/B report inside band; tactical arm between extremes.

## Phase 3 — Unlock pacing

- Retune `target_value`s in `progress_manager.gd` per the difficulty→channel schedule (1–2→ch1–3, 3–4→ch4–7, 5–6→ch8–11, 7–8→ch12–15, 9→ch15–17, 10→ch18–20), calibrated so each item's measured firing channel lands on schedule. Convert only uncalibratable conditions (firing-channel CV > 0.5) to `COMPLETE_CHANNEL`.
- Fix `lower_section_boost` duplicate (distinct id for the diff-9 registration). The 4 "NOT IMPLEMENTED" PowerUps and 3 avoidance items are excluded from the 80% accounting (documented).

**Files:** `Scripts/Managers/progress_manager.gd`, `Docs/unlock_conditions.md`, `Docs/item_difficulty_ratings.md`.
**Verify:** tone_weighted climb reports ≥80% of pool unlocked by ch15 completion; all diff 9–10 items fire ≥ch15; no duplicate unlock ids.

## Phase 4 — Validation

Re-run full 3-arm climbs after all changes. Acceptance:
1. Per-channel win rate tracks anchors (≈80% ch1 → ≈50% ch20, ±10pp), tone_weighted arm.
2. Comply vs sass arms inside ±7.5% on both parity metrics.
3. ≥80% of pool unlocked by ch15; legendaries ch15+.
4. Punishment log: zero events exceeding caps.
5. Comply runs unaffected by rebel premium (premium[0]=0; comply vs tone_weighted medians within band).

**Files:** `PLAN_BALANCE.md` (results appendix), regenerated `CHANNELS_REFERENCE.md`, archived bot reports.
**Verify:** all five criteria green in one report set.
