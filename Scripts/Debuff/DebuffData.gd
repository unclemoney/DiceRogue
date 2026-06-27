extends Resource
class_name DebuffData

## DebuffData
##
## Resource that defines a debuff's metadata, scene reference, and procedural
## glyph shader configuration. The UI renders debuffs with the
## debuff_glyph_glow.gdshader SDF glyph system instead of static icon textures.
## Used by DebuffManager for spawning and by the automatic debuff
## selection system based on difficulty rating.

@export var id: String
@export var display_name: String
@export var description: String
@export var scene: PackedScene

## Procedural glyph ID rendered by debuff_glyph_glow.gdshader (0-15).
## Glyph reference:
## 0 = Coupon Block, 1 = Paid Rerolls, 2 = Color Drain, 3 = Mod Lockout,
## 4 = No Twos, 5 = Chore Surge, 6 = Half Value, 7 = Sold Out,
## 8 = No Locks, 9 = D4 Swap, 10 = Power Cut, 11 = One Roll Only,
## 12 = Level Loss, 13 = Roll Tax, 14 = Divide All, 15 = Wealth Drain.
@export_range(0, 15) var glyph_id: int = 0

## Optional glyph tint. If alpha is 0, the UI falls back to the difficulty tint.
@export var glow_color: Color = Color(0.0, 0.0, 0.0, 0.0)

## Per-debuff SDF shader overrides. Defaults mirror debuff_glyph_glow.gdshader.
@export_range(0.2, 2.0) var glyph_scale: float = 1.0
@export_range(0.0, 0.4) var line_thickness: float = 0.10
@export_range(0.0, 0.2) var rim_thickness: float = 0.03
@export_range(0.0, 0.5) var bloom_softness: float = 0.18
@export_range(0.0, 1.0) var wobble_strength: float = 0.4
@export_range(0.0, 1.0) var roughness_strength: float = 0.35
@export_range(0.0, 4.0) var glow_strength: float = 1.4

## Difficulty rating (1-5) for automatic selection based on round config.
## 1 = Easy (early game), 5 = Brutal (late game only)
@export_range(1, 5) var difficulty_rating: int = 1
