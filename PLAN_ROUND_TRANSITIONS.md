# Round Transition Visuals — Implementation Plan

## Overview

Add a cinematic round-start/end sequence to DiceRogue:
- **TV Turn-On/Off**: A CRT beam shader on a new overlay inside `CRTTV`. White dot → horizontal line → vertical rectangle sweep. Reverse for turn-off.
- **TV Off State**: Black screen during shop / between rounds.
- **New Round Panel**: Full-screen overlay that flies in after TV turns on. Displays Channel, Round, Debuffs (icons + names), Challenge, and Chore. "Let's Play" button dismisses it.
- **Scorecard Entrance**: After panel dismissal, `ScoreCardUI` flies into the CRTTV area with a bouncy landing.
- **Chore Selection**: Shown during Round 1 intro if no active chore is selected.
- **Button Wave**: Gameplay buttons (Roll, Next Turn, Shop, Next Round) stagger-bounce when enabled at round start.

---

## 1. TV Turn-On/Off Shader (`Scripts/Shaders/tv_power_on.gdshader`)

### Shader Behavior
- `progress` uniform: `0.0` = fully black, `1.0` = fully transparent (content visible)
- Phase A (0.0–0.5): Horizontal expansion. Centered rectangle with width `progress*2` × height `line_thickness`.
- Phase B (0.5–1.0): Vertical expansion. Width stays full; height expands from `line_thickness` to full.
- Edge glow: The boundary of the expanding rectangle gets a bright `beam_color` glow using `smoothstep`.
- Inside mask: Samples `SCREEN_TEXTURE` via `SCREEN_UV`.
- Outside mask: Solid black.

### Uniforms
```glsl
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float line_thickness : hint_range(0.0, 0.1) = 0.02;
uniform vec4 beam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow_size : hint_range(0.0, 0.05) = 0.015;
```

### Implementation Notes
- `shader_type canvas_item; render_mode unshaded;`
- Use `texture(SCREEN_TEXTURE, SCREEN_UV)` to capture siblings behind the overlay.
- The overlay must be the **last child** of `CRTTV` (topmost draw order) so `SCREEN_TEXTURE` contains all other CRTTV children.

---

## 2. TV Power Controller (`Scripts/Effects/tv_power_controller.gd`)

A script attached to the new `TVPowerOverlay` ColorRect inside `CRTTV`.

### API
```gdscript
extends ColorRect
class_name TVPowerController

signal tv_turned_on
signal tv_turned_off

@export var turn_on_duration: float = 1.2
@export var turn_off_duration: float = 0.8

func turn_on() -> void:
    """Play beam expansion from 0→1, then hide overlay."""

func turn_off() -> void:
    """Show overlay, play beam collapse from 1→0, hold black."""

func set_progress(value: float) -> void:
    """Directly set shader progress. Used for debug."""
```

### Behavior
- `turn_on()`: `visible = true`, tween `progress` 0→1, then `visible = false` (performance).
- `turn_off()`: `visible = true`, set `progress = 1.0`, tween 1→0, stay visible (black).
- Tween use `Tween.TRANS_QUAD` / `Tween.EASE_IN_OUT` for smooth CRT beam feel.

---

## 3. CRTManager Integration (`Scripts/Effects/CRTManager.gd`)

Extend CRTManager to orchestrate the power animation with existing CRT/VHS overlays.

### New Exports
```gdscript
@export var tv_power_controller_path: NodePath
@onready var tv_power_controller: TVPowerController = get_node_or_null(tv_power_controller_path)
```

### New Methods
```gdscript
func turn_on_tv() -> void:
    """Play TV turn-on beam animation, then enable CRT effects."""
    if tv_power_controller:
        await tv_power_controller.turn_on()
    enable_crt()

func turn_off_tv() -> void:
    """Disable CRT effects, play TV turn-off beam animation, hold black."""
    disable_crt()
    if tv_power_controller:
        await tv_power_controller.turn_off()
```

### Existing API Preservation
- `enable_crt()` / `disable_crt()` / `set_tv_off()` remain unchanged for mid-round usage.
- `turn_on_tv()` / `turn_off_tv()` are the **dramatic transitions** used only at round boundaries.

---

## 4. Scene Changes — CRTTV (`Tests/DebuffTest.tscn`)

Add a new child to `CRTTV` (must be the **last** child for correct `SCREEN_TEXTURE` sampling):

```
CRTTV (Node2D)
  ├── ... (existing children)
  └── TVPowerOverlay (ColorRect) ← NEW, topmost
       offset_left = -137.0
       offset_top = -276.0
       offset_right = 563.0
       offset_bottom = 284.0
       mouse_filter = 2
       color = Color(1, 1, 1, 1)  # White, shader handles coloring
       material = ShaderMaterial(tv_power_on.gdshader)
       script = tv_power_controller.gd
```

Also update `CRTManager` node in the same scene:
- Set `tv_power_controller_path = NodePath("../TVPowerOverlay")`

---

## 5. New Round Panel

### Scene: `Scenes/UI/new_round_panel.tscn`
Root: `CanvasLayer` (full-screen overlay, outside CRTTV)

### Hierarchy
```
NewRoundPanel (CanvasLayer)
├── Overlay (ColorRect) — semi-transparent black backdrop
└── PanelContainer (PanelContainer) — centered, retro TV-guide styling
    ├── MarginContainer
        └── VBoxContainer
            ├── TitleLabel — "ROUND X"
            ├── ChannelRow — HBox with channel icon + "Channel Y"
            ├── ChallengeRow — challenge name + description
            ├── DebuffsContainer — GridContainer for debuff icons + names
            ├── ChoreRow — current chore (hidden if none)
            └── Let'sPlayButton (Button)
```

### Script: `Scripts/UI/new_round_panel.gd`
```gdscript
extends CanvasLayer
class_name NewRoundPanel

signal panel_dismissed

@onready var overlay: ColorRect = $Overlay
@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/.../TitleLabel
@onready var channel_label: Label = $PanelContainer/.../ChannelLabel
@onready var challenge_label: Label = $PanelContainer/.../ChallengeLabel
@onready var debuffs_container: GridContainer = $PanelContainer/.../DebuffsContainer
@onready var chore_label: Label = $PanelContainer/.../ChoreLabel
@onready var lets_play_button: Button = $PanelContainer/.../Let'sPlayButton

var _tfx: TweenFXHelper

func setup(data: Dictionary) -> void:
    """Populate UI with round data before showing."""

func show_panel() -> void:
    """Animate overlay fade + panel drop_in with TweenFX."""

func _on_lets_play_pressed() -> void:
    """Animate panel drop_out, hide, emit panel_dismissed."""
```

### Animation
- Entrance: Fade in overlay (0.2s), then `TweenFX.drop_in(panel_container, 0.5, 400.0, Vector2(1.2, 0.8))`, then `TweenFX.jelly(panel_container, 0.3, 0.15, 2)` for impact settle.
- Exit: `TweenFX.drop_out(panel_container, 0.4, 300.0)`, fade out overlay, hide CanvasLayer.

### Data Population (`GameController` passes this)
```gdscript
var panel_data = {
    "channel": channel_manager.current_channel,
    "round_number": round_num,
    "challenge_name": challenge_data.display_name,
    "challenge_desc": challenge_data.description,
    "debuffs": debuff_manager.get_active_debuff_ids(),  # fetch names/icons from DebuffData
    "chore_name": chores_manager.current_task.display_name if chores_manager.current_task else ""
}
```

---

## 6. ScoreCardUI Entrance Animation (`Scripts/UI/score_card_ui.gd`)

Add a dedicated entrance method that animates the scorecard flying into the CRTTV area.

### New Method
```gdscript
func animate_entrance() -> void:
    """
    Fly the scorecard in from above the CRTTV area with a bouncy landing.
    Called by GameController after the New Round Panel is dismissed.
    """
```

### Behavior
- Store/restores the designed `position.y` (e.g., `-202.0`).
- Start at `position.y - 400` (above the TV screen).
- Tween `position:y` to target over `0.6s` with `Tween.TRANS_BACK` / `Tween.EASE_OUT`.
- On finish: `TweenFX.jelly(self, 0.3, 0.08, 2)` for bouncy settle.
- Ensure `visible = true` and `modulate.a = 1.0` before animating.

### Scene Note
In `Tests/DebuffTest.tscn`, `ScoreCardUI` is currently at `offset_top = -202`. Since it's a Control inside a Node2D, animate its `position` property.

---

## 7. Gameplay Button Wave (`Scripts/UI/game_button_ui.gd`)

When buttons are enabled at round start, play a staggered scale-bounce wave.

### New Method
```gdscript
func animate_button_wave() -> void:
    """
    Staggered bounce on all enabled gameplay buttons.
    Called at the end of _on_round_started().
    """
    var buttons = [roll_button, next_turn_button, shop_button, next_round_button]
    for i in range(buttons.size()):
        var btn = buttons[i]
        if not btn or btn.disabled or not btn.visible:
            continue
        btn.pivot_offset = btn.size / 2.0
        var tween = create_tween()
        tween.tween_property(btn, "scale", Vector2(1.15, 0.85), 0.08).set_delay(i * 0.06)
        tween.tween_property(btn, "scale", Vector2(0.95, 1.05), 0.08)
        tween.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

### Integration
Call `animate_button_wave()` at the end of `_on_round_started()` in `game_button_ui.gd`, after existing button state setup.

---

## 8. GameController Round Intro Sequence (`Scripts/Core/game_controller.gd`)

### New State
```gdscript
var _round_transition_tv_off: bool = false
var _new_round_panel: NewRoundPanel = null
```

### Modified Flow: Shop Open → TV Off
In `_on_stats_panel_continue()`:
```gdscript
func _on_stats_panel_continue() -> void:
    # ... award bonuses ...
    _round_transition_tv_off = true
    if crt_manager:
        await crt_manager.turn_off_tv()
    if round_manager:
        round_manager.complete_round()
    _open_shop_ui()
```

### Modified Flow: Shop Close
In `_open_shop_ui()`, when **closing** the shop:
```gdscript
# Existing:
# crt_manager.enable_crt()  ← REMOVE or gate behind _round_transition_tv_off
if _round_transition_tv_off:
    # Keep TV off between rounds
    pass
else:
    crt_manager.enable_crt()  # mid-round shop close only
```

### New Flow: Next Round Pressed
In `_on_next_round_pressed()` (new handler for `game_button_ui.next_round_pressed`):
```gdscript
func _on_next_round_pressed() -> void:
    _round_transition_tv_off = false
    
    var current_round_num = round_manager.get_current_round_number()
    var is_first_round = not game_button_ui.first_roll_done
    var intro_round_num = current_round_num if is_first_round else current_round_num + 1
    
    # 1. TV Turn On
    if crt_manager:
        await crt_manager.turn_on_tv()
    
    # 2. Hide scorecard so it can animate in later
    if score_card_ui:
        score_card_ui.visible = false
    
    # 3. Show New Round Panel
    await _show_new_round_panel(intro_round_num)
    
    # 4. Scorecard Entrance
    if score_card_ui:
        await score_card_ui.animate_entrance()
    
    # 5. Chore Selection (Round 1 only, if no active chore)
    if is_first_round and chores_manager:
        if chores_manager.pending_chore_selection or chores_manager.current_task == null:
            _show_chore_selection_popup()
            while _chore_selection_popup and is_instance_valid(_chore_selection_popup) and _chore_selection_popup.visible:
                await get_tree().process_frame
    
    # 6. Start Actual Round
    if is_first_round:
        round_manager.start_round(1)
    else:
        round_manager.complete_round()
        round_manager.start_round(current_round_num + 1)
```

### New Helper: `_show_new_round_panel(round_num: int)`
```gdscript
func _show_new_round_panel(round_num: int) -> void:
    if not _new_round_panel or not is_instance_valid(_new_round_panel):
        _new_round_panel = NewRoundPanel.new()
        _new_round_panel.name = "NewRoundPanel"
        add_child(_new_round_panel)
        _new_round_panel.panel_dismissed.connect(_on_new_round_panel_dismissed)
    
    var data = _build_round_panel_data(round_num)
    _new_round_panel.setup(data)
    await _new_round_panel.show_panel()
```

### Modified: GameButtonUI._on_next_round_button_pressed()
Remove direct `round_manager.start_round()` / `complete_round()` calls. Keep dice clearing and scorecard reset, then emit signal.

```gdscript
func _on_next_round_button_pressed() -> void:
    # ... existing cleanup (cancel anims, clear dice, reset scorecard) ...
    emit_signal("next_round_pressed")
```

### Signal Connection
In `GameController._ready()`:
```gdscript
if game_button_ui:
    game_button_ui.next_round_pressed.connect(_on_next_round_pressed)
```

---

## 9. Debug Commands (`Scripts/UI/debug_panel.gd`)

Add a new tab "Round Transitions" with buttons:

| Command | Action |
|---------|--------|
| `tv_on` | Instantly turn TV on (`crt_manager.turn_on_tv()` at 10× speed or direct `set_progress(1.0)`) |
| `tv_off` | Instantly turn TV off |
| `show_round_panel` | Show New Round Panel with dummy data |
| `skip_intro` | Toggle `_skip_round_intro` flag in GameController (skips TV + panel for rapid testing) |
| `wave_buttons` | Trigger `game_button_ui.animate_button_wave()` |

---

## 10. Test Scene

Create `Tests/RoundTransitionTest.tscn`:
- Minimal scene with CRTTV, CRTManager, TVPowerOverlay, and a dummy NewRoundPanel.
- Buttons to trigger `turn_on()`, `turn_off()`, and panel show/hide.
- Verify shader renders correctly and panel flies in/out.

---

## 11. TODO List

### Shader & TV Power
- [ ] Create `Scripts/Shaders/tv_power_on.gdshader`
- [ ] Create `Scripts/Effects/tv_power_controller.gd`
- [ ] Modify `Scripts/Effects/CRTManager.gd` (add `turn_on_tv()` / `turn_off_tv()`)
- [ ] Add `TVPowerOverlay` ColorRect to `Tests/DebuffTest.tscn` (last child of CRTTV)
- [ ] Wire `CRTManager.tv_power_controller_path` in scene

### New Round Panel
- [ ] Create `Scenes/UI/new_round_panel.tscn`
- [ ] Create `Scripts/UI/new_round_panel.gd`
- [ ] Add panel instance to `Tests/DebuffTest.tscn` (as sibling of GameController, outside CRTTV)
- [ ] Build `_build_round_panel_data()` helper in GameController

### Scorecard Entrance
- [ ] Add `animate_entrance()` to `Scripts/UI/score_card_ui.gd`
- [ ] Ensure `ScoreCardUI` is hidden before intro sequence in GameController

### Button Wave
- [ ] Add `animate_button_wave()` to `Scripts/UI/game_button_ui.gd`
- [ ] Call it at end of `_on_round_started()`

### GameController Flow
- [ ] Add `_on_next_round_pressed()` to `Scripts/Core/game_controller.gd`
- [ ] Modify `_on_stats_panel_continue()` to turn off TV
- [ ] Modify `_open_shop_ui()` to respect `_round_transition_tv_off`
- [ ] Modify GameButtonUI._on_next_round_button_pressed() to emit signal only
- [ ] Add `_round_transition_tv_off` state tracking

### Chore Integration
- [ ] Ensure chore popup shows during Round 1 intro only when needed
- [ ] Suppress duplicate chore popup from existing signal path during intro

### Debug & Tests
- [ ] Add debug commands to `Scripts/UI/debug_panel.gd`
- [ ] Create `Tests/RoundTransitionTest.tscn`
- [ ] Run full game flow: Round 1 → Shop → Round 2
- [ ] Verify TV off/on animations play at correct times
- [ ] Verify New Round Panel data is accurate
- [ ] Verify Scorecard bounces into CRTTV bounds
- [ ] Verify button wave plays on round start
- [ ] Verify first-round chore selection appears correctly

---

## 12. Creative Polish Ideas (Post-MVP)

1. **Phosphor Bloom**: Add RGB chromatic aberration to the beam edge in the shader.
2. **Static Snap**: Brief VHS static flash at the horizontal→vertical phase transition.
3. **Scanline Reveal**: Scanlines fade in progressively as the vertical sweep completes.
4. **Retro TV Guide Theme**: New Round Panel styled like an 80s cable TV menu (colored banners, pixel borders).
5. **"Commercial Break" Static**: Brief static burst before chore selection popup on Round 1.
6. **Audio Hook**: Add TV hum / degauss sound calls to `AudioManager` at `tv_turned_on` / `tv_turned_off`.
