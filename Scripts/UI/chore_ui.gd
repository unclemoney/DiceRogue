extends Control
class_name ChoreUI

## ChoreUI
##
## Displays the chore progress bar and current task in the top-left corner.
## Progress increases by 1 each dice roll and decreases by 20 when tasks complete.
## Shows a details panel on hover with the current task information.

signal task_clicked

@export var chores_manager_path: NodePath

# Node references
var progress_bar: ProgressBar
var task_label: Label
var details_panel: PanelContainer
var details_label: RichTextLabel
var _chores_manager = null  # ChoresManager - duck typed to avoid class resolution issues

# Visual settings
const BAR_WIDTH: float = 30.0
const BAR_HEIGHT: float = 160.0
const DANGER_THRESHOLD: float = 80.0
const WARNING_THRESHOLD: float = 60.0

func _ready() -> void:
	_create_ui_structure()
	_setup_signals()
	print("[ChoreUI] Initialized")

## set_chores_manager()
##
## Sets the ChoresManager reference and connects signals.
##
## Parameters:
##   manager: ChoresManager - the ChoresManager instance
func set_chores_manager(manager) -> void:
	if _chores_manager:
		_disconnect_signals()
	
	_chores_manager = manager
	
	if _chores_manager:
		_chores_manager.progress_changed.connect(_on_progress_changed)
		_chores_manager.task_selected.connect(_on_task_selected)
		_chores_manager.task_completed.connect(_on_task_completed)
		
		# Defer initialization to ensure UI nodes exist
		call_deferred("_initialize_from_manager")
	
	print("[ChoreUI] Connected to ChoresManager")

## _initialize_from_manager()
##
## Deferred initialization after UI is ready.
func _initialize_from_manager() -> void:
	if not _chores_manager:
		return
	
	# Initialize with current values
	_on_progress_changed(_chores_manager.current_progress)
	if _chores_manager.current_task:
		_on_task_selected(_chores_manager.current_task)
		print("[ChoreUI] Initialized with task: %s" % _chores_manager.current_task.display_name)
	else:
		print("[ChoreUI] No initial task available")

func _disconnect_signals() -> void:
	if _chores_manager:
		if _chores_manager.progress_changed.is_connected(_on_progress_changed):
			_chores_manager.progress_changed.disconnect(_on_progress_changed)
		if _chores_manager.task_selected.is_connected(_on_task_selected):
			_chores_manager.task_selected.disconnect(_on_task_selected)
		if _chores_manager.task_completed.is_connected(_on_task_completed):
			_chores_manager.task_completed.disconnect(_on_task_completed)

func _create_ui_structure() -> void:
	# Set size and position
	custom_minimum_size = Vector2(80, 140)
	size = Vector2(80, 140)
	
	# Main container
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)
	
	# Title
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "CHORES"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	main_container.add_child(title_label)
	
	# Progress bar container (centered)
	var bar_container = CenterContainer.new()
	bar_container.name = "BarContainer"
	bar_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(bar_container)
	
	# Progress bar (vertical)
	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	progress_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	progress_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_apply_progress_bar_style()
	bar_container.add_child(progress_bar)
	
	# Task label (short name)
	task_label = Label.new()
	task_label.name = "TaskLabel"
	task_label.text = "..."
	task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	task_label.add_theme_font_size_override("font_size", 10)
	task_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task_label.custom_minimum_size = Vector2(80, 0)
	#main_container.add_child(task_label)
	
	# Details panel (shown on hover)
	details_panel = PanelContainer.new()
	details_panel.name = "DetailsPanel"
	details_panel.visible = false
	details_panel.position = Vector2(85, 0)  # Position to the right
	details_panel.custom_minimum_size = Vector2(180, 80)
	_apply_panel_style()
	add_child(details_panel)
	
	# Details content
	var details_vbox = VBoxContainer.new()
	details_panel.add_child(details_vbox)
	
	var details_title = Label.new()
	details_title.name = "DetailsTitle"
	details_title.text = "Current Task"
	details_title.add_theme_font_size_override("font_size", 14)
	details_title.add_theme_color_override("font_color", Color.YELLOW)
	details_vbox.add_child(details_title)
	
	details_label = RichTextLabel.new()
	details_label.name = "DetailsLabel"
	details_label.bbcode_enabled = true
	details_label.fit_content = true
	details_label.custom_minimum_size = Vector2(170, 50)
	details_label.add_theme_color_override("default_color", Color.WHITE)
	details_vbox.add_child(details_label)

func _apply_progress_bar_style() -> void:
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.border_color = Color(0.3, 0.3, 0.3)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.7, 0.2)  # Green
	fill_style.set_corner_radius_all(2)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

func _apply_panel_style() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(5)
	panel_style.set_content_margin_all(8)
	details_panel.add_theme_stylebox_override("panel", panel_style)

func _setup_signals() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _on_progress_changed(new_value: int) -> void:
	if progress_bar:
		progress_bar.value = new_value
		_update_progress_color(new_value)
	print("[ChoreUI] Progress updated: %d" % new_value)

func _on_task_selected(task) -> void:  # ChoreData - duck typed
	if task == null:
		if task_label:
			task_label.text = "..."
		if details_label:
			details_label.text = "No task"
		return
	
	if task_label:
		task_label.text = task.display_name
	
	if details_label:
		details_label.text = "[b]%s[/b]\n%s\n[color=green][/color]" % [
			task.display_name,
			task.description
		]
	
	print("[ChoreUI] Task selected: %s" % task.display_name)

func _on_task_completed(_task) -> void:  # ChoreData - duck typed, unused
	# Flash effect when task completes
	_play_completion_flash()

func _update_progress_color(value: int) -> void:
	var fill_style = progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		return
	
	# Create a new stylebox to avoid modifying shared resource
	var new_style = StyleBoxFlat.new()
	new_style.set_corner_radius_all(2)
	
	if value >= DANGER_THRESHOLD:
		new_style.bg_color = Color(0.8, 0.2, 0.2)  # Red
	elif value >= WARNING_THRESHOLD:
		new_style.bg_color = Color(0.8, 0.6, 0.2)  # Orange
	else:
		new_style.bg_color = Color(0.2, 0.7, 0.2)  # Green
	
	progress_bar.add_theme_stylebox_override("fill", new_style)

func _play_completion_flash() -> void:
	var tween = create_tween()
	tween.tween_property(progress_bar, "modulate", Color(0.5, 1.0, 0.5), 0.1)
	tween.tween_property(progress_bar, "modulate", Color.WHITE, 0.2)

func _on_mouse_entered() -> void:
	details_panel.visible = true

func _on_mouse_exited() -> void:
	details_panel.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			task_clicked.emit()
