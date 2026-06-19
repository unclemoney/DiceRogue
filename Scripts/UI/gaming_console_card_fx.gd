extends RefCounted
class_name GamingConsoleCardFX

const ORINGIUS_JULIUS_SHADER_PATH := "res://Scripts/Shaders/oringius_julius_vip_card.gdshader"
const ARCADIA_ARCADE_SHADER_PATH := "res://Scripts/Shaders/arcadia_arcade_vip_card.gdshader"
const WALDEN_POND_BOOKS_SHADER_PATH := "res://Scripts/Shaders/walden_pond_books_vip_card.gdshader"
const HOBBY_HAVE_SHADER_PATH := "res://Scripts/Shaders/hobby_have_vip_card.gdshader"
const J_MART_SHADER_PATH := "res://Scripts/Shaders/j_mart_vip_card.gdshader"
const DOWNTOWN_VIDEO_RENTALS_SHADER_PATH := "res://Scripts/Shaders/downtown_video_rentals_vip_card.gdshader"


static func get_art_texture(data: GamingConsoleData) -> Texture2D:
	if not data:
		return null
	if data.vip_card_art:
		return data.vip_card_art
	return data.icon


static func create_material(shader_key: String, rect_size: Vector2, effect_strength: float = 1.0) -> ShaderMaterial:
	var shader: Shader = _get_shader(shader_key)
	if not shader:
		return null

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("effect_time", 0.0)
	material.set_shader_parameter("rect_size", rect_size)
	material.set_shader_parameter("effect_strength", effect_strength)
	return material


static func configure_material(material: ShaderMaterial, rect_size: Vector2, effect_time: float, effect_strength: float = 1.0) -> void:
	if not material:
		return
	material.set_shader_parameter("rect_size", rect_size)
	material.set_shader_parameter("effect_time", effect_time)
	material.set_shader_parameter("effect_strength", effect_strength)


static func _get_shader(shader_key: String) -> Shader:
	match shader_key:
		"oringius_julius":
			return load(ORINGIUS_JULIUS_SHADER_PATH) as Shader
		"arcadia_arcade":
			return load(ARCADIA_ARCADE_SHADER_PATH) as Shader
		"walden_pond_books":
			return load(WALDEN_POND_BOOKS_SHADER_PATH) as Shader
		"hobby_have":
			return load(HOBBY_HAVE_SHADER_PATH) as Shader
		"j_mart":
			return load(J_MART_SHADER_PATH) as Shader
		"downtown_video_rentals":
			return load(DOWNTOWN_VIDEO_RENTALS_SHADER_PATH) as Shader
		_:
			return null