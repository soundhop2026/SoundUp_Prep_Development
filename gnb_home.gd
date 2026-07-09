extends Node2D

const PURPLE    : Color  = Color("#4B0082")
const AMBER     : Color  = Color("#FFB703")
const WHITE     : Color  = Color("#FFFFFF")
const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"

var _font : Font = null

func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	# Background
	var bg := ColorRect.new()
	bg.color        = AMBER
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_back_button()
	_build_logo()
	_build_menu_buttons()


func _build_back_button() -> void:
	var btn := TextureButton.new()
	btn.texture_normal      = load("res://UI_assets/back_button.png") as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.size                = Vector2(90, 90)
	btn.position            = Vector2(30, 30)
	btn.z_index             = 10
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 c : source_color = vec4(0.294, 0.0, 0.51, 1.0);
void fragment() { vec4 t = texture(TEXTURE, UV); COLOR = vec4(c.rgb, t.a); }"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("c", PURPLE)
	btn.material = mat
	btn.pressed.connect(_on_back_pressed)
	add_child(btn)


func _build_logo() -> void:
	const LOGO_PNG : String = "res://UI_assets/GNB_SOUNDHOPplaybutton.png"
	if not ResourceLoader.exists(LOGO_PNG):
		return
	var logo := TextureRect.new()
	logo.texture      = load(LOGO_PNG) as Texture2D
	logo.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size         = Vector2(680, 400)
	logo.position     = Vector2((1280 - 680) * 0.5, 60)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)


func _build_menu_buttons() -> void:
	const BTN_W  : float = 500.0
	const BTN_H  : float = 170.0
	const GAP    : float =  40.0
	const BTN_Y  : float = 472.0
	const RADIUS : int   =  24

	var start_x : float = (1280 - BTN_W * 2 - GAP) * 0.5

	var labels  : Array[String] = ["What's SoundHop", "Where am I"]
	var targets : Array[String] = ["res://gnb_whats_soundhop.tscn", "res://gnb_where_am_i.tscn"]

	for i in range(2):
		var btn := Button.new()
		btn.text         = labels[i]
		btn.size         = Vector2(BTN_W, BTN_H)
		btn.position     = Vector2(start_x + i * (BTN_W + GAP), BTN_Y)
		btn.pivot_offset = Vector2(BTN_W * 0.5, BTN_H * 0.5)
		btn.z_index      = 5

		if _font:
			btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 38)
		btn.add_theme_color_override("font_color",         PURPLE)
		btn.add_theme_color_override("font_hover_color",   PURPLE)
		btn.add_theme_color_override("font_pressed_color", PURPLE)
		btn.add_theme_color_override("font_focus_color",   PURPLE)

		var style := StyleBoxFlat.new()
		style.bg_color                   = WHITE
		style.border_color               = PURPLE
		style.border_width_top           = 3
		style.border_width_bottom        = 3
		style.border_width_left          = 3
		style.border_width_right         = 3
		style.corner_radius_top_left     = RADIUS
		style.corner_radius_top_right    = RADIUS
		style.corner_radius_bottom_left  = RADIUS
		style.corner_radius_bottom_right = RADIUS

		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color("#FFF4CC")

		btn.add_theme_stylebox_override("normal",  style)
		btn.add_theme_stylebox_override("hover",   hover)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus",   style)

		btn.pressed.connect(_on_menu_pressed.bind(targets[i]))
		add_child(btn)


func _on_back_pressed() -> void:
	if GNBState.return_scene != "":
		var target := GNBState.return_scene
		GNBState.return_scene = ""
		get_tree().change_scene_to_file(target)
	else:
		get_tree().change_scene_to_file("res://title.tscn")


func _on_menu_pressed(target: String) -> void:
	get_tree().change_scene_to_file(target)
