# Scripts/Managers/mom_juice_coordinator.gd
# Autoload singleton — do NOT add class_name
# Orchestrates all post-Mom-visit juice: the money pull (Mom fines), the
# buff/debuff arrival fanfare, and sequencing against the scoring animation.
# Visual layer only — MomLogicHandler outcomes are never touched here.
extends Node

const FanfareIconScript = preload("res://Scripts/Effects/fanfare_icon.gd")
const MoneyChipScript = preload("res://Scripts/Effects/money_chip.gd")
const COIN_SOUND_PATH := "res://Resources/Audio/UI/COIN_1.wav"
const JACKPOT_SOUND_PATH := "res://Resources/Audio/UI/JACKPOT_1.wav"

# Snapshot taken at arm time (before apply_consequences) so the fanfare only
# fires for icons that are NEW after the Mom consequences land.
var _armed: bool = false
var _armed_buff_ids: Array = []
var _armed_debuff_ids: Array = []
var _armed_powerup_ids: Array = []

var _coin_sound: AudioStream = null
var _jackpot_sound: AudioStream = null


## arm_money_pull(result)
##
## Called by GameController right BEFORE MomLogicHandler.apply_consequences.
## Conceals the money display at its pre-fine value (the fine's
## money_changed signal then only updates the pending target) and snapshots
## which buff/debuff/powerup icons already exist.
func arm_money_pull(result) -> void:
	if result == null:
		return
	_armed_buff_ids = _current_buff_ids()
	_armed_debuff_ids = _current_debuff_ids()
	_armed_powerup_ids = _current_powerup_ids()
	_armed = true
	if int(result.fine_amount) > 0:
		var money_ui = _money_ui()
		if money_ui and money_ui.has_method("begin_pull_concealment"):
			money_ui.begin_pull_concealment()


## play_post_mom_sequence(result)
##
## Called by GameController AFTER apply_consequences (and any Mom-granted
## buff grants). Fire-and-forget coroutine: waits for any running scoring
## animation, lets the confiscation explosion settle, pulls the fine money
## chip-by-chip toward Mom, then plays the buff/debuff arrival fanfares.
func play_post_mom_sequence(result) -> void:
	if result == null:
		return
	var profile := _profile()

	await _await_scoring_idle()

	# The confiscation animation itself completes before the dialog closes;
	# this settle lets its explosion dissipate before the money pull starts.
	if result.removed_power_ups.size() > 0 and profile.mom_sequence_powerup_settle > 0.0:
		await get_tree().create_timer(profile.mom_sequence_powerup_settle).timeout

	if int(result.fine_amount) > 0:
		await _play_money_pull(int(result.fine_amount), profile)

	await _play_fanfares(profile)
	_armed = false


## ─── Queue gate ──────────────────────────────────────────────────

## _await_scoring_idle()
##
## The fanfare waits its turn behind any running scoring animation, using
## the scoring controller's own state/signal (no separate queue system).
func _await_scoring_idle() -> void:
	var sac = get_tree().get_first_node_in_group("scoring_animation_controller")
	if sac == null:
		return
	while sac.get("animation_in_progress"):
		await sac.animation_sequence_complete


## ─── Money pull ──────────────────────────────────────────────────

## _play_money_pull(amount, profile)
##
## Streams individual "-step" chips from the money display toward the Mom
## portrait (money is pulled player -> Mom). The money counter ticks down
## per chip arrival, not all at once.
func _play_money_pull(amount: int, profile: JuiceProfile) -> void:
	var money_ui = _money_ui()
	var from := _money_label_center(money_ui)
	var to := _mom_anchor(profile)

	var chip_count := amount
	var step := 1
	if profile.money_pull_max_chips > 0 and amount > profile.money_pull_max_chips:
		chip_count = profile.money_pull_max_chips
		step = int(ceil(float(amount) / float(chip_count)))

	for i in range(chip_count):
		_fly_money_chip(i, from, to, step, profile)
		await get_tree().create_timer(profile.money_pull_stagger).timeout

	# Let the last chip arrive before reconciling the display.
	await get_tree().create_timer(profile.money_pull_flight_time).timeout
	if money_ui and money_ui.has_method("end_pull_concealment"):
		money_ui.end_pull_concealment()


func _fly_money_chip(index: int, from: Vector2, to: Vector2, step: int, profile: JuiceProfile) -> void:
	var parent := _fx_parent()
	if parent == null:
		return
	var chip := MoneyChipScript.new()
	parent.add_child(chip)
	chip.setup("-%d" % step)
	chip.global_position = from

	var tween := create_tween()
	tween.tween_method(_arc_chip.bind(chip, from, to, profile.money_pull_arc_height), 0.0, 1.0, profile.money_pull_flight_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_money_chip_arrived.bind(chip, to, step, index, profile))


func _arc_chip(progress: float, chip: Control, from: Vector2, to: Vector2, arc_height: float) -> void:
	if not is_instance_valid(chip):
		return
	var pos := from.lerp(to, progress)
	# Quadratic arc: peaks at the midpoint, slight upward bow.
	pos.y -= arc_height * 4.0 * progress * (1.0 - progress)
	chip.global_position = pos


func _on_money_chip_arrived(chip: Control, to: Vector2, step: int, index: int, profile: JuiceProfile) -> void:
	var money_ui = _money_ui()
	if money_ui and money_ui.has_method("tick_pull_display"):
		money_ui.tick_pull_display(-step)
	_flash_at(to, profile.money_pull_flash_time)
	_play_coin_sfx(index, profile)
	if is_instance_valid(chip):
		var shrink := create_tween()
		shrink.tween_property(chip, "scale", Vector2.ZERO, 0.1)
		shrink.tween_callback(chip.queue_free)


func _flash_at(pos: Vector2, flash_time: float) -> void:
	var parent := _fx_parent()
	if parent == null:
		return
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.3, 0.3, 0.8)
	flash.size = Vector2(12, 12)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = RenderLayers.Z_SCREEN_FX
	parent.add_child(flash)
	flash.global_position = pos - flash.size / 2.0
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, flash_time)
	tween.tween_callback(flash.queue_free)


func _play_coin_sfx(index: int, profile: JuiceProfile) -> void:
	if _coin_sound == null:
		_coin_sound = load(COIN_SOUND_PATH)
	if _coin_sound == null:
		return
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = _coin_sound
	player.pitch_scale = maxf(profile.money_pull_base_pitch - profile.money_pull_pitch_step * index, 0.5)
	player.volume_db = -8.0 + _master_volume_db()
	player.play()
	player.finished.connect(player.queue_free)


## ─── Buff/debuff fanfare ─────────────────────────────────────────

## _play_fanfares(profile)
##
## Diffs the post-consequences icon sets against the arm-time snapshot and
## flies a fanfare icon into every NEW buff/debuff/powerup slot. Buffs land
## first, then debuffs; within a kind, top-to-bottom, staggered.
func _play_fanfares(profile: JuiceProfile) -> void:
	var entries: Array = []
	if _armed:
		for id in _diff(_current_powerup_ids(), _armed_powerup_ids):
			entries.append({"kind": "powerup", "id": id})
		for id in _diff(_current_buff_ids(), _armed_buff_ids):
			entries.append({"kind": "buff", "id": id})
		for id in _diff(_current_debuff_ids(), _armed_debuff_ids):
			entries.append({"kind": "debuff", "id": id})
	if entries.is_empty():
		return

	# Resolve targets, buffs before debuffs, top-to-bottom within a kind.
	var kind_order := {"powerup": 0, "buff": 0, "debuff": 1}
	var resolved: Array = []
	for entry in entries:
		var target := _fanfare_target(entry)
		if target != null and is_instance_valid(target):
			resolved.append({
				"entry": entry,
				"target": target,
				"sort": kind_order[entry["kind"]] * 100000.0 + target.get_global_rect().get_center().y,
			})
	resolved.sort_custom(func(a, b): return a["sort"] < b["sort"])

	for i in range(resolved.size()):
		_spawn_fanfare(resolved[i]["entry"], resolved[i]["target"], profile)
		if i < resolved.size() - 1:
			await get_tree().create_timer(profile.fanfare_stagger).timeout


func _spawn_fanfare(entry: Dictionary, target: Control, profile: JuiceProfile) -> void:
	var parent := _fx_parent()
	if parent == null:
		return
	var kind: String = entry["kind"]
	var is_debuff := kind == "debuff"
	var tint: Color = profile.fanfare_debuff_tint if is_debuff else profile.fanfare_buff_tint

	var icon := FanfareIconScript.new()
	parent.add_child(icon)
	if kind == "powerup":
		icon.setup_buff(_powerup_icon_for(entry["id"]), _powerup_name_for(entry["id"]), tint)
	else:
		# Mom-granted buffs and debuffs are both DebuffData glyph chips.
		icon.setup_debuff(_debuff_data_for(entry["id"]), tint)

	# Hide the real slot until the fanfare icon lands on it.
	if not is_debuff:
		target.modulate.a = 0.0

	icon.landed.connect(func():
		if is_instance_valid(target):
			if not is_debuff:
				var fade := target.create_tween()
				fade.tween_property(target, "modulate:a", 1.0, 0.1)
			var tfx = get_node_or_null("/root/TweenFXHelper")
			if tfx:
				tfx.container_hop(target, profile.fanfare_hop_height, profile.fanfare_hop_time)
		_play_landing_sfx(profile)
	)
	_play_fly_sfx(is_debuff)
	icon.play_flight(target.get_global_rect().get_center(), profile)


func _play_fly_sfx(is_debuff: bool) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr == null:
		return
	if is_debuff:
		if audio_mgr.has_method("play_denied_sound"):
			audio_mgr.play_denied_sound()
	elif audio_mgr.has_method("play_powerup_apply_sound"):
		audio_mgr.play_powerup_apply_sound()


func _play_landing_sfx(profile: JuiceProfile) -> void:
	# Jackpot beat at low volume (AudioManager's jackpot has no volume param).
	if _jackpot_sound == null:
		_jackpot_sound = load(JACKPOT_SOUND_PATH)
	if _jackpot_sound == null:
		return
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = _jackpot_sound
	player.volume_db = profile.fanfare_jackpot_volume_db + _master_volume_db()
	player.play()
	player.finished.connect(player.queue_free)


## ─── Lookups (all duck-typed) ────────────────────────────────────

func _profile() -> JuiceProfile:
	var tfx = get_node_or_null("/root/TweenFXHelper")
	if tfx and tfx.has_method("get_default_juice_profile"):
		return tfx.get_default_juice_profile()
	return JuiceProfile.new()


func _game_controller() -> Node:
	return get_tree().get_first_node_in_group("game_controller")


func _fx_parent() -> Node:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	return parent


func _money_ui() -> Node:
	return get_tree().get_first_node_in_group("money_ui")


func _money_label_center(money_ui: Node) -> Vector2:
	if money_ui and money_ui.has_method("get_label_center"):
		return money_ui.get_label_center()
	return get_viewport().get_visible_rect().size * 0.5


func _mom_anchor(profile: JuiceProfile) -> Vector2:
	var gc = _game_controller()
	if gc:
		var dialog = gc.get("_mom_dialog")
		if dialog and is_instance_valid(dialog) and dialog.has_method("get_portrait_center"):
			return dialog.get_portrait_center()
	return profile.money_pull_mom_fallback_pos


func _current_buff_ids() -> Array:
	var ids: Array = []
	var gc = _game_controller()
	if gc:
		var chore_ui = gc.get("chore_ui")
		if chore_ui:
			var icons = chore_ui.get("_buff_icons")
			if icons is Dictionary:
				ids = icons.keys()
	return ids


func _current_debuff_ids() -> Array:
	var ids: Array = []
	var gc = _game_controller()
	if gc:
		var debuff_ui = gc.get("debuff_ui")
		if debuff_ui:
			var icons = debuff_ui.get("_icons")
			if icons is Dictionary:
				ids = icons.keys()
	return ids


func _current_powerup_ids() -> Array:
	var ids: Array = []
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var spines = power_up_ui.get("_spines")
		if spines is Dictionary:
			ids = spines.keys()
	return ids


func _fanfare_target(entry: Dictionary) -> Control:
	var gc = _game_controller()
	match entry["kind"]:
		"powerup":
			var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
			if power_up_ui:
				var spines = power_up_ui.get("_spines")
				if spines is Dictionary and spines.has(entry["id"]):
					return spines[entry["id"]]
		"buff":
			if gc:
				var chore_ui = gc.get("chore_ui")
				if chore_ui:
					var icons = chore_ui.get("_buff_icons")
					if icons is Dictionary and icons.has(entry["id"]):
						return icons[entry["id"]]
		"debuff":
			if gc:
				var debuff_ui = gc.get("debuff_ui")
				if debuff_ui and debuff_ui.has_method("get_debuff_icon"):
					return debuff_ui.get_debuff_icon(entry["id"])
	return null


func _debuff_data_for(id: String) -> DebuffData:
	var gc = _game_controller()
	if gc:
		var debuff_manager = gc.get("debuff_manager")
		if debuff_manager and debuff_manager.has_method("get_def"):
			return debuff_manager.get_def(id)
	return null


func _powerup_icon_for(id: String) -> Texture2D:
	var def = _powerup_def_for(id)
	if def != null:
		var icon = def.get("icon")
		if icon is Texture2D:
			return icon
	return null


func _powerup_name_for(id: String) -> String:
	var def = _powerup_def_for(id)
	if def != null:
		return str(def.get("display_name"))
	return id.replace("_", " ")


func _powerup_def_for(id: String):
	var gc = _game_controller()
	if gc:
		var pu_manager = gc.get("pu_manager")
		if pu_manager and pu_manager.has_method("get_def"):
			return pu_manager.get_def(id)
	return null


func _master_volume_db() -> float:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		var volume = audio_mgr.get("master_volume_db")
		if volume != null:
			return float(volume)
	return 0.0


func _diff(new_ids: Array, old_ids: Array) -> Array:
	var added: Array = []
	for id in new_ids:
		if not id in old_ids:
			added.append(id)
	return added
