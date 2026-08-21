extends Node2D

# ─── Constants ────────────────────────────────────────────────────────────────
const BG_COLOR   : Color = Color("#4B0082")
const FACE_COLOR : Color = Color("#F5E6CC")  # PlayButton face — cream beige
const LOGO_COLOR : Color = Color("#FFB703")  # SOUNDUP + subtitle — amber

const LETTERS       : Array[String] = ["S","O","U","N","D","H","O","P"]
const LETTER_SIZE   : int           = 86
const SUBTITLE_SIZE : int           = 25
const LETTER_W      : float         = 64.0
const LETTER_H      : float         = 88.0

const ARC_CENTER  : Vector2 = Vector2(618.0, 450.0)
const ARC_RADIUS  : float   = 300.0
const ARC_MIN_DEG : float   = -36.0
const ARC_MAX_DEG : float   =  36.0

const FACE_CENTER_Y : float = 300.0
const BTN_SCALE     : float = 0.90

const WORD_TEXTS    : Array[String] = ["Learning", "Sounds"]
const WORD_W        : Array[float]  = [128.0, 96.0]
const WORD_X_OFFSET : Array[float]  = [-142.0, -2.0]  # offsets from viewport centre; centred on x=618 (the logo's true visual centre), not 640 — see ARC_CENTER
const WORDS_Y       : float         = 450.0

const FLY_OUT : Array[Vector2] = [
	Vector2(-900.0,  -80.0),
	Vector2(-420.0, -800.0),
	Vector2(  60.0, -900.0),
	Vector2(  50.0, -950.0),
	Vector2( 900.0, -420.0),
	Vector2( 580.0, -760.0),
	Vector2( 800.0,  300.0),
	Vector2( 950.0,  -60.0),
]

# ─── State ────────────────────────────────────────────────────────────────────
var _letters : Array[Label] = []
var _words   : Array[Label] = []
var _word_x  : Array[float] = []
var _font    : Font         = null
var _mono_font : Font       = null
var _pressed        : bool         = false
var _can_press      : bool         = false
var _letter_landing : Array[bool]  = []
var _drift_tweens   : Array        = []
var _sway_tween     : Tween        = null
var _debug_btn      : Button       = null
var _gnb_btn        : Button       = null
var _vp_cx          : float        = 640.0   # true horizontal centre of the viewport

# ─── Setup ────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	$ColorRect.color    = BG_COLOR
	$ColorRect.size     = get_viewport_rect().size
	$ColorRect.position = Vector2(0, 0)

	_vp_cx = get_viewport_rect().size.x / 2.0
	for off in WORD_X_OFFSET:
		_word_x.append(_vp_cx + off)

	_create_gnb_entry()

	$PlayButton.scale    = Vector2(BTN_SCALE, BTN_SCALE)
	$PlayButton.position = Vector2(
		_vp_cx - 907.0 * BTN_SCALE * 0.5,
		FACE_CENTER_Y - 437.0 * BTN_SCALE * 0.5
	)
	_apply_shader($PlayButton, FACE_COLOR)
	$PlayButton.pressed.connect(_on_play_pressed)

	$BGMPlayer.finished.connect(_on_bgm_finished)

	var font_path : String = "res://UI_assets/210 연필스케치R.ttf"
	if ResourceLoader.exists(font_path):
		_font = load(font_path)

	var mono_font_path : String = "res://UI_assets/JetBrainsMono-Regular.ttf"
	if ResourceLoader.exists(mono_font_path):
		_mono_font = load(mono_font_path)

	for _i in range(LETTERS.size()):
		_letter_landing.append(false)
		_drift_tweens.append(null)

	_create_letters()
	_create_words()
	_create_copyright_label()
	_create_debug_menu_button()
	_animate_in()

func _create_copyright_label() -> void:
	const BOTTOM_MARGIN : float = 50.0   # distance from the bottom of the screen

	var lbl := Label.new()
	lbl.text                 = "© 2026 Acron Inc. All rights reserved."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position             = Vector2(-24.0, get_viewport_rect().size.y - BOTTOM_MARGIN)
	lbl.size                 = Vector2(get_viewport_rect().size.x, 20.0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", LOGO_COLOR)
	if _mono_font:
		lbl.add_theme_font_override("font", _mono_font)
	add_child(lbl)

func _create_debug_menu_button() -> void:
	if not DebugConfig.DEBUG_MODE:
		return
	_debug_btn              = Button.new()
	_debug_btn.text         = "DEBUG"
	_debug_btn.size         = Vector2(200, 70)
	_debug_btn.position     = Vector2(20.0, 20.0)
	_debug_btn.z_index      = 10
	_debug_btn.add_theme_font_size_override("font_size", 22)
	_debug_btn.add_theme_color_override("font_color", Color("#FFFFFF"))
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color("#E0334D")
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	_debug_btn.add_theme_stylebox_override("normal",  style)
	_debug_btn.add_theme_stylebox_override("hover",   style)
	_debug_btn.add_theme_stylebox_override("pressed", style)
	_debug_btn.add_theme_stylebox_override("focus",   style)
	_debug_btn.pressed.connect(_on_debug_menu_pressed)
	add_child(_debug_btn)

func _on_debug_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://debug_menu.tscn")

func _apply_shader(node: CanvasItem, color: Color) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 tint_color : source_color;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tint_color.rgb, tex.a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint_color", color)
	node.material = mat

# ─── Arc helpers ──────────────────────────────────────────────────────────────
func _letter_final_pos(idx: int) -> Vector2:
	var t   : float = float(idx) / float(LETTERS.size() - 1)
	var deg : float = ARC_MIN_DEG + t * (ARC_MAX_DEG - ARC_MIN_DEG)
	var rad : float = deg_to_rad(deg)
	var cx  : float = (_vp_cx - 22.0) + ARC_RADIUS * sin(rad)
	var cy  : float = ARC_CENTER.y - ARC_RADIUS * cos(rad)
	return Vector2(cx - LETTER_W * 0.5, cy - LETTER_H * 0.5)

func _letter_final_rot(idx: int) -> float:
	var t : float = float(idx) / float(LETTERS.size() - 1)
	return ARC_MIN_DEG + t * (ARC_MAX_DEG - ARC_MIN_DEG)

# ─── Node creation ────────────────────────────────────────────────────────────
func _create_letters() -> void:
	for i in range(LETTERS.size()):
		var lbl := Label.new()
		lbl.text                 = LETTERS[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size                 = Vector2(LETTER_W, LETTER_H)
		lbl.pivot_offset         = Vector2(LETTER_W * 0.5, LETTER_H * 0.5)
		lbl.position             = _letter_final_pos(i)
		lbl.rotation_degrees     = _letter_final_rot(i)
		lbl.modulate.a           = 0.0
		lbl.z_index              = 3
		if _font:
			lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", LETTER_SIZE)
		lbl.add_theme_color_override("font_color", LOGO_COLOR)
		add_child(lbl)
		_letters.append(lbl)

func _create_words() -> void:
	for i in range(WORD_TEXTS.size()):
		var lbl := Label.new()
		lbl.text                 = WORD_TEXTS[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size                 = Vector2(WORD_W[i], 34.0)
		lbl.position             = Vector2(_word_x[i], WORDS_Y)
		lbl.modulate.a           = 0.0
		lbl.z_index              = 3
		if _font:
			lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
		lbl.add_theme_color_override("font_color", LOGO_COLOR)
		add_child(lbl)
		_words.append(lbl)

# ─── Birds-flocking drift ─────────────────────────────────────────────────────
func _drift_loop(i: int) -> void:
	while not _letter_landing[i]:
		var target_pos := Vector2(randf_range(60.0, 1220.0), randf_range(40.0, 360.0))
		var target_rot : float = randf_range(-18.0, 18.0)
		var duration   : float = randf_range(1.1, 2.0)
		_drift_tweens[i] = create_tween()
		_drift_tweens[i].set_parallel(true)
		_drift_tweens[i].tween_property(_letters[i], "position", target_pos, duration) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_drift_tweens[i].tween_property(_letters[i], "rotation_degrees", target_rot, duration) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(duration).timeout

func _land_letter(i: int) -> void:
	_letter_landing[i] = true
	if _drift_tweens[i] != null:
		_drift_tweens[i].kill()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_letters[i], "position", _letter_final_pos(i), 0.85) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_letters[i], "rotation_degrees", _letter_final_rot(i), 0.85) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# ─── Intro animation ──────────────────────────────────────────────────────────
func _animate_in() -> void:
	for i in range(LETTERS.size()):
		_letter_landing[i]           = false
		_letters[i].position         = Vector2(randf_range(60.0, 1220.0), randf_range(40.0, 360.0))
		_letters[i].rotation_degrees = randf_range(-20.0, 20.0)
		_letters[i].modulate.a       = 0.0

	await get_tree().create_timer(0.3).timeout

	for i in range(LETTERS.size()):
		var t := create_tween()
		t.tween_property(_letters[i], "modulate:a", 1.0, 0.5)

	await get_tree().create_timer(0.7).timeout

	for i in range(LETTERS.size()):
		_drift_loop(i)

	await get_tree().create_timer(3.0).timeout

	for i in range(LETTERS.size()):
		_land_letter(i)
		await get_tree().create_timer(0.65).timeout

	await get_tree().create_timer(0.85).timeout

	for i in range(WORD_TEXTS.size()):
		_words[i].position   = Vector2(_word_x[i], 830.0)
		_words[i].modulate.a = 1.0
		var t := create_tween()
		t.tween_property(_words[i], "position:y", WORDS_Y, 0.50) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(1.0).timeout

	await get_tree().create_timer(3.0).timeout
	_start_sway()
	_can_press = true

# ─── Idle sway ────────────────────────────────────────────────────────────────
func _start_sway() -> void:
	var base_x : float = $PlayButton.position.x
	_sway_tween = create_tween().set_loops()
	_sway_tween.tween_property($PlayButton, "position:x", base_x + 12.0, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_sway_tween.tween_property($PlayButton, "position:x", base_x - 12.0, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_sway() -> void:
	if _sway_tween != null:
		_sway_tween.kill()
		_sway_tween = null
	$PlayButton.position.x = _vp_cx - 907.0 * BTN_SCALE * 0.5

func _create_gnb_entry() -> void:
	const BTN_W  : float = 72.0
	const BTN_H  : float = 56.0
	const BAR_W  : float = 44.0
	const BAR_H  : float = 7.0
	const BAR_GAP: float = 9.0

	_gnb_btn             = Button.new()
	_gnb_btn.text        = ""
	_gnb_btn.size        = Vector2(BTN_W, BTN_H)
	_gnb_btn.position    = Vector2(get_viewport_rect().size.x - BTN_W - 20.0, 20.0)
	_gnb_btn.z_index     = 10
	_gnb_btn.pivot_offset = Vector2(BTN_W * 0.5, BTN_H * 0.5)

	var blank := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		_gnb_btn.add_theme_stylebox_override(s, blank)

	var x0 : float = (BTN_W - BAR_W) * 0.5
	var y0 : float = (BTN_H - (BAR_H * 3.0 + BAR_GAP * 2.0)) * 0.5
	for i in range(3):
		var bar := ColorRect.new()
		bar.color        = LOGO_COLOR
		bar.size         = Vector2(BAR_W, BAR_H)
		bar.position     = Vector2(x0, y0 + i * (BAR_H + BAR_GAP))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gnb_btn.add_child(bar)

	_gnb_btn.pressed.connect(_on_gnb_pressed)
	add_child(_gnb_btn)

func _on_gnb_pressed() -> void:
	get_tree().change_scene_to_file("res://gnb_home.tscn")

# ─── Play button pressed ──────────────────────────────────────────────────────
func _on_play_pressed() -> void:
	if _pressed or not _can_press:
		return
	_pressed = true
	$PlayButton.pressed.disconnect(_on_play_pressed)
	_animate_out_then_route()

# ─── BGM looping ──────────────────────────────────────────────────────────────
func _on_bgm_finished() -> void:
	$BGMPlayer.play()

# ─── Exit animation + routing ─────────────────────────────────────────────────
func _animate_out_then_route() -> void:
	_stop_sway()

	var bgm_fade := create_tween()
	bgm_fade.tween_property($BGMPlayer, "volume_db", -40.0, 1.0)
	bgm_fade.tween_callback($BGMPlayer.stop)

	for i in range(LETTERS.size()):
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(_letters[i], "position",
			_letter_final_pos(i) + FLY_OUT[i], 0.60) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		t.tween_property(_letters[i], "modulate:a", 0.0, 0.45)
		await get_tree().create_timer(0.55).timeout

	var slide_x : Array[float] = [-280.0, get_viewport_rect().size.x + 300.0]
	for i in range(WORD_TEXTS.size()):
		var t := create_tween()
		t.tween_property(_words[i], "position:x", slide_x[i], 0.55) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		await get_tree().create_timer(0.65).timeout

	# PlayButton hand-wave before scene change
	var base_x : float = $PlayButton.position.x
	var bt := create_tween().set_parallel(false)
	bt.tween_property($PlayButton, "position:x", base_x + 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x - 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x + 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x - 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x + 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x - 15.0, 0.22) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bt.tween_property($PlayButton, "position:x", base_x,        0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await bt.finished
	await get_tree().create_timer(1.0).timeout

	if SaveManager.is_level2_completed():
		pass  # TODO: route to next level when built
	elif SaveManager.is_level15_completed():
		Level2Progress.current_index  = SaveManager.get_level2_set_index()
		get_tree().change_scene_to_file("res://game2.tscn")
	elif SaveManager.is_level1_completed():
		Level15Progress.current_index = SaveManager.get_level15_set_index()
		get_tree().change_scene_to_file("res://game15.tscn")
	elif SaveManager.is_prep_completed():
		LevelProgress.current_index   = SaveManager.get_level1_set_index()
		get_tree().change_scene_to_file("res://game.tscn")
	elif SaveManager.get_level1_set_index() > 0:
		# Mid-progress in Level 1 (past set 1) — clearly on Level 1 path
		LevelProgress.current_index   = SaveManager.get_level1_set_index()
		get_tree().change_scene_to_file("res://game.tscn")
	elif SaveManager.get_prep_set_index() > 0:
		# Mid-progress in Prep — on Prep path (direct or redirected)
		PrepLevelProgress.load_from_save()
		get_tree().change_scene_to_file("res://prep_game.tscn")
	elif SaveManager.is_chose_level1_path():
		# Both indices 0 — a legacy save from before the title-screen choice
		# buttons were removed; a returning player who chose Level 1 back
		# then but hasn't finished set 1 yet
		LevelProgress.current_index = 0
		get_tree().change_scene_to_file("res://game.tscn")
	elif SaveManager.is_path_chosen():
		# Already been shown the Prep intro before (see the branch below) —
		# skip straight back in, same as any other return-to-title press.
		PrepLevelProgress.load_from_save()
		get_tree().change_scene_to_file("res://prep_game.tscn")
	else:
		# Genuinely first-ever Play press on this device — same intro copy
		# screen the old "Prep Level" choice button used to route through,
		# shown exactly once.
		SaveManager.set_path_chosen()
		LevelIntroState.level_id = "prep"
		get_tree().change_scene_to_file("res://level_intro.tscn")
