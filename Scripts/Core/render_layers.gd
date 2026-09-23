extends RefCounted
class_name RenderLayers

## Central draw-order registry for the whole project.
##
## Single source of truth for every CanvasLayer layer and z_index tier.
## Rules:
## - Scripts MUST use these constants instead of numeric literals.
## - Scene files (.tscn) cannot reference script constants, so their
##   z_index/layer literals must match a tier below; the tier comments
##   record which scenes hold each literal.
## - The debug band (>= 3000) is RESERVED for the debug panel. Never
##   assign any other element a z_index >= Z_DEBUG_ROOT.
##   (Godot's CANVAS_ITEM_Z_MAX is 4096; the band must stay below it.)

# ---------------------------------------------------------------------------
# CanvasLayer tiers (layers outrank z_index across canvases)
# ---------------------------------------------------------------------------

## Default canvas. Legacy UICanvasLayer (ui_canvas_layer.tscn), CRTOverlay (crt_overlay.tscn).
const LAYER_GAME_UI: int = 1
## Shared fan-out card overlay "SpineFanOverlay" (fan_overlay_helper.gd).
const LAYER_FAN_OVERLAY: int = 10
## Debuff fullscreen glow, deliberately one above the fan overlay (debuff_ui.gd).
const LAYER_DEBUFF_GLOW: int = 11
## RoundTransitionOverlay (RoundTransitionOverlay.tscn, round_transition_overlay.gd).
const LAYER_ROUND_TRANSITION: int = 12
## ChoreSelectionPopupLayer, above the round transition overlay but below
## the pause menu and debug panel (game_controller.gd).
const LAYER_CHORE_POPUP: int = 20
## PauseMenu wrapper layer; above the chore popup (game_controller.gd).
const LAYER_PAUSE_MENU: int = 30
## DebugPanel wrapper layer; above every gameplay/UI overlay.
## Tooltips (128) and scene transitions (999) still render above it by design.
const LAYER_DEBUG_PANEL: int = 40
## Tutorial cutout highlight (tutorial_manager.gd).
const LAYER_TUTORIAL_HIGHLIGHT: int = 100
## Tutorial dialog, above the highlight (tutorial_manager.gd).
const LAYER_TUTORIAL_DIALOG: int = 101
## One-shot fullscreen effect flashes (the_replicator_power_up.gd).
const LAYER_SCREEN_FLASH: int = 110
## Shared hover tooltips "TooltipLayer" (game_ui.gd).
const LAYER_TOOLTIP: int = 128
## SceneTransitionManager fade/wipe canvas. Topmost by design.
const LAYER_SCENE_TRANSITION: int = 999

# ---------------------------------------------------------------------------
# z_index tiers
# ---------------------------------------------------------------------------

## Far background, behind everything (shop BackgroundPanel).
const Z_FAR_BACKGROUND: int = -10
## Drop shadows and backdrops (card shadows, main menu bg, shop shelf bg).
const Z_SHADOW: int = -1
## Card-local: frame over card art. Scene literals in ChallengeIcon/consumable_icon/power_up_icon .tscn.
const Z_CARD_FRAME: int = 1
## Card-local: title/info container; also dice StateOverlay (dice.tscn).
const Z_CARD_INFO: int = 2
## Card-local: sell/use buttons and hover label backgrounds (icon .tscn files).
const Z_CARD_BUTTON: int = 3
## Card-local: rarity gem (power_up_icon).
const Z_CARD_RARITY: int = 4
## Card-local: highest hover background (dice ColorLabelBg, dice.tscn).
const Z_CARD_HOVER_BG: int = 5
## In-panel spines (challenge/debuff spines) and local click-catchers (kiosk hit_area).
const Z_SPINE: int = 10
## Consumable spine and kiosk StickerBadge (kiosk_tile.tscn).
const Z_BADGE: int = 15
## Local fullscreen tint FX inside a panel (challenge red vignette).
const Z_LOCAL_FX: int = 40
## Local stamps/dims inside a panel (FAILED stamp, chore dim background).
const Z_LOCAL_STAMP: int = 50
## Scorecard upgrade/downgrade particle bursts; chore details panel.
## Scene literals in ScorecardUpgradeParticles.tscn / ScorecardDowngradeParticles.tscn.
const Z_SCORECARD_PARTICLES: int = 60
## Fullscreen dim under a modal (CRT power-off rect, continue/win dims).
const Z_MODAL_DIM: int = 99
## Standard modal/panel tier. ALL full-screen popups use this
## (shop, pause-adjacent popups, round panels, notifications).
const Z_MODAL: int = 100
## Modal content above its dim (continue/win popup panels).
const Z_MODAL_CONTENT: int = 101
## Fan-out dim background (power-up fan).
const Z_FAN_BG: int = 120
## Fan-out dim background, corkboard variant.
const Z_FAN_BG_ALT: int = 121
## Fan-out cards: z_index = Z_FAN_CARD_BASE + index. Used by ALL fan systems.
const Z_FAN_CARD_BASE: int = 125
## Hovered fan card boost.
const Z_FAN_HOVER: int = 135
## Spine tooltips above fanned icons.
const Z_FAN_TOOLTIP: int = 140
## "+N more" overflow labels above fanned icons.
const Z_FAN_OVERFLOW: int  = 145
## Elevated persistent characters/panels (mom character, console info panel).
const Z_ELEVATED: int = 150
## Gaming console fan background.
const Z_CONSOLE_FAN_BG: int = 180
## Gaming console VIP card.
const Z_CONSOLE_VIP: int = 181
## Critical banners and menus (pause menu, turn banner, challenge banner,
## synergy banner, bot results, debug ProgressBarShowcase).
const Z_BANNER: int = 200
## Settings menu, above banners.
const Z_SETTINGS: int = 300
## Screen FX below modal-adjacent effects (piggy-bank falling coins).
const Z_SCREEN_FX_LOW: int = 499
## Fullscreen flash FX (scoring flash, piggy-bank coin label).
const Z_SCREEN_FX: int = 500
## PowerUp result labels and burst particles ("YAHTZEED!", replicator sparkles).
## Demoted from the old 1000-1001 band which collided with the debug panel.
const Z_POWERUP_FX: int = 600
## Mod sell button. Demoted from 1000; must stay below the debug band.
const Z_MOD_SELL: int = 700
## Shared hover tooltip root (tooltip.tscn). Lives inside LAYER_TOOLTIP,
## so the value only orders content within that layer; kept below the
## reserved debug band so debug stays topmost everywhere.
const Z_TOOLTIP: int = 2000
## RESERVED debug band. Debug panel root (DebugPanel.tscn).
## Godot caps z_index at 4096 (CANVAS_ITEM_Z_MAX); 3000 leaves headroom
## while staying above every gameplay tier.
const Z_DEBUG_ROOT: int = 3000
## RESERVED debug band. Debug panel fullscreen background.
const Z_DEBUG_BG: int = 3001
## RESERVED debug band. Debug panel content container.
const Z_DEBUG_CONTENT: int = 3002
