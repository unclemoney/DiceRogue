extends Node

const MoneyBagsScript = preload("res://Scripts/PowerUps/money_bags_power_up.gd")
const MoneyWellSpentScript = preload("res://Scripts/PowerUps/money_well_spent_power_up.gd")
const PoorHouseScript = preload("res://Scripts/Consumable/poor_house_consumable.gd")
const MoneyUIScript = preload("res://Scripts/UI/money_ui.gd")
const MomLogicHandlerScript = preload("res://Scripts/Core/mom_logic_handler.gd")
const MomDialogOutcomeScript = preload("res://Scripts/Data/mom_dialog_outcome.gd")

var _failures := 0


class TestGameController extends GameController:
	func _ready() -> void:
		pass


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	PlayerEconomy.reset_to_starting_money()
	_check(is_equal_approx(PlayerEconomy.money, 1.0), "starting balance is 1.0")
	_check(NumberFormatter.format_money(1.0) == "$1.00", "starting balance formats as $1.00")
	_check(NumberFormatter.format_money(-0.05) == "-$0.05", "negative money keeps two decimals")

	var money_ui = MoneyUIScript.new()
	add_child(money_ui)
	var money_label: Label = money_ui.get_node("MarginContainer/CenterContainer/VBoxContainer/MoneyLabel")
	_check(money_label.text == "$1.00", "MoneyUI displays $1.00")
	money_ui.queue_free()

	var bonus_data: PowerUpData = load("res://Scripts/PowerUps/BonusMoneyPowerUp.tres")
	_check(is_equal_approx(bonus_data.price, 0.5), "representative shop cost is $0.50")

	var die := Dice.new()
	die.value = 5
	die.color = DiceColor.Type.GREEN
	var effects: Dictionary = DiceColorManager.calculate_color_effects([die], [])
	_check(is_equal_approx(effects.green_money, 0.05), "green face 5 pays $0.05")
	die.free()

	var round_manager := RoundManager.new()
	_check(is_equal_approx(round_manager.calculate_score_above_target_bonus(130, 100), 0.3), "30 points above target pays $0.30")
	var scorecard := Scorecard.new()
	_check(is_equal_approx(round_manager.calculate_empty_category_bonus(scorecard), 0.65), "13 empty categories pay $0.65")
	scorecard.free()
	round_manager.free()

	PlayerEconomy.money = 2.5
	var money_bags = MoneyBagsScript.new()
	add_child(money_bags)
	money_bags._on_about_to_score(Scorecard.Section.UPPER, "ones", [])
	_check(is_equal_approx(ScoreModifierManager.get_total_multiplier(), 3.5), "Money Bags preserves 3.50x at $2.50")
	money_bags._on_score_assigned(Scorecard.Section.UPPER, "ones", 0)
	money_bags.queue_free()

	var previous_spent: float = Statistics.total_money_spent
	Statistics.total_money_spent = 2.5
	var well_spent = MoneyWellSpentScript.new()
	add_child(well_spent)
	well_spent.apply(null)
	_check(well_spent.get_current_additive() == 5, "Money Well Spent gives +5 at $2.50")
	well_spent.remove(null)
	well_spent.queue_free()
	Statistics.total_money_spent = previous_spent

	var controller := TestGameController.new()
	PlayerEconomy.reset_to_starting_money()
	var mod_payout: float = controller.award_score_time_power_up_money(0.08, "test_mod_money")
	_check(is_equal_approx(mod_payout, 0.08) and is_equal_approx(PlayerEconomy.money, 1.08), "Mod Money pays $0.08")

	controller.scorecard = Scorecard.new()
	controller.add_child(controller.scorecard)
	PlayerEconomy.money = 5.0
	var poor_house = PoorHouseScript.new()
	add_child(poor_house)
	poor_house.apply(controller)
	_check(ScoreModifierManager.get_additive("poor_house_bonus") == 250, "Poor House converts $5.00 to +250")
	_check(is_equal_approx(PlayerEconomy.money, 0.0), "Poor House consumes the balance")
	poor_house._on_score_assigned(Scorecard.Section.UPPER, "ones", 0)
	poor_house.queue_free()

	var outcome = MomDialogOutcomeScript.new()
	outcome.effect = "reward_money"
	outcome.magnitude = 0.0
	var mom_result = MomLogicHandlerScript.apply_outcome(controller, outcome, 0)
	_check(mom_result.reward_money >= 0.5 and mom_result.reward_money <= 1.5, "Mom default reward is $0.50-$1.50")
	PlayerEconomy.reset_to_starting_money()
	MomLogicHandlerScript.apply_consequences(controller, mom_result)
	_check(is_equal_approx(PlayerEconomy.money, 1.0 + mom_result.reward_money), "Mom reward credits the exact dollar amount")
	controller.free()

	PlayerEconomy.reset_to_starting_money()
	if _failures == 0:
		print("[EconomyRescaleTest] PASS")
	else:
		push_error("[EconomyRescaleTest] %d check(s) failed" % _failures)
	await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("[EconomyRescaleTest] OK: " + description)
	else:
		_failures += 1
		push_error("[EconomyRescaleTest] FAIL: " + description)
