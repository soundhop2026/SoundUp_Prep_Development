extends Node2D

# ─── Prep Transition ──────────────────────────────────────────────────────────
# 4 discrete bounces (ascending pitch) → 2s silent bob → route
# ─────────────────────────────────────────────────────────────────────────────

# ─── Cube board — same constants as transition.gd (Level 1's set cube board) ───
const CUBE_FILLED : Color = Color(0.15, 0.35, 0.90, 1.0)   # deep blue
const CUBE_EMPTY  : Color = Color(1.00, 1.00, 1.00, 0.28)  # faint white outline
const CUBE_SIZE   : float = 40.0
const CUBE_STEP   : float = 48.0   # 40px + 8px gap
const CUBE_ROW1_Y : float = 625.0
const CUBE_ROW2_Y : float = 670.0

# ─── Play Button constants ─────────────────────────────────────────────────────
const BASE_SCALE  : float = 0.80
const SQUASH_X    : float = 0.88
const SQUASH_Y    : float = 0.72
const LAND_X      : float = 0.72
const LAND_Y      : float = 0.88

# ─── Audio ────────────────────────────────────────────────────────────────────
const PITCH_STEPS : Array[float] = [1.0, 1.08, 1.16, 1.24, 1.32, 1.40]

var _cubes       : Array[Sprite2D] = []
var _cube_scale  : float           = 1.0
var _info_label  : Label           = null
var _info_label2 : Label           = null

# ─── Info labels ──────────────────────────────────────────────────────────────

func _create_info_labels() -> void:
	_info_label                      = Label.new()
	_info_label.text                 = "Prep Level"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.position             = Vector2(0, 68)
	_info_label.size                 = Vector2(1280, 50)
	_info_label.z_index              = 1
	_info_label.modulate.a           = 0.0
	_info_label.add_theme_font_size_override("font_size", 24)
	_info_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.90))
	add_child(_info_label)

	_info_label2                      = Label.new()
	_info_label2.text                 = "Set " + PrepLevelProgress.current_set_label()
	_info_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label2.position             = Vector2(0, 102)
	_info_label2.size                 = Vector2(1280, 40)
	_info_label2.z_index              = 1
	_info_label2.modulate.a           = 0.0
	_info_label2.add_theme_font_size_override("font_size", 18)
	_info_label2.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.90))
	add_child(_info_label2)

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	SceneBackground.set_color(Color("#A8E063"))
	$background.color           = Color("#A8E063")
	$background.size            = get_viewport_rect().size
	$background.position        = Vector2(0, 0)
	$background.mouse_filter    = Control.MOUSE_FILTER_IGNORE
	$PlayButtonImage.position   = Vector2(640, 290)
	$PlayButtonImage.scale      = Vector2(BASE_SCALE, BASE_SCALE)
	$PlayButtonImage.modulate   = Color(1.0, 1.0, 1.0, 1.0)
	_create_info_labels()
	_create_cube_board()
	_play_transition()

# ─── Cube board ───────────────────────────────────────────────────────────────

func _create_cube_board() -> void:
	var cube_tex : Texture2D = load("res://UI_assets/preplevel_set_counting_cube_empty.png")
	var tex_px   : float     = min(cube_tex.get_size().x, cube_tex.get_size().y)
	_cube_scale              = CUBE_SIZE / tex_px
	var total    : int       = PrepLevelProgress.sets.size()
	var row1     : int       = (total + 1) / 2   # ceiling half: 26→13
	var row2     : int       = total - row1
	for i in range(total):
		var sp := Sprite2D.new()
		sp.texture  = cube_tex
		sp.scale    = Vector2(_cube_scale, _cube_scale)
		sp.modulate = CUBE_EMPTY
		sp.visible  = false
		if i < row1:
			var start_x : float = 640.0 - ((row1 - 1) * CUBE_STEP) / 2.0
			sp.position = Vector2(start_x + i * CUBE_STEP, CUBE_ROW1_Y)
		else:
			var j       : int   = i - row1
			var start_x : float = 640.0 - ((row2 - 1) * CUBE_STEP) / 2.0
			sp.position = Vector2(start_x + j * CUBE_STEP, CUBE_ROW2_Y)
		add_child(sp)
		_cubes.append(sp)

# Reveals the whole board at once: filled cubes solid, rest faint outline
func _show_cubes(earned: int) -> void:
	for i in range(_cubes.size()):
		_cubes[i].visible  = true
		_cubes[i].modulate = CUBE_FILLED if i < earned else CUBE_EMPTY

# Each earned cube bounces independently — runs until scene changes
func _dance_cube(idx: int) -> void:
	var base_pos := _cubes[idx].position
	while true:
		var rot := randf_range(-5.0,   5.0)
		var dx  := randf_range(-4.0,   4.0)
		var dy  := randf_range(-8.0,   8.0)
		var sc  := randf_range(0.92,  1.10) * _cube_scale
		var dur := randf_range(0.12,  0.20) + idx * 0.01
		var t   := create_tween()
		t.set_parallel(true)
		t.tween_property(_cubes[idx], "rotation_degrees", rot,                         dur)
		t.tween_property(_cubes[idx], "position",         base_pos + Vector2(dx, dy), dur)
		t.tween_property(_cubes[idx], "scale",            Vector2(sc, sc),             dur)
		await t.finished

# ─── Main sequence ────────────────────────────────────────────────────────────

func _play_transition() -> void:
	await get_tree().create_timer(0.3).timeout

	var passed : bool  = PrepLevelProgress.last_score_pct >= 85.0
	var base_y : float = 290.0

	# ── 4 bounces with ascending pitch ────────────────────────────────────────
	var snd := AudioStreamPlayer.new()
	snd.stream = load("res://BGM&effect/SoundUp_set_transition_sfx.wav")
	add_child(snd)

	for i in range(6):
		snd.pitch_scale = PITCH_STEPS[i]
		snd.play()

		var ts := create_tween()
		ts.tween_property($PlayButtonImage, "scale", Vector2(SQUASH_X, SQUASH_Y), 0.06)
		await ts.finished

		var tr := create_tween()
		tr.set_parallel(true)
		tr.tween_property($PlayButtonImage, "position:y", base_y - 20.0, 0.12).set_ease(Tween.EASE_OUT)
		tr.tween_property($PlayButtonImage, "scale", Vector2(BASE_SCALE, BASE_SCALE), 0.12)
		await tr.finished

		var tl := create_tween()
		tl.set_parallel(true)
		tl.tween_property($PlayButtonImage, "position:y", base_y, 0.12).set_ease(Tween.EASE_IN)
		tl.tween_property($PlayButtonImage, "scale", Vector2(LAND_X, LAND_Y), 0.12)
		await tl.finished

		var tse := create_tween()
		tse.tween_property($PlayButtonImage, "scale", Vector2(BASE_SCALE, BASE_SCALE), 0.06)
		await tse.finished

	# Fade in labels during the bob
	if _info_label != null:
		var lf := create_tween()
		lf.set_parallel(true)
		lf.tween_property(_info_label,  "modulate:a", 1.0, 0.5)
		lf.tween_property(_info_label2, "modulate:a", 1.0, 0.5)

	# ── 2.0s gentle bob (silence) — 4 cycles × 0.5s ──────────────────────────
	for _b in range(4):
		var tb1 := create_tween()
		tb1.tween_property($PlayButtonImage, "position:y", base_y - 6.0, 0.25).set_ease(Tween.EASE_IN_OUT)
		await tb1.finished
		var tb2 := create_tween()
		tb2.tween_property($PlayButtonImage, "position:y", base_y, 0.25).set_ease(Tween.EASE_IN_OUT)
		await tb2.finished

	$PlayButtonImage.position.y = base_y

	if not passed:
		PrepLevelProgress.is_retry = true
		await _exit_play_button()
		get_tree().change_scene_to_file("res://prep_game.tscn")
		return

	# ── Passed (≥ 85%) — one cube per set, same reveal as Level 1 ────────────
	PrepLevelProgress.is_retry = false

	var earned : int = PrepLevelProgress.current_index + 1
	_show_cubes(earned)
	_dance_cube(earned - 1)
	await get_tree().create_timer(2.0).timeout

	await _exit_play_button()

	# ── Free → premium boundary: never auto-continues past here ──────────────
	# Everything above this point (bounce, cubes, exit fade) is identical for
	# every set, free or not. Only right here — after the transition has
	# fully finished — do we ever stop and wait for an explicit choice.
	if PrepLevelProgress.crosses_into_premium():
		_await_keep_hopping_then_continue()
		return

	_continue_to_next_set()


func _continue_to_next_set() -> void:
	if PrepLevelProgress.has_next():
		PrepLevelProgress.advance()
		get_tree().change_scene_to_file("res://prep_game.tscn")
	else:
		SaveManager.set_prep_completed()
		PrepLevelProgress.reset()
		LevelTransition.next_level_id = "level1"
		LevelTransition.level_name    = "Level 1"
		get_tree().change_scene_to_file("res://level_transition.tscn")


# ─── "Keep Hopping!" — the one explicit choice before premium content ───────
func _await_keep_hopping_then_continue() -> void:
	var btn := Button.new()
	btn.text         = "Keep Hopping!"
	btn.size         = Vector2(340, 84)
	btn.position     = Vector2(640.0 - 170.0, 290.0 - 42.0)
	btn.pivot_offset = btn.size / 2.0
	var font_path : String = "res://UI_assets/210 연필스케치R.ttf"
	if ResourceLoader.exists(font_path):
		btn.add_theme_font_override("font", load(font_path))
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color",         Color.WHITE)
	btn.add_theme_color_override("font_hover_color",   Color("#FFB703"))
	btn.add_theme_color_override("font_pressed_color", Color("#FFB703"))
	btn.add_theme_color_override("font_focus_color",   Color.WHITE)
	var sty := StyleBoxFlat.new()
	sty.bg_color                   = Color("#4B0082")
	sty.corner_radius_top_left     = 20
	sty.corner_radius_top_right    = 20
	sty.corner_radius_bottom_left  = 20
	sty.corner_radius_bottom_right = 20
	sty.shadow_color               = Color(0.0, 0.0, 0.0, 0.30)
	sty.shadow_size                = 14
	sty.shadow_offset              = Vector2(0, 6)
	btn.add_theme_stylebox_override("normal",  sty)
	btn.add_theme_stylebox_override("hover",   sty)
	btn.add_theme_stylebox_override("pressed", sty)
	btn.add_theme_stylebox_override("focus",   sty)
	btn.modulate.a = 0.0
	add_child(btn)

	var fade := create_tween()
	fade.tween_property(btn, "modulate:a", 1.0, 0.4)

	btn.pressed.connect(func():
		PremiumIntroState.context_id = "prep"
		get_tree().change_scene_to_file("res://premium_intro.tscn")
	)

# ─── PlayButton exit (shrink + fade) ─────────────────────────────────────────

func _exit_play_button() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property($PlayButtonImage, "scale",      Vector2(0.0, 0.0), 0.30).set_ease(Tween.EASE_IN)
	t.tween_property($PlayButtonImage, "modulate:a", 0.0,               0.30)
	await t.finished
