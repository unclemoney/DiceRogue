extends PowerUp
class_name UngroundedPowerUp

## UngroundedPowerUp
##
## A legendary PowerUp that prevents all debuffs from activating.
## Uses a passive check in GameController's apply_debuff() function.
## When a debuff is blocked, this powerup tracks the count.

# Reference to game controller
var game_controller_ref: GameController = null

# Track debuffs blocked
var debuffs_blocked: int = 0

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")
	print("[UngroundedPowerUp] Added to 'power_ups' group")

func _on_debuff_blocked(debuff_id: String) -> void:
	# Track blocked debuff
	debuffs_blocked += 1
	
	print("[UngroundedPowerUp] Blocked debuff: %s (total blocked: %d)" % [debuff_id, debuffs_blocked])
	
	# Update description
	emit_signal("description_updated", id, get_current_description())
	
	# Update UI icons
	if is_inside_tree():
		_update_power_up_icons()

func apply(target) -> void:
	print("=== Applying UngroundedPowerUp ===")
	var game_controller = target as GameController
	if not game_controller:
		push_error("[UngroundedPowerUp] Target is not a GameController")
		return
	
	# Store reference to the game controller
	game_controller_ref = game_controller
	
	# Connect to debuff_blocked signal (emitted by GameController when this powerup blocks a debuff)
	if game_controller.has_signal("debuff_blocked"):
		if not game_controller.is_connected("debuff_blocked", _on_debuff_blocked):
			game_controller.debuff_blocked.connect(_on_debuff_blocked)
			print("[UngroundedPowerUp] Connected to debuff_blocked signal")
	else:
		print("[UngroundedPowerUp] Warning: GameController does not have debuff_blocked signal yet")
	
	# Connect to tree_exiting for cleanup
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[UngroundedPowerUp] Applied successfully - all debuffs will be blocked")

func remove(target) -> void:
	print("=== Removing UngroundedPowerUp ===")
	
	var game_controller: GameController = null
	if target is GameController:
		game_controller = target
	elif target == self:
		game_controller = game_controller_ref
	
	if game_controller:
		if game_controller.has_signal("debuff_blocked"):
			if game_controller.is_connected("debuff_blocked", _on_debuff_blocked):
				game_controller.debuff_blocked.disconnect(_on_debuff_blocked)
				print("[UngroundedPowerUp] Disconnected from debuff_blocked signal")
	
	game_controller_ref = null

func get_current_description() -> String:
	if debuffs_blocked > 0:
		return "Prevents all debuffs\nBlocked: %d" % debuffs_blocked
	else:
		return "Prevents all debuffs"

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("ungrounded")
		if icon:
			icon.update_hover_description()
			if icon._is_hovering and icon.hover_label and icon.label_bg:
				icon.label_bg.visible = true

func _on_tree_exiting() -> void:
	# Cleanup when PowerUp is destroyed
	if game_controller_ref:
		if game_controller_ref.has_signal("debuff_blocked"):
			if game_controller_ref.is_connected("debuff_blocked", _on_debuff_blocked):
				game_controller_ref.debuff_blocked.disconnect(_on_debuff_blocked)
		print("[UngroundedPowerUp] Cleanup: Disconnected signals")
