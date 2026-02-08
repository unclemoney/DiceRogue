extends Debuff
class_name RotatingDisabledPowerUpDebuff

## RotatingDisabledPowerUpDebuff
##
## Randomly disables one of the player's active power-ups each turn.
## The disabled power-up rotates on each new turn — the previous one is
## re-enabled and a new random one is chosen. A red-X shader overlay is
## applied to the disabled power-up's spine and icon in the UI.

var game_controller: Node
var turn_tracker: Node
var currently_disabled_id: String = ""
var disabled_shader: Shader
var _shader_check_timer: Timer = null

## _is_our_shader(mat)
##
## Returns true if the given material is a ShaderMaterial using our disabled shader.
func _is_our_shader(mat) -> bool:
	if mat is ShaderMaterial:
		return mat.shader == disabled_shader
	return false

## apply(_target)
##
## Connects to the turn_started signal and immediately disables one random
## power-up. Loads the disabled overlay shader for visual feedback.
func apply(_target) -> void:
	print("[RotatingDisabledPowerUp] Applied - One random powerup disabled each turn")
	self.target = _target
	game_controller = _target

	turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if not turn_tracker:
		push_error("[RotatingDisabledPowerUp] Could not find TurnTracker")
		return

	disabled_shader = load("res://Scripts/Shaders/disabled_powerup_overlay.gdshader")

	if not turn_tracker.is_connected("turn_started", _on_turn_started):
		turn_tracker.turn_started.connect(_on_turn_started)

	# Create timer to periodically reapply shader to icons (which get destroyed/recreated on fan)
	_shader_check_timer = Timer.new()
	_shader_check_timer.wait_time = 0.3
	_shader_check_timer.autostart = true
	_shader_check_timer.timeout.connect(_on_shader_check_timeout)
	add_child(_shader_check_timer)

	# Wait for next frame to ensure spines are fully ready
	await get_tree().process_frame
	await get_tree().process_frame
	_rotate_disabled_powerup()

## remove()
##
## Re-enables the currently disabled power-up, removes the shader overlay,
## and disconnects from turn signals.
func remove() -> void:
	print("[RotatingDisabledPowerUp] Removed - Restoring all powerups")
	_enable_current()

	if _shader_check_timer and is_instance_valid(_shader_check_timer):
		_shader_check_timer.queue_free()
		_shader_check_timer = null

	if turn_tracker and is_instance_valid(turn_tracker):
		if turn_tracker.is_connected("turn_started", _on_turn_started):
			turn_tracker.turn_started.disconnect(_on_turn_started)

## _on_turn_started()
##
## Signal handler called at the start of each new turn.
func _on_turn_started() -> void:
	_rotate_disabled_powerup()

## _on_shader_check_timeout()
##
## Periodically ensures shader is applied to current disabled powerup.
## Handles icon recreation during fan_out/fan_in transitions.
func _on_shader_check_timeout() -> void:
	if currently_disabled_id != "":
		_apply_disabled_shader(currently_disabled_id)

## _rotate_disabled_powerup()
##
## Re-enables the previous power-up, then picks a new random one to disable.
## Applies the red-X shader to the disabled power-up's spine in the UI.
func _rotate_disabled_powerup() -> void:
	if not game_controller or not is_instance_valid(game_controller):
		return

	# Re-enable previous
	_enable_current()

	# Get all active power-up IDs
	var active_ids: Array = game_controller.active_power_ups.keys()
	if active_ids.is_empty():
		print("[RotatingDisabledPowerUp] No active powerups to disable")
		currently_disabled_id = ""
		return

	# Pick a random power-up
	var random_index: int = randi() % active_ids.size()
	currently_disabled_id = active_ids[random_index]
	print("[RotatingDisabledPowerUp] Disabling powerup: %s" % currently_disabled_id)

	# Deactivate it (call remove on the PowerUp to undo its effect)
	var pu = game_controller.active_power_ups.get(currently_disabled_id)
	if pu and is_instance_valid(pu):
		game_controller._deactivate_power_up(currently_disabled_id)

	# Apply shader to spine and icon
	_apply_disabled_shader(currently_disabled_id)

## _enable_current()
##
## Re-enables the currently disabled power-up and removes its shader overlay.
func _enable_current() -> void:
	if currently_disabled_id == "":
		return

	if not game_controller or not is_instance_valid(game_controller):
		return

	# Re-activate the power-up (call apply again)
	if game_controller.active_power_ups.has(currently_disabled_id):
		var pu = game_controller.active_power_ups.get(currently_disabled_id)
		if pu and is_instance_valid(pu):
			game_controller._activate_power_up(currently_disabled_id)

	# Remove shader
	_remove_disabled_shader(currently_disabled_id)
	currently_disabled_id = ""

## _create_disabled_material()
##
## Creates a new ShaderMaterial with the disabled overlay shader.
func _create_disabled_material() -> ShaderMaterial:
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = disabled_shader
	shader_mat.set_shader_parameter("disabled", true)
	return shader_mat

## _apply_disabled_shader(power_up_id)
##
## Applies the red-X overlay shader to the spine's spine_rect member variable
## and the icon's card_art (if fanned). Uses the actual node references instead of
## get_node_or_null to avoid the duplicate SpineRect problem.
## Checks the ACTUAL current material on each node to decide whether to apply,
## rather than tracking via dictionaries (which go stale when icons are destroyed).
func _apply_disabled_shader(power_up_id: String) -> void:
	if not disabled_shader:
		return
	if not game_controller or not is_instance_valid(game_controller):
		return

	var powerup_ui = game_controller.powerup_ui
	if not powerup_ui or not is_instance_valid(powerup_ui):
		return

	# === SPINE: Apply to ALL SpineRect children (scene may define one, code creates another) ===
	if powerup_ui._spines.has(power_up_id):
		var spine = powerup_ui._spines[power_up_id]
		if spine and is_instance_valid(spine):
			# Apply to spine.spine_rect (the code-created member variable)
			if spine.spine_rect and is_instance_valid(spine.spine_rect):
				if not _is_our_shader(spine.spine_rect.material):
					spine.spine_rect.material = _create_disabled_material()
					print("[RotatingDisabledPowerUp] Applied shader to spine.spine_rect: %s" % power_up_id)

			# Also apply to any other SpineRect children from the .tscn scene
			for child in spine.get_children():
				if child is TextureRect and child.name == "SpineRect" and child != spine.spine_rect:
					if not _is_our_shader(child.material):
						child.material = _create_disabled_material()
						print("[RotatingDisabledPowerUp] Applied shader to scene SpineRect: %s" % power_up_id)

	# === ICON: Apply to icon.card_art (only exists when fanned) ===
	if powerup_ui._fanned_icons.has(power_up_id):
		var icon = powerup_ui._fanned_icons[power_up_id]
		if icon and is_instance_valid(icon) and icon.card_art:
			if not _is_our_shader(icon.card_art.material):
				icon.card_art.material = _create_disabled_material()
				print("[RotatingDisabledPowerUp] Applied shader to icon.card_art: %s" % power_up_id)

## _remove_disabled_shader(power_up_id)
##
## Removes the red-X overlay shader from spine and icon, restoring original materials.
func _remove_disabled_shader(power_up_id: String) -> void:
	if not game_controller or not is_instance_valid(game_controller):
		return

	var powerup_ui = game_controller.powerup_ui
	if not powerup_ui or not is_instance_valid(powerup_ui):
		return

	# === SPINE: Restore all SpineRect children ===
	if powerup_ui._spines.has(power_up_id):
		var spine = powerup_ui._spines[power_up_id]
		if spine and is_instance_valid(spine):
			# Restore spine.spine_rect (the code-created member variable)
			if spine.spine_rect and is_instance_valid(spine.spine_rect):
				if _is_our_shader(spine.spine_rect.material):
					spine.spine_rect.material = null
					print("[RotatingDisabledPowerUp] Removed shader from spine.spine_rect: %s" % power_up_id)

			# Also restore any scene-defined SpineRect children
			for child in spine.get_children():
				if child is TextureRect and child.name == "SpineRect" and child != spine.spine_rect:
					if _is_our_shader(child.material):
						child.material = null
						print("[RotatingDisabledPowerUp] Removed shader from scene SpineRect: %s" % power_up_id)

	# === ICON: Restore card_perspective shader (icon._shader_material) ===
	if powerup_ui._fanned_icons.has(power_up_id):
		var icon = powerup_ui._fanned_icons[power_up_id]
		if icon and is_instance_valid(icon) and icon.card_art:
			if _is_our_shader(icon.card_art.material):
				# Restore the icon's original card_perspective shader
				icon.card_art.material = icon._shader_material
				print("[RotatingDisabledPowerUp] Restored shader on icon.card_art: %s" % power_up_id)
