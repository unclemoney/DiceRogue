extends Control

## ContainerHoverTitleTest
##
## Verifies the GameUI container hover tooltips:
## 1. Tooltips live on a dedicated top-level CanvasLayer (not clipped/hidden).
## 2. Tooltip uses larger high-contrast styling.
## 3. Tooltip only appears after the hover delay.
## 4. Settings toggle suppresses tooltips.
##
## Hover is driven through GameUI's own hover handlers (Input.warp_mouse is a
## no-op in headless mode, so real mouse simulation is unreliable here).
##
## The scene does NOT auto-quit: after the automated assertions it stays open
## so you can hover panels with the real mouse. A diagnostic timer prints the
## currently hovered control and every tooltip's state once per second.

var _game_ui: GameUI
var _failures: int = 0
var _diag_timer: Timer


func _ready() -> void:
	print("[ContainerHoverTitleTest] Starting...")
	print("[ContainerHoverTitleTest] setting container_title_tooltips_enabled = %s" % GameSettings.container_title_tooltips_enabled)
	GameSettings.container_title_tooltips_enabled = true

	_game_ui = GameUI.new()
	add_child(_game_ui)
	await get_tree().process_frame
	await get_tree().process_frame

	# ── Test 1: tooltip layer exists and hosts tooltips ──
	var layer := _game_ui.get_node_or_null("TooltipLayer") as CanvasLayer
	_assert(layer != null, "TooltipLayer CanvasLayer exists")
	if layer:
		_assert(layer.layer == 128, "TooltipLayer renders above other layers (layer=%d)" % layer.layer)
		_assert(layer.get_child_count() > 0, "Tooltips are parented to TooltipLayer")

	# ── Test 2: styling ──
	if layer and layer.get_child_count() > 0:
		var tooltip := layer.get_child(0) as PanelContainer
		var label := tooltip.get_node_or_null("TooltipLabel") as Label
		_assert(label != null and label.get_theme_font_size("font_size") >= 18,
			"Tooltip font size is larger (>= 18)")
		_assert(tooltip.has_theme_stylebox_override("panel"), "Tooltip has high-contrast stylebox override")
		_assert(tooltip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Tooltip ignores mouse")

	# ── Registered panels overview (diagnostic) ──
	print("[ContainerHoverTitleTest] Registered hover panels:")
	for entry in _game_ui._hover_entries:
		var p: PanelContainer = entry["panel"]
		print("[ContainerHoverTitleTest]   %s rect=%s hovered=%s" % [p.name, p.get_global_rect(), entry["hovered"]])

	# Reset all hover state so timing assertions are deterministic.
	for entry in _game_ui._hover_entries:
		(entry["timer"] as Timer).stop()
		(entry["tooltip"] as PanelContainer).visible = false

	# Prefer the panel the (resting) mouse is naturally over, else money.
	var target_panel: PanelContainer = _game_ui.money_container
	for entry in _game_ui._hover_entries:
		if entry["hovered"]:
			target_panel = entry["panel"]
	var entry := _entry_for(target_panel)
	_assert(not entry.is_empty(), "Found hover entry for '%s'" % target_panel.name)
	print("[ContainerHoverTitleTest] Testing with panel '%s' rect=%s" % [target_panel.name, target_panel.get_global_rect()])

	# ── Test 3: hover delay then show ──
	_assert(not _any_tooltip_visible(layer), "No tooltip visible before hover")
	_game_ui._on_tooltip_hover_start(entry)
	await get_tree().create_timer(0.5).timeout
	_assert(not _any_tooltip_visible(layer), "Tooltip NOT visible before 1s delay elapses")
	await get_tree().create_timer(0.85).timeout
	await get_tree().process_frame
	_assert(_any_tooltip_visible(layer), "Tooltip visible after 1s delay")

	# ── On-screen placement ──
	var shown := _visible_tooltip(layer)
	if shown:
		var vp := get_viewport().get_visible_rect()
		print("[ContainerHoverTitleTest]   shown tooltip pos=%s size=%s viewport=%s" % [
			shown.global_position, shown.size, vp.size])
		_assert(vp.has_point(shown.global_position), "Tooltip position is inside the viewport")

	# ── Exit hides ──
	_game_ui._on_tooltip_hover_end(entry)
	await get_tree().process_frame
	_assert(not _any_tooltip_visible(layer), "Tooltip hidden after hover end")

	# ── Test 4: settings toggle suppresses ──
	GameSettings.container_title_tooltips_enabled = false
	_game_ui._on_tooltip_hover_start(entry)
	await get_tree().create_timer(1.3).timeout
	_assert(not _any_tooltip_visible(layer), "Tooltip suppressed when setting disabled")
	_game_ui._on_tooltip_hover_end(entry)
	GameSettings.container_title_tooltips_enabled = true

	print("[ContainerHoverTitleTest] Automated assertions %s (%d failure(s))" % [
		"PASSED" if _failures == 0 else "FAILED", _failures])
	print("[ContainerHoverTitleTest] ────────────────────────────────────────────")
	print("[ContainerHoverTitleTest] Scene stays open: hover panels with your mouse.")
	print("[ContainerHoverTitleTest] Diagnostics print every second. Close window to exit.")

	# ── Continuous diagnostics (no auto-quit) ──
	_diag_timer = Timer.new()
	_diag_timer.wait_time = 1.0
	_diag_timer.autostart = true
	_diag_timer.timeout.connect(_dump_diagnostics)
	add_child(_diag_timer)


func _entry_for(panel: PanelContainer) -> Dictionary:
	for e in _game_ui._hover_entries:
		if e["panel"] == panel:
			return e
	return {}


func _dump_diagnostics() -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	var hovered_name := "<none>"
	if hovered:
		hovered_name = "%s (%s)" % [hovered.name, hovered.get_class()]
	var layer := _game_ui.get_node_or_null("TooltipLayer") as CanvasLayer
	var states := PackedStringArray()
	if layer:
		for child in layer.get_children():
			if child is PanelContainer and child.visible:
				var tip_label := child.get_node_or_null("TooltipLabel") as Label
				var title := tip_label.text if tip_label else "?"
				var vp := get_viewport().get_visible_rect()
				states.append("%s: VISIBLE pos=%s size=%s inside_vp=%s scale=%s alpha=%.2f" % [
					title, child.global_position, child.size,
					vp.has_point(child.global_position), child.scale, child.modulate.a])
	# Also report delay timers that are currently counting down
	var timers := PackedStringArray()
	for entry in _game_ui._hover_entries:
		var t: Timer = entry["timer"]
		if is_instance_valid(t) and not t.is_stopped():
			timers.append("%s(%.2fs left)" % [(entry["panel"] as PanelContainer).name, t.time_left])
	print("[ContainerHoverTitleTest] hover=%s | tooltips: %s | timers: %s" % [
		hovered_name,
		"; ".join(states) if not states.is_empty() else "none visible",
		", ".join(timers) if not timers.is_empty() else "none pending"])


func _any_tooltip_visible(layer: CanvasLayer) -> bool:
	return _visible_tooltip(layer) != null


func _visible_tooltip(layer: CanvasLayer) -> PanelContainer:
	if not layer:
		return null
	for child in layer.get_children():
		if child is PanelContainer and child.visible:
			return child
	return null


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[ContainerHoverTitleTest]   PASS: %s" % message)
	else:
		_failures += 1
		printerr("[ContainerHoverTitleTest]   FAIL: %s" % message)
