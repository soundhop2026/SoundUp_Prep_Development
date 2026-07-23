class_name BackButton
extends TextureButton

# Shared Back Button — same position, size, touch target, and appearance
# everywhere it's used across SoundHop gameplay rounds (game.gd, prep_game.gd,
# game2.gd, game25.gd, game15.gd). Each screen still connects its own
# `pressed` handler so the navigation/guard logic can differ per game flow —
# only the button itself (this file) is shared.

func _init() -> void:
	texture_normal      = load("res://UI_assets/back_button.png") as Texture2D
	ignore_texture_size = true
	stretch_mode        = TextureButton.STRETCH_KEEP_CENTERED
	custom_minimum_size = Vector2(150, 150)
	size                = Vector2(150, 150)
	position             = Vector2(108, 25)
	z_index              = 2

	# Recolour the black triangle to white so it reads clearly on a dark background
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(1.0, 1.0, 1.0, c.a); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	material = mat
