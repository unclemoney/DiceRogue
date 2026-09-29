# Mom Dialog System

Godot 4.4.1 · DiceRogue

This is the working reference for building Mom dialog trees. It covers the resource schema, visit routing, outcome effects, punishment tiers, story arcs, and the exact runtime behavior of `MomLogicHandler`.

Use this when adding or editing files in:

- `Resources/Data/Mom/Dialog/`
- `Resources/Data/Mom/Punishments/`
- `Resources/Data/Mom/Cast/`

Primary code:

- `Scripts/Core/mom_logic_handler.gd` — severity, weighted draws, outcome resolution, consequence building/application.
- `Scripts/Core/game_controller.gd` — visit routing, dialog-tree walking, UI handoff, Rebellion/Teacher's Pet, final state application.
- `Scripts/Data/mom_dialog_node.gd` — one dialog beat.
- `Scripts/Data/mom_dialog_response.gd` — one player response button.
- `Scripts/Data/mom_dialog_outcome.gd` — one weighted result of a response.
- `Scripts/Data/mom_punishment_tier.gd` — weighted punishment/reward tables.
- `Scripts/Managers/ChoresManager.gd` — mood, grudge, defer streak, meter/check-in state.
- `Scripts/Managers/cast_manager.gd` — recurring cast, story arcs, sightings, flags, story rewards.
- `Tests/mom_data_validation_test.gd` — data rules enforced in CI/headless tests.

---

## 1. Mental model

A Mom conversation is a small resource graph:

```text
MomDialogNode
├─ id
├─ mom_text
├─ expression
├─ speaker_name
└─ responses[]
   └─ MomDialogResponse
      ├─ button_text
      ├─ tone
      └─ outcomes[]
         └─ MomDialogOutcome
            ├─ weight
            ├─ effect + magnitude
            ├─ mood_delta / grudge_delta
            ├─ result_text / result_expression
            ├─ followup_node_id
            └─ ends_visit
```

Runtime flow:

```text
Trigger
  ├─ Meter full  → compute severity → choose visit/story root
  └─ Check-in    → cast claim → inventory/flavor root

GameController
  → load root MomDialogNode
  → show node
  → await response
  → MomLogicHandler.resolve_response()
  → MomLogicHandler.apply_outcome()
  → merge result
  → follow up or show final reply
  → await dialog close
  → MomLogicHandler.apply_consequences()
  → CastManager.on_session_finished()
```

Important: consequences are collected during the conversation, but most game-state changes execute only after the dialog closes.

---

## 2. Fast authoring checklist

- [ ] Create or duplicate a `.tres` in `Resources/Data/Mom/Dialog/`.
- [ ] Give the root node a unique `id`.
- [ ] Fill `mom_text`.
- [ ] Choose an `expression`: `happy`, `neutral`, or `upset`.
- [ ] Add responses. Use 2–4 options.
- [ ] Give every response a valid `tone`: `polite`, `neutral`, or `sassy`.
- [ ] Give every response at least one outcome.
- [ ] Keep outcome weights positive and relative.
- [ ] For continuing dialog, set `followup_node_id` to an existing node id.
- [ ] For a terminal reply, leave `followup_node_id` empty and write `result_text`.
- [ ] Use `apply_tier` when the normal punishment table should decide consequences.
- [ ] Use direct effects only when the dialog beat must force a specific result.
- [ ] If this is story content, add/update a `MomStoryArc` in `Resources/Data/Mom/Cast/`.
- [ ] Run `Tests/MomSuiteRunner.tscn` headless before committing.

Preferred editor workflow: duplicate a nearby working `.tres`, then edit it in the Godot Inspector. This avoids hand-maintaining resource UIDs, `load_steps`, typed arrays, and sub-resource references.

---

## 3. File and responsibility map

| Path | Responsibility |
|---|---|
| `Scripts/Core/mom_logic_handler.gd` | Pure-ish logic layer. Computes severity, loads nodes/tiers, picks weighted entries/outcomes, converts effects into `MomCheckResult`, applies consequences. |
| `Scripts/Core/game_controller.gd` | Runtime owner. Chooses root trees, walks nodes, handles UI, accumulates outcomes, applies Rep and Mom-granted buffs, emits analytics. |
| `Scripts/UI/mom_character.gd` | Popup display, typewriter text, response buttons, OK button, expressions, portrait tint. |
| `Scripts/Managers/ChoresManager.gd` | Mom mood, grudge, defer streak, low-mood visit count, meter visits, once-per-round check-ins. |
| `Scripts/Managers/cast_manager.gd` | Cast claims on check-ins, story progression, Patterson sightings, Dad events, story flags and rewards. |
| `Scripts/Data/mom_dialog_node.gd` | Dialog node schema and local validation. |
| `Scripts/Data/mom_dialog_response.gd` | Response schema and local validation. |
| `Scripts/Data/mom_dialog_outcome.gd` | Outcome schema, dialog-only effects, local validation. |
| `Scripts/Data/mom_punishment_tier.gd` | Tier schema and canonical direct effect list. |
| `Resources/Data/Mom/Dialog/` | Every dialog node. Auto-scanned by the handler. |
| `Resources/Data/Mom/Punishments/` | Six punishment/reward tier resources. |
| `Resources/Data/Mom/Cast/` | Cast characters and story arcs. |

---

## 4. Dialog node schema

`MomDialogNode` is one beat of conversation.

| Field | Type | Required | Notes |
|---|---:|---:|---|
| `id` | `String` | Yes | Unique across every file in `Resources/Data/Mom/Dialog/`. This is the link key. |
| `mom_text` | `String` | Yes | Mom's visible line. Supports BBCode. `{zone}` is replaced by `GameController`. |
| `expression` | enum | Yes | `happy`, `neutral`, `upset`. Maps to the existing portraits. |
| `speaker_name` | `String` | No | Defaults to `Mom`. Use labels such as `Mom (on the phone with Dad)` for cast beats. |
| `speaker_tint` | `Color` | No | Defaults to white. Dark tints are useful for off-screen/phone speakers. |
| `responses` | `Array[MomDialogResponse]` | No | Empty means terminal: the popup shows OK and ends the session. |

### Node rules

- Every node must have non-empty `mom_text`.
- Every node id must be unique.
- A node with no responses is terminal.
- Root nodes and follow-up nodes live in the same directory; there is no separate file format.
- The handler auto-loads every `.tres` in `Resources/Data/Mom/Dialog/`. Do not add a preload for each new node.
- The data validation test requires every node to be reachable from a router root, a code-claimed root, a cast arc, or another reachable node.

---

## 5. Response schema

`MomDialogResponse` is one player-facing button.

| Field | Type | Required | Notes |
|---|---:|---:|---|
| `button_text` | `String` | Yes | Keep it short enough for a stacked dialog button. |
| `tone` | enum | Yes | `polite`, `neutral`, `sassy`. Drives bot choices, Rep, and sass escalation. |
| `outcomes` | `Array[MomDialogOutcome]` | Yes | One outcome is drawn by weight when selected. |

### Tone semantics

| Tone | Current meaning |
|---|---|
| `polite` | Usually safer. Bot weight `6.0`. Can reduce Rep in punishment/check-in contexts. |
| `neutral` | Middle path. Bot weight `3.0`. No special Rep reward. |
| `sassy` | Risk/reward path. Bot weight `1.0`. Can build Rebellion, but punished sass can scale with Rep tier. |

Use tone honestly. The player learns the risk language. Do not mark a clearly insulting button as `neutral` just to avoid sass systems.

---

## 6. Outcome schema

`MomDialogOutcome` is one possible result of a response.

| Field | Type | Default | Notes |
|---|---:|---:|---|
| `weight` | `float` | `1.0` | Relative draw weight. Must be greater than 0. |
| `effect` | enum | `none` | See the effect reference below. |
| `magnitude` | `int` | `0` | Effect-specific. For `apply_tier`, `-1`, `0`, and `1–5` have special meanings. |
| `mood_delta` | `int` | `0` | Positive makes Mom angrier; negative makes her happier. |
| `grudge_delta` | `int` | `0` | Positive raises the next visit's severity floor. |
| `permanent` | `bool` | `false` | Used by direct punishment effects. Temporary usually means round-scoped. |
| `followup_node_id` | `String` | `""` | Explicit next node. If set, runtime follows it. |
| `result_text` | `String` | `""` | Reply shown when no follow-up continues the tree. |
| `result_expression` | `String` | `""` | Empty keeps the current expression. Otherwise use `happy`, `neutral`, or `upset`. |
| `ends_visit` | `bool` | `true` | Validation/design contract. Runtime behavior is determined mainly by `followup_node_id`; see below. |

### Weight math

Weights are relative, not percentages.

```text
Outcome A weight 7
Outcome B weight 3

Total = 10
A chance = 70%
B chance = 30%
```

Keep weights simple: `1`, `2`, `3`, `5`, `7`, `8`, `9`. Avoid fake precision like `3.17`.

---

## 7. Runtime chaining rules

This section describes what `GameController` actually does.

### If the current node has no responses

The dialog shows the node as a terminal beat with an OK button. No outcome is drawn.

Use terminal nodes for:

- Final story beats.
- Storm-off text.
- Flag-setting beats.
- Simple informational scenes.

### If the player picks a response

1. `MomLogicHandler.resolve_response()` draws one weighted outcome.
2. `MomLogicHandler.apply_outcome()` converts it into a partial result.
3. `GameController` merges that partial result into the session result.
4. Runtime checks `outcome.followup_node_id`.

### Explicit follow-up wins

If `followup_node_id` is set:

- The walker loads that node.
- If the follow-up is terminal, it is shown and the session ends.
- If the follow-up has responses, the session continues.
- The outcome's `result_text` is not shown as a separate beat.

### No follow-up ends the session

If `followup_node_id` is empty:

- The walker ends the session.
- If `result_text` is non-empty, it is shown as Mom's parting reply.
- If the accumulated result has visible consequences, the UI appends a summary.

### `ends_visit` caveat

`ends_visit` is enforced by validation for special effects, but the current walker does not branch on it directly.

Practical rule:

- Set `ends_visit = true` when there is no follow-up.
- Set `ends_visit = false` only when `followup_node_id` points to a non-terminal continuation.
- Do not rely on `ends_visit = false` plus `result_text` to continue the conversation. Runtime will end the session.

### Loop guard

The walker allows at most 10 non-terminal beats per session. Avoid loops. A loop will hit the guard and end awkwardly.

---

## 8. Visit routing

## 8.1 Meter-full visits

A meter visit starts when the chore meter reaches the current threshold.

Before severity is computed, `ChoresManager` adds `+2` mood if no chores were completed during that meter cycle.

`GameController` then:

1. Reads `pre_visit_grudge`.
2. Calls `MomLogicHandler.compute_severity(chores_manager)`.
3. Picks the base tree from current mood:
   - `mom_mood <= 3` → `visit_reward`
   - `mom_mood >= 4` → `visit_punishment`
4. Lets special events override the base tree.

### Meter override order

```text
visit_punishment
  ├─ Dad call?       → story_dad_call
  └─ silent treatment? → visit_silent_treatment
```

Dad call conditions:

- `severity >= 4`
- pre-computation grudge `>= 2`
- 20% chance
- once per playthrough

Silent treatment conditions:

- Base tree is `visit_punishment`
- computed severity is `1` or `2`
- 10% chance

## 8.2 Random check-ins

One check-in can fire per round. `ChoresManager` schedules it on a random roll from `2` through `6 + current_channel`.

If Mom is already active, the check-in waits. If the round ends first, it is dropped.

### Check-in precedence

`CastManager` gets the first claim:

1. F12 debug forced claim.
2. `story_derek_quiet`, if pending.
3. `story_dad_cover`, if pending.
4. Highest-priority due story beat.
5. Due delayed Patterson report.
6. Fresh Patterson sighting roll.
7. No cast claim.

If no cast content claims the slot:

1. `force_cool_mom` flag → `checkin_cool_mom`.
2. Inventory has NC-17 → `checkin_caught_nc17`.
3. Inventory has R or PG-13 → `checkin_warning`.
4. Mood `<= 3` and 5% roll → `checkin_cool_mom`.
5. Weighted flavor pool.

### Flavor check-in pool

| Root | Relative weight |
|---|---:|
| `checkin_neutral` | 4 |
| `checkin_nostalgia` | 2 |
| `checkin_gossip` | 2 |
| `checkin_bargain` | 2 |
| `checkin_zone_flavor` | 1 |

Missing ids are skipped. If none can load, the fallback is `checkin_neutral`.

### Check-in severity

- `checkin_caught_nc17` → severity `3`
- every other check-in → severity `0`

A zero-severity check-in can still punish you if its dialog outcome uses `apply_tier` or a direct punishment effect.

---

## 9. Severity and punishment tiers

## 9.1 Mood to severity

| Mood | Base severity |
|---:|---:|
| 1–3 | 0 |
| 4–6 | 1 |
| 7 | 2 |
| 8 | 3 |
| 9 | 4 |
| 10 | 5 |

Severity is clamped to `0–5`.

## 9.2 Severity modifiers

Applied in this order:

1. Mood band.
2. Grudge floor: `severity = max(severity, current_grudge)`.
3. Grudge is consumed and then decays by 1.
4. Defer streak: `severity += defer_streak`.
5. If severity is now `>= 3`, add `low_mood_visits_this_run`.
6. Clamp to `5`.
7. Register the visit as a low-mood visit when applicable.

Limits:

- `grudge`: `0–3`
- `defer_streak`: `0–3`
- `low_mood_visits_this_run`: run-scoped count

### Defer streak

A successful `defer_punishment` outcome:

- Applies no tier now.
- Adds `+1` grudge automatically.
- Increments `defer_streak`.
- Makes the eventual punishment harsher.

When a real punishment tier `>= 1` is applied, the defer streak resets.

## 9.3 Current tier table

| Tier | Name | Picks | Entries |
|---:|---|---:|---|
| 0 | Proud Mom | 1 | reward money, reward consumable, reward power-up |
| 1 | Disappointed | 1 | fine, none, mood delta |
| 2 | Grounded Lite | 1 | fine, debuff, confiscate R-rated power-ups |
| 3 | Confiscation | 1 | confiscate R/NC-17 power-ups, debuff, fine |
| 4 | No Fun | 2 | lock cosmetics, remove mod, two debuffs |
| 5 | Furious | 2 | confiscate R/NC-17 power-ups, fine, remove mods |

### Tier 0 — Proud Mom

| Effect | Weight | Params | Permanent |
|---|---:|---|---:|
| `reward_money` | 2 | `$50–150` | No |
| `reward_consumable` | 2 | `random_power_up_uncommon`, `green_envy`, `the_rarities` | No |
| `reward_powerup` | 1 | `extra_rolls`, `bonus_money`, `full_house_bonus` | No |

### Tier 1 — Disappointed

| Effect | Weight | Params | Permanent |
|---|---:|---|---:|
| `fine` | 3 | `$50` | No |
| `none` | 2 | — | No |
| `mood_delta` | 1 | `+1` mood | No |

### Tier 2 — Grounded Lite

| Effect | Weight | Params | Permanent |
|---|---:|---|---:|
| `fine` | 3 | `$100–150` | No |
| `debuff` | 3 | 1 debuff | No |
| `confiscate_powerups` | 2 | max rating `R` | Yes |

### Tier 3 — Confiscation

| Effect | Weight | Params | Permanent |
|---|---:|---|---:|
| `confiscate_powerups` | 3 | max rating `NC-17`, stack debuffs | Yes |
| `debuff` | 2 | 1 debuff | No |
| `fine` | 2 | `$150` | No |

### Tier 4 — No Fun

| Effect | Weight | Params | Permanent |
|---|---:|---|---:|
| `lock_cosmetics` | 3 | dice colors locked | No |
| `remove_mod` | 3 | 1 mod | Yes |
| `debuff` | 2 | 2 debuffs | No |

### Tier 5 — Furious

| Effect | Weight | Params | Permanent |
|---|---:|---|---:|
| `confiscate_powerups` | 3 | max rating `NC-17`, stack debuffs | Yes |
| `fine` | 2 | `$200–300` | No |
| `remove_mod` | 1 | 2 mods | Yes |

### Tier draw behavior

- `picks` entries are drawn without replacement.
- Entry weights are relative.
- If `picks > entries.size()`, the draw stops at the entry count.
- Lighter tiers are usually temporary; harsher tiers create permanent loss.

---

## 10. Effect reference

## 10.1 Dialog-only effects

These are valid on `MomDialogOutcome`, not in tier entries.

| Effect | Magnitude | Behavior |
|---|---:|---|
| `apply_tier` | `-1`, `0`, `1–5` | Resolves a punishment tier. See below. |
| `storms_off` | Ignored | No punishment now. Marks Mom upset and usually carries grudge into the next visit. Must end the visit. |
| `defer_punishment` | Ignored | No punishment now. Adds `+1` grudge automatically and increments defer streak. Must end the visit. |
| `rep_delta` | Signed int | Changes persistent Rebellion Rep by `magnitude`. |
| `mood_delta` | Ignored | Uses the outcome's `mood_delta` field. |
| `grudge_delta` | Ignored | Uses the outcome's `grudge_delta` field. |

### `apply_tier` magnitude

| Magnitude | Meaning |
|---:|---|
| `-1` | Current severity + 1, clamped to 5 |
| `0` | Current severity |
| `1–5` | Exact tier id |

Use `0` for normal punishment visits. Use `-1` when a response escalates. Use an exact tier only for scripted moments like `checkin_caught_nc17`.

### Sass escalation

If the selected response has `tone = "sassy"` and the outcome applies a punishment tier, the tier increases with the player's persistent Rep tier:

- Every 2 Rep tiers add +1 punishment tier.
- At Rep tier 3 or higher, debuff entries add one extra debuff.
- The tier is clamped to 5.

This means sass should be tempting, not free.

## 10.2 Direct outcome effects

These can be used directly on an outcome.

| Effect | Magnitude | Generated params |
|---|---:|---|
| `fine` | Exact amount | `{"min": amount, "max": amount}`. If magnitude is 0, current code uses `$50`. |
| `debuff` | Count | `{"count": max(magnitude, 1)}` |
| `remove_mod` | Count | `{"count": max(magnitude, 1)}` |
| `confiscate_powerups` | Ignored | `{"max_rating": "NC-17", "stack_debuffs": true}` |
| `reward_money` | Exact amount | If 0, random `$50–150` |
| `reward_consumable` | Ignored | Empty pool; falls back to tier-0 consumable pool |
| `reward_powerup` | Ignored | Empty pool; falls back to tier-0 power-up pool |
| `lock_cosmetics` | Ignored | Locks colors; `permanent` controls duration |
| `mood_delta` | Ignored | Uses `mood_delta` field |
| `none` | Ignored | No direct consequence |

Note: `MomDialogOutcome`'s inline comment says a zero-magnitude direct fine falls back to random `$50–150`. The current implementation uses an exact `$50` fine. Treat `$50` as the actual behavior until the code changes.

## 10.3 Tier entry effects

Tier entries use the same direct effect strings, but with explicit `params` dictionaries.

| Effect | Params |
|---|---|
| `none` | `{}` |
| `fine` | `{"min": int, "max": int}` |
| `debuff` | `{"count": int}` |
| `confiscate_powerups` | `{"max_rating": "R" or "NC-17", "stack_debuffs": bool}` |
| `remove_mod` | `{"count": int}` |
| `lock_cosmetics` | `{}` |
| `mood_delta` | `{"delta": int}` |
| `reward_money` | `{"min": int, "max": int}` |
| `reward_consumable` | `{"pool": Array[String]}` |
| `reward_powerup` | `{"pool": Array[String]}` |

Do not put dialog-only effects in a tier entry. In particular, `defer_punishment` is a player choice and must never be a random tier entry.

## 10.4 Debuff pool

Mom punishment debuffs draw from:

- `lock_dice`
- `costly_roll`
- `disabled_twos`
- `roll_score_minus_one`
- `the_division`

The picker avoids debuffs already active or already applied during the same resolution. If all are active, it picks one anyway.

## 10.5 Fines

A fine checks `PlayerEconomy.can_afford(amount)` before assigning the amount.

- If the player can pay: `fine_amount += amount`.
- If the player cannot pay: Mom applies a debuff instead.

The money is removed later by `apply_consequences()`.

## 10.6 Confiscation

`confiscate_powerups` inspects active power-up definitions by rating.

- `max_rating = "R"`: removes R-rated items.
- `max_rating = "NC-17"`: removes R-rated and NC-17 items.
- With `stack_debuffs = true`, each confiscated NC-17 item also adds a debuff.
- NC-17 confiscation sets `mom_is_furious`.

## 10.7 Rewards

Reward power-ups prefer pool entries the player does not already own. If every candidate is owned, the reward becomes `$75–125` instead.

Direct `reward_consumable` and `reward_powerup` outcomes use empty pools and intentionally fall back to tier 0's pools. Do not reorder tier 0 entries; the handler indexes entries `1` and `2`, and the validation test pins that layout.

---

## 11. Result and consequence pipeline

`apply_outcome()` returns a `MomCheckResult`. `GameController` merges each outcome into one session result.

### `MomCheckResult` fields

| Field | Meaning |
|---|---|
| `removed_power_ups` | Power-up ids to revoke. |
| `removed_mods` | Mod ids to remove permanently without refund. |
| `applied_debuffs` | Debuff ids to enable. |
| `fine_amount` | Money to remove. |
| `reward_money` | Money to grant. |
| `reward_consumable_id` | Consumable id to grant. |
| `reward_powerup_id` | Power-up id to grant. |
| `cosmetics_locked` | Whether dice colors are locked. |
| `cosmetics_lock_permanent` | Whether the lock wipes purchases permanently. |
| `mood_delta` | Mood change to apply after close. |
| `grudge_delta` | Grudge change to apply after close. |
| `storms_off` | Whether Mom stormed off. |
| `deferred` | Whether punishment was deferred. |
| `rep_delta` | Rebellion Rep change. |
| `rebellion_granted` | Whether successful sass granted Rebellion. |
| `tier_id` | Resolved tier id, or `-1` when no tier applied. |
| `mom_is_upset` | Legacy/UI state. |
| `mom_is_furious` | NC-17 found/confiscated. |
| `no_chores_penalty` | Legacy field retained for existing callers/UI. |
| `dialog_text` | Outcome result text. Mostly superseded by `GameController`'s UI flow. |
| `expression` | Outcome result expression. |

### Application order after close

1. Revoke power-ups.
2. Remove mods without refund.
3. Remove fine money.
4. Enable debuffs.
5. Lock cosmetics.
6. Grant money.
7. Grant consumable.
8. Grant power-up.
9. Apply mood delta.
10. Apply grudge delta.
11. Register defer or reset defer streak.

Rep is different: `GameController` applies non-zero `rep_delta` before the dialog closes so the in-dialog Rep meter updates visibly.

Temporary Mom debuffs and cosmetic locks are cleared at round end. Permanent removals do not return.

---

## 12. Rep, Rebellion, and Teacher's Pet

These systems live in `GameController`, not `MomLogicHandler`, but dialog authors shape them through tone and outcome choice.

## 12.1 Rep constants

| Event | Rep |
|---|---:|
| Successful sass | `+8` |
| Successful defer | `+7` |
| Mom storms off after sass | `+9` |
| Polite response during a punishment visit | `-2` |
| Polite response during a check-in | `-1` |

A sassy response is successful when its drawn outcome is one of:

- `none`
- `mood_delta`
- `grudge_delta`
- `storms_off`
- `defer_punishment`

A punished sassy response gives no sass success Rep.

## 12.2 Rebellion

Successful sass builds Rebellion stacks for the round. Rebellion is granted after the dialog closes and expires at round end.

## 12.3 Teacher's Pet

Non-sassy positive responses can qualify when the pre-dialog mood is low enough:

| Pre-dialog mood | Teacher's Pet tier | Activation chance |
|---:|---:|---:|
| 1–2 | 3 | 80% |
| 3 | 2 | 65% |
| 4 | 1 | 50% |
| 5+ | Ineligible | — |

A qualifying response must:

- Not be sassy.
- Avoid tangible punishment.
- Avoid `storms_off`.
- Have `mood_delta <= 0`.
- Have `grudge_delta <= 0`.

Rebellion and Teacher's Pet are mutually exclusive; the newest qualifying Mom-granted buff removes the other.

---

## 13. Cast and story arcs

Mom's World content can claim a check-in before the normal router.

## 13.1 CastCharacter

`CastCharacter` files define identity and reusable flavor data.

| Field | Notes |
|---|---|
| `id` | Unique character id, e.g. `dad`, `patterson`. |
| `display_name` | Human-readable name. |
| `role_description` | Designer-facing role summary. |
| `portrait` | Placeholder texture. |
| `portrait_tint` | Placeholder tint. |
| `zone_affinity` | Mall zones this character is associated with. |
| `line_pools` | Topic → array of BBCode-safe lines. |

Cast members do not speak directly. Mom relays everything.

Current line-pool topics include:

- `sighting`
- `comparison`
- `gossip`
- `greeting`
- `escalation`
- `payoff`
- `zone_reference`

Allowed cast-line BBCode tags are restricted to:

- `[color]`
- `[shake]`
- `[b]`
- `[i]`

## 13.2 MomStoryArc

A story arc is an ordered set of beats.

| Field | Notes |
|---|---|
| `id` | Unique arc id. |
| `character_id` | Owning `CastCharacter.id`. |
| `display_name` | Designer-facing name. |
| `priority` | Higher priority wins when multiple beats are due. |
| `beats` | Ordered `MomStoryBeat` array. `beat_index` must match array position. |

The class comment still says “3-beat” arcs, but current data includes longer arcs. Treat “ordered beats” as the real contract.

## 13.3 MomStoryBeat

A beat links story state to a root dialog node.

| Field | Meaning |
|---|---|
| `beat_index` | Position in the arc. Must match array index. |
| `dialog_node_id` | Root node id in `Resources/Data/Mom/Dialog/`. |
| `min_channel` | Earliest mall zone where it may fire. |
| `min_grudge` | Minimum current grudge. |
| `max_grudge` | Maximum current grudge. |
| `min_rep` | Minimum persistent Rep. |
| `requires_flag` | Required story flag. Empty means none. |
| `requires_chores_done` | Requires at least one completed chore this round. |
| `sets_flag` | Flag set when this beat's session completes. Empty means none. |
| `reward_money` | Money paid after the session. |
| `reward_mood` | Mood delta after the session. Positive makes Mom angrier; negative makes her happier. |
| `reward_rep` | Persistent Rep change after the session. |

Story beat conditions are checked when the check-in slot is decided. The highest-priority due arc wins.

## 13.4 Story flags

There are two flag mechanisms:

1. `MomStoryBeat.sets_flag` sets a flag when the beat root completes.
2. A visited dialog node whose id starts with `flag_` sets a flag of the same name.

Example:

```text
story_question
  └─ outcome followup_node_id = "flag_patterson_doubted"

flag_patterson_doubted
  └─ terminal node
```

When the terminal node is visited, `CastManager` sets:

```text
flags["flag_patterson_doubted"] = true
```

Special case: `patterson_contest_failed` emits the contest-failed signal but is not stored as a flag.

---

## 14. Special events

## 14.1 Patterson sightings

Constants:

| Rule | Value |
|---|---:|
| Fresh sighting chance | 30% |
| Post-truce sighting chance | 15% |
| Base false-report chance | 40% |
| False-report chance at mood 8+ | 25% |
| False-report chance at mood <= 4 | 60% |
| Believed false accusation mood cap | 4 |
| Delayed report wait | 2 zones |

Sighting trees:

- `sighting_true`
- `sighting_false`
- `sighting_false_believed`

`{zone}` in node text is replaced by the claimed zone.

## 14.2 Dad call

Tree: `story_dad_call`

A rare high-heat meter override. Its `apply_tier` outcomes usually use `magnitude = -1`, making the resolved punishment one tier worse than computed severity.

Use a darker `speaker_tint` and a speaker label like `Mom (on the phone with Dad)`.

## 14.3 Dad cover

Tree: `story_dad_cover`

Arms when grudge has previously reached at least 2 and later returns to 0. Once per playthrough.

## 14.4 Derek quiet visit

Tree: `story_derek_quiet`

Takes priority over other cast check-ins when pending. Completing it sets `force_cool_mom`, making the next non-cast check-in use `checkin_cool_mom`.

---

## 15. Text and presentation guidelines

- `mom_text` and `result_text` support BBCode.
- Use BBCode for emotional emphasis, not as a substitute for clear writing.
- Keep response button text short.
- Give the player a real choice. Avoid three labels that differ only in punctuation.
- Use `result_expression` only when the expression changes.
- Empty `result_expression` keeps the current expression.
- Use `{zone}` only for Patterson/zone-aware lines. `GameController` replaces it from the claim context or current zone.
- Keep cast members off-screen. Mom reports their words and actions.

Common tags already used by the data:

```text
[color=green]...[/color]
[color=orange]...[/color]
[color=red]...[/color]
[shake rate=20 level=10]...[/shake]
[wave amp=50 freq=3]...[/wave]
```

---

## 16. Minimal dialog tree template

This is a complete two-response root with one terminal follow-up. Prefer duplicating an existing file in the editor over hand-writing this.

```ini
[gd_resource type="Resource" script_class="MomDialogNode" load_steps=8 format=3]

[ext_resource type="Script" path="res://Scripts/Data/mom_dialog_node.gd" id="1_node"]
[ext_resource type="Script" path="res://Scripts/Data/mom_dialog_response.gd" id="2_resp"]
[ext_resource type="Script" path="res://Scripts/Data/mom_dialog_outcome.gd" id="3_out"]

[sub_resource type="Resource" id="out_polite"]
script = ExtResource("3_out")
weight = 7.0
effect = "mood_delta"
mood_delta = -1
result_text = "[color=green]Good.[/color] Keep it that way."
result_expression = "happy"
ends_visit = true

[sub_resource type="Resource" id="out_sassy_fail"]
script = ExtResource("3_out")
weight = 8.0
effect = "apply_tier"
magnitude = 0
mood_delta = 1
result_text = "[color=red]Wrong tone, kiddo.[/color]"
result_expression = "upset"
ends_visit = true

[sub_resource type="Resource" id="out_sassy_escape"]
script = ExtResource("3_out")
weight = 2.0
effect = "storms_off"
mood_delta = 2
grudge_delta = 1
followup_node_id = "sass_storm_off"
ends_visit = true

[sub_resource type="Resource" id="resp_polite"]
script = ExtResource("2_resp")
button_text = "Everything's handled."
tone = "polite"
outcomes = Array[ExtResource("3_out")]([SubResource("out_polite")])

[sub_resource type="Resource" id="resp_sassy"]
script = ExtResource("2_resp")
button_text = "You're not my boss."
tone = "sassy"
outcomes = Array[ExtResource("3_out")]([SubResource("out_sassy_fail"), SubResource("out_sassy_escape")])

[resource]
script = ExtResource("1_node")
id = "checkin_example"
mom_text = "I heard dice. Again. Should I be concerned?"
expression = "neutral"
speaker_name = "Mom"
speaker_tint = Color(1, 1, 1, 1)
responses = Array[ExtResource("2_resp")]([SubResource("resp_polite"), SubResource("resp_sassy")])
```

After adding this file, it is loaded automatically. To make it reachable, do one of these:

- Add its id to a follow-up link.
- Add it to `CHECKIN_FLAVOR_POOL` in `MomLogicHandler`.
- Reference it from a story arc beat.
- Add it to a router/code path.
- If it is only a structural terminal node, link to it from another outcome.

---

## 17. Common patterns

## 17.1 Safe check-in flavor

Use no tangible effects. Small mood shifts only.

```text
polite  → mood_delta -1
neutral → none or mood_delta 0/+1
sassy   → mood_delta +1/+2, rarely storms_off
```

## 17.2 Normal punishment visit

Use `apply_tier` with `magnitude = 0`.

```text
polite  → mostly apply_tier 0, sometimes no punishment and mood relief
neutral → apply_tier 0
sassy   → apply_tier -1, apply_tier 0, rare storms_off/defer_punishment
```

## 17.3 Scripted confiscation

Use an exact tier only when the fiction demands it.

```text
effect = "apply_tier"
magnitude = 3
```

Do this for the NC-17 catch. Do not use exact tiers for ordinary sass; it bypasses the severity model.

## 17.4 Rare escape valve

Use `storms_off` or `defer_punishment` at low weight.

```text
storms_off:
  +9 Rep through GameController
  no punishment now
  usually grudge +1

 defer_punishment:
  +7 Rep through GameController
  no punishment now
  automatic grudge +1
  defer streak +1
```

Both must end the visit.

## 17.5 Story-only beat

Use `none`, `mood_delta`, `grudge_delta`, or `rep_delta` on outcomes. Put completion rewards on the `MomStoryBeat`, not on every dialog outcome, when the reward belongs to the arc.

---

## 18. Validation and testing

Run the full Mom suite after changing dialog data:

```powershell
& "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --headless --path . Tests/MomSuiteRunner.tscn -- --quit-after
```

With a deterministic seed:

```powershell
& "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --headless --path . Tests/MomSuiteRunner.tscn -- --quit-after --seed 999
```

The suite runs:

1. Data validation.
2. Distribution.
3. Consequences.
4. Coverage simulation.
5. Dialog popup behavior.

### Data validation catches

- Empty node ids.
- Duplicate node ids.
- Empty `mom_text`.
- Null responses or outcomes.
- Empty button text.
- Invalid tones.
- Unknown effects.
- Bad outcome weights.
- Bad `apply_tier` magnitudes.
- Missing follow-up targets.
- Unreachable nodes.
- Invalid tier entries.
- Tier draw errors.
- Tier 0 fallback-pool layout changes.

---

## 19. Pitfalls

### “My new node never appears.”

The directory scan loads it, but loading is not routing. It still needs a root claim or a follow-up link.

### “My `ends_visit = false` outcome still ends.”

Set a non-terminal `followup_node_id`. The current walker ends any outcome with no follow-up.

### “My follow-up text ignored `result_text`.”

That is expected. With a follow-up, the next node supplies the visible text.

### “My terminal follow-up has responses in the data, but the conversation ends.”

Check `followup_node_id` and the target file. If the target node has an empty `responses` array, it is terminal.

### “My direct reward used the wrong pool.”

Direct reward outcomes intentionally use the tier-0 fallback pools. For a custom pool, add or modify a tier entry instead of using a direct outcome.

### “My new effect validates in the Inspector but crashes resolution.”

Add it in all required places:

- `MomPunishmentTier.VALID_EFFECTS`, if it is a tier/direct effect.
- `MomDialogOutcome`’s exported enum.
- `MomLogicHandler._resolve_entry()`.
- `MomDialogOutcome.validate()`.
- `Tests/mom_data_validation_test.gd`’s `KNOWN_EFFECTS`.

### “The tree loops.”

The walker stops after 10 non-terminal beats. This is a guard, not a feature. Rewrite the tree as a directed acyclic graph.

### “The story beat never fires.”

Check, in order:

1. Arc file loads from `Resources/Data/Mom/Cast/`.
2. Arc is not already completed.
3. `beat_index` matches array position.
4. `dialog_node_id` exists.
5. Current channel is at least `min_channel`.
6. Grudge is inside `[min_grudge, max_grudge]`.
7. Rep is at least `min_rep`.
8. `requires_flag` is set.
9. `requires_chores_done` is satisfied.
10. Another higher-priority arc is not claiming the slot.

---

## 20. Design rules of thumb

- Put systemic punishment in tiers. Put authored exceptions in dialog outcomes.
- Let mood decide the baseline. Let player tone modify risk.
- Give sass a real escape chance, but make failure hurt.
- Keep low tiers noisy and survivable. Reserve permanent loss for tiers 2+ and make it legible.
- Use `grudge_delta` for “this is not over.”
- Use `mood_delta` for immediate emotional movement.
- Use `rep_delta` sparingly in story beats. Ordinary sass Rep is already handled by `GameController`.
- Do not make every check-in consequential. Flavor keeps the world alive and makes punishment visits sharper.
- Every weighted response should have at least one outcome the player would consider good.
- If a response can punish, its button text should telegraph risk.

---

## 21. Quick lookup

### I want to add a normal check-in

1. Create `Resources/Data/Mom/Dialog/checkin_my_topic.tres`.
2. Add responses/outcomes.
3. Add `checkin_my_topic` to `MomLogicHandler.CHECKIN_FLAVOR_POOL`.
4. Run the Mom suite.

### I want to add a branch to an existing check-in

1. Create the new node.
2. Add a `followup_node_id` from an outcome in the existing tree.
3. Keep the branch acyclic.
4. Run the Mom suite.

### I want to add a story arc

1. Create one dialog root per beat.
2. Create `Resources/Data/Mom/Cast/arc_my_arc.tres`.
3. Set `character_id`, `priority`, and ordered beats.
4. Use flags for dependencies.
5. Put completion rewards on the beats.
6. Run the Mom suite.

### I want a response to use the current punishment severity

```text
effect = "apply_tier"
magnitude = 0
```

### I want a response to escalate by one tier

```text
effect = "apply_tier"
magnitude = -1
```

### I want a forced punishment tier

```text
effect = "apply_tier"
magnitude = 3
```

### I want no consequence, only dialog

```text
effect = "none"
mood_delta = 0
grudge_delta = 0
```

### I want Mom to remember this

```text
grudge_delta = 1
```

For a stronger deferred bill:

```text
effect = "defer_punishment"
```

### I want a terminal story flag

Create a terminal node with an id like:

```text
flag_my_story_moment
```

Then link an outcome to it:

```text
followup_node_id = "flag_my_story_moment"
```

---

Last verified against `unclemoney/DiceRogue` `main` and the uploaded `Scripts/Core/mom_logic_handler.gd`.
