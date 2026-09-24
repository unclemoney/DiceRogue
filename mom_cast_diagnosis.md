# Mom Cast Dialog Diagnosis — 46 never-triggered cast-claimed nodes

**Date:** 2026-09-24
**Scope:** The Mom coverage sim (`Tests/mom_coverage_sim_test.gd`, 50,000 seeded visits) passes all gates but reports 46 dialog nodes as "never triggered in flow" — every node claimed by CastManager rather than by the visit/check-in router. The sim models Mom flow only, not CastManager, so it cannot tell reachable cast content from dead content. This report classifies each node:

- **A** — arc-gated content that fires fine in real play
- **B** — content whose conditions are impossible in a real run (dead content)
- **C** — wiring bug (a code path references a node id that no path ever selects)

The task brief said 43 nodes; the actual report (`user://mom_coverage_report.txt`) lists **46**. All 46 are covered below.

## Summary

| Class | Count | Meaning |
|---|---|---|
| A — reachable | 13 | Triggers in real play through the real CastManager gates |
| B — dead | 33 | Conditions can never be met in a real run |
| C — broken wiring | 0 | None found — every `dialog_node_id` resolves, every `requires_flag` is set by some beat, every follow-up target exists |

## Root cause of the B class: MAX_CHANNEL = 4 vs. arcs authored for ~20 zones

`CastManager._beat_conditions_pass()` (`Scripts/Managers/cast_manager.gd:270-292`) requires `current_channel >= beat.min_channel`. But `ChannelManager` hard-clamps the channel to 1..4:

- `Scripts/Managers/channel_manager.gd:21` — `const MAX_CHANNEL: int = 4`
- `Scripts/Managers/channel_manager.gd:335` — `current_channel = clampi(channel, MIN_CHANNEL, MAX_CHANNEL)`
- Only 4 channel configs exist (`Resources/Data/Channels/channel_01..04.tres`, zones "North/East/West/South Wing")

Every arc beat with `min_channel >= 6` can never fire. The arc data (`Resources/Data/Mom/Cast/arc_*.tres`) uses `min_channel` values up to 20, and `channel_manager.gd:6` still documents a "difficulty channel system (1-20)" — the arcs were authored against a 20-zone mall design that was later cut to 4 zones, and the gating values were never re-tuned.

**Consequence:** no story arc can progress past its first one or two beats in real play. **No arc payoff beat and no arc completion reward (money/mood/rep on final beats) is reachable.** This is a data/design issue, not a code bug — the gating machinery works exactly as written. Whether to raise `MAX_CHANNEL`, re-tune `min_channel` values, or cut the dead arcs is a design decision for the owner; this report does not change game data.

## Verified mechanics (evidence for the classifications)

- Check-in claim precedence — `cast_manager.gd:202-243`: F12 debug > Derek quiet (`derek_quiet_pending` flag) > Dad cover (`dad_cover_pending`) > due story beat (highest `priority` arc whose beat conditions pass) > due pending Patterson report (2-zone delay) > fresh sighting roll (30% per check-in, 15% after truce; one per zone, never two zones in a row) > normal check-in trees.
- Dad call — `cast_manager.gd:396-405`, invoked from `game_controller.gd:6118-6121`: only when the meter visit picked `visit_punishment`, `severity >= 4`, pre-visit grudge >= 2, 20% roll, once per playthrough.
- Dad cover — `cast_manager.gd:413-417` + `:217-220`: armed when grudge changes to 0 after `max_grudge_seen >= 2`; `ChoresManager.add_grudge` emits `grudge_changed` (`ChoresManager.gd:645-650`) and `consume_grudge` decays grudge by 1 per meter visit (`ChoresManager.gd:658-662`), so grudge 2 -> 0 takes two clean visits. Feasible; once per playthrough.
- Flag/contest terminals — `flag_patterson_doubted` and `patterson_contest_failed` are `followup_node_id` targets inside `sighting_true.tres`, `sighting_false.tres`, `sighting_false_believed.tres` (and the dead `story_patterson_escalation.tres`); sessions set `flag_*` nodes as story flags via `CastManager.on_session_finished` (`cast_manager.gd:427-435`).
- Rep — run-scoped (reset per new game, `progress_manager.gd:867-879`), +7/+8/+9 per successful sass (`game_controller.gd:6642-6644`). Reaching rep 10 in a run takes ~2 successful sass responses, so `min_rep = 10` gates are feasible; rep 25 (~3-4 sass) is also numerically feasible but its beat is channel-dead anyway.
- Sightings — 4 named zones exist, so the true-report pool (`visited_zones.size() >= 2`) and the false-accusation pool (`get_unvisited_zones()`) are both satisfiable within a run (`cast_manager.gd:301-339`).

## Gate map — all 46 nodes

### Case A — reachable in real play (13)

| # | Node | Trigger path | Required conditions | Evidence |
|---|---|---|---|---|
| 1 | story_dad_call | Meter visit escalation | severity >= 4, pre-visit grudge >= 2, 20% roll, once/run | `cast_manager.gd:396-405`, `game_controller.gd:6118-6121` |
| 2 | story_dad_cover | `decide_checkin` step 2 | grudge reached >= 2 then decayed to 0, once/run | `cast_manager.gd:217-220`, `:413-417` |
| 3 | story_dad_longweek | dads_long_week beat 0 (priority 5) | channel >= 2, grudge 0-3 | `arc_dads_long_week.tres` beat_0 |
| 4 | story_patterson_intro | patterson_file beat 0 (priority 10) | channel >= 2 | `arc_patterson_file.tres` beat_0 |
| 5 | story_henderson_warning | henderson_called beat 0 (priority 5) | channel >= 3 | `arc_henderson_called.tres` beat_0 |
| 6 | story_derek_comparison | golden_child beat 0 (priority 20) | channel >= 3 | `arc_golden_child.tres` beat_0 |
| 7 | story_mom_played | moms_secret_past beat 0 (priority 3) | rep >= 10 (no channel gate) | `arc_moms_secret_past.tres` beat_0 |
| 8 | story_mom_tips | moms_secret_past beat 1 | channel >= 4, rep >= 10, flag `mom_played` | `arc_moms_secret_past.tres` beat_1 |
| 9 | sighting_true | `decide_checkin` steps 4-5 | true pool non-empty (>= 2 visited zones) or due pending report | `cast_manager.gd:229-241`, `:318-339` |
| 10 | sighting_false | `decide_checkin` step 5 | false roll, mood > 4, unvisited zone exists | `cast_manager.gd:369-379` |
| 11 | sighting_false_believed | `decide_checkin` step 5 | false roll, mood <= 4 | `cast_manager.gd:369-379` |
| 12 | flag_patterson_doubted | follow-up terminal in sighting trees | reached through sighting_true/false/false_believed contest outcomes | `sighting_true.tres:92`, `sighting_false.tres:53`, `sighting_false_believed.tres:58` |
| 13 | patterson_contest_failed | follow-up terminal in sighting trees | same | `sighting_true.tres:79`, `sighting_false.tres:61`, `sighting_false_believed.tres:51` |

Frequency notes: sighting trees fire at 30% of eligible check-ins (15% after truce) — common. Arc setup beats fire as soon as their channel/rep gate is met and they out-prioritize sightings. `story_dad_call` and `story_dad_cover` are rare by design (once per playthrough each, behind compound conditions).

### Case B — dead content, impossible conditions (33)

All gated by `min_channel >= 6` (> MAX_CHANNEL 4) or by flags set only by such beats.

| # | Node | Owning arc / path | Blocking condition |
|---|---|---|---|
| 1 | story_patterson_escalation | patterson_file beat 1 | min_channel 6 |
| 2 | story_patterson_payoff | patterson_file beat 2 | min_channel 12 (also needs flag_patterson_doubted, which IS reachable — irrelevant) |
| 3 | story_patterson_informant | patterson_file beat 3 | min_channel 14 (also needs patterson_truce from beat 2) |
| 4 | story_dad_writing_down | dads_long_week beat 1 | min_channel 6 |
| 5 | story_dad_almost | dads_long_week beat 2 | min_channel 10 |
| 6 | story_dad_list_found | dads_long_week beat 3 | min_channel 12 |
| 7 | story_dad_coverup | dads_long_week beat 4 | min_channel 14 |
| 8 | story_dad_list_burned | follow-up of story_dad_coverup (`story_dad_coverup.tres:15`) | dead with its parent beat |
| 9 | story_henderson_dinner | henderson_called beat 1 | min_channel 7 |
| 10 | story_henderson_payoff | henderson_called beat 2 | min_channel 11 (also requires_chores_done) |
| 11 | story_henderson_evidence | henderson_called beat 3 | min_channel 13 |
| 12 | story_derek_resentment | golden_child beat 1 | min_channel 8 |
| 13 | story_derek_twist | golden_child beat 2 | min_channel 12 |
| 14 | story_derek_covers | golden_child beat 3 | min_channel 14 |
| 15 | story_derek_quiet | `decide_checkin` step 1 | needs flag `derek_quiet_pending`, set only by story_derek_twist (dead) |
| 16 | story_derek_room_mess | derek_room_disaster beat 0 | min_channel 15 (also needs flag `derek_covered` from story_derek_covers, dead) |
| 17 | story_derek_room_blame | derek_room_disaster beat 1 | min_channel 17 |
| 18 | story_derek_room_cleanup | derek_room_disaster beat 2 | min_channel 19 (also requires_chores_done) |
| 19 | story_debra_opinions | perfume_cloud beat 0 | min_channel 10 |
| 20 | story_debra_counter | perfume_cloud beat 1 | min_channel 16 |
| 21 | story_debra_payoff | perfume_cloud beat 2 | min_channel 17 |
| 22 | story_debra_backfire | perfume_cloud beat 3 | min_channel 18 |
| 23 | story_debra_dish_missing | debra_casserole_dish beat 0 | min_channel 16 (also needs flag `debra_backfired` from story_debra_backfire, dead) |
| 24 | story_debra_dish_labels | debra_casserole_dish beat 1 | min_channel 18 |
| 25 | story_debra_dish_returned | debra_casserole_dish beat 2 | min_channel 20 |
| 26 | story_squirrel_first_sighting | squirrel_campaign beat 0 | min_channel 10 |
| 27 | story_squirrel_countermove | squirrel_campaign beat 1 | min_channel 14 |
| 28 | story_squirrel_payoff | squirrel_campaign beat 2 | min_channel 18 |
| 29 | story_bird_feeder_blueprint | bird_feeder_fever beat 0 | min_channel 9 |
| 30 | story_bird_feeder_stakeout | bird_feeder_fever beat 1 | min_channel 13 |
| 31 | story_bird_feeder_payoff | bird_feeder_fever beat 2 | min_channel 17 |
| 32 | story_mom_champ | moms_secret_past beat 2 | min_channel 8 (rep 25 is feasible; channel is not) |
| 33 | story_mom_trophy | moms_secret_past beat 3 | min_channel 10 |

### Case C — broken wiring (0)

None. Every arc `dialog_node_id` resolves to an existing dialog resource (enforced by `Tests/mom_data_validation_test.gd`), every `requires_flag` is set by some beat's `sets_flag` or by a `flag_*` terminal, and every `followup_node_id` target exists. The B class is entirely explained by the `min_channel` ceiling, plus flags chained to channel-dead beats — not by dangling references.

## What this means for the coverage sim

The 46 "never triggered in flow" INFO lines are expected: 33 nodes can never trigger in ANY real run (B), and 13 trigger only through CastManager gates the sim did not model (A). The sim's Pass D extension (added with this diagnosis) instantiates a real CastManager and simulates seeded runs across channels 1-4; it asserts every A node triggers and re-reports every B node with its dead-condition evidence, turning this table into a regression check.

## UNKNOWNs

None. All classifications are backed by the cited file/line evidence within the read budget.
