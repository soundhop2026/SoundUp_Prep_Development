extends Node2D

# ─── Prep Game ────────────────────────────────────────────────────────────────
# Prep Level game loop. Copied from game.gd and modified for ear-training mode.
#
# Key differences from game.gd:
#   • Phoneme auto-plays ×3 (child does not press Listen)
#   • Word sounds auto-play ×2 per image with image bounce animation
#   • Pointed hand guides attention throughout, disappears before choice
#   • Wrong answer → full loop replay (no separate try-again)
#   • No Play Button, no Eval system, no idle hint timer
#   • No back button
#   • Background: baby green (#A8E063)
#   • Always routes to prep_transition.tscn
# ─────────────────────────────────────────────────────────────────────────────

var rounds              : Array          = []
var round_index         : int            = 0
var result_locked       : bool           = false
var num_choices         : int            = 3
var _btn_centers        : Array[Vector2] = []
var _btn_base_pos       : Array[Vector2] = []   # original positions for animation reset
var _waiting_for_choice   : bool           = false  # true during the 3-second choice window
var _listen_bar_base_pos  : Vector2        = Vector2(100, 60)

# ─── Accuracy tracking (per set / per retry pass) ─────────────────────────────
var _round_had_error    : bool  = false   # true if child pressed wrong at least once this round
var _local_wrong_rounds : Array = []      # wrong round dicts collected this set
var _local_total        : int   = 0       # rounds completed this set
var _local_wrong        : int   = 0       # wrong rounds this set
var _round_cubes        : Array[ColorRect] = []
var _total_set_rounds   : int              = 0

func _ready() -> void:
	$background.color    = Color("#A8E063")
	$background.size         = get_viewport_rect().size
	$background.position     = Vector2(0, 0)
	$background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Hide eval play button — not used in Prep
	$EvalPlayButton.visible = false

	# Listen bar is visual only in Prep — child does not press it
	$ListenButton.position = Vector2(100, 60)
	$ListenButton.size     = Vector2(980, 80)
	$ListenButton.text     = "👂 LISTEN"
	$ListenButton.pressed.connect(_on_listen_ignored)

	$PointedHand.visible = false
	$PointedHand.scale   = Vector2(0.08, 0.08)
	$PointedHand.z_index = 5

	$ImageButton1.pressed.connect(_on_button_pressed.bind(1))
	$ImageButton2.pressed.connect(_on_button_pressed.bind(2))
	$ImageButton3.pressed.connect(_on_button_pressed.bind(3))
	$ImageButton4.pressed.connect(_on_button_pressed.bind(4))
	$ImageButton5.pressed.connect(_on_button_pressed.bind(5))

	_load_rounds()
	_create_round_cubes()
	_start_round()

# ─── Listen button ignored in Prep ───────────────────────────────────────────

func _on_listen_ignored() -> void:
	pass   # visual only

# ─── Round loading ────────────────────────────────────────────────────────────

func _load_rounds() -> void:
	# Reset per-set tracking
	_local_wrong_rounds = []
	_local_total        = 0
	_local_wrong        = 0

	var file := FileAccess.open(PrepLevelProgress.current_set(), FileAccess.READ)
	var data : Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	_total_set_rounds = data["rounds"].size()

	if PrepLevelProgress.is_retry:
		# Retry mode: load the wrong rounds snapshot, shuffle for variety
		rounds = PrepLevelProgress.retry_rounds.duplicate()
		rounds.shuffle()
	else:
		rounds = data["rounds"].duplicate()
		_shuffle_no_consecutive()

func _shuffle_no_consecutive() -> void:
	rounds.shuffle()
	for i in range(1, rounds.size()):
		if rounds[i]["phoneme_audio"] != rounds[i - 1]["phoneme_audio"]:
			continue
		var prev_ph : String = rounds[i - 1]["phoneme_audio"]
		var next_ph : String = "" if i + 1 >= rounds.size() else rounds[i + 1]["phoneme_audio"]
		for j in range(i + 1, rounds.size()):
			if rounds[j]["phoneme_audio"] != prev_ph and rounds[j]["phoneme_audio"] != next_ph:
				var tmp   = rounds[i]
				rounds[i] = rounds[j]
				rounds[j] = tmp
				break

# ─── Layout ───────────────────────────────────────────────────────────────────

func _update_layout(n: int) -> void:
	num_choices = n
	for i in range(1, 6):
		get_node("ImageButton%d" % i).visible = (i <= n)
	match n:
		3:
			_btn_centers = [
				Vector2(220, 290),
				Vector2(540, 290),
				Vector2(860, 290),
			]
		4:
			_btn_centers = [
				Vector2(370, 270),
				Vector2(810, 270),
				Vector2(370, 490),
				Vector2(810, 490),
			]
		5:
			_btn_centers = [
				Vector2(220, 320),
				Vector2(540, 320),
				Vector2(860, 320),
				Vector2(380, 510),
				Vector2(700, 510),
			]

func _place_button(btn: TextureButton, center: Vector2) -> void:
	var tex_size : Vector2 = btn.texture_normal.get_size()
	var s        : float   = min(220.0 / tex_size.x, 220.0 / tex_size.y)
	btn.pivot_offset = tex_size / 2.0
	btn.position     = center - tex_size / 2.0
	btn.scale        = Vector2(s, s)

# ─── Round start ──────────────────────────────────────────────────────────────

func _start_round() -> void:
	if round_index >= rounds.size():
		_do_level_complete()
		return

	_round_had_error = false   # reset for each new round
	var rd : Dictionary = rounds[round_index]
	result_locked = true

	$ListenSound.stop()
	$PointedHand.visible    = false
	$EvalPlayButton.visible = false

	$ListenSound.stream = load(rd["phoneme_audio"])

	var n : int = rd["choices"].size()
	_update_layout(n)
	_btn_base_pos.clear()

	for i in range(n):
		var choice : Dictionary = rd["choices"][i]
		var btn    : TextureButton = get_node("ImageButton%d" % (i + 1))
		btn.texture_normal = load(choice["image"]) as Texture2D
		_place_button(btn, _btn_centers[i])
		_btn_base_pos.append(btn.position)   # store base position after placement
		var wa : String = choice.get("word_audio", "")
		get_node("WordSound%d" % (i + 1)).stream = load(wa) if wa != "" else null

	_run_prep_sequence.call_deferred()

# ─── Prep auto-play sequence ──────────────────────────────────────────────────

func _run_prep_sequence() -> void:
	result_locked = true
	var rd : Dictionary = rounds[round_index]
	var n  : int        = rd["choices"].size()

	# ── Step 1: Phoneme plays ×2, Listen bar bounces each play ──────────────
	$PointedHand.position         = Vector2(1050, 280)
	$PointedHand.rotation_degrees = -30.0
	$PointedHand.visible          = true
	for i in range(2):
		$ListenSound.play()
		_bounce_listen_bar()
		await $ListenSound.finished
		if i < 1:
			await get_tree().create_timer(0.3).timeout

	await get_tree().create_timer(0.5).timeout

	# ── Step 2: Word sound ×1 per image — EvalPlayButton shown ──────────────
	$PointedHand.visible    = false
	$EvalPlayButton.visible = true

	for i in range(n):
		var btn : TextureButton      = get_node("ImageButton%d" % (i + 1))
		var snd : AudioStreamPlayer  = get_node("WordSound%d" % (i + 1))
		if snd.stream == null:
			continue

		_bounce_image(btn, i)
		snd.play()
		await snd.finished
		await get_tree().create_timer(0.6).timeout

	# ── Step 3: Hide EvalPlayButton, unlock for child's choice ───────────────
	$EvalPlayButton.visible = false
	result_locked           = false
	_waiting_for_choice     = true

	# 3-second choice window — if no answer, replay the full loop
	await get_tree().create_timer(5.0).timeout
	if _waiting_for_choice:
		_waiting_for_choice = false
		result_locked       = true
		_restore_button_positions()
		_run_prep_sequence()

# ─── Image bounce animation ───────────────────────────────────────────────────
# Called fire-and-forget — runs in parallel with audio.

func _bounce_image(btn: TextureButton, index: int) -> void:
	var base := _btn_base_pos[index]
	var t    := create_tween()
	t.tween_property(btn, "position", base + Vector2(0, -18), 0.10).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "position", base,                   0.10).set_ease(Tween.EASE_IN)
	t.tween_property(btn, "position", base + Vector2(0, -9),  0.07).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "position", base,                   0.07).set_ease(Tween.EASE_IN)

func _bounce_listen_bar() -> void:
	var base : Vector2 = _listen_bar_base_pos
	await get_tree().create_timer(0.05).timeout   # let .playing become true
	while $ListenSound.playing:
		var t := create_tween()
		t.tween_property($ListenButton, "position", base + Vector2(0, -8), 0.06).set_ease(Tween.EASE_OUT)
		t.tween_property($ListenButton, "position", base,                  0.06).set_ease(Tween.EASE_IN)
		await t.finished
	$ListenButton.position = base

# ─── Button press ─────────────────────────────────────────────────────────────

func _on_button_pressed(btn_number: int) -> void:
	if result_locked:
		return
	_waiting_for_choice      = false   # cancel the 3-second auto-replay timer
	result_locked            = true
	$PointedHand.visible     = false
	$EvalPlayButton.visible  = false

	await get_tree().create_timer(0.2).timeout

	if btn_number == rounds[round_index].get("correct_slot", 0):
		# Play the word sound once on correct tap
		var word_snd : AudioStreamPlayer = get_node("WordSound%d" % btn_number)
		if word_snd.stream != null:
			word_snd.play()
		await get_tree().create_timer(0.5).timeout
		await _do_correct()
	else:
		await _do_wrong()

# ─── Round Progress Cubes ─────────────────────────────────────────────────────

func _create_round_cubes() -> void:
	var total   : int   = _total_set_rounds
	if total == 0:
		return
	var max_w   : float = 1100.0
	var gap     : float = 4.0
	var sz      : float = min(36.0, (max_w - gap * (total - 1)) / total)
	var start_x : float = 90.0
	var cube_y  : float = 630.0
	for i in range(total):
		var rect := ColorRect.new()
		rect.size     = Vector2(sz, sz)
		rect.color    = Color.WHITE
		rect.position = Vector2(start_x + i * (sz + gap), cube_y)
		add_child(rect)
		_round_cubes.append(rect)

func _blend_round_cube() -> void:
	if round_index < _round_cubes.size():
		var t := create_tween()
		t.tween_property(_round_cubes[round_index], "color", Color("#A8E063"), 0.8)

# ─── Correct ──────────────────────────────────────────────────────────────────

func _do_correct() -> void:
	# Record round result before advancing
	_local_total += 1
	if _round_had_error:
		_local_wrong += 1
		_local_wrong_rounds.append(rounds[round_index])

	$CorrectSound.play()
	_blend_round_cube()
	await $CorrectSound.finished
	await get_tree().create_timer(0.6).timeout
	round_index += 1
	_start_round()

# ─── Wrong — replay full prep loop ────────────────────────────────────────────

func _do_wrong() -> void:
	_round_had_error = true   # mark this round as having an error
	$OopsSound.play()
	await $OopsSound.finished
	$WrongSound.play()
	await $WrongSound.finished
	await get_tree().create_timer(0.3).timeout
	# Restore button positions in case of animation drift, then replay
	_restore_button_positions()
	_run_prep_sequence()

func _restore_button_positions() -> void:
	for i in range(num_choices):
		var btn : TextureButton = get_node("ImageButton%d" % (i + 1))
		btn.position = _btn_base_pos[i]

# ─── Set complete ─────────────────────────────────────────────────────────────

func _do_level_complete() -> void:
	result_locked = true
	if ReviewState.active:
		ReviewState.active = false
		SaveManager.increment_review_count(ReviewState.set_key)
		get_tree().change_scene_to_file("res://gnb_where_am_i.tscn")
		return
	var score_pct : float = 100.0 if _local_total == 0 else \
		float(_local_total - _local_wrong) / float(_local_total) * 100.0
	PrepLevelProgress.last_score_pct = score_pct
	PrepLevelProgress.retry_rounds   = _local_wrong_rounds.duplicate()
	get_tree().change_scene_to_file("res://prep_transition.tscn")
