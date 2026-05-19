## UI Animation Framework — Example Usage
##
## Copy these patterns into your own scripts. These are reference snippets,
## not attached to any scene by default.
##
## All examples assume TweenFXHelper is available as an autoload.

# ═══════════════════════════════════════════════════════════════════════════════
# EXAMPLE 1: Menu Panel — Cascade Entrance on VBoxContainer Buttons
# ═══════════════════════════════════════════════════════════════════════════════
#
# Scene tree:
#   MenuPanel (Control)
#   └── ButtonList (VBoxContainer)
#       ├── ContainerAnimator (Node)   <-- add this
#       ├── PlayButton (Button)
#       ├── SettingsButton (Button)
#       └── QuitButton (Button)
#
# Configure ContainerAnimator in the Inspector:
#   trigger_mode = READY
#   entrance_preset = "fly_in_left"
#   stagger_pattern = CASCADE
#   stagger_delay = 0.08
#   delay_before_start = 0.2
#
# On _ready(), the buttons will fly in from the left, top-to-bottom.


# ═══════════════════════════════════════════════════════════════════════════════
# EXAMPLE 2: Popup Panel — Overshoot Pop Entrance
# ═══════════════════════════════════════════════════════════════════════════════
#
# For a popup that needs to feel punchy and important:
#
#   PopupRoot (Control)
#   ├── Overlay (ColorRect)
#   ├── MainPanel (PanelContainer)
#   │   └── ContentVBox (VBoxContainer)
#   │       ├── TitleLabel (Label)
#   │       ├── BodyLabel (Label)
#   │       └── CloseButton (Button)
#   └── ContentVBox/ContainerAnimator (Node)  <-- add this as child of ContentVBox
#
# ContainerAnimator settings:
#   trigger_mode = MANUAL
#   entrance_preset = "overshoot_pop"
#   stagger_pattern = CENTER_OUT
#   stagger_delay = 0.06
#
# Code in PopupRoot:
#   func show_popup() -> void:
#       visible = true
#       # Fade overlay manually (PanelContainer scale warning)
#       var overlay_tween = create_tween()
#       overlay_tween.tween_property(overlay, "modulate:a", 1.0, 0.2)
#       # Trigger container animator
#       $ContentVBox/ContainerAnimator.trigger_entrance()


# ═══════════════════════════════════════════════════════════════════════════════
# EXAMPLE 3: Settings Menu — Slide In from the Left
# ═══════════════════════════════════════════════════════════════════════════════
#
#   SettingsMenu (Control)
#   ├── Overlay (ColorRect)
#   └── Panel (PanelContainer)
#       └── ContainerAnimator (Node)  <-- animate the panel itself, not children
#
# Wait — ContainerAnimator animates children of a Container. To animate the
# panel itself, use TweenFXHelper directly or attach a UIAnimated node:
#
#   Panel (PanelContainer)
#   └── UIAnimated (Node)  <-- attach as child
#
# UIAnimated settings:
#   entrance_preset = "fly_in_left"
#   exit_preset = "fly_out_right"
#   auto_trigger_on_ready = false
#
# Code:
#   func open() -> void:
#       visible = true
#       $Panel/UIAnimated.play_entrance()
#   func close() -> void:
#       await $Panel/UIAnimated.play_exit().finished
#       visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# EXAMPLE 4: Grid of Shop Items — Center-Out Stagger
# ═══════════════════════════════════════════════════════════════════════════════
#
#   ShopGrid (GridContainer)
#   ├── ContainerAnimator (Node)  <-- add this
#   ├── ShopItem_0 (PanelContainer)
#   ├── ShopItem_1 (PanelContainer)
#   ├── ShopItem_2 (PanelContainer)
#   ├── ShopItem_3 (PanelContainer)
#   ├── ShopItem_4 (PanelContainer)
#   └── ShopItem_5 (PanelContainer)
#
# ContainerAnimator settings:
#   trigger_mode = MANUAL
#   entrance_preset = "pop_in"
#   stagger_pattern = CENTER_OUT
#   stagger_delay = 0.06
#   delay_before_start = 0.1
#
# Code (e.g. after restocking the shop):
#   func restock() -> void:
#       _build_items()
#       $ShopGrid/ContainerAnimator.trigger_entrance()
#
# The center item(s) will pop in first, then the ones around them,
# radiating outward in a satisfying wave.


# ═══════════════════════════════════════════════════════════════════════════════
# EXAMPLE 5: Per-Child Override with UIAnimated
# ═══════════════════════════════════════════════════════════════════════════════
#
# In a list where MOST items pop in, but the header should slide in:
#
#   ListVBox (VBoxContainer)
#   ├── ContainerAnimator (Node)
#   ├── HeaderLabel (Label)
#   │   └── UIAnimated (Node)   <-- override for this child only
#   │       entrance_preset = "slide_and_fade"
#   ├── Item1 (Button)
#   ├── Item2 (Button)
#   └── Item3 (Button)
#
# ContainerAnimator settings:
#   entrance_preset = "pop_in"
#   respect_child_overrides = true
#
# Result: HeaderLabel slides and fades, while Item1-3 pop in.


# ═══════════════════════════════════════════════════════════════════════════════
# EXAMPLE 6: Manual Container Sequencing from Code
# ═══════════════════════════════════════════════════════════════════════════════
#
# Use TweenFXHelper directly when you don't want to add a node.
#
#   func show_level_complete() -> void:
#       var rows = $StatsVBox.get_children()
#       var profile = JuiceProfile.new()
#       profile.default_stagger = 0.12
#       profile.overshoot_strength = 0.2
#       TweenFXHelper.animate_container_children(
#           $StatsVBox,
#           "fly_in_up",
#           "cascade",
#           profile
#       )


# ═══════════════════════════════════════════════════════════════════════════════
# EXAMPLE 7: Exit Animation with Await
# ═══════════════════════════════════════════════════════════════════════════════
#
#   func close_menu() -> void:
#       # 1. Animate all buttons out
#       var tweens = $ButtonList/ContainerAnimator.trigger_exit()
#       if not tweens.is_empty():
#           await tweens[-1].finished
#       # 2. Fade overlay
#       var tween = create_tween()
#       tween.tween_property(overlay, "modulate:a", 0.0, 0.2)
#       await tween.finished
#       # 3. Hide
#       visible = false
