extends Node2D

# ─── Constants ────────────────────────────────────────────────────────────────
const BG_COLOR    : Color  = Color("#7A8C2E")
const IMG_SIZE    : float  = 220.0
const IMG_Y       : float  =  60.0
const EVAL_W      : float  = 150.0
const EVAL_H      : float  =  75.0
const VOWEL_Y     : float  = 520.0
const VOWEL_BTN_W : float  = 90.0
const VOWEL_GAP   : float  = 22.0
const NUM_VOWELS  : int    = 5
const IDLE_SECS   : float  = 3.0
const EVAL_DELAY  : float  = 1.0
const SNAP_DIST   : float  = 70.0

const CUBE_SIZE    : float = 88.0
const CUBE_GAP     : float = 16.0
const CUBE_ROW_Y   : float = 320.0
const CUBE_EMPTY   : Color = Color("#DDD0BE")
const CUBE_BORDER  : Color = Color("#E8724A")
const CUBE_BORDER_INACTIVE : Color = Color("#C4B8A8")
const CUBE_BORDER_W : float = 3.0
const CUBE_CORNER  : float = 10.0

const VOWELS : Array[String] = ["a", "e", "i", "o", "u"]
const VOWEL_AUDIO : Dictionary = {
	"a": "res://BGM&effect/SoundUp_level2_phonemes/short_a.wav",
	"e": "res://BGM&effect/SoundUp_level2_phonemes/short_e.wav",
	"i": "res://BGM&effect/SoundUp_level2_phonemes/short_i.wav",
	"o": "res://BGM&effect/SoundUp_level2_phonemes/short_o.wav",
	"u": "res://BGM&effect/SoundUp_level2_phonemes/short_u.wav",
}

# ─── State ────────────────────────────────────────────────────────────────────
var rounds              : Array  = []
var round_index         : int    = 0
var result_locked       : bool   = false
var phase               : String = "wait_listen"
var idle_time           : float  = 0.0
var hint_playing        : bool   = false
var _vowel_order        : Array  = []
var _walk_gen           : int    = 0
var correct_count       : int    = 0
var clean_correct_count : int    = 0
var _round_hint_used    : bool   = false
var _assisted_rounds    : Array  = []
var _round_cubes        : Array[ColorRect] = []
var _total_set_rounds   : int              = 0

# ─── Drag state ───────────────────────────────────────────────────────────────
var _dragging   : bool     = false
var _drag_slot  : int      = -1
var _drag_ghost : Sprite2D = null
var _drag_pos   : Vector2  = Vector2.ZERO

# ─── Nodes (built dynamically) ────────────────────────────────────────────────
var _img_btn    : TextureButton = null
var _eval_btn   : TextureButton = null
var _hand       : Sprite2D      = null
var _cube_row   : Node2D        = null
var _cube_mid   : Panel         = null
var _vowel_btns : Array         = []
var _back_btn   : TextureButton = null
var _gnb_btn    : Button        = null

# ─── Tweens ───────────────────────────────────────────────────────────────────
var _blink_tween    : Tween = null
var _eval_btn_tween : Tween = null

# ─── Ready ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	$background.color    = BG_COLOR
	$background.size         = get_viewport_rect().size
	$background.position     = Vector2.ZERO
	$background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_image_button()
	_setup_cube_row()
	_setup_hand()
	_setup_eval_button()
	_setup_vowel_buttons()
	_setup_back_button()
	_create_gnb_flag()
	_load_rounds()
	_create_round_cubes()
	_start_round()

# ─── Node setup ───────────────────────────────────────────────────────────────
func _setup_image_button() -> void:
	_img_btn                     = TextureButton.new()
	_img_btn.ignore_texture_size = true
	_img_btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_img_btn.custom_minimum_size = Vector2(IMG_SIZE, IMG_SIZE)
	_img_btn.size                = Vector2(IMG_SIZE, IMG_SIZE)
	_img_btn.position            = Vector2((1280.0 - IMG_SIZE) / 2.0, IMG_Y)
	_img_btn.pivot_offset        = Vector2(IMG_SIZE / 2.0, IMG_SIZE / 2.0)
	_img_btn.z_index             = 3
	_img_btn.visible             = false
	_img_btn.pressed.connect(_on_image_pressed)
	add_child(_img_btn)

func _setup_cube_row() -> void:
	_cube_row          = Node2D.new()
	_cube_row.position = Vector2(0.0, CUBE_ROW_Y)
	_cube_row.z_index  = 2
	add_child(_cube_row)

func _build_cube_row(phoneme_count: int, vowel_index: int) -> void:
	for child in _cube_row.get_children():
		child.queue_free()
	_cube_mid = null

	var total_w : float = phoneme_count * CUBE_SIZE + (phoneme_count - 1) * CUBE_GAP
	var start_x : float = (1280.0 - total_w) / 2.0

	for i in range(phoneme_count):
		var highlighted : bool = (i == vowel_index - 1)
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(CUBE_SIZE, CUBE_SIZE)
		panel.size                = Vector2(CUBE_SIZE, CUBE_SIZE)
		panel.position            = Vector2(start_x + i * (CUBE_SIZE + CUBE_GAP), 0.0)
		var style := StyleBoxFlat.new()
		style.bg_color                    = CUBE_EMPTY
		style.border_color                = CUBE_BORDER if highlighted else CUBE_BORDER_INACTIVE
		style.border_width_left           = int(CUBE_BORDER_W)
		style.border_width_right          = int(CUBE_BORDER_W)
		style.border_width_top            = int(CUBE_BORDER_W)
		style.border_width_bottom         = int(CUBE_BORDER_W)
		style.corner_radius_top_left      = int(CUBE_CORNER)
		style.corner_radius_top_right     = int(CUBE_CORNER)
		style.corner_radius_bottom_left   = int(CUBE_CORNER)
		style.corner_radius_bottom_right  = int(CUBE_CORNER)
		panel.add_theme_stylebox_override("panel", style)
		_cube_row.add_child(panel)
		if highlighted:
			_cube_mid = panel

func _setup_hand() -> void:
	_hand         = Sprite2D.new()
	_hand.texture = load("res://UI_assets/handsigns/pointed.png") as Texture2D
	_hand.scale   = Vector2(0.08, 0.08)
	_hand.z_index = 5
	_hand.visible = false
	add_child(_hand)

func _setup_eval_button() -> void:
	_eval_btn                     = TextureButton.new()
	_eval_btn.texture_normal      = load("res://UI_assets/playbutton.png") as Texture2D
	_eval_btn.ignore_texture_size = true
	_eval_btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_eval_btn.custom_minimum_size = Vector2(EVAL_W, EVAL_H)
	_eval_btn.size                = Vector2(EVAL_W, EVAL_H)
	_eval_btn.position            = Vector2(1050.0, 440.0)
	_eval_btn.pivot_offset        = Vector2(EVAL_W / 2.0, EVAL_H / 2.0)
	_eval_btn.z_index             = 5
	_eval_btn.visible             = false
	_eval_btn.pressed.connect(_on_eval_pressed)
	add_child(_eval_btn)

func _setup_vowel_buttons() -> void:
	var open_tex : Texture2D = load("res://UI_assets/handsigns/openhand.png") as Texture2D
	var total_w  : float     = NUM_VOWELS * VOWEL_BTN_W + (NUM_VOWELS - 1) * VOWEL_GAP
	var start_x  : float     = (1280.0 - total_w) / 2.0
	for i in range(NUM_VOWELS):
		var btn := TextureButton.new()
		btn.texture_normal        = open_tex
		btn.ignore_texture_size   = true
		btn.stretch_mode          = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size   = Vector2(VOWEL_BTN_W, VOWEL_BTN_W)
		btn.size                  = Vector2(VOWEL_BTN_W, VOWEL_BTN_W)
		btn.position              = Vector2(start_x + i * (VOWEL_BTN_W + VOWEL_GAP), VOWEL_Y)
		btn.pivot_offset          = Vector2(VOWEL_BTN_W / 2.0, VOWEL_BTN_W / 2.0)
		btn.z_index               = 3
		btn.visible               = false
		# button_down: start drag and play phoneme immediately
		btn.button_down.connect(_start_drag.bind(i))
		add_child(btn)
		_vowel_btns.append(btn)

func _setup_back_button() -> void:
	_back_btn = BackButton.new()
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)

# ─── Cube blink ───────────────────────────────────────────────────────────────
func _start_cube_blink() -> void:
	if _blink_tween != null:
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_cube_mid, "modulate:a", 0.2, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_property(_cube_mid, "modulate:a", 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_cube_blink() -> void:
	if _blink_tween != null:
		_blink_tween.kill()
		_blink_tween = null
	if _cube_mid != null:
		_cube_mid.modulate.a = 1.0

# ─── Eval pulse ───────────────────────────────────────────────────────────────
func _start_eval_pulse() -> void:
	if _eval_btn_tween != null:
		_eval_btn_tween.kill()
	var orig_y : float   = _eval_btn.position.y
	_eval_btn.scale      = Vector2(1.0, 1.0)
	_eval_btn.position.y = orig_y
	_eval_btn_tween = create_tween().set_loops()
	_eval_btn_tween.tween_property(_eval_btn, "scale", Vector2(1.18, 1.18), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_eval_btn_tween.parallel().tween_property(_eval_btn, "position:y", orig_y - 8.0, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_eval_btn_tween.tween_property(_eval_btn, "scale", Vector2(1.0, 1.0), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_eval_btn_tween.parallel().tween_property(_eval_btn, "position:y", orig_y, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_eval_pulse() -> void:
	if _eval_btn_tween != null:
		_eval_btn_tween.kill()
		_eval_btn_tween  = null
	_eval_btn.scale      = Vector2(1.0, 1.0)
	_eval_btn.position.y = 440.0

# ─── Round loading ────────────────────────────────────────────────────────────
func _load_rounds() -> void:
	var file := FileAccess.open(Level2Progress.current_set(), FileAccess.READ)
	var data : Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	_total_set_rounds = data["rounds"].size()
	if Level2Progress.is_retry and Level2Progress.retry_rounds.size() > 0:
		rounds = Level2Progress.retry_rounds.duplicate()
		Level2Progress.is_retry = false
		Level2Progress.retry_rounds.clear()
	else:
		rounds = data["rounds"].duplicate()
	rounds.shuffle()
	correct_count       = 0
	clean_correct_count = 0
	_assisted_rounds    = []

# ─── Round flow ───────────────────────────────────────────────────────────────
func _start_round() -> void:
	if round_index >= rounds.size():
		_do_level_complete()
		return
	result_locked    = false
	idle_time        = 0.0
	phase            = "wait_listen"
	hint_playing     = false
	_round_hint_used = false
	_walk_gen       += 1

	_vowel_order = VOWELS.duplicate()
	_vowel_order.shuffle()

	_stop_eval_pulse()
	_stop_cube_blink()
	_eval_btn.visible = false
	for btn in _vowel_btns:
		btn.visible = true

	var r : Dictionary = rounds[round_index]
	_build_cube_row(int(r["phonemes"]), int(r["vowel_pos"]))
	_start_cube_blink()

	_img_btn.texture_normal = load(rounds[round_index]["word_image"]) as Texture2D
	_img_btn.visible        = true

	_hand.position         = Vector2(1050.0, 280.0)
	_hand.rotation_degrees = -30.0
	_hand.visible          = true

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
		t.tween_property(_round_cubes[round_index], "color", BG_COLOR, 0.8)

func _restart_round() -> void:
	_clear_drag()
	var was_hint_used : bool = _round_hint_used
	_start_round()
	_round_hint_used = was_hint_used

func _do_level_complete() -> void:
	result_locked = true
	_stop_cube_blink()
	_stop_eval_pulse()
	if ReviewState.active:
		ReviewState.active = false
		SaveManager.increment_review_count(ReviewState.set_key)
		get_tree().change_scene_to_file("res://gnb_where_am_i.tscn")
		return
	Level2Progress.last_score_pct = \
		float(clean_correct_count) / float(rounds.size()) * 100.0
	Level2Progress.retry_rounds = _assisted_rounds.duplicate()
	Level2Progress.active = true
	SaveManager.set_level2_set_index(Level2Progress.current_index)
	get_tree().change_scene_to_file("res://transition.tscn")

# ─── Image pressed (hear the word) ───────────────────────────────────────────
func _on_image_pressed() -> void:
	if result_locked:
		return
	if phase != "wait_listen":
		return
	phase         = "word_playing"
	_hand.visible = false
	hint_playing  = false
	idle_time     = 0.0
	$WordPlayer.stream = load(rounds[round_index]["word_audio"])
	$WordPlayer.play()
	await $WordPlayer.finished
	if phase != "word_playing":
		return
	await get_tree().create_timer(EVAL_DELAY).timeout
	if phase != "word_playing":
		return
	phase             = "walk"
	_eval_btn.visible = true
	_start_eval_pulse()
	idle_time = 0.0
	var gen : int = _walk_gen
	await _vowel_walk(gen)
	if _walk_gen != gen:
		return
	_stop_eval_pulse()
	_eval_btn.visible = false
	_hand.visible     = false
	phase             = "wait_answer"
	idle_time         = 0.0

# ─── EvalPlayButton pressed ───────────────────────────────────────────────────
func _on_eval_pressed() -> void:
	pass

func _vowel_walk(gen: int) -> void:
	for i in range(NUM_VOWELS):
		if _walk_gen != gen:
			return
		var btn_center_x : float = _vowel_btns[i].position.x + VOWEL_BTN_W / 2.0
		_hand.position         = Vector2(btn_center_x, VOWEL_Y - 40.0)
		_hand.rotation_degrees = 180.0
		_hand.visible          = true
		$VowelPlayer.stream = load(VOWEL_AUDIO[_vowel_order[i]])
		$VowelPlayer.play()
		await $VowelPlayer.finished
		if _walk_gen != gen:
			return
		await get_tree().create_timer(0.5).timeout

# ─── Drag mechanics ───────────────────────────────────────────────────────────
func _start_drag(slot: int) -> void:
	if result_locked or phase != "wait_answer":
		return
	if _dragging:
		return
	_dragging  = true
	_drag_slot = slot
	_drag_pos  = get_viewport().get_mouse_position()

	$VowelPlayer.stream = load(VOWEL_AUDIO[_vowel_order[slot]])
	$VowelPlayer.play()

	var open_tex : Texture2D = load("res://UI_assets/handsigns/openhand.png") as Texture2D
	_drag_ghost         = Sprite2D.new()
	_drag_ghost.texture = open_tex
	_drag_ghost.z_index = 20
	if open_tex:
		var sc : float = VOWEL_BTN_W / max(open_tex.get_size().x, open_tex.get_size().y)
		_drag_ghost.scale = Vector2(sc, sc)
	_drag_ghost.global_position = _drag_pos
	add_child(_drag_ghost)

func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false

	var slot     : int    = _drag_slot
	var drop_pos : Vector2 = _drag_pos

	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null

	if phase != "wait_answer" or result_locked:
		return

	var cube_center : Vector2 = _cube_mid.global_position + Vector2(CUBE_SIZE, CUBE_SIZE) / 2.0
	if drop_pos.distance_to(cube_center) <= SNAP_DIST:
		_handle_drop(slot)

func _handle_drop(slot: int) -> void:
	result_locked = true
	var chosen  : String = _vowel_order[slot]
	var correct : String = rounds[round_index]["correct_vowel"]
	if chosen == correct:
		await _do_correct()
	else:
		await _do_wrong()

func _clear_drag() -> void:
	_dragging = false
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null

# ─── Input (drag tracking) ────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _dragging:
		_drag_pos = (event as InputEventMouseMotion).position
		return
	if event is InputEventScreenDrag and _dragging:
		_drag_pos = (event as InputEventScreenDrag).position
		return
	if not _dragging:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_drag_pos = mb.position
			_end_drag.call_deferred()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed:
			_drag_pos = st.position
			_end_drag.call_deferred()

# ─── Correct / Wrong ──────────────────────────────────────────────────────────
func _do_correct() -> void:
	correct_count += 1
	if not _round_hint_used:
		clean_correct_count += 1
	else:
		_assisted_rounds.append(rounds[round_index])
	_stop_cube_blink()
	var style := StyleBoxFlat.new()
	style.bg_color                   = CUBE_BORDER
	style.corner_radius_top_left     = int(CUBE_CORNER)
	style.corner_radius_top_right    = int(CUBE_CORNER)
	style.corner_radius_bottom_left  = int(CUBE_CORNER)
	style.corner_radius_bottom_right = int(CUBE_CORNER)
	_cube_mid.add_theme_stylebox_override("panel", style)
	$CorrectSound.play()
	_blend_round_cube()
	await $CorrectSound.finished
	await get_tree().create_timer(0.5).timeout
	_advance_round()

func _do_wrong() -> void:
	_round_hint_used = true
	$OopsSound.play()
	await $OopsSound.finished
	$WrongSound.play()
	await $WrongSound.finished
	result_locked = false
	_restart_round()

# ─── Back button ──────────────────────────────────────────────────────────────
func _on_back_pressed() -> void:
	if result_locked or round_index == 0:
		return
	_walk_gen        += 1
	round_index      -= 1
	_round_hint_used  = false
	_clear_drag()
	_start_round()


func _create_gnb_flag() -> void:
	const BTN_W  : float = 72.0
	const BTN_H  : float = 56.0

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
	pill.size         = Vector2(50.0, 52.0)
	pill.position     = (Vector2(BTN_W, BTN_H) - pill.size) / 2.0
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	var pill_color := Color("#4B0082")
	pill_color.a                  = 0.4
	ps.bg_color                   = pill_color
	ps.corner_radius_top_left     = 14
	ps.corner_radius_top_right    = 14
	ps.corner_radius_bottom_left  = 14
	ps.corner_radius_bottom_right = 14
	pill.add_theme_stylebox_override("panel", ps)
	_gnb_btn.add_child(pill)

	var flag_icon := TextureRect.new()
	flag_icon.texture      = load("res://UI_assets/flag.png") as Texture2D
	flag_icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	flag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag_icon.size         = Vector2(42, 47)
	flag_icon.position     = (Vector2(BTN_W, BTN_H) - flag_icon.size) / 2.0
	_gnb_btn.add_child(flag_icon)

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


# ─── Idle hint ────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _dragging and _drag_ghost != null:
		_drag_ghost.global_position = _drag_pos

	if result_locked or hint_playing:
		return
	idle_time += delta
	if idle_time < IDLE_SECS:
		return
	pass  # no idle hand hints beyond the initial round-start pointer
