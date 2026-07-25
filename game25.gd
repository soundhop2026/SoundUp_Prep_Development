extends Node2D

# ─── Constants ────────────────────────────────────────────────────────────────
const BG_COLOR       : Color = Color("#7A8C2E")
const CUBE_SIZE      : float = 120.0
const CUBE_Y         : float = 80.0
const IMG_SIZE       : float = 160.0
const IMG_GAP        : float = 20.0
const IMG_Y          : float = 380.0
const EVAL_W         : float = 150.0
const EVAL_H         : float = 75.0
const EVAL_DELAY     : float = 1.0
const IMAGE_GAP_SEC  : float = 0.8
const IDLE_SECS      : float = 3.0

const CUBE_FILL      : Color = Color("#DDD0BE")
const CUBE_ACTIVE    : Color = Color("#E8724A")
const CUBE_BORDER_W  : float = 3.0
const CUBE_CORNER    : float = 10.0

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
var correct_count       : int    = 0
var clean_correct_count : int    = 0
var _round_hint_used    : bool   = false
var _assisted_rounds    : Array  = []
var _scored_rounds      : Dictionary = {} # round_index -> true once counted toward the set's
                                           # score — Back is unlimited for review, but a round's
                                           # score is locked in on its first completion and never
                                           # changes on replay
var _round_cubes        : Array[ColorRect] = []
var _total_set_rounds   : int              = 0
var _walk_gen           : int    = 0
var _image_order        : Array  = []   # [{word, audio, image, is_correct}, ...]
var _dragging           : bool  = false
var _drag_ghost         : Panel = null

# ─── Nodes ────────────────────────────────────────────────────────────────────
var _cube_btn   : Button        = null
var _eval_btn   : TextureButton = null
var _hand       : Sprite2D      = null
var _img_btns   : Array         = []
var _back_btn   : TextureButton = null
var _gnb_btn    : Button        = null

# ─── Tweens ───────────────────────────────────────────────────────────────────
var _blink_tween    : Tween = null
var _eval_btn_tween : Tween = null

# ─── Drag input ───────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if phase != "wait_answer" or result_locked:
		return
	var pos      : Vector2 = Vector2.ZERO
	var pressed  : bool    = false
	var released : bool    = false
	var moved    : bool    = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos      = event.position
		pressed  = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and _dragging:
		pos   = event.position
		moved = true
	elif event is InputEventScreenTouch:
		pos      = event.position
		pressed  = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag and _dragging:
		pos   = event.position
		moved = true
	if pressed:
		var cube_rect := Rect2(_cube_btn.position, _cube_btn.size)
		if cube_rect.has_point(pos):
			_start_drag(pos)
			get_viewport().set_input_as_handled()
	elif moved:
		_update_drag(pos)
		get_viewport().set_input_as_handled()
	elif released and _dragging:
		_end_drag(pos)
		get_viewport().set_input_as_handled()

func _start_drag(pos: Vector2) -> void:
	if _dragging:
		return
	_dragging        = true
	var panel        := Panel.new()
	panel.size       = Vector2(CUBE_SIZE, CUBE_SIZE)
	panel.position   = pos - Vector2(CUBE_SIZE / 2.0, CUBE_SIZE / 2.0)
	panel.z_index    = 10
	panel.modulate.a = 0.85
	var style := StyleBoxFlat.new()
	style.bg_color                   = CUBE_FILL
	style.border_color               = CUBE_ACTIVE
	style.border_width_left          = int(CUBE_BORDER_W)
	style.border_width_right         = int(CUBE_BORDER_W)
	style.border_width_top           = int(CUBE_BORDER_W)
	style.border_width_bottom        = int(CUBE_BORDER_W)
	style.corner_radius_top_left     = int(CUBE_CORNER)
	style.corner_radius_top_right    = int(CUBE_CORNER)
	style.corner_radius_bottom_left  = int(CUBE_CORNER)
	style.corner_radius_bottom_right = int(CUBE_CORNER)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_drag_ghost      = panel
	_cube_btn.modulate.a = 0.3
	_stop_cube_blink()

func _update_drag(pos: Vector2) -> void:
	if _drag_ghost != null:
		_drag_ghost.position = pos - Vector2(CUBE_SIZE / 2.0, CUBE_SIZE / 2.0)

func _end_drag(pos: Vector2) -> void:
	_dragging = false
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	_cube_btn.modulate.a = 1.0
	for i in range(_img_btns.size()):
		var rect := Rect2(_img_btns[i].position, _img_btns[i].size)
		if rect.has_point(pos):
			_on_image_tapped(i)
			return
	_start_cube_blink()

func _cancel_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	_cube_btn.modulate.a = 1.0

# ─── Ready ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	$background.color        = BG_COLOR
	$background.size         = get_viewport_rect().size
	$background.position     = Vector2.ZERO
	$background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_cube_button()
	_setup_hand()
	_setup_eval_button()
	_setup_back_button()
	_create_gnb_flag()
	_load_rounds()
	_create_round_cubes()
	_start_round()

# ─── Node setup ───────────────────────────────────────────────────────────────
func _setup_cube_button() -> void:
	_cube_btn               = Button.new()
	_cube_btn.custom_minimum_size = Vector2(CUBE_SIZE, CUBE_SIZE)
	_cube_btn.size          = Vector2(CUBE_SIZE, CUBE_SIZE)
	_cube_btn.position      = Vector2((1280.0 - CUBE_SIZE) / 2.0, CUBE_Y)
	_cube_btn.pivot_offset  = Vector2(CUBE_SIZE / 2.0, CUBE_SIZE / 2.0)
	_cube_btn.z_index       = 3
	_cube_btn.text          = ""
	var style := StyleBoxFlat.new()
	style.bg_color                   = CUBE_FILL
	style.border_color               = CUBE_ACTIVE
	style.border_width_left          = int(CUBE_BORDER_W)
	style.border_width_right         = int(CUBE_BORDER_W)
	style.border_width_top           = int(CUBE_BORDER_W)
	style.border_width_bottom        = int(CUBE_BORDER_W)
	style.corner_radius_top_left     = int(CUBE_CORNER)
	style.corner_radius_top_right    = int(CUBE_CORNER)
	style.corner_radius_bottom_left  = int(CUBE_CORNER)
	style.corner_radius_bottom_right = int(CUBE_CORNER)
	_cube_btn.add_theme_stylebox_override("normal",   style)
	_cube_btn.add_theme_stylebox_override("hover",    style)
	_cube_btn.add_theme_stylebox_override("pressed",  style)
	_cube_btn.add_theme_stylebox_override("focus",    style)
	_cube_btn.pressed.connect(_on_cube_pressed)
	add_child(_cube_btn)

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
	_eval_btn.position            = Vector2(1050.0, 300.0)
	_eval_btn.pivot_offset        = Vector2(EVAL_W / 2.0, EVAL_H / 2.0)
	_eval_btn.z_index             = 5
	_eval_btn.visible             = false
	_eval_btn.pressed.connect(_on_eval_pressed)
	add_child(_eval_btn)

func _setup_back_button() -> void:
	_back_btn = BackButton.new()
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)

# ─── Cube blink ───────────────────────────────────────────────────────────────
func _start_cube_blink() -> void:
	if _blink_tween != null:
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_cube_btn, "modulate:a", 0.2, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_property(_cube_btn, "modulate:a", 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_cube_blink() -> void:
	if _blink_tween != null:
		_blink_tween.kill()
		_blink_tween = null
	_cube_btn.modulate.a = 1.0

# ─── Eval pulse ───────────────────────────────────────────────────────────────
func _start_eval_pulse() -> void:
	if _eval_btn_tween != null:
		_eval_btn_tween.kill()
	var orig_y : float = _eval_btn.position.y
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
	_eval_btn.position.y = 300.0

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
	_scored_rounds      = {}

# ─── Round flow ───────────────────────────────────────────────────────────────
func _start_round() -> void:
	if round_index >= rounds.size():
		_do_level_complete()
		return
	_cancel_drag()
	result_locked    = false
	phase            = "wait_listen"
	_round_hint_used = false
	_walk_gen       += 1

	_stop_eval_pulse()
	_stop_cube_blink()
	_eval_btn.visible = false
	_hand.visible     = false
	_clear_image_buttons()

	# Build shuffled image order: correct + distractors
	var r : Dictionary = rounds[round_index]
	_image_order = []
	_image_order.append({
		"word": r["correct_word"],
		"audio": r["correct_audio"],
		"image": r["correct_image"],
		"is_correct": true,
	})
	for d in r["distractors"]:
		_image_order.append({
			"word": d["word"],
			"audio": d["audio"],
			"image": d["image"],
			"is_correct": false,
		})
	_image_order.shuffle()
	_show_image_buttons()

	# Cube blinks; pointed hand sits in same position as game2
	_start_cube_blink()
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
	var was_hint : bool = _round_hint_used
	_start_round()
	_round_hint_used = was_hint

func _clear_image_buttons() -> void:
	for btn in _img_btns:
		btn.queue_free()
	_img_btns.clear()

func _show_image_buttons() -> void:
	_clear_image_buttons()
	var n       : int   = _image_order.size()
	var total_w : float = n * IMG_SIZE + (n - 1) * IMG_GAP
	var start_x : float = (1280.0 - total_w) / 2.0
	for i in range(n):
		var btn := TextureButton.new()
		btn.texture_normal      = load(_image_order[i]["image"]) as Texture2D
		btn.ignore_texture_size = true
		btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(IMG_SIZE, IMG_SIZE)
		btn.size                = Vector2(IMG_SIZE, IMG_SIZE)
		btn.position            = Vector2(start_x + i * (IMG_SIZE + IMG_GAP), IMG_Y)
		btn.pivot_offset        = Vector2(IMG_SIZE / 2.0, IMG_SIZE / 2.0)
		btn.z_index             = 3
		btn.visible             = true
		btn.pressed.connect(_on_image_tapped.bind(i))
		add_child(btn)
		_img_btns.append(btn)

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
	Level2Progress.active       = true
	SaveManager.set_level2_set_index(Level2Progress.current_index)
	get_tree().change_scene_to_file("res://transition.tscn")

# ─── Cube pressed (hear vowel) ────────────────────────────────────────────────
func _on_cube_pressed() -> void:
	if result_locked:
		return
	if phase != "wait_listen":
		return
	phase         = "vowel_playing"
	_hand.visible = false
	var vowel_stream = load(VOWEL_AUDIO[rounds[round_index]["target_vowel"]])
	if vowel_stream != null:
		$VowelPlayer.stream = vowel_stream
		$VowelPlayer.play()
		await $VowelPlayer.finished
	if phase != "vowel_playing":
		return
	await get_tree().create_timer(EVAL_DELAY).timeout
	if phase != "vowel_playing":
		return
	phase             = "walk"
	_eval_btn.visible = true
	_start_eval_pulse()
	var gen : int = _walk_gen
	await _image_walk(gen)
	if _walk_gen != gen:
		return
	_stop_eval_pulse()
	_eval_btn.visible = false
	_hand.visible     = false
	phase             = "wait_answer"

# ─── EvalPlayButton pressed ───────────────────────────────────────────────────
func _on_eval_pressed() -> void:
	pass

func _image_walk(gen: int) -> void:
	for i in range(_img_btns.size()):
		if _walk_gen != gen:
			return
		var btn_cx : float = _img_btns[i].position.x + IMG_SIZE / 2.0
		var btn_ty : float = _img_btns[i].position.y
		_hand.position         = Vector2(btn_cx, btn_ty - 50.0)
		_hand.rotation_degrees = 180.0
		_hand.visible          = true
		var word_stream = load(_image_order[i]["audio"])
		if word_stream == null:
			await get_tree().create_timer(0.8).timeout
		else:
			$WordPlayer.stream = word_stream
			$WordPlayer.play()
			await $WordPlayer.finished
		if _walk_gen != gen:
			return
		await get_tree().create_timer(IMAGE_GAP_SEC).timeout

# ─── Image tapped (the answer) ───────────────────────────────────────────────
func _on_image_tapped(idx: int) -> void:
	if phase != "wait_answer" or result_locked:
		return
	result_locked = true
	if _image_order[idx]["is_correct"]:
		await _do_correct()
	else:
		await _do_wrong()

# ─── Correct / Wrong ──────────────────────────────────────────────────────────
func _do_correct() -> void:
	# Back is unlimited for review; replaying an already-scored round must
	# never change the score, pass percentage, or gate result.
	if not _scored_rounds.has(round_index):
		_scored_rounds[round_index] = true
		correct_count += 1
		if not _round_hint_used:
			clean_correct_count += 1
		else:
			_assisted_rounds.append(rounds[round_index])
	_stop_cube_blink()
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
	_clear_image_buttons()
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
