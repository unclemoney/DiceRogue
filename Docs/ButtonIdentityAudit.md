# Button Identity Audit

## Scope

This audit covers live, player-facing gameplay UI and front-end menu surfaces.

Included control types:

- `Button`
- `TextureButton`
- `CheckButton`
- `OptionButton`
- `Control` wrappers that behave like buttons through an overlay `Button`

Excluded from the primary list:

- `Tests/`
- debug-only panels
- addon tooling
- backup and orphan scenes unless they affect cleanup risk

## Target Standard

The target identity is the glass-button pattern defined in `Docs/GlassButtonShaderStandard.md` and implemented by `Scripts/UI/glass_action_button.gd`.

Baseline requirements for a standard-compliant glass button:

- root `Control` owns the button surface
- full-rect `ColorRect` named `ShaderRect`
- `ShaderMaterial` applied to the `ColorRect`
- transparent overlay `Button` handles input
- text/content lives above the shader surface
- colors come from a palette dictionary instead of hard-coded one-off button colors
- hover and state visuals are driven by shader params such as `hover_strength`, `pulse_strength`, `press_flash`, and `disabled_factor`

Status buckets used below:

- `Standard-compliant`: uses `GlassActionButton` directly
- `Standard-variant`: structurally follows the glass pattern but is implemented as a custom one-off
- `Native exception`: not a glass button, but likely should remain a specialized control family
- `Non-standard/outlier`: live button surface that does not follow the standard and is a likely remediation candidate

## Active Button Families

| Family | Mechanism | Primary assets | Live use |
| --- | --- | --- | --- |
| Glass standard | `GlassActionButton` wrapper with shader-backed `ColorRect` + overlay `Button` | `Scripts/UI/glass_action_button.gd`, `Scripts/Shaders/shop_reroll_button_glass.gdshader` | Core gameplay CTA buttons, dialog choices, popup confirms |
| Glass variant | Custom shell with `ShaderRect` + overlay `Button` | `Scripts/UI/roll_button_ui.gd`, `Scripts/Shaders/roll_button_glass.gdshader`; `Scripts/UI/shop_ui.gd` reroll shell | Roll button, shop reroll |
| Action theme family | Native `Button` with flat purple/teal styleboxes | `Resources/UI/action_button_theme.tres`, `Resources/UI/action_button_theme_no_panel.tres` | Shop close, round-transition buttons |
| Front-end menu theme family | Native `Button` with textured teal button frames | `Resources/UI/main_menu_theme.tres`, `Resources/Art/UI/button_normal_teal.png`, `button_hover_teal.png`, `button_press_teal.png` | Main menu, pause menu, themed dialogs |
| Scorecard row family | Transparent button row with specialized row shaders | `Scenes/UI/Scorecard/scorecard_row.tscn`, `Scripts/Shaders/row_highlight_pulse.gdshader`, `row_blinds.gdshader` | Scorecard category rows |
| Coupon family | Coupon-specific theme variations on native buttons | `Resources/UI/coupon_theme.tres`, `Resources/Art/Background/coupon_atlas.png` | Coupon consumables |
| Card micro-button family | Direct `StyleBoxFlat` styling on tiny card buttons | `Scripts/Consumable/consumable_icon.gd`, `Scripts/UI/power_up_icon.gd` | Consumable Use/Sell, PowerUp Sell |
| Kiosk tile family | Inline neon magenta sell button styling | `Scripts/UI/kiosk_tile.gd` | Power-up kiosk sell button |
| Console family | Inline VCR + `StyleBoxFlat` buttons inside custom panel shells | `Scripts/UI/gaming_console_ui.gd`, `gaming_console_spine.gd`, `gaming_console_vip_card.gd` | Console activate and adjustment controls |
| Settings family | Inline panel/menu `StyleBoxFlat` buttons and semantic toggles | `Scripts/UI/settings_menu.gd` | Settings buttons, binds, option and check controls |
| Tutorial family | Inline purple tutorial dialog buttons | `Scripts/UI/tutorial_dialog.gd` | Tutorial next and skip |
| Unlock notification family | Single inline teal OK button | `Scripts/UI/unlock_notification_ui.gd` | Unlock acknowledgement popup |

Note: no live scoped `TextureButton` surfaces were found in the current player-facing flow. `TextureButton` usage appears only in backup or orphaned scenes.

## Gameplay Audit

| Area | Button surface | Owner | Control type | Current implementation | Status | Notes and likely target |
| --- | --- | --- | --- | --- | --- | --- |
| Core HUD | `NextRoundButton`, `ShopButton`, `NextTurnButton` | `Scenes/UI/game_button_ui.tscn`, `Scripts/UI/game_button_ui.gd` | `Control` wrappers with `GlassActionButton` script | Standard glass wrapper using `shop_reroll_button_glass.gdshader`; per-button palettes defined in `game_button_ui.gd` | Standard-compliant | Keep. This is the reference family for general gameplay CTA buttons. |
| Core HUD | `RollButton` | `Scenes/UI/roll_button_ui.tscn`, `Scripts/UI/roll_button_ui.gd` | `Control` shell + overlay `Button` | Custom shader shell with `ShaderRect`, `ContentMargin`, labels, and transparent `RollButton`; uses `roll_button_glass.gdshader` with hard-coded roll palette | Standard-variant | Keep as a specialized primary-action variant. Later cleanup could make the palette contract match the standard more closely. |
| Scorecard | Score row buttons | `Scenes/UI/Scorecard/scorecard_row.tscn`, `Scripts/UI/Scorecard/scorecard_row.gd` | `Button` subclass | Transparent native button with hover stylebox plus `row_highlight_pulse.gdshader` and `row_blinds.gdshader` overlays | Native exception | This is a score row, not a CTA. It should stay a specialized row-control family unless the whole scorecard is redesigned. |
| Shop | Footer page arrows | `Scripts/UI/shop_ui.gd` | `Button` | Inline dark-blue and gold `StyleBoxFlat` states via `_apply_footer_arrow_button_styling()` | Non-standard/outlier | Strong gameplay remediation candidate. Best target is a compact glass-arrow variant or a sanctioned small-button family. |
| Shop | Footer reroll shell | `Scripts/UI/shop_ui.gd` | `Control` shell + overlay `Button` | Manual glass shell using `shop_reroll_button_glass.gdshader`, green palette, and overlay `RerollButton` | Standard-variant | Visually aligned with the standard, but duplicated instead of reusing `GlassActionButton`. Good consolidation target. |
| Shop | `CloseButton` | `Scenes/UI/shop_ui.tscn` | `Button` | Inherits `action_button_theme_no_panel.tres` from the scene | Non-standard/outlier | Live gameplay close button that does not match the glass family. Candidate for migration. |
| Shop card | `BuyButton` | `Scenes/Shop/shop_item.tscn`, `Scripts/Shop/shop_item.gd` | `GlassActionButton` | Amber/gold glass palette on `GlassActionButton`; card itself uses `shop_item_theme.tres` and shop-card shaders | Standard-compliant | Keep. Good example of using the standard with a role-specific palette. |
| Consumables | Coupon `UseButton`, `SellButton` | `Scenes/Consumable/consumable_coupon.tscn`, `Resources/UI/coupon_theme.tres` | `Button` | Theme variations `CouponPrimaryButton` and `CouponSecondaryButton` on a coupon-paper panel using `coupon_atlas.png` | Native exception | Intentionally diegetic. This is a reasonable exception if coupon cards should preserve their paper identity. |
| Consumables | Card `UseButton`, `SellButton` | `Scripts/Consumable/consumable_icon.gd`, `Scenes/Consumable/consumable_icon.tscn` | `Button` | Tiny direct-style buttons using inline gold-on-plum `StyleBoxFlat`; root card uses `card_perspective.gdshader`; `UseButton` sits inside the `powerup_hover_theme` context | Non-standard/outlier | High-value remediation target. These are live gameplay action buttons and currently form a separate ad-hoc micro-button family. |
| Power-ups | Card `SellButton` | `Scripts/UI/power_up_icon.gd`, `Scenes/PowerUp/power_up_icon.tscn` | `Button` | Same direct gold-on-plum micro-button styling as consumables; card tooltip family uses `powerup_hover_theme.tres`; card art uses perspective shader treatment | Non-standard/outlier | High-value remediation target, especially if item action buttons should share one identity. |
| Power-up kiosk | Tile `SellButton` | `Scenes/PowerUp/kiosk_tile.tscn`, `Scripts/UI/kiosk_tile.gd` | `Button` | Inline neon magenta `StyleBoxFlat` button with VCR font and glossy checkout-key look | Non-standard/outlier | Strong-looking button, but still a separate one-off family. Candidate for migration or for explicit sanction as a kiosk-only variant. |
| Game start selector | `StartButton` | `Scenes/Managers/ChannelManagerUI.tscn`, `Scripts/Managers/channel_manager_ui.gd` | `GlassActionButton` | Uses mall-map glass palette (`MallMapRendererScript.MALL_GLASS_PALETTE`) | Standard-compliant | Keep. |
| Game start selector | Dice set `<` and `>` buttons | `Scripts/Managers/channel_manager_ui.gd` | `GlassActionButton` | Small glass buttons created by `_create_dice_arrow_button()` with the mall-map palette | Standard-compliant | Keep. Good small-size standard usage. |
| Carry-over flow | Per-type toggle buttons | `Scenes/UI/CarryOverPanel.tscn`, `Scripts/UI/carry_over_panel.gd` | `GlassActionButton` | Toggle-mode glass buttons with per-type palettes and selected-state glow | Standard-compliant | Keep. |
| Carry-over flow | `ConfirmButton` | `Scenes/UI/CarryOverPanel.tscn`, `Scripts/UI/carry_over_panel.gd` | `GlassActionButton` | Purple confirm palette on `GlassActionButton` | Standard-compliant | Keep. |
| Chore flow | Easy/Hard select buttons | `Scripts/UI/chore_selection_popup.gd` | `GlassActionButton` | `SELECT CHORE` buttons use accent-driven glass palettes tied to easy/hard card color | Standard-compliant | Keep. |
| Mom dialog | Response buttons | `Scenes/UI/mom_dialog_popup.tscn`, `Scripts/UI/mom_character.gd` | `GlassActionButton` | Dialogue response buttons built with `GlassActionButton` and `MOM_BUTTON_PALETTE` | Standard-compliant | Keep. |
| Mom dialog | `OK` close button | `Scenes/UI/mom_dialog_popup.tscn`, `Scripts/UI/mom_character.gd` | `GlassActionButton` | Same glass family as the response buttons | Standard-compliant | Keep. |
| Mall map | `CloseButton` | `Scenes/UI/MallMapPopup.tscn`, `Scripts/UI/mall_map_popup.gd` | `GlassActionButton` | Mall glass palette close button | Standard-compliant | Keep. |
| End-of-round stats | `ContinueButton` | `Scenes/UI/EndOfRoundStatsPanel.tscn`, `Scripts/UI/end_of_round_stats_panel.gd` | `GlassActionButton` | Teal glass CTA labeled `Head to Shop` or `Head to Next Mall Zone` | Standard-compliant | Keep. |
| Round transition | `KeepPlayingButton`, `EnterShopButton` | `Scenes/UI/RoundTransitionOverlay.tscn`, `Scripts/UI/round_transition_overlay.gd` | `Button` | Native buttons themed with `action_button_theme.tres`; `Enter Shop` gets extra highlight treatment | Non-standard/outlier | Gameplay CTA buttons that sit close to the glass family in purpose, but not in implementation. Good remediation target. |
| Loaded dice | Value buttons and `BackButton` | `Scenes/UI/loaded_die_picker.tscn`, `Scripts/UI/loaded_die_picker.gd` | `Button` | Buttons inside a panel themed with `powerup_hover_theme.tres`; theme supplies panel chrome and font, but not a full button identity | Non-standard/outlier | Good remediation candidate. The panel is styled; the buttons are not. |
| Gaming console | `Activate` button on spine card | `Scenes/UI/gaming_console_spine.tscn`, `Scripts/UI/gaming_console_spine.gd` | `Button` | Inline console-family `StyleBoxFlat` via `_apply_button_style()` with VCR font and panel accent colors | Non-standard/outlier | Live gameplay action button with its own mini-family. Candidate for migration or explicit exception. |
| Gaming console | `Activate` button on VIP card | `Scenes/UI/gaming_console_vip_card.tscn`, `Scripts/UI/gaming_console_vip_card.gd` | `Button` | Same inline console-family `StyleBoxFlat` treatment | Non-standard/outlier | Same recommendation as the spine card. |
| Gaming console | NES `+1`, `-1`, `+1 ALL`, `-1 ALL` controls | `Scripts/UI/gaming_console_ui.gd` | `Button` | Inline console-family `StyleBoxFlat` buttons with accent-colored borders and VCR font | Non-standard/outlier | Utility gameplay buttons; they need either a sanctioned console subfamily or migration to a compact standard family. |
| Unlock flow | `OKButton` | `Scenes/UI/UnlockNotificationUI.tscn`, `Scripts/UI/unlock_notification_ui.gd` | `Button` | Inline teal button with custom `StyleBoxFlat` states inside a `powerup_hover_theme` panel | Non-standard/outlier | Candidate for migration if gameplay popups should share the glass identity. |

## Front-End Audit

| Area | Button surface | Owner | Control type | Current implementation | Status | Notes and likely target |
| --- | --- | --- | --- | --- | --- | --- |
| Main menu | Profile buttons (3 slots) | `Scenes/UI/MainMenu.tscn`, `Scripts/UI/main_menu.gd` | `Button` | Default path uses `main_menu_theme.tres`, which provides textured teal button states from `button_normal_teal.png`, `button_hover_teal.png`, and `button_press_teal.png`; script has a programmatic fallback when `use_theme_styling` is disabled | Non-standard/outlier | This is a coherent second family, not random drift. Decide whether menus keep a separate identity or migrate. |
| Main menu | Nav buttons (`NEW GAME`, `CONTINUE`, `SETTINGS`, tutorial, `QUIT`) | `Scenes/UI/MainMenu.tscn`, `Scripts/UI/main_menu.gd` | `Button` | Same `main_menu_theme.tres` textured front-end family by default; programmatic fallback exists | Non-standard/outlier | Same decision point as profile buttons. |
| Main menu | Rename dialog `DELETE PROFILE` button and dialog OK/Cancel controls | `Scripts/UI/main_menu.gd` | `Button` and themed `ConfirmationDialog` buttons | Dialogs use `main_menu_theme.tres`; the explicit delete button adds text-color overrides on top | Non-standard/outlier | Same front-end family. Keep together if menus remain a separate identity. |
| Pause menu | `RESUME`, `SAVE`, `SETTINGS`, `MAIN MENU` | `Scenes/UI/PauseMenu.tscn`, `Scripts/UI/pause_menu.gd` | `Button` | Default path uses `main_menu_theme.tres`; programmatic fallback mirrors main-menu styles | Non-standard/outlier | Front-end family reused in gameplay pause flow. Review whether pause should follow menus or gameplay glass CTA identity. |
| Settings | Header `X` close button | `Scenes/UI/SettingsMenu.tscn`, `Scripts/UI/settings_menu.gd` | `Button` | Inline magenta-accent `StyleBoxFlat` menu button via `_apply_button_style()` | Non-standard/outlier | Clear candidate if the settings overlay should align to the glass standard. |
| Settings | `APPLY`, reset buttons, keybind capture buttons | `Scenes/UI/SettingsMenu.tscn`, `Scripts/UI/settings_menu.gd` | `Button` | Inline menu-family `StyleBoxFlat` buttons with VCR font | Non-standard/outlier | Forms a consistent settings-only family, but not the glass standard. |
| Settings | Resolution selector, fullscreen toggle, FX toggles | `Scenes/UI/SettingsMenu.tscn`, `Scripts/UI/settings_menu.gd` | `OptionButton`, `CheckButton` | Semantic form controls styled with the same inline menu family | Native exception | These are semantic controls. They should be judged on theme alignment, not forced into a literal glass CTA wrapper. |
| Tutorial | `Skip Tutorial`, `Next ->` | `Scripts/UI/tutorial_dialog.gd` | `Button` | Inline purple tutorial dialog `StyleBoxFlat` buttons | Non-standard/outlier | Separate one-off family. Candidate for migration if tutorials should match the rest of the front-end/gameplay language. |

## Standard-Compliant Surfaces

These areas already follow the glass-button direction closely enough to treat as approved baselines:

- `GameButtonUI` HUD buttons
- `ShopItem` buy button
- `ChannelManagerUI` start and dice-carousel buttons
- `CarryOverPanel` toggles and confirm button
- `ChoreSelectionPopup` select buttons
- `MomCharacter` response and close buttons
- `MallMapPopup` close button
- `EndOfRoundStatsPanel` continue button

These areas are close but not fully standardized because they duplicate the pattern instead of reusing `GlassActionButton` directly:

- `RollButtonUI`
- shop footer reroll shell in `shop_ui.gd`

## Primary Outliers To Review First

If the goal is to reduce visual drift fast, these are the highest-value gameplay surfaces to decide first:

1. `shop_ui.gd` footer arrows and `shop_ui.tscn` close button
2. `consumable_icon.gd` and `power_up_icon.gd` card action buttons
3. `kiosk_tile.gd` sell button
4. `round_transition_overlay.gd` action buttons
5. `loaded_die_picker.gd` value and back buttons
6. `gaming_console_spine.gd`, `gaming_console_vip_card.gd`, and `gaming_console_ui.gd` buttons
7. `unlock_notification_ui.gd` OK button

The biggest front-end identity decision is separate from gameplay cleanup:

1. Keep `main_menu_theme.tres` as an intentional second button family for menus and pause/settings
2. Or migrate front-end menus toward the glass standard for one global identity

## Legacy and Cleanup Notes

These button-like scenes were not included in the primary audit because they do not appear to be part of the live scoped flow:

- `Scenes/UI/PowerUpIcon.tscn` (`TextureButton` root, no live reference found)
- `Scenes/Challenge/ChallengeIconBackup.tscn`
- `Scenes/Consumable/ConsumableIconBackup.tscn`
- `Scenes/Debuff/DebuffIconBackup.tscn`
- `Scenes/PowerUp/power_up_icon_backup.tscn`

These should be reviewed during cleanup so legacy button families do not confuse the remediation pass.