extends PowerUp
class_name ShopRerollsPowerUp

## ShopRerollsPowerUp
##
## Locks shop reroll costs at $25 - they never increase no matter how many times
## the player rerolls. Affects both PowerUp and Consumable shop tabs.
## Uncommon rarity, PG rating.

# Reference to the shop UI
var shop_ui_ref: ShopUI = null
var original_reroll_cost: int = 25

const LOCKED_REROLL_COST: int = 25

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying ShopRerollsPowerUp ===")
	
	# Get shop UI from the tree - try multiple methods
	var tree = null
	if target is Node:
		tree = target.get_tree()
	elif is_inside_tree():
		tree = get_tree()
	
	if not tree:
		push_error("[ShopRerollsPowerUp] Cannot access scene tree")
		return
	
	# Try to find ShopUI - first by group, then by class
	shop_ui_ref = tree.get_first_node_in_group("shop_ui")
	if not shop_ui_ref:
		# Fallback: search all nodes for ShopUI class
		var nodes = tree.root.find_children("*", "ShopUI", true, false)
		if nodes.size() > 0:
			shop_ui_ref = nodes[0]
			print("[ShopRerollsPowerUp] Found ShopUI by class search")
	
	if not shop_ui_ref:
		push_error("[ShopRerollsPowerUp] ShopUI not found")
		return
	
	# Store original cost (in case it's already modified)
	original_reroll_cost = shop_ui_ref.reroll_cost
	
	# Lock the reroll cost
	shop_ui_ref.reroll_cost = LOCKED_REROLL_COST
	shop_ui_ref._update_reroll_cost_display()
	
	# Enable _process to continuously enforce the locked cost
	set_process(true)
	
	# Connect to tab changed signal to maintain the lock after each reroll
	if not shop_ui_ref.is_connected("visibility_changed", _on_shop_visibility_changed):
		shop_ui_ref.visibility_changed.connect(_on_shop_visibility_changed)
	
	# Connect cleanup signal
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)
	
	print("[ShopRerollsPowerUp] Reroll cost locked at $%d" % LOCKED_REROLL_COST)

func _on_shop_visibility_changed() -> void:
	# Ensure cost stays locked when shop is shown/hidden
	if shop_ui_ref and shop_ui_ref.reroll_cost != LOCKED_REROLL_COST:
		shop_ui_ref.reroll_cost = LOCKED_REROLL_COST
		shop_ui_ref._update_reroll_cost_display()

func _process(_delta: float) -> void:
	# Continuously enforce the locked cost
	if shop_ui_ref and shop_ui_ref.reroll_cost != LOCKED_REROLL_COST:
		shop_ui_ref.reroll_cost = LOCKED_REROLL_COST
		shop_ui_ref._update_reroll_cost_display()

func remove(target) -> void:
	print("=== Removing ShopRerollsPowerUp ===")
	
	set_process(false)
	
	var shop_ui: ShopUI = null
	if target is ShopUI:
		shop_ui = target
	elif shop_ui_ref:
		shop_ui = shop_ui_ref
	
	if shop_ui:
		# Disconnect signals
		if shop_ui.is_connected("visibility_changed", _on_shop_visibility_changed):
			shop_ui.visibility_changed.disconnect(_on_shop_visibility_changed)
		
		# Reset to base cost
		shop_ui.reroll_cost = shop_ui.REROLL_BASE_COST
		shop_ui._update_reroll_cost_display()
		print("[ShopRerollsPowerUp] Reroll cost restored to base $%d" % shop_ui.REROLL_BASE_COST)
	
	shop_ui_ref = null

func _on_tree_exiting() -> void:
	if shop_ui_ref:
		if shop_ui_ref.is_connected("visibility_changed", _on_shop_visibility_changed):
			shop_ui_ref.visibility_changed.disconnect(_on_shop_visibility_changed)
