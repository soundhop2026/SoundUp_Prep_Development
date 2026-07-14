extends Node2D

# Star positions for the lottery / dance phase (3 fixed slots)
const STAR_POSITIONS : Array[Vector2] = [
	Vector2(440, 490),
	Vector2(640, 490),
	Vector2(840, 490),
]

# Slot machine bitmasks (bit 0 = left, bit 1 = centre, bit 2 = right)
# 7=★★★  6=○★★  4=○○★  3=★★○  1=★○○  5=★○★  2=○★○
const LOTTERY_STATES : Array[int] = [
	7, 6, 4, 7, 3, 1, 7, 5, 2, 7,
	7, 6, 4, 7, 3, 1, 7, 5, 2, 7,
	7, 6, 4, 7, 3, 1, 7, 5, 2, 7,
]
const LOTTERY_TIMES : Array[float] = [
	0.15, 0.13, 0.11,
	0.09, 0.08, 0.07,
	0.06, 0.05, 0.05,
	0.05, 0.05, 0.05,
	0.05, 0.05, 0.05,
	0.05, 0.05, 0.05,
	0.05, 0.05, 0.05,
	0.05, 0.05, 0.05,
	0.05, 0.05, 0.05,
	0.05, 0.05, 0.05,
]

const COLOR_FILLED : Color = Color(1.0,  0.85, 0.1,  1.0)
const COLOR_EMPTY  : Color = Color(0.55, 0.55, 0.55, 0.55)

# ─── Cube board constants ──────────────────────────────────────────────────────
# Uses preplevel_set_counting_cube_empty.png (white fill) modulated deep blue
const CUBE_FILLED : Color = Color(0.15, 0.35, 0.90, 1.0)   # deep blue
const CUBE_EMPTY  : Color = Color(1.00, 1.00, 1.00, 0.28)  # faint white outline
const CUBE_SIZE   : float = 40.0
const CUBE_STEP   : float = 48.0   # 40px + 8px gap
const CUBE_ROW1_Y : float = 625.0  # 9 cubes (sets 1–9)
const CUBE_ROW2_Y : float = 670.0  # 8 cubes (sets 10–17)

const BASE_SCALE  : float = 0.80
const PULSE_SCALE : float = 1.76   # BASE × 2.2
const SQUASH_X    : float = 0.88   # BASE × 1.10
const SQUASH_Y    : float = 0.72   # BASE × 0.90
const LAND_X      : float = 0.72   # BASE × 0.90
const LAND_Y      : float = 0.88   # BASE × 1.10
const BOUNCE_UP    : float = -180.0
const BOUNCE_LAND  : float =  25.0
const SHAKE_MARGIN : float =  32.0   # background extends ±32 px on all sides to cover max shake of 16 px

var _stars        : Array[Sprite2D] = []
var _star_scale   : float = 1.0
var _star_dancing : bool  = false   # flag that keeps each star's dance loop alive
var _music_player : AudioStreamPlayer = null

var _cubes        : Array[Sprite2D] = []
var _cube_scale   : float = 1.0
var _info_label   : Label = null   # "Level 1"
var _info_label2  : Label = null   # "Set 1A" — smaller

# Set once in _ready() from Level15Progress.active / Level2Progress.active.
var _for_l15 : bool = false
var _for_l2  : bool = false

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_for_l15                    = Level15Progress.active
	_for_l2                     = Level2Progress.active
	var _vp := get_viewport_rect().size
	$background.size            = _vp + Vector2(SHAKE_MARGIN * 2.0, SHAKE_MARGIN * 2.0)
	$background.position        = Vector2(-SHAKE_MARGIN, -SHAKE_MARGIN)
	$background.mouse_filter    = Control.MOUSE_FILTER_IGNORE
	if _for_l2:
		$background.color = Color(0.478, 0.549, 0.180, 1.0)   # #7A8C2E — Level 2
	elif _for_l15:
		$background.color = Color(0.659, 0.227, 0.133, 1.0)   # #A83A22 — Level 1.5
	else:
		$background.color = Color(0.431, 0.710, 1.0, 1.0)     # sky blue — Level 1
	SceneBackground.set_color($background.color)
	$PlayButtonImage.position   = Vector2(640, 290)
	$PlayButtonImage.scale      = Vector2(BASE_SCALE, BASE_SCALE)
	$PlayButtonImage.modulate   = Color(1.0, 1.0, 1.0, 1.0)
	_create_info_label()
	_create_stars()
	_create_cubes()
	_start_music()
	_play_transition()

func _create_info_label() -> void:
	var level_text : String
	var set_text   : String
	if _for_l2:
		level_text = "Level 2"
		set_text   = "Set " + Level2Progress.current_set_label()
	elif _for_l15:
		level_text = "Level 1.5"
		set_text   = "Set " + Level15Progress.current_set_label()
	else:
		level_text = "Level 1"
		set_text   = "Set " + LevelProgress.current_set_label()

	_info_label                      = Label.new()
	_info_label.text                 = level_text
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.position             = Vector2(0, 68)
	_info_label.size                 = Vector2(1280, 50)
	_info_label.z_index              = 1
	_info_label.modulate.a           = 0.0
	_info_label.add_theme_font_size_override("font_size", 24)
	_info_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.90))
	add_child(_info_label)

	_info_label2                      = Label.new()
	_info_label2.text                 = set_text
	_info_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label2.position             = Vector2(0, 102)
	_info_label2.size                 = Vector2(1280, 40)
	_info_label2.z_index              = 1
	_info_label2.modulate.a           = 0.0
	_info_label2.add_theme_font_size_override("font_size", 18)
	_info_label2.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.90))
	add_child(_info_label2)

func _create_stars() -> void:
	var star_tex : Texture2D = load("res://UI_assets/star.png")
	var star_px  : float     = min(star_tex.get_size().x, star_tex.get_size().y)
	_star_scale              = 220.0 / star_px
	for i in range(3):
		var sp := Sprite2D.new()
		sp.texture  = star_tex
		sp.position = STAR_POSITIONS[i]
		sp.scale    = Vector2(_star_scale, _star_scale)
		sp.modulate = COLOR_EMPTY
		add_child(sp)
		_stars.append(sp)

func _create_cubes() -> void:
	var cube_tex : Texture2D = load("res://UI_assets/preplevel_set_counting_cube_empty.png")
	var tex_px   : float     = min(cube_tex.get_size().x, cube_tex.get_size().y)
	_cube_scale              = CUBE_SIZE / tex_px
	var total    : int       = Level2Progress.sets.size() if _for_l2 else (Level15Progress.sets.size() if _for_l15 else LevelProgress.sets.size())
	var row1     : int       = (total + 1) / 2   # ceiling half: 17→9, 13→7
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

func _start_music() -> void:
	_music_player           = AudioStreamPlayer.new()
	_music_player.stream    = load("res://BGM&effect/transition_fanfare.wav")
	_music_player.volume_db = 0.0
	add_child(_music_player)
	# As soon as track 1 ends, roll track 2 immediately — no gap
	_music_player.finished.connect(_play_track_2)
	_music_player.play()

func _play_track_2() -> void:
	var player2 := AudioStreamPlayer.new()
	player2.stream    = load("res://BGM&effect/transition_fanfare_2.wav")
	player2.volume_db = 0.0
	add_child(player2)
	player2.play()
	_music_player = player2   # routing code now awaits track 2

# ─── Impact helpers (fire-and-forget) ─────────────────────────────────────────

func _flash(alpha: float = 0.45, duration: float = 0.12) -> void:
	var rect := ColorRect.new()
	rect.color        = Color(1.0, 1.0, 1.0, alpha)
	rect.size         = get_viewport_rect().size
	rect.z_index      = 20
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var t := create_tween()
	t.tween_property(rect, "color:a", 0.0, duration)
	t.tween_callback(rect.queue_free)

func _shake(amount: float = 10.0) -> void:
	var orig := position
	var t := create_tween()
	t.tween_property(self, "position", orig + Vector2( amount, -amount * 0.5), 0.025)
	t.tween_property(self, "position", orig + Vector2(-amount,  amount * 0.5), 0.025)
	t.tween_property(self, "position", orig + Vector2( amount * 0.5,  amount), 0.025)
	t.tween_property(self, "position", orig + Vector2(-amount * 0.5, -amount * 0.5), 0.025)
	t.tween_property(self, "position", orig, 0.025)

# ─── Star pre-lottery dance ────────────────────────────────────────────────────

# Launches one independent dance coroutine per star — all three run in parallel.
func _start_star_dance() -> void:
	_star_dancing = true
	for i in range(3):
		_stars[i].visible  = true
		_stars[i].modulate = COLOR_FILLED   # gold — exciting, not a score yet
		_dance_star(i)                       # start coroutine without awaiting

func _stop_star_dance() -> void:
	_star_dancing = false
	# Each coroutine will finish its current tween then reset itself (0.15 s).
	# Caller must wait ~0.40 s before using the stars again.

# Each star loops: random rotation + bounce + scale + wiggle until flag clears.
func _dance_star(idx: int) -> void:
	var base_pos := STAR_POSITIONS[idx]
	while _star_dancing:
		var rot := randf_range(-8.0,   8.0)
		var dx  := randf_range(-10.0, 10.0)
		var dy  := randf_range(-20.0, 20.0)
		var sc  := randf_range(0.90,  1.20) * _star_scale
		var dur := randf_range(0.10,  0.16) + idx * 0.03   # slightly different per star
		var t   := create_tween()
		t.set_parallel(true)
		t.tween_property(_stars[idx], "rotation_degrees", rot,                          dur)
		t.tween_property(_stars[idx], "position",         base_pos + Vector2(dx, dy),  dur)
		t.tween_property(_stars[idx], "scale",            Vector2(sc, sc),              dur)
		await t.finished
	# Dance ended — snap back to neutral so slot machine takes over cleanly
	var reset := create_tween()
	reset.set_parallel(true)
	reset.tween_property(_stars[idx], "rotation_degrees", 0.0,                           0.15)
	reset.tween_property(_stars[idx], "position",         base_pos,                      0.15)
	reset.tween_property(_stars[idx], "scale",            Vector2(_star_scale, _star_scale), 0.15)

# ─── Main animation sequence ──────────────────────────────────────────────────

func _play_transition() -> void:
	await get_tree().create_timer(0.4).timeout

	var base_y : float = 290.0

	# Stars begin dancing immediately — runs concurrently with pulse + bounce
	_start_star_dance()

	# --- Heartbeat pulse ×10: BASE → PEAK → BASE ---
	for _i in range(10):
		var t1 := create_tween()
		t1.tween_property($PlayButtonImage, "scale",
				Vector2(PULSE_SCALE, PULSE_SCALE), 0.10).set_ease(Tween.EASE_OUT)
		await t1.finished
		var t2 := create_tween()
		t2.tween_property($PlayButtonImage, "scale",
				Vector2(BASE_SCALE, BASE_SCALE), 0.08).set_ease(Tween.EASE_IN)
		await t2.finished
		await get_tree().create_timer(0.06).timeout

	# --- Rubber-ball bounce ×10, 180 px, flash + shake on every landing ---
	for _i in range(10):
		var ts := create_tween()
		ts.tween_property($PlayButtonImage, "scale", Vector2(SQUASH_X, SQUASH_Y), 0.08)
		await ts.finished

		var tr := create_tween()
		tr.set_parallel(true)
		tr.tween_property($PlayButtonImage, "position:y",
				base_y + BOUNCE_UP, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tr.tween_property($PlayButtonImage, "scale", Vector2(BASE_SCALE, BASE_SCALE), 0.22)
		await tr.finished

		var tl := create_tween()
		tl.set_parallel(true)
		tl.tween_property($PlayButtonImage, "position:y",
				base_y + BOUNCE_LAND, 0.14).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tl.tween_property($PlayButtonImage, "scale", Vector2(LAND_X, LAND_Y), 0.14)
		await tl.finished

		_flash(0.35, 0.12)
		_shake(10.0)

		var tse := create_tween()
		tse.set_parallel(true)
		tse.tween_property($PlayButtonImage, "position:y", base_y, 0.08)
		tse.tween_property($PlayButtonImage, "scale", Vector2(BASE_SCALE, BASE_SCALE), 0.08)
		await tse.finished

	# Stop dance — wait 0.40 s so each star's reset tween (0.15 s) fully completes
	_stop_star_dance()
	# Fade in Level/Set labels now that Play Button has finished moving
	if _info_label != null:
		var lf := create_tween()
		lf.set_parallel(true)
		lf.tween_property(_info_label,  "modulate:a", 1.0, 0.5)
		lf.tween_property(_info_label2, "modulate:a", 1.0, 0.5)
	await get_tree().create_timer(0.40).timeout

	# PlayButtonImage is now still — does NOT move for the rest of the scene

	# --- Slot machine: all three star positions blink ---
	for idx in range(LOTTERY_STATES.size()):
		_show_stars_mask(LOTTERY_STATES[idx])
		await get_tree().create_timer(LOTTERY_TIMES[idx]).timeout

	# Sudden stop — big flash, hide all stars
	_flash(0.60, 0.15)
	for i in range(3):
		_stars[i].visible = false
	await get_tree().create_timer(0.35).timeout

	# --- Final reveal: earned stars only, centred, drop in from above ---
	var pct   : float = Level2Progress.last_score_pct if _for_l2 else (Level15Progress.last_score_pct if _for_l15 else LevelProgress.last_score_pct)
	var stars : int   = 1
	if pct >= 95.0:
		stars = 3
	elif pct >= 85.0:
		stars = 2

	var gap     : float = 200.0
	var start_x : float = 640.0 - (stars - 1) * gap / 2.0
	var final_y : float = 490.0

	for i in range(stars):
		_stars[i].position         = Vector2(start_x + i * gap, final_y - 100.0)
		_stars[i].rotation_degrees = 0.0
		_stars[i].modulate         = COLOR_FILLED
		_stars[i].scale            = Vector2(_star_scale * 0.4, _star_scale * 0.4)
		_stars[i].visible          = true

	# Drop fast with overshoot
	var td := create_tween()
	td.set_parallel(true)
	for i in range(stars):
		td.tween_property(_stars[i], "position:y",
				final_y + 20.0, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		td.tween_property(_stars[i], "scale",
				Vector2(_star_scale * 1.3, _star_scale * 1.3), 0.16)
	await td.finished

	_flash(0.65, 0.16)
	_shake(16.0)

	# Settle to final position
	var tr2 := create_tween()
	tr2.set_parallel(true)
	for i in range(stars):
		tr2.tween_property(_stars[i], "position:y", final_y, 0.14).set_ease(Tween.EASE_OUT)
		tr2.tween_property(_stars[i], "scale", Vector2(_star_scale, _star_scale), 0.14)
	await tr2.finished

	await get_tree().create_timer(0.10).timeout

	# --- POP ×10: 1.0 → 1.8 → 1.0 ---
	# First 5: fast (0.10 s) — POP POP POP POP POP
	# Last 5:  slow (0.14 s) — POP.... POP.... POP.... POP.... POP....
	var pop_big : float = _star_scale * 1.8
	for pop_i in range(10):
		var grow_t   : float = 0.10 if pop_i < 5 else 0.14
		var shrink_t : float = grow_t

		var tp1 := create_tween()
		tp1.set_parallel(true)
		for i in range(stars):
			tp1.tween_property(_stars[i], "scale", Vector2(pop_big, pop_big), grow_t)
		await tp1.finished

		var tp2 := create_tween()
		tp2.set_parallel(true)
		for i in range(stars):
			tp2.tween_property(_stars[i], "scale", Vector2(_star_scale, _star_scale), shrink_t)
		await tp2.finished

		await get_tree().create_timer(0.04).timeout

	# --- Cube board: one cube per set, index is the truth ---
	# Level 1: 3★ only (≥95%). Level 1.5 and Level 2: ≥2★ (Gain and Move).
	var show_cubes : bool = (stars == 3) if not (_for_l2 or _for_l15) else (stars >= 2)
	if show_cubes:
		if _for_l2:
			var earned : int = Level2Progress.current_index + 1
			_show_cubes(earned)
			_dance_cube(earned - 1)
		elif _for_l15:
			var earned : int = Level15Progress.current_index + 1
			_show_cubes(earned)
			_dance_cube(earned - 1)
		else:
			var earned : int = LevelProgress.current_index + 1
			_show_cubes(earned)
			_dance_cube(earned - 1)

	# 2.0s to see the stars (+ cubes dancing), then fade music and route
	await get_tree().create_timer(2.0).timeout

	if _music_player != null and _music_player.playing:
		var fade := create_tween()
		fade.tween_property(_music_player, "volume_db", -80.0, 5.0)

	await get_tree().create_timer(2.0).timeout

	# --- Progression routing ---
	if _for_l2:
		Level2Progress.active = false
		var next_scene : String = "res://game25.tscn" if Level2Progress.is_option1() else "res://game2.tscn"
		if stars >= 2:
			if Level2Progress.has_next():
				Level2Progress.advance()
				SaveManager.set_level2_set_index(Level2Progress.current_index)
				var after_scene : String = "res://game25.tscn" if Level2Progress.is_option1() else "res://game2.tscn"
				get_tree().change_scene_to_file(after_scene)
			else:
				SaveManager.set_level2_completed()
				Level2Progress.reset()
				LevelTransition.next_level_id = "level25"
				LevelTransition.level_name    = "Level 2.5"
				get_tree().change_scene_to_file("res://level_transition.tscn")
		else:
			Level2Progress.is_retry = true
			get_tree().change_scene_to_file(next_scene)
	elif _for_l15:
		Level15Progress.active = false
		if stars >= 2:
			if Level15Progress.has_next():
				Level15Progress.advance()
				get_tree().change_scene_to_file("res://game15.tscn")
			else:
				SaveManager.set_level15_completed()
				Level15Progress.reset()
				LevelTransition.next_level_id = "level2"
				LevelTransition.level_name    = "Level 2"
				get_tree().change_scene_to_file("res://level_transition.tscn")
		else:
			Level15Progress.is_retry = true
			get_tree().change_scene_to_file("res://game15.tscn")
	else:
		if stars == 3:
			if LevelProgress.has_next():
				LevelProgress.advance()
				SaveManager.set_level1_set_index(LevelProgress.current_index)
				get_tree().change_scene_to_file("res://game.tscn")
			else:
				SaveManager.set_level1_completed()
				LevelProgress.reset()
				LevelTransition.next_level_id = "level15"
				LevelTransition.level_name    = "Level 1.5"
				get_tree().change_scene_to_file("res://level_transition.tscn")
		elif stars == 2:
			LevelProgress.is_retry = true
			get_tree().change_scene_to_file("res://game.tscn")
		else:
			# 1 star: below 65% on the very first set → redirect to Prep
			if LevelProgress.current_index == 0 \
					and not SaveManager.is_prep_completed() \
					and LevelProgress.last_score_pct < 65.0:
				LevelProgress.is_retry = false
				LevelProgress.retry_rounds.clear()
				PrepLevelProgress.load_from_save()
				get_tree().change_scene_to_file("res://prep_game.tscn")
			else:
				LevelProgress.is_retry = false
				LevelProgress.retry_rounds.clear()
				get_tree().change_scene_to_file("res://game.tscn")

# ─── Star display helpers ──────────────────────────────────────────────────────

func _show_stars(count: int) -> void:
	for i in range(3):
		_stars[i].modulate = COLOR_FILLED if i < count else COLOR_EMPTY

func _show_stars_mask(mask: int) -> void:
	for i in range(3):
		_stars[i].visible          = true
		_stars[i].rotation_degrees = 0.0   # clear any leftover dance rotation
		_stars[i].modulate         = COLOR_FILLED if (mask >> i) & 1 else COLOR_EMPTY
