extends Node2D

# ─── Prep Transition ──────────────────────────────────────────────────────────
# 4 discrete bounces (ascending pitch) → 2s silent bob → route
# ─────────────────────────────────────────────────────────────────────────────

# ─── Cube board ───────────────────────────────────────────────────────────────
const CUBE_SIZE   : int   = 50
const CUBE_GAP    : int   = 5
const CUBE_ROW1_Y : float = 559.0
const CUBE_ROW2_Y : float = 607.0

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
	$background.color           = Color("#A8E063")
	$background.size            = Vector2(1280, 720)
	$background.position        = Vector2(0, 0)
	$PlayButtonImage.position   = Vector2(640, 290)
	$PlayButtonImage.scale      = Vector2(BASE_SCALE, BASE_SCALE)
	$PlayButtonImage.modulate   = Color(1.0, 1.0, 1.0, 1.0)
	_create_info_labels()
	if PrepLevelProgress.is_main_set_boundary() and PrepLevelProgress.last_score_pct >= 85.0:
		_create_cube_board()
	_play_transition()

# ─── Cube board ───────────────────────────────────────────────────────────────

func _create_cube_board() -> void:
	var cube_tex : Texture2D = load("res://UI_assets/preplevel_set_counting_cube_empty.png")
	var tex_px   : float     = max(cube_tex.get_size().x, cube_tex.get_size().y)
	_cube_scale              = float(CUBE_SIZE) / tex_px

	const TOTAL  : int   = 6
	const STEP   : float = 80.0
	var width    : float = (TOTAL - 1) * STEP
	var x0       : float = 640.0 - width / 2.0

	for i in range(TOTAL):
		var sp := Sprite2D.new()
		sp.texture  = cube_tex
		sp.scale    = Vector2(_cube_scale, _cube_scale)
		sp.position = Vector2(x0 + i * STEP, CUBE_ROW1_Y)
		sp.z_index  = 5
		sp.modulate = Color(1.0, 1.0, 1.0, 0.25)
		sp.visible  = true
		add_child(sp)
		_cubes.append(sp)

	for i in range(PrepLevelProgress.main_set_number()):
		_cubes[i].modulate = Color(1.0, 1.0, 1.0, 1.0)

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

	# ── Fade to green before routing ──────────────────────────────────────────
	var overlay := ColorRect.new()
	overlay.color        = Color("#A8E063")
	overlay.size         = Vector2(1280, 720)
	overlay.z_index      = 30
	overlay.modulate.a   = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var fade := create_tween()
	fade.tween_property(overlay, "modulate:a", 1.0, 0.5)
	await fade.finished

	if not passed:
		PrepLevelProgress.is_retry = true
		get_tree().change_scene_to_file("res://prep_game.tscn")
		return

	# ── Passed (≥ 85%) ────────────────────────────────────────────────────────
	PrepLevelProgress.is_retry = false

	if PrepLevelProgress.is_main_set_boundary():
		var earned : int = PrepLevelProgress.main_set_number() + 1
		_cubes[earned - 1].modulate = Color(1.0, 1.0, 1.0, 1.0)
		await _dance_all_earned_cubes(earned)
		await get_tree().create_timer(0.3).timeout

	if PrepLevelProgress.has_next():
		PrepLevelProgress.advance()
		get_tree().change_scene_to_file("res://prep_game.tscn")
	else:
		await get_tree().create_timer(0.2).timeout
		SaveManager.set_prep_completed()
		PrepLevelProgress.reset()
		LevelTransition.next_level_id = "level1"
		LevelTransition.level_name    = "Level 1"
		get_tree().change_scene_to_file("res://level_transition.tscn")

# ─── All earned cubes dance together ─────────────────────────────────────────

func _dance_all_earned_cubes(done: int) -> void:
	var earned : Array[Sprite2D] = []
	for i in range(min(done, _cubes.size())):
		earned.append(_cubes[i])

	if earned.is_empty():
		return

	var base_positions : Array[Vector2] = []
	var base_scales    : Array[Vector2] = []
	for cube in earned:
		base_positions.append(cube.position)
		base_scales.append(cube.scale)

	for i in range(19):
		var rot : float = -12.0 if i % 2 == 0 else 12.0
		var sc  : float = _cube_scale * 1.35

		for j in range(earned.size()):
			var t1 := create_tween()
			t1.set_parallel(true)
			t1.tween_property(earned[j], "rotation_degrees", rot,                                    0.10)
			t1.tween_property(earned[j], "position",         base_positions[j] + Vector2(0, -18.0), 0.10)
			t1.tween_property(earned[j], "scale",            Vector2(sc, sc),                        0.10)
		await get_tree().create_timer(0.10).timeout

		for j in range(earned.size()):
			var t2 := create_tween()
			t2.set_parallel(true)
			t2.tween_property(earned[j], "rotation_degrees", 0.0,               0.10)
			t2.tween_property(earned[j], "position",         base_positions[j], 0.10)
			t2.tween_property(earned[j], "scale",            base_scales[j],    0.10)
		await get_tree().create_timer(0.10).timeout

	for j in range(earned.size()):
		var settle := create_tween()
		settle.set_parallel(true)
		settle.tween_property(earned[j], "rotation_degrees", 0.0,               0.12)
		settle.tween_property(earned[j], "position",         base_positions[j], 0.12)
		settle.tween_property(earned[j], "scale",            base_scales[j],    0.12)
