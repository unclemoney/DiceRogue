extends PanelContainer
class_name Tooltip

## Tooltip
##
## Standardized animated tooltip. Content is set via setup() with a Dictionary
## (keys: title, body, flavor, rarity). Show/hide animations route through the
## TweenFX singleton ONLY; shader uniforms (background fade, border trace) are
## tweened via TweenFX.tween_shader_param.

const VCR_FONT: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

const RarityColors := {
	"common": Color.WHITE,
	"uncommon": Color.GREEN,
	"rare": Color.BLUE,
	"epic": Color.PURPLE,
	"legendary": Color.GOLD,
}

const DEFAULT_BORDER_COLOR := Color(0.95, 0.86, 0.42, 1.0)

## Hard cap on total rendered rows across all visible sections.
const MAX_ROWS := 15

@export var tint_border_by_rarity: bool = false

var _trace_tween: Tween = null
var _fade_tween: Tween = null
var _setup_gen := 0
var _show_gen := 0
var _last_title := ""

@onready var _background: ColorRect = $Background
@onready var _border: ColorRect = $Border
@onready var _margin: MarginContainer = $Margin
@onready var _name_label: RichTextLabel = $Margin/Sections/NameLabel
@onready var _body_label: RichTextLabel = $Margin/Sections/BodyLabel
@onready var _flavor_label: RichTextLabel = $Margin/Sections/FlavorLabel
@onready var _rarity_label: RichTextLabel = $Margin/Sections/RarityLabel
@onready var _sections_extra: VBoxContainer = $Margin/Sections/SectionsExtra


## _ready()
##
## Side-effects: duplicates both ShaderMaterials per-instance (fix 2 — the
## .tscn-shared material would make all Tooltip instances fight over the
## fade/trace uniforms), hides the tooltip, feeds rect_size to the border
## shader on every resize.
func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = RenderLayers.Z_TOOLTIP
	_background.material = _background.material.duplicate()
	_border.material = _border.material.duplicate()
	_sync_rect_size()
	resized.connect(_sync_rect_size)


## _content_width()
##
## The width the VBox will assign every label once the container cascade
## sorts: tooltip width (custom_minimum_size.x unless content forces wider)
## minus the MarginContainer's horizontal margins.
func _content_width() -> float:
	var w := maxf(custom_minimum_size.x, get_combined_minimum_size().x)
	var m_l: int = _margin.get_theme_constant("margin_left")
	var m_r: int = _margin.get_theme_constant("margin_right")
	return maxf(1.0, w - m_l - m_r)


## _pin_content_width()
##
## Assigns every label its final width UP FRONT so fit_content wraps at the
## real width synchronously. Without this, freshly-texted labels sit at ~1px
## width until the engine's deferred container sort reaches them (several
## frames, trickling label by label), reporting hundreds of phantom lines —
## the first-show bug (260x5564 panel) and bogus row-cap counts both come
## from that window. The later real sort assigns the same width, so pinning
## is idempotent.
func _pin_content_width() -> void:
	var cw := _content_width()
	for label: RichTextLabel in [_name_label, _body_label, _flavor_label, _rarity_label]:
		label.size.x = cw
	for child in _sections_extra.get_children():
		child.size.x = cw


## setup(data)
##
## Sets all four sections from data keys: title, body, flavor, rarity.
## Empty sections are hidden. Border color follows rarity ONLY when
## tint_border_by_rarity is on and rarity is non-empty; otherwise tan/gold.
## All dynamic sections in SectionsExtra are freed first — add_section()
## calls must be re-issued after every setup().
func setup(data: Dictionary) -> void:
	# Callers may instantiate and setup() before add_child(); @onready lookups
	# are null until the node enters the tree, so wait for ready first.
	if not is_node_ready():
		await ready
	for child in _sections_extra.get_children():
		child.free()
	_pin_content_width()

	var title: String = data.get("title", "")
	var body: String = data.get("body", "")
	var flavor: String = data.get("flavor", "")
	var rarity: String = data.get("rarity", "")
	_last_title = title

	_name_label.visible = title != ""
	if title != "":
		_name_label.text = "[b][color=#ffd75e]%s[/color][/b]" % title

	_body_label.visible = body != ""
	_body_label.text = body

	_flavor_label.visible = flavor != ""
	if flavor != "":
		_flavor_label.text = "[i][color=#a8a8a8]%s[/color][/i]" % flavor

	_rarity_label.visible = rarity != ""
	if rarity != "":
		var rarity_col: Color = RarityColors.get(rarity.to_lower(), Color.WHITE)
		_rarity_label.text = "[color=#%s]%s[/color]" % [rarity_col.to_html(false), rarity.capitalize()]

	var border_col := DEFAULT_BORDER_COLOR
	if tint_border_by_rarity and rarity != "":
		border_col = RarityColors.get(rarity.to_lower(), DEFAULT_BORDER_COLOR)
	_border.material.set_shader_parameter("border_color", border_col)

	_setup_gen += 1
	_enforce_row_cap(title, _setup_gen)


## add_section(text, style, label)
##
## Appends one dynamic section to SectionsExtra. Call AFTER setup() — setup
## frees all dynamic sections. style: "stat" (with label, renders
## "[color=gray]LABEL:[/color] value" on one line; the value keeps any bbcode
## the caller passed, e.g. TooltipFormat numbers), "bullet" (indented "• "
## prefix, white), "plain" (white, no prefix). Each section re-arms the
## deferred row cap so sections added after setup() still count.
func add_section(text: String, style: String = "plain", label: String = "") -> void:
	var section := RichTextLabel.new()
	section.bbcode_enabled = true
	section.fit_content = true
	section.scroll_active = false
	section.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_theme_font_override("normal_font", VCR_FONT)
	section.add_theme_font_override("bold_font", VCR_FONT)
	section.add_theme_font_override("italics_font", VCR_FONT)
	section.add_theme_font_override("bold_italics_font", VCR_FONT)
	section.add_theme_font_size_override("normal_font_size", 13)
	section.size.x = _content_width()
	match style:
		"stat":
			if label != "":
				section.text = "[color=gray]%s:[/color] %s" % [label, text]
			else:
				section.text = text
		"bullet":
			section.text = "  • " + text
		_:
			section.text = text
	_sections_extra.add_child(section)
	_setup_gen += 1
	_enforce_row_cap(_last_title, _setup_gen)


## _await_layout_settled() — async
##
## fit_content RichTextLabels report bogus heights (every word wrapped at a
## ~1px width, observed size 260x5564) until the container cascade assigns the
## real content width — and the engine flushes that sort AFTER the
## process_frame emission, and label fit-heights lag the width assignment by
## further frames, so a fixed frame count resumes early. Waits until the
## combined minimum size is unchanged across two consecutive frames (bounded
## at 16), i.e. fully settled. A concurrent row-cap truncation keeps the min
## size moving, so show_at waits for any in-flight truncation to finish and
## then bakes the truncated size. Callers must re-check their gen token
## afterwards.
func _await_layout_settled() -> void:
	var last := Vector2(-1.0, -1.0)
	for i in 16:
		await get_tree().process_frame
		var m := get_combined_minimum_size()
		if m == last:
			break
		last = m


## _enforce_row_cap(title, gen) — async, deferred
##
## Designer-facing guard: after layout settles, if the total rendered rows
## across all visible sections exceed MAX_ROWS, trailing lines are dropped
## until it fits, an ellipsis is appended, and push_warning fires ONCE per
## setup/section batch. Truncation order: the LAST SectionsExtra section
## first, then body, then earlier sections last-to-first. Name/flavor/rarity
## are never touched. The gen token makes stale checks from superseded
## setup()/add_section() calls no-ops. Row counting waits for layout settle —
## counting pre-settle would see the bogus 1px-width wrap (hundreds of
## phantom rows) and wrongly truncate content that actually fits.
func _enforce_row_cap(title: String, gen: int) -> void:
	await _await_layout_settled()
	if gen != _setup_gen:
		return
	var total := _count_rows()
	if total <= MAX_ROWS:
		return
	var original := total
	var sections := _sections_extra.get_children()
	var order: Array[RichTextLabel] = []
	if sections.size() > 0:
		order.append(sections[-1])
	order.append(_body_label)
	for i in range(sections.size() - 2, -1, -1):
		order.append(sections[i])
	var ellipsis_target: RichTextLabel = _body_label
	for label in order:
		var min_lines := 1 if label == _body_label else 0
		while total > MAX_ROWS and label.get_line_count() > min_lines and label.text != "":
			_drop_trailing_line(label)
			ellipsis_target = label
			await get_tree().process_frame
			if gen != _setup_gen:
				return
			total = _count_rows()
		if label != _body_label and label.text.strip_edges() == "":
			label.visible = false
		if total <= MAX_ROWS:
			break
	ellipsis_target.text = ellipsis_target.text + " [color=gray]…[/color]"
	push_warning("Tooltip '%s' exceeds 15 rows (%d) — content truncated. Shorten the source text." % [title, original])


## _drop_trailing_line(label)
##
## Removes one trailing rendered line's worth of text: everything after the
## last "\n" if there is one, otherwise a per-line character estimate trimmed
## at a word boundary (same heuristic the body truncation always used).
func _drop_trailing_line(label: RichTextLabel) -> void:
	var text: String = label.text
	var newline := text.rfind("\n")
	if newline >= 0:
		label.text = text.substr(0, newline)
		return
	var lines := label.get_line_count()
	var per_line := maxi(1, int(ceil(float(text.length()) / float(maxi(lines, 1)))))
	text = text.substr(0, maxi(0, text.length() - per_line))
	var last_space := text.rfind(" ")
	if last_space > 0:
		text = text.substr(0, last_space)
	label.text = text


func _count_rows() -> int:
	var total := 0
	for label in [_name_label, _body_label, _flavor_label, _rarity_label]:
		if label.visible:
			total += label.get_line_count()
	for child in _sections_extra.get_children():
		if child.visible:
			total += child.get_line_count()
	return total


## show_at(global_pos, anchor_rect)
##
## anchor_rect: optional hover area, forwarded to TweenFX.show_tooltip for
## the stale-tooltip exit guard (auto-hide once the cursor leaves the anchor
## + 24px grace — covers mouse_exited missed on fast mouse movement).
## Deferred until layout settles (_await_layout_settled): fit_content labels
## report bogus heights (each word wrapped at width ~1px, observed size
## 260x5564) until the container assigns the real content width, and
## reset_size() called before that bakes the huge height permanently
## (first-show bug). The tooltip stays invisible during the wait (first
## show), so no wrong-size frame is ever rendered; the show tween starts only
## after correct positioning.
## Clamps to the viewport, positions, then runs the show sequence:
## TweenFX.show_tooltip (pop+fade), shader fade 0->1 on both materials
## (0.25s), border trace 0->1 (0.6s, linear). If the TweenFX cooldown blocks
## the show (returns null), the tooltip snaps to fully shown instead of
## animating — it is never left invisible by a blocked call.
## The gen token makes a pending show a no-op when hide() or a newer
## show_at() supersedes it during the wait.
func show_at(global_pos: Vector2, anchor_rect: Rect2 = Rect2()) -> void:
	_show_gen += 1
	var gen : int = _show_gen
	await _await_layout_settled()
	if gen != _show_gen:
		return
	reset_size()
	var vp : Vector2 = get_viewport_rect().size
	global_pos.x = clampf(global_pos.x, 0.0, maxf(0.0, vp.x - size.x))
	global_pos.y = clampf(global_pos.y, 0.0, maxf(0.0, vp.y - size.y))
	global_position = global_pos

	if _trace_tween and _trace_tween.is_valid():
		_trace_tween.kill()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	var show_tween: Tween = TweenFX.show_tooltip(self, anchor_rect)
	if show_tween == null:
		visible = true
		modulate.a = 1.0
		scale = Vector2.ONE

	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_method(_set_bg_fade, 0.0, 1.0, 0.25)
	_fade_tween.tween_method(_set_border_fade, 0.0, 1.0, 0.25)

	_trace_tween = create_tween()
	_trace_tween.tween_method(_set_border_trace, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_LINEAR)


## cancel_pending_show()
##
## Bumps the show generation so a deferred show_at() still waiting in
## _await_layout_settled() becomes a no-op. Called by TweenFX's stale-tooltip
## exit guard, which hides through TweenFX.hide_tooltip() (no gen bump) —
## without this the pending show would re-pop a ghost after the guard's hide.
func cancel_pending_show() -> void:
	_show_gen += 1


## hide()
##
## TweenFX.hide_tooltip (fade+shrink, then visible=false) and both shader
## fades to 0. Overlapping show/hide is safe: TweenFX kills the prior tooltip
## tween, so the newest call always wins (fix 1), and the gen bump cancels
## any deferred show_at() still waiting for layout settle (fix 3). Overrides
## CanvasItem.hide() by design — the animated path replaces the instant
## native hide.
@warning_ignore("native_method_override")
func hide() -> void:
	_show_gen += 1
	if _trace_tween and _trace_tween.is_valid():
		_trace_tween.kill()
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	TweenFX.hide_tooltip(self)
	var bg_fade: float = _background.material.get_shader_parameter("fade")
	var border_fade: float = _border.material.get_shader_parameter("fade")
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_method(_set_bg_fade, bg_fade, 0.0, 0.2)
	_fade_tween.tween_method(_set_border_fade, border_fade, 0.0, 0.2)


func _set_bg_fade(v: float) -> void:
	_background.material.set_shader_parameter("fade", v)


func _set_border_fade(v: float) -> void:
	_border.material.set_shader_parameter("fade", v)


func _set_border_trace(v: float) -> void:
	_border.material.set_shader_parameter("trace", v)


func _sync_rect_size() -> void:
	_border.material.set_shader_parameter("rect_size", size)
	_background.material.set_shader_parameter("rect_size", size)
