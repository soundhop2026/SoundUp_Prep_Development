extends Node2D

const PURPLE    : Color  = Color("#4B0082")
const AMBER     : Color  = Color("#FFB703")
const CREAM     : Color  = Color("#EDE4D3")
const WHITE     : Color  = Color("#FFFFFF")
const DARK      : Color  = Color("#333333")
const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"

# 3-column card grid — narrower cards with side breathing room
const CARD_W   : float = 330.0
const CARD_GAP : float = 16.0
const CARD_L_X : float = (1280.0 - CARD_W * 3.0 - CARD_GAP * 2.0) * 0.5  # ≈ 129

var _font : Font = null

func _ready() -> void:
	SceneBackground.set_color(CREAM)
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	var bg := ColorRect.new()
	bg.color        = CREAM
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_back_button()
	_build_hero()
	_build_what_is_soundhop()
	_build_how_it_works()
	_build_meet_characters()


# ─── Back button ─────────────────────────────────────────────────────────────
func _build_back_button() -> void:
	var btn := TextureButton.new()
	btn.texture_normal      = load("res://UI_assets/back_button.png") as Texture2D
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.size                = Vector2(90, 90)
	btn.position            = Vector2(30, 0)
	btn.z_index             = 10
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 c : source_color;
void fragment() { vec4 t = texture(TEXTURE, UV); COLOR = vec4(c.rgb, t.a); }"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("c", AMBER)
	btn.material = mat
	btn.pressed.connect(_on_back_pressed)
	add_child(btn)


# ─── Section 1: Hero ──────────────────────────────────────────────────────────
func _build_hero() -> void:
	var panel := ColorRect.new()
	panel.color        = PURPLE
	panel.size         = Vector2(1280, 90)
	panel.position     = Vector2.ZERO
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_root_label("Hear it. Find it. Hop.",
		Vector2(0, 8), Vector2(1280, 40), 30, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	_root_label("A phonics game where sound always comes first — no letters, no reading, no rush.",
		Vector2(100, 50), Vector2(1080, 34), 15, AMBER, HORIZONTAL_ALIGNMENT_CENTER)


# ─── Section 2: What is SoundHop ─────────────────────────────────────────────
func _build_what_is_soundhop() -> void:
	_root_label("What is SoundHop",
		Vector2(CARD_L_X, 100), Vector2(600, 24), 18, PURPLE)
	_root_label(
		"Children need to hear sounds before they can read them.\n" +
		"SoundHop trains the ear first — through listening, matching, and play.",
		Vector2(CARD_L_X, 126), Vector2(1280 - CARD_L_X * 2.0, 44), 15, DARK)


# ─── Section 3: How it works ─────────────────────────────────────────────────
func _build_how_it_works() -> void:
	_root_label("How it works",
		Vector2(CARD_L_X, 179), Vector2(400, 24), 18, PURPLE)

	var steps : Array[Dictionary] = [
		{ "num": "01", "title": "Listen",
		  "body": "Press LISTEN, hear the sound.",
		  "icon": "res://UI_assets/playbutton.png" },
		{ "num": "02", "title": "Find",
		  "body": "Look at the pictures carefully.",
		  "icon": "" },
		{ "num": "03", "title": "Tap or Drag",
		  "body": "Tap or drag to match the sound.",
		  "icon": "" },
	]

	for i in range(3):
		var s : Dictionary = steps[i]
		var cx : float = CARD_L_X + i * (CARD_W + CARD_GAP)
		_make_step_card(s["num"], s["title"], s["body"], s["icon"], Vector2(cx, 206))


func _make_step_card(num: String, title: String, body: String,
		icon_path: String, pos: Vector2) -> void:
	const H : float = 110.0
	var panel := _card_panel(pos, Vector2(CARD_W, H))

	var hdr := Label.new()
	hdr.text     = num + "   " + title
	hdr.position = Vector2(12, 10)
	hdr.size     = Vector2(CARD_W - 24, 26)
	hdr.add_theme_font_size_override("font_size", 17)
	hdr.add_theme_color_override("font_color", PURPLE)
	if _font: hdr.add_theme_font_override("font", _font)
	panel.add_child(hdr)

	var body_lbl := Label.new()
	body_lbl.text          = body
	body_lbl.position      = Vector2(12, 40)
	body_lbl.size          = Vector2(CARD_W - 76, 56)
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.add_theme_font_size_override("font_size", 14)
	body_lbl.add_theme_color_override("font_color", DARK)
	if _font: body_lbl.add_theme_font_override("font", _font)
	panel.add_child(body_lbl)

	# EvalPlayButton icon: native 907×437 (≈ 2.07:1 landscape) — display at ratio
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var img := TextureRect.new()
		img.texture        = load(icon_path) as Texture2D
		img.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		img.size           = Vector2(62, 30)   # respects 2:1 native ratio, no upscale
		img.position       = Vector2(CARD_W - 70, H - 38)
		_apply_playbutton_tint(img, icon_path)
		panel.add_child(img)


# ─── Section 4: Meet the Characters ──────────────────────────────────────────
func _build_meet_characters() -> void:
	_root_label("Meet the Characters",
		Vector2(CARD_L_X, 328), Vector2(700, 24), 18, PURPLE)

	var chars : Array[Dictionary] = [
		{ "name": "Pointed Hand",
		  "desc": "I point to what to listen to —\nthe LISTEN bar or the pictures above.\nTap where I point, not me.",
		  "path": "res://UI_assets/handsigns/pointed.png" },
		{ "name": "Listen Button",
		  "desc": "When I appear,\nlisten to the choices below.\nDo not tap me.",
		  "path": "res://UI_assets/playbutton.png" },
		{ "name": "Open Hand",
		  "desc": "Tap me to hear a sound,\nthen drag me to the cubes.",
		  "path": "res://UI_assets/handsigns/openhand.png" },
		{ "name": "Star",
		  "desc": "You earned it. Well done!",
		  "path": "res://UI_assets/star.png" },
		{ "name": "Crown",
		  "desc": "Complete a level. Earn your crown.",
		  "path": "res://UI_assets/level_transition_crown/SoundUp_crown.png" },
		{ "name": "Cube Board",
		  "desc": "Each sound fades as you go.",
		  "path": "res://UI_assets/preplevel_set_counting_cube.png" },
	]

	const ROW_H   : float = 158.0
	const ROW_GAP : float = 8.0
	const START_Y : float = 354.0

	for i in range(6):
		var row : int   = i / 3
		var col : int   = i % 3
		var cx  : float = CARD_L_X + col * (CARD_W + CARD_GAP)
		var cy  : float = START_Y + row * (ROW_H + ROW_GAP)
		_make_char_card(chars[i]["name"], chars[i]["desc"], chars[i]["path"],
			Vector2(cx, cy))


func _make_char_card(char_name: String, desc: String,
		icon_path: String, pos: Vector2) -> void:
	const H         : float = 158.0
	const ICON_W    : float = 62.0   # matches native 907×437 ≈ 2:1 ratio → 62×30
	const ICON_H    : float = 30.0
	const ICON_FULL : float = 60.0   # square icons use this size
	var panel := _card_panel(pos, Vector2(CARD_W, H))

	if ResourceLoader.exists(icon_path):
		var img := TextureRect.new()
		img.texture        = load(icon_path) as Texture2D
		img.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# EvalPlayButton is landscape — give it a landscape box so it isn't forced into a square
		var is_playbutton : bool = icon_path.ends_with("playbutton.png")
		if is_playbutton:
			img.size     = Vector2(ICON_W * 2.0, ICON_H * 2.0)   # 124×60
			img.position = Vector2((CARD_W - ICON_W * 2.0) * 0.5, 6)
		else:
			img.size     = Vector2(ICON_FULL, ICON_FULL)
			img.position = Vector2((CARD_W - ICON_FULL) * 0.5, 4)
		_apply_playbutton_tint(img, icon_path)
		panel.add_child(img)

	var name_lbl := Label.new()
	name_lbl.text                 = char_name
	name_lbl.position             = Vector2(6, 72)
	name_lbl.size                 = Vector2(CARD_W - 12, 22)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", PURPLE)
	if _font: name_lbl.add_theme_font_override("font", _font)
	panel.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text                 = desc
	desc_lbl.position             = Vector2(6, 96)
	desc_lbl.size                 = Vector2(CARD_W - 12, 58)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", DARK)
	if _font: desc_lbl.add_theme_font_override("font", _font)
	panel.add_child(desc_lbl)


# ─── Helpers ──────────────────────────────────────────────────────────────────
func _card_panel(pos: Vector2, sz: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size     = sz
	var style := StyleBoxFlat.new()
	style.bg_color                   = WHITE
	style.border_color               = PURPLE
	style.border_width_top           = 2
	style.border_width_bottom        = 2
	style.border_width_left          = 2
	style.border_width_right         = 2
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _apply_playbutton_tint(node: TextureRect, path: String) -> void:
	if not path.ends_with("playbutton.png"):
		return
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 c : source_color;
void fragment() { vec4 t = texture(TEXTURE, UV); COLOR = vec4(c.rgb, t.a); }"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("c", AMBER)
	node.material = mat


func _root_label(text: String, pos: Vector2, sz: Vector2, fsize: int, col: Color,
		halign: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.position             = pos
	lbl.size                 = sz
	lbl.horizontal_alignment = halign
	lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	if _font: lbl.add_theme_font_override("font", _font)
	add_child(lbl)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://gnb_home.tscn")
