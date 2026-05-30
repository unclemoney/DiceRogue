## Plan: UI Container Refactor

Consolidate all game UI into a single deterministic `GameUI` scene using nested Godot containers (MarginContainer, VBoxContainer, HBoxContainer, PanelContainer). Replace manual offset positioning with anchor/container-driven layout. Retire `CorkboardUI` and unused `ui_canvas_layer.tscn`. Adapt existing spine, scorecard, dice, and tracker scenes to fit within bounded containers. Add SubViewport-based glowing titles. Restructure main scene (`DebuffTest.tscn`) so `CRTTV` becomes a full-screen background layer and `GameUI` sits above it. Update `GameController` NodePaths.

---

## Phase 1: Layout Skeleton
*Goal:* Build `GameUI.tscn` with all 13 containers, correct proportions, 8px margins, translucent backgrounds, and simple text labels. No game logic.

**Files**
- New: `Scenes/UI/GameUI.tscn` — master UI scene root (`Control`, `PRESET_FULL_RECT`, 1280×720).
- New: `Scripts/UI/game_ui.gd` — minimal script exposing container references.
- New: `Resources/UI/game_ui_theme.tres` — translucent `StyleBoxFlat` panel style (pastel peach fill at low alpha, Chrome border).
- New: `Tests/UILayoutTest.tscn` — root Node2D with `GameUI` instance on a colored backdrop.

**TODO**
1. Create `GameUI` root with `MarginContainer` (8px all margins).
2. Add `VBoxContainer` (separation = 8) with three sections.
3. `UpperSection` (`HBoxContainer`, stretch_ratio = 17): `TurnInfoContainer` (ratio 25), `PowerUpContainer` (ratio 50), `MoneyContainer` (ratio 25).
4. `MiddleSection` (`HBoxContainer`, stretch_ratio = 166): `LeftColumn` (`VBoxContainer`, ratio 1), `CenterColumn` (`VBoxContainer`, ratio 1), `RightColumn` (`VBoxContainer`, ratio 1).
5. `LeftColumn`: `ChallengeContainer` (ratio 19), `DebuffContainer` (ratio 19), `ConsumableContainer` (ratio 43), `ConsoleContainer` (ratio 19).
6. `CenterColumn`: `TitleContainer` (ratio 30), `DiceAreaContainer` (ratio 60), `ChoreMeterContainer` (ratio 10).
7. `RightColumn`: `ScorecardContainer` (ratio 1).
8. `BottomPanel` (`HBoxContainer`, stretch_ratio = 17): `LeftInfoArea`, `CenterRollArea`, `RightButtonArea`.
9. Apply translucent panel styles to all `PanelContainer` roots.
10. Add temporary `Label` titles (24px) to each container for visual verification.
11. Run `Tests/UILayoutTest.tscn` in editor and verify proportions, margins, and separation at 1280×720.

---

## Phase 2: Glowing Title System
*Goal:* Replace temporary labels with SubViewport-based glowing titles.

**Files**
- New: `Scenes/UI/GlowingTitle.tscn` — `SubViewport` (transparent_bg) + `RichTextLabel` + `WorldEnvironment` (glow enabled) + display `TextureRect`.
- New: `Scripts/UI/glowing_title.gd` — `set_text(text: String)`, `set_glow_intensity(value: float)`.
- Modify: `Scenes/UI/GameUI.tscn` — swap Labels for `GlowingTitle` instances inside each container.

**TODO**
1. Build `GlowingTitle.tscn` with `SubViewport` size matching title text bounds.
2. Configure `WorldEnvironment` Environment resource with glow enabled for Forward+ renderer.
3. Create `glowing_title.gd` API for text and glow control.
4. Instantiate in all 13 containers + Scorecard title (if needed).
5. Test with `Tests/UILayoutTest.tscn` (or `Tests/GlowingTitleTest.tscn`). Verify visible glow and stable FPS with ~13 SubViewports.

---

## Phase 3: Scorecard Integration
*Goal:* Migrate and adapt `ScoreCardUI` into the right-column container.

**Files**
- Modify: `Scenes/UI/score_card_ui.tscn` — remove top "Guhtzee!" title; ensure internal containers use `SIZE_EXPAND_FILL`.
- Modify: `Scripts/UI/score_card_ui.gd` — update `@onready` paths if nodes renamed/moved.
- Modify: `Scenes/UI/GameUI.tscn` — instance `ScoreCardUI` inside `ScorecardContainer`.
- New: `Tests/ScorecardIntegrationTest.tscn`.

**TODO**
1. Remove `RichTextLabel` title from `ScoreCardUI` (title moves to center `TitleContainer`).
2. Adjust `ScoreCardUI` root sizing to fill parent `PanelContainer`.
3. Verify internal `HBoxContainer`/`VBoxContainer`/`GridContainer` stretch flags.
4. Ensure `BestHandPanel`/`TotalScorePanel` layout matches wireframe Additive/Multiplier boxes; adjust if required.
5. Instance into `ScorecardContainer`.
6. Populate mock scores in test scene and verify no overflow at 1280×720.

---

## Phase 4: Core Gameplay UI
*Goal:* Integrate Turn Tracker, Money, Dice Area, and Bottom Panel.

**Files**
- Modify: `Scenes/UI/vcr_turn_tracker_ui.tscn` + `Scripts/UI/vcr_turn_tracker_ui.gd` — remove `MoneyLabel`, adapt to `TurnInfoContainer`.
- New: `Scenes/UI/money_ui.tscn` + `Scripts/UI/money_ui.gd` — extracted money display reacting to `PlayerEconomy.money_changed`.
- Modify: `Scenes/UI/dice_area_container.tscn` + `Scripts/UI/dice_area_container.gd` — reparent `DiceHand` logic; update `calculate_dice_positions()` to derive bounds from container `rect` instead of hardcoded values.
- Modify/Replace: `Scenes/UI/game_button_ui.tscn` + `Scripts/UI/game_button_ui.gd` — new bottom panel layout: left score info, center 360×50 `ROLL` button, right `NextTurn`/`Shop`/`NextRound` buttons.
- Modify: `Scenes/UI/GameUI.tscn` — instance tracker, money, dice area, bottom panel into respective containers.
- New: `Tests/GameplayUITest.tscn`.

**TODO**
1. Strip money display from `VCRTurnTrackerUI`; keep Turn/Roll/Round/Channel labels.
2. Build `MoneyUI` scene with animated label connecting to `PlayerEconomy` autoload.
3. Instance tracker in `TurnInfoContainer`, money in `MoneyContainer`.
4. Reparent `DiceHand` and dice positioning logic into `DiceAreaContainer`. Update position math to use `get_global_rect().size`.
5. Rebuild bottom panel scene per wireframe (remove VCR graphics). Wire signals (`roll_pressed`, `next_turn_pressed`, `shop_button_pressed`, `next_round_pressed`).
6. Connect `TweenFXHelper` hover/press effects to all buttons.
7. Test: dice center within container, buttons align correctly, tracker and money update via signals.

---

## Phase 5: Spine Container Integration
*Goal:* Integrate PowerUp, Challenge, Debuff, Consumable, and Console UIs into bounded containers. Retire `CorkboardUI`.

**Files**
- Modify: `Scenes/UI/power_up_ui.tscn` + `Scripts/UI/power_up_ui.gd` — position spines within `PowerUpContainer`; add container-wide click to fan out.
- Modify: `Scenes/UI/challenge_ui.tscn` + `Scripts/UI/challenge_ui.gd` — adapt to `ChallengeContainer`.
- Modify: `Scenes/UI/debuff_ui.tscn` + `Scripts/UI/debuff_ui.gd` — adapt to `DebuffContainer`.
- Modify: `Scenes/UI/consumable_ui.tscn` + `Scripts/UI/consumable_ui.gd` — adapt to `ConsumableContainer`.
- Modify: `Scenes/UI/gaming_console_ui.tscn` + `Scripts/UI/gaming_console_ui.gd` — adapt to `ConsoleContainer`.
- Modify: `Scripts/Core/game_controller.gd` — remove `CorkboardUI` references; add paths to new container scenes.
- Modify: `Scenes/UI/GameUI.tscn` — instance spine UIs and console UI into containers.
- New: `Tests/SpineIntegrationTest.tscn`.

**TODO**
1. Adapt `PowerUpUI` layout to fit inside `PowerUpContainer` (collapsed summary or scaled grid). Keep `power_up_spine.tscn` unchanged.
2. Adapt `ChallengeUI`, `DebuffUI`, `ConsumableUI` to their containers. Keep individual spine/icon scenes unchanged.
3. Add full-container input detection (`gui_input` or full-size `Button`) that calls `_fan_out_cards()` / `_fold_back_cards()` on click.
4. Adapt `GamingConsoleUI` to `ConsoleContainer`.
5. Remove `CorkboardUI` instantiation and signal connections from `game_controller.gd`.
6. Update GameController NodePaths to point to new container-hosted scenes.
7. Test: clicking each container fans spines radially; second click folds back; no `CorkboardUI` present.

---

## Phase 6: CRTTV, Background, and GameController Hookup
*Goal:* Restructure main scene, remove obsolete nodes, update all controller paths, verify full loop.

**Files**
- Modify: `Tests/DebuffTest.tscn` (or create `Tests/FullGameTest.tscn`) — remove `HutchBackground`, `TVFrame`; make `CRTTV` full screen; add `GameUI` instance.
- Modify: `Scripts/Core/game_controller.gd` — update all 40+ `@export NodePath` references to new tree layout.

**TODO**
1. Delete `HutchBackground` and `TVFrame` nodes from main scene.
2. Set `CRTTV` position to `(0, 0)`; resize `BackgroundSwirl` to fill 1280×720.
3. Instance `GameUI` as sibling to `CRTTV` at full rect.
4. Ensure `CRTOverlay` (CanvasLayer) renders above `GameUI`.
5. Update `game_controller.gd` `@export` paths (e.g., `^"GameUI/MiddleSection/RightColumn/ScorecardContainer/ScoreCardUI"`).
6. Run full gameplay loop: roll → score → shop → next turn → next round.
7. Verify no `get_node()` errors in Output panel.

---

## Phase 7: Polish & Documentation
*Goal:* Theme tuning, debug commands, README update.

**Files**
- Modify: `Resources/UI/game_ui_theme.tres` — finalize colors (pastel teal `#6EE7D6`, magenta `#FF4DA6`, peach `#FFD6C2`, chrome `#E6E6E6`) and fonts.
- Modify: `Scripts/UI/debug_panel.gd` — add commands to toggle UI containers, test glow intensity, force layout rebuild.
- Modify: `README.md` — document `GameUI` scene structure, container layout, and new test scenes.

**TODO**
1. Tune panel background alpha, border widths, and corner radii in theme.
2. Assign fonts: `PumpDemiBoldPlain.otf` titles, `BALLOON1.ttf` subheads, `GillSans Condensed.otf` body, `BrushScriptOpti-Regular.otf` accents.
3. Add debug panel commands per AGENTS.md requirement.
4. Update README with architecture description and test scene list.
5. Final editor playthrough at 1280×720.

---

## Relevant Files
- `Tests/DebuffTest.tscn` — main game scene to restructure.
- `Scenes/UI/GameUI.tscn` (new) — master UI container scene.
- `Scripts/UI/game_ui.gd` (new) — master UI script.
- `Scenes/UI/GlowingTitle.tscn` (new) — reusable glowing title.
- `Scripts/UI/glowing_title.gd` (new) — title control script.
- `Scenes/UI/score_card_ui.tscn` + `Scripts/UI/score_card_ui.gd` — adapt to container.
- `Scenes/UI/game_button_ui.tscn` + `Scripts/UI/game_button_ui.gd` — rebuild bottom panel.
- `Scenes/UI/vcr_turn_tracker_ui.tscn` + `Scripts/UI/vcr_turn_tracker_ui.gd` — remove money, adapt to TurnInfoContainer.
- `Scenes/UI/dice_area_container.tscn` + `Scripts/UI/dice_area_container.gd` — reparent dice hand.
- `Scenes/UI/power_up_ui.tscn` + `Scripts/UI/power_up_ui.gd` — adapt to PowerUpContainer.
- `Scenes/UI/challenge_ui.tscn` + `Scripts/UI/challenge_ui.gd` — adapt to ChallengeContainer.
- `Scenes/UI/debuff_ui.tscn` + `Scripts/UI/debuff_ui.gd` — adapt to DebuffContainer.
- `Scenes/UI/consumable_ui.tscn` + `Scripts/UI/consumable_ui.gd` — adapt to ConsumableContainer.
- `Scenes/UI/gaming_console_ui.tscn` + `Scripts/UI/gaming_console_ui.gd` — adapt to ConsoleContainer.
- `Scenes/UI/chore_ui.tscn` + `Scripts/UI/chore_ui.gd` — adapt to ChoreMeterContainer.
- `Scripts/Core/game_controller.gd` — update NodePath exports.
- `Resources/UI/game_ui_theme.tres` (new) — theme with colors, fonts, panel styles.
- `Scenes/UI/CorkboardUI.tscn` — retire.

---

## Verification
1. **Phase 1:** Run `Tests/UILayoutTest.tscn`. All 13 containers visible with correct proportions. Margins = 8px.
2. **Phase 2:** Titles render with glow. FPS stable (>60) with 13 SubViewports.
3. **Phase 3:** Scorecard populates without overflow. Additive/Multiplier panels visible.
4. **Phase 4:** Dice center within `DiceAreaContainer`. Bottom panel buttons align left/center/right. Tracker shows Turn/Roll/Round/Channel. Money animates on change.
5. **Phase 5:** Clicking any spine container fans out spines; clicking again folds back. `CorkboardUI` absent.
6. **Phase 6:** No `get_node()` errors. Full gameplay loop (roll → score → shop → next round) completes.
7. **Phase 7:** Debug panel has UI toggle commands. README documents `GameUI`.

---

## Decisions
- Retire `CorkboardUI` in favor of separate Challenge/Debuff/Consumable containers.
- Reparent `DiceHand` into `DiceAreaContainer`.
- Center `TitleContainer` displays "Guhtzee!" (moved from ScoreCardUI).
- Use SubViewport + WorldEnvironment per title despite overhead, per user preference.
- Keep existing spine scene files (`power_up_spine.tscn`, `consumable_spine.tscn`, etc.) unchanged; only parent UI scripts (`power_up_ui.gd`, etc.) adapt layout and input handling.
- Upper/Bottom sections use stretch ratio 17 (~8.5% height). May adjust if collapsed spine representation does not fit.

---

## Further Considerations
1. **Upper section height risk:** ~61px may be too small for current spine assets (92px tall). If collapsed spines do not fit, raise stretch ratio to ~25 (12.5%) or implement a scaled summary representation (icon + count) that expands on fan-out.
2. **SubViewport performance:** 13 SubViewports are expensive. If Phase 2 testing reveals frame drops, batch titles into fewer viewports or pivot to a single CanvasLayer global glow.
3. **GameController path fragility:** Rather than updating 40+ string NodePaths, consider migrating critical references to typed `@export var node: NodeType` assigned in the inspector. This eliminates path breakage on future UI refactors.
