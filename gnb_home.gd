extends Node2D

const PURPLE    : Color  = Color("#4B0082")
const AMBER     : Color  = Color("#FFB703")
const WHITE     : Color  = Color("#FFFFFF")
const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"

# ─── Logo ───────────────────────────────────────────────────────────────────
# Face + "SOUNDHOP" hair are the original hand-drawn artwork again — a
# code-built version (individual arced letters + a synthetic fill behind the
# face) kept missing the mark on look and feel. Split into two separately
# color-masked layers from the same original GNB_SOUNDHOPplaybutton.png
# (letters-only and face-only, both on an identical 2000x1264 canvas so they
# stay aligned) so the face alone can be scaled up without resizing the
# letters — the baked-in "Start with Sound" text was also dropped from both;
# the subtitle below is real, separate text instead, so it stays correctable.
const LOGO_LETTERS_IMG : String = "res://UI_assets/GNB_SOUNDHOP_letters_only.png"
const LOGO_FACE_IMG    : String = "res://UI_assets/GNB_SOUNDHOP_face_only.png"
const LOGO_SIZE         : Vector2 = Vector2(604.0, 382.0)
const LOGO_TOP          : float   = 25.0
const LOGO_FACE_SCALE   : float   = 1.10   # face only, relative to its size in the original art
const LOGO_LETTERS_Y_OFFSET : float = 6.0  # nudge the hair down, closer to the head

const LOGO_SUBTITLE_Y     : float = 427.0
const LOGO_SUBTITLE_SIZE  : int   = 24

var _font : Font = null

func _ready() -> void:
	SceneBackground.set_color(AMBER)
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
	_build_logo_image()
	_build_logo_subtitle()


func _build_logo_image() -> void:
	var pos : Vector2 = Vector2((1280.0 - LOGO_SIZE.x) * 0.5, LOGO_TOP)

	# Face first (behind), scaled up around its own center — both layers
	# share the exact same source canvas, so this position/size also lines
	# up the letters layer drawn on top with no extra offset math needed.
	if ResourceLoader.exists(LOGO_FACE_IMG):
		var face := TextureRect.new()
		face.texture       = load(LOGO_FACE_IMG) as Texture2D
		face.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size          = LOGO_SIZE
		face.position      = pos
		face.pivot_offset  = LOGO_SIZE * 0.5
		face.scale         = Vector2(LOGO_FACE_SCALE, LOGO_FACE_SCALE)
		face.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		face.z_index       = 1
		add_child(face)

	if ResourceLoader.exists(LOGO_LETTERS_IMG):
		var letters := TextureRect.new()
		letters.texture      = load(LOGO_LETTERS_IMG) as Texture2D
		letters.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		letters.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		letters.size         = LOGO_SIZE
		letters.position     = pos + Vector2(0.0, LOGO_LETTERS_Y_OFFSET)
		letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
		letters.z_index      = 2
		add_child(letters)


func _build_logo_subtitle() -> void:
	var lbl := Label.new()
	lbl.text                 = "Start with the Sound"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(1280.0, 36.0)
	lbl.position             = Vector2(0.0, LOGO_SUBTITLE_Y)
	lbl.z_index              = 3
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	if _font:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", LOGO_SUBTITLE_SIZE)
	lbl.add_theme_color_override("font_color", PURPLE)
	add_child(lbl)


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
