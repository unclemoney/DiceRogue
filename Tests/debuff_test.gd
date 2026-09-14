extends Node2D

const QUICK_CASH_DATA: ConsumableData = preload("res://Scripts/Consumable/QuickCashConsumable.tres")

@onready var dice_hand: DiceHand       = $GameUI/MarginContainer/MainVBox/MiddleSection/CenterColumn/DiceAreaContainer/DiceHand
@onready var dice_container: Node2D    = $CRTTV/DiceContainer
@onready var score_card: Scorecard     = $ScoreCard
@onready var score_card_ui: Control    = $GameUI/MarginContainer/MainVBox/MiddleSection/RightColumn/ScorecardContainer/ScoreCardUI
@onready var turn_tracker: TurnTracker = $TurnTracker
#@onready var turn_tracker_ui: Control  = $TurnTrackerUI
@onready var game_button_ui: Control   = $GameUI/MarginContainer/MainVBox/MiddleSection/LeftColumn/GameButtonContainer/ContentVBox/GameButtonUI
@onready var game_controller: Node     = $GameController
@onready var pu_manager = get_node_or_null("Managers/PowerUpManager")
@onready var pu_ui = get_node_or_null("GameUI/MarginContainer/MainVBox/UpperSection/PowerUpContainer/ContentVBox/PowerUpUI")
@onready var consumable_ui: ConsumableUI = $GameUI/MarginContainer/MainVBox/MiddleSection/LeftColumn/ConsumableContainer/ContentVBox/ConsumableUI
@onready var consumable_manager: ConsumableManager = $Managers/ConsumableManager
@onready var mod_manager: ModManager = $Managers/ModManager
@onready var debuff_manager: DebuffManager = $Managers/DebuffManager
@onready var challenge_manager: ChallengeManager = $Managers/ChallengeManager
# ChallengeUI node no longer exists in this scene (challenges deprecated;
# stores/target-score rounds replaced them). challenge_manager stays as the
# signal hub for challenge_completed/challenge_failed.
@onready var vcr_ui: VCRTurnTrackerUI = $GameUI/MarginContainer/MainVBox/UpperSection/TurnInfoContainer/ContentVBox/VCRTurnTrackerUI

var _failures: int = 0

func _ready():
	score_card_ui.bind_scorecard(score_card)
	if vcr_ui and turn_tracker:
		vcr_ui.bind_tracker(turn_tracker)

	# Log missing optional components without errors
	if not pu_manager:
		print("Note: PowerUpManager not found - optional component")
	if not pu_ui:
		print("Note: PowerUpUI not found - optional component")
	
	# Add Camera2D + CameraDynamics for juice zoom effects
	var crt = get_node_or_null("CRTTV")
	if crt and not crt.has_node("Camera2D"):
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
		cam.position = Vector2.ZERO
		crt.add_child(cam)
		var dyn = CameraDynamics.new()
		dyn.name = "CameraDynamics"
		cam.add_child(dyn)
		print("[DebuffTest] Added Camera2D + CameraDynamics to CRTTV")
	
	print("Round Manager Test Scene")
	
	# Note: start_game() is called from GameController._on_game_start(),
	# no need to call it manually here.
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--abstinence-smoke"):
		await _run_abstinence_smoke_test()
		if user_args.has("--quit-after"):
			get_tree().quit(0 if _failures == 0 else 1)
		return

	# Headless smoke run support: quit shortly after full scene load
	if user_args.has("--quit-after"):
		await get_tree().create_timer(3.0).timeout
		get_tree().quit()


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[DebuffTest] OK: " + label)
	else:
		push_error("[DebuffTest] FAILED: " + label)
		_failures += 1


func _run_abstinence_smoke_test() -> void:
	print("[DebuffTest] Running Abstinence smoke test")
	await get_tree().process_frame
	await get_tree().process_frame

	_check("game controller exists", game_controller != null)
	_check("turn tracker exists", turn_tracker != null)
	_check("consumable UI exists", consumable_ui != null)
	if _failures > 0:
		return

	if not turn_tracker.is_active:
		turn_tracker.start_new_turn()
		await get_tree().process_frame

	consumable_ui.add_consumable(QUICK_CASH_DATA)
	await get_tree().process_frame
	_check("quick cash consumable added", consumable_ui.has_consumable(QUICK_CASH_DATA.id))

	game_controller.call("apply_debuff", "no_consumables_allowed")
	await get_tree().process_frame

	var active_debuffs: Dictionary = game_controller.get("active_debuffs")
	var abstinence: Debuff = active_debuffs.get("no_consumables_allowed") as Debuff
	_check("abstinence debuff became active", abstinence != null and abstinence.is_active)

	await consumable_ui._fan_out_cards()
	await get_tree().process_frame

	var icon: ConsumableIcon = consumable_ui.get_fanned_icon(QUICK_CASH_DATA.id)
	_check("fanned consumable icon created", icon != null)
	if icon == null:
		return

	_check("use button exists", icon.use_button != null)
	if icon.use_button == null:
		return

	_check("use button disabled while abstinence active", icon.use_button.disabled)
	_check("use button relabeled to DEBUFFED", icon.use_button.text == "DEBUFFED")

	game_controller.call("disable_debuff", "no_consumables_allowed")
	await get_tree().process_frame
	await get_tree().process_frame

	_check("use button re-enabled after abstinence removal", not icon.use_button.disabled)
	_check("use button text restored after abstinence removal", icon.use_button.text == "USE COUPON")

	if _failures == 0:
		print("[DebuffTest] PASS - Abstinence smoke test passed")
	else:
		print("[DebuffTest] FAIL - %d check(s) failed" % _failures)
