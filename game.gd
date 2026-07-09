extends Node2D

var rounds            : Array  = []
var round_index       : int    = 0
var idle_time          : float  = 0.0
var phase              : String = "wait_listen"
var result_locked      : bool   = false
var hint_playing       : bool   = false
var _hint_voice_active : bool   = false
var num_choices        : int    = 3
var _btn_centers       : Array[Vector2] = []
var correct_count       : int   = 0
var clean_correct_count : int   = 0      # correct with no wrong click this round
var _round_hint_used    : bool  = false  # set true on first wrong click this round
var _assisted_rounds    : Array = []     # round dicts where _round_hint_used was true
var _back_btn           : TextureButton = null
var _gnb_btn            : Button        = null
var _round_cubes        : Array[ColorRect] = []
var _round_bg_color     : Color            = Color.WHITE
var _total_set_rounds   : int              = 0
var _btn_base_pos       : Array[Vector2]   = []
var _is_ending_set      : bool             = false
var _eval_tween         : Tween            = null

func _ready() -> void:
	$background.size         = get_viewport_rect().size
	$background.position     = Vector2(0, 0)
	$background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$background.color      = Color(0.431, 0.710, 1.0, 1.0)   # sky blue — Level 1
	_round_bg_color        = Color(0.431, 0.710, 1.0, 1.0)
	$ListenButton.position = Vector2(100, 60)
	$ListenButton.size     = Vector2(980, 80)
	$ListenButton.text     = "👂 LISTEN"
	$PointedHand.visible   = false
	$PointedHand.scale     = Vector2(0.08, 0.08)
	$PointedHand.z_index   = 5
	$EvalPlayButton.visible = false
	_setup_back_button()
	_create_gnb_flag()
	$ListenButton.pressed.connect(_on_listen_pressed)
	$ImageButton1.pressed.connect(_on_button_pressed.bind(1))
	$ImageButton2.pressed.connect(_on_button_pressed.bind(2))
	$ImageButton3.pressed.connect(_on_button_pressed.bind(3))
	$ImageButton4.pressed.connect(_on_button_pressed.bind(4))
	$ImageButton5.pressed.connect(_on_button_pressed.bind(5))
	_load_rounds()
	_create_round_cubes()
	_start_round()

func _setup_back_button() -> void:
	_back_btn = TextureButton.new()
	_back_btn.texture_normal      = load("res://UI_assets/back_button.png") as Texture2D
	_back_btn.ignore_texture_size = true
	_back_btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# 150×150 — 2.5× the previous 60px size
	_back_btn.custom_minimum_size = Vector2(150, 150)
	_back_btn.size                = Vector2(150, 150)
	# Inside the left side of the Listen bar, centred on the bar's vertical centre (y=100)
	_back_btn.position            = Vector2(108, 25)
	_back_btn.z_index             = 2
	# Recolour the black triangle to white so it shows on the dark Listen bar
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(1.0, 1.0, 1.0, c.a); }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_back_btn.material = mat
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)

func _on_back_pressed() -> void:
	if result_locked or round_index == 0:
		return
	round_index -= 1
	_start_round()


func _create_gnb_flag() -> void:
	const BTN_W  : float = 72.0
	const BTN_H  : float = 56.0
	const AMBER  : Color = Color("#FFB703")

	_gnb_btn              = Button.new()
	_gnb_btn.text         = ""
	_gnb_btn.size         = Vector2(BTN_W, BTN_H)
	_gnb_btn.position     = Vector2(1280.0 - BTN_W - 20.0, 20.0)
	_gnb_btn.z_index      = 10
	_gnb_btn.pivot_offset = Vector2(BTN_W * 0.5, BTN_H * 0.5)

	var blank := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		_gnb_btn.add_theme_stylebox_override(s, blank)

	var pill := Panel.new()
	pill.size         = Vector2(56.0, 44.0)
	pill.position     = Vector2(8.0, 6.0)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.0, 0.0, 0.0, 0.4)
	ps.corner_radius_top_left     = 14
	ps.corner_radius_top_right    = 14
	ps.corner_radius_bottom_left  = 14
	ps.corner_radius_bottom_right = 14
	pill.add_theme_stylebox_override("panel", ps)
	_gnb_btn.add_child(pill)

	var pole := ColorRect.new()
	pole.color        = AMBER
	pole.size         = Vector2(4.0, 36.0)
	pole.position     = Vector2(24.0, 10.0)
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gnb_btn.add_child(pole)

	var flag := ColorRect.new()
	flag.color        = AMBER
	flag.size         = Vector2(22.0, 16.0)
	flag.position     = Vector2(28.0, 10.0)
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gnb_btn.add_child(flag)

	_gnb_btn.pressed.connect(_on_gnb_flag_pressed)
	add_child(_gnb_btn)


func _on_gnb_flag_pressed() -> void:
	if get_node_or_null("GNBOverlay") != null:
		return
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	overlay.name  = "GNBOverlay"
	var wai : Node = load("res://gnb_where_am_i.tscn").instantiate()
	wai.set("is_overlay", true)
	wai.connect("close_requested", func(): overlay.queue_free())
	overlay.add_child(wai)
	add_child(overlay)

func _load_rounds() -> void:
	var file := FileAccess.open(LevelProgress.current_set(), FileAccess.READ)
	var data : Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	_total_set_rounds = data["rounds"].size()
	if LevelProgress.is_retry and LevelProgress.retry_rounds.size() > 0:
		rounds = LevelProgress.retry_rounds.duplicate()
		LevelProgress.is_retry = false
		LevelProgress.retry_rounds.clear()
	else:
		rounds = data["rounds"].duplicate()
	_shuffle_no_consecutive()
	correct_count       = 0
	clean_correct_count = 0
	_assisted_rounds    = []

func _shuffle_no_consecutive() -> void:
	rounds.shuffle()
	# Forward pass: wherever two consecutive rounds share the same phoneme,
	# swap the second one with the earliest later round that fits both neighbors.
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

func _start_round() -> void:
	if round_index >= rounds.size():
		_do_level_complete()
		return
	var rd : Dictionary = rounds[round_index]
	result_locked         = false
	idle_time             = 0.0
	phase                 = "wait_listen"
	hint_playing          = false
	_round_hint_used      = false
	$EvalPlayButton.visible = false
	$ListenSound.stop()
	$ListenVoice.stop()
	_hint_voice_active          = false
	$PointedHand.visible = false
	$ListenSound.stream = load(rd["phoneme_audio"])
	var n : int = rd["choices"].size()
	_update_layout(n)
	_btn_base_pos.clear()
	_is_ending_set = LevelProgress.current_set_label().begins_with("G")
	for i in range(n):
		var choice : Dictionary = rd["choices"][i]
		var btn    : TextureButton = get_node("ImageButton%d" % (i + 1))
		btn.texture_normal = load(choice["image"]) as Texture2D
		_place_button(btn, _btn_centers[i])
		_btn_base_pos.append(btn.position)
		var wa : String = choice.get("word_audio", "")
		get_node("WordSound%d" % (i + 1)).stream = load(wa) if wa != "" else null

func _advance_round() -> void:
	round_index += 1
	_start_round()

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
		t.tween_property(_round_cubes[round_index], "color", _round_bg_color, 0.8)

func _do_level_complete() -> void:
	result_locked = true
	if ReviewState.active:
		ReviewState.active = false
		SaveManager.increment_review_count(ReviewState.set_key)
		get_tree().change_scene_to_file("res://gnb_where_am_i.tscn")
		return
	LevelProgress.last_score_pct = float(clean_correct_count) / float(rounds.size()) * 100.0
	LevelProgress.retry_rounds   = _assisted_rounds.duplicate()
	get_tree().change_scene_to_file("res://transition.tscn")

func _on_listen_pressed() -> void:
	if result_locked:
		return
	result_locked           = true
	$PointedHand.visible    = false
	$EvalPlayButton.visible = false
	idle_time               = 0.0
	hint_playing            = false
	if _is_ending_set:
		_run_ending_sequence.call_deferred()
		return
	$ListenSound.play()
	phase         = "wait_image"
	result_locked = false

func _on_button_pressed(btn_number: int) -> void:
	if result_locked:
		return
	result_locked           = true
	idle_time               = 0.0
	hint_playing            = false
	$PointedHand.visible    = false
	$EvalPlayButton.visible = false
	await get_tree().create_timer(0.2).timeout
	if btn_number == rounds[round_index].get("correct_slot", 0):
		var word_snd : AudioStreamPlayer = get_node("WordSound%d" % btn_number)
		if word_snd.stream != null:
			word_snd.play()
		await get_tree().create_timer(0.5).timeout
		await _do_correct()
	else:
		await _do_wrong()

func _do_correct() -> void:
	correct_count += 1
	if not _round_hint_used:
		clean_correct_count += 1
	else:
		_assisted_rounds.append(rounds[round_index])
	$CorrectSound.play()
	_blend_round_cube()
	await $CorrectSound.finished
	await get_tree().create_timer(0.8).timeout
	_advance_round()

func _do_wrong() -> void:
	_round_hint_used = true   # wrong click — round is no longer clean
	$OopsSound.play()
	await $OopsSound.finished
	$WrongSound.play()
	await $WrongSound.finished
	result_locked           = false
	idle_time               = 0.0
	hint_playing            = false
	$EvalPlayButton.visible = false
	phase                   = "wait_listen"

func _process(delta: float) -> void:
	if result_locked or hint_playing:
		return
	idle_time += delta
	if idle_time < 3.0:
		return
	if phase == "wait_listen":
		hint_playing                  = true
		$PointedHand.visible          = true
		$PointedHand.position         = Vector2(1050, 280)
		$PointedHand.rotation_degrees = -30.0
		_play_listen_hint()

func _play_listen_hint() -> void:
	if _hint_voice_active:
		return
	_hint_voice_active = true
	$ListenVoice.play()
	await $ListenVoice.finished
	_hint_voice_active = false

# ─── Ending-sound sequence (Set G only) ──────────────────────────────────────

func _run_ending_sequence() -> void:
	phase = "ending_sequence"
	$ListenSound.play()
	await $ListenSound.finished
	await get_tree().create_timer(0.35).timeout
	$ListenSound.play()
	await $ListenSound.finished
	await get_tree().create_timer(0.4).timeout
	$EvalPlayButton.position = Vector2(1050, 280)
	$EvalPlayButton.visible  = true
	_start_eval_pulse()
	var n : int = rounds[round_index]["choices"].size()
	for i in range(n):
		var btn : TextureButton     = get_node("ImageButton%d" % (i + 1))
		var snd : AudioStreamPlayer = get_node("WordSound%d" % (i + 1))
		if snd.stream == null:
			continue
		_bounce_image(btn, i)
		snd.play()
		await snd.finished
		await get_tree().create_timer(0.5).timeout
	_stop_eval_pulse()
	$EvalPlayButton.visible = false
	_restore_btn_positions()
	phase         = "wait_image"
	result_locked = false

func _bounce_image(btn: TextureButton, index: int) -> void:
	var base := _btn_base_pos[index]
	var t    := create_tween()
	t.tween_property(btn, "position", base + Vector2(0, -18), 0.10).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "position", base,                   0.10).set_ease(Tween.EASE_IN)
	t.tween_property(btn, "position", base + Vector2(0, -9),  0.07).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "position", base,                   0.07).set_ease(Tween.EASE_IN)

func _restore_btn_positions() -> void:
	for i in range(num_choices):
		get_node("ImageButton%d" % (i + 1)).position = _btn_base_pos[i]

func _start_eval_pulse() -> void:
	if _eval_tween:
		_eval_tween.kill()
	var base_y : float = $EvalPlayButton.position.y
	_eval_tween = create_tween().set_loops()
	_eval_tween.tween_property($EvalPlayButton, "position:y", base_y - 12.0, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_eval_tween.tween_property($EvalPlayButton, "position:y", base_y,         0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_eval_pulse() -> void:
	if _eval_tween:
		_eval_tween.kill()
		_eval_tween = null
	$EvalPlayButton.position = Vector2(1050, 280)
