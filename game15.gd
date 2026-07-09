extends Node2D

# ── SCENE TREE: create game15.tscn with these nodes ─────────────────────────
#
#   Node2D                 ← attach game15.gd here
#   ├── BG                 ColorRect
#   ├── ImgBtn1            TextureButton
#   ├── ImgBtn2            TextureButton
#   ├── ImgBtn3            TextureButton
#   ├── CubeRow            Node2D   position=(0, 345)  ← children added in code
#   ├── ChoiceRow          Node2D   position=(0, 515)  ← children added in code
#   ├── CountArea          Node2D   position=(0, 350)  ← kept in scene, never shown
#   │   ├── Count3Btn      Button
#   │   ├── Count4Btn      Button
#   │   └── Count5Btn      Button
#   ├── WordPlayer         AudioStreamPlayer
#   ├── PhonemePlayer      AudioStreamPlayer
#   ├── CorrectSound       AudioStreamPlayer  ← copy stream from game.tscn
#   ├── OopsSound          AudioStreamPlayer  ← copy stream from game.tscn
#   └── WrongSound         AudioStreamPlayer  ← copy stream from game.tscn
#
# AUTOLOAD REQUIRED: Level15Progress (level15_progress.gd)
#   Expose: current_set()→String, last_score_pct, retry_rounds, is_retry
#
# TRANSITION NOTE: transition.gd routes to game.tscn after set complete.
#   To route to game15.tscn instead, add a target_scene field to Level15Progress
#   and read it in transition.gd. Until then test routing manually.
# ────────────────────────────────────────────────────────────────────────────

const WORDS_PATH    := "res://data/words.json"
const PHONEMES_PATH := "res://data/phonemes.json"
const OPEN_HAND_TEX := "res://UI_assets/handsigns/openhand.png"
const BACK_BTN_TEX  := "res://UI_assets/back_button.png"

const CANVAS_W := 1280.0
const BG_COLOR        := Color("#A83A22")
const OPEN_HAND_COLOR := Color("#E8724A")

# Image layout
const IMG_SZ_SINGLE := 250.0
const IMG_SZ_TRIPLE := 175.0
const IMG_Y_SINGLE  :=  80.0
const IMG_Y_TRIPLE  := 100.0
const IMG_CENTERS_TRIPLE := [
	Vector2(360.0, 195.0),
	Vector2(640.0, 195.0),
	Vector2(920.0, 195.0),
]

# Cube layout
const CUBE_SIZE    := 88.0
const CUBE_GAP     := 16.0
const CUBE_CORNER  := 10.0
const CUBE_EMPTY   := Color("#DDD0BE")
const CUBE_FILLED  := Color("#E8724A")
const CUBE_BORDER  := Color("#E8724A")
const CUBE_BORDER_INACTIVE := Color("#C4B8A8")
const CUBE_BORDER_W := 3.0

# Choice layout
const CHOICE_SIZE  := 96.0
const CHOICE_GAP   := 22.0

# Count button layout
const COUNT_BTN_W   := 180.0
const COUNT_BTN_H   :=  90.0
const COUNT_BTN_GAP := 40.0

# Back button
const BACK_USES_MAX  : int   = 2

# Idle hint timing
const HINT_IDLE_SEC  : float = 3.0
const EVAL_DELAY     : float = 1.0

# Build-word 3-phase flow
const EVAL_BTN_TEX       : String = "res://UI_assets/playbutton.png"

# Sound-count layout
const SC_CUBE_SIZE       : float  = 56.0
const SC_DROP_W          : float  = 320.0
const SC_DROP_H          : float  = 70.0
const SC_DROP_Y          : float  = 355.0
const SC_CLUSTER_Y       : float  = 480.0
const SC_CLUSTER_SPACING : float  = 330.0

# ── Node refs ────────────────────────────────────────────────────────────────
@onready var _bg            : ColorRect         = $BG
@onready var _img1          : TextureButton     = $ImgBtn1
@onready var _img2          : TextureButton     = $ImgBtn2
@onready var _img3          : TextureButton     = $ImgBtn3
@onready var _cube_row      : Node2D            = $CubeRow
@onready var _choice_row    : Node2D            = $ChoiceRow
@onready var _count_area    : Node2D            = $CountArea
@onready var _count3_btn    : Button            = $CountArea/Count3Btn
@onready var _count4_btn    : Button            = $CountArea/Count4Btn
@onready var _count5_btn    : Button            = $CountArea/Count5Btn
@onready var _word_player   : AudioStreamPlayer = $WordPlayer
@onready var _phoneme_player: AudioStreamPlayer = $PhonemePlayer
@onready var _correct_snd   : AudioStreamPlayer = $CorrectSound
@onready var _oops_snd      : AudioStreamPlayer = $OopsSound
@onready var _wrong_snd     : AudioStreamPlayer = $WrongSound
@onready var _hand          : Sprite2D          = $PointedHand

# ── Loaded data ──────────────────────────────────────────────────────────────
var _set_def      : Dictionary = {}
var _all_words    : Dictionary = {}
var _phoneme_data : Dictionary = {}
var _word_pool    : Array      = []   # word keys matching allowed_structures

# ── Rounds ───────────────────────────────────────────────────────────────────
var _rounds        : Array      = []
var _round_index   : int        = 0
var _current_round : Dictionary = {}
var _result_locked : bool       = false
var _round_cubes        : Array[ColorRect] = []
var _total_set_rounds   : int              = 0

# ── Build-word tracking ──────────────────────────────────────────────────────
var _build_index : int = 0   # next cube slot to fill

# ── Accuracy ─────────────────────────────────────────────────────────────────
var _clean_correct   : int   = 0
var _round_hint_used : bool  = false
var _assisted_rounds : Array = []

# ── Dynamic nodes ────────────────────────────────────────────────────────────
var _cube_nodes   : Array         = []
var _choice_nodes : Array         = []
var _back_btn     : TextureButton = null
var _gnb_btn      : Button        = null

# ── Back button use limit ────────────────────────────────────────────────────
var _back_uses : int = 0

# ── Idle hint ────────────────────────────────────────────────────────────────
var _idle_time   : float = 0.0
var _hint_stage  : int   = 0
var _hint_tween  : Tween = null
var _force_hint  : bool  = false

# ── Autoplay ─────────────────────────────────────────────────────────────────
var _autoplay_active : bool = false

# ── Build-word phase ──────────────────────────────────────────────────────────
var _bw_phase         : String        = ""    # "word_listen"|"phoneme_listen"|"build"
var _bw_gen           : int           = 0     # guard against stale coroutines

# ── Build-word drag ───────────────────────────────────────────────────────────
var _bw_dragging        : bool    = false
var _bw_drag_ghost      : Panel   = null
var _bw_drag_phoneme    : String  = ""
var _bw_drag_choice_idx : int     = -1

# ── Identification phase ───────────────────────────────────────────────────────
var _id_phase         : String        = ""    # "image_listen"|"phoneme_listen"|"choose"
var _id_gen           : int           = 0
var _eval_btn         : TextureButton = null
var _cube_shake_tween : Tween         = null
var _eval_btn_tween   : Tween         = null

# ── Sound-count drag ─────────────────────────────────────────────────────────
var _sc_dragging      : bool    = false
var _sc_drag_cluster  : Panel   = null
var _sc_drag_offset   : Vector2 = Vector2.ZERO
var _sc_orig_pos      : Vector2 = Vector2.ZERO
var _sc_drop_target   : Panel   = null
var _sc_cluster_nodes : Array   = []
var _sc_cluster_orig  : Array   = []
var _sc_blink_tween   : Tween   = null
var _drag_pos         : Vector2 = Vector2.ZERO


# ════════════════════════════════════════════════════════════════════════════
# SETUP
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_bg.size         = get_viewport_rect().size
	_bg.position     = Vector2.ZERO
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color    = BG_COLOR

	_hand.visible = false
	_hand.scale   = Vector2(0.08, 0.08)

	_setup_img_buttons()
	_setup_count_buttons()
	_setup_back_button()
	_create_gnb_flag()
	_setup_eval_button()

	_load_data()
	_build_word_pool()
	_generate_rounds()
	_create_round_cubes()
	_start_round()


func _setup_img_buttons() -> void:
	for btn in [_img1, _img2, _img3]:
		btn.ignore_texture_size = true
		btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_img1.pressed.connect(_on_img_pressed.bind(0))
	_img2.pressed.connect(_on_img_pressed.bind(1))
	_img3.pressed.connect(_on_img_pressed.bind(2))


func _setup_count_buttons() -> void:
	for btn in [_count3_btn, _count4_btn, _count5_btn]:
		btn.text                = ""
		btn.custom_minimum_size = Vector2(COUNT_BTN_W, COUNT_BTN_H)
	_count3_btn.pressed.connect(_on_count_pressed.bind(3))
	_count4_btn.pressed.connect(_on_count_pressed.bind(4))
	_count5_btn.pressed.connect(_on_count_pressed.bind(5))

	# Position the 3 count buttons centred on screen
	var total_w : float = COUNT_BTN_W * 3.0 + COUNT_BTN_GAP * 2.0
	var start_x : float = (CANVAS_W - total_w) / 2.0
	_count3_btn.position = Vector2(start_x, 0.0)
	_count4_btn.position = Vector2(start_x + COUNT_BTN_W + COUNT_BTN_GAP, 0.0)
	_count5_btn.position = Vector2(start_x + (COUNT_BTN_W + COUNT_BTN_GAP) * 2.0, 0.0)
	_count_area.visible  = false

	# Cube visuals — N filled cubes on each button instead of a number
	_add_count_cubes(_count3_btn, 3)
	_add_count_cubes(_count4_btn, 4)
	_add_count_cubes(_count5_btn, 5)


func _add_count_cubes(btn: Button, count: int) -> void:
	const SZ  : float = 28.0   # mini cube side length
	const GAP : float =  6.0   # gap between cubes
	var total_w : float = count * SZ + (count - 1) * GAP
	var x0      : float = (COUNT_BTN_W - total_w) / 2.0
	var y0      : float = (COUNT_BTN_H - SZ)      / 2.0

	for i in range(count):
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(SZ, SZ)
		panel.size                = Vector2(SZ, SZ)
		panel.position            = Vector2(x0 + i * (SZ + GAP), y0)
		panel.mouse_filter        = Control.MOUSE_FILTER_IGNORE

		var style := StyleBoxFlat.new()
		style.bg_color                   = CUBE_FILLED
		style.border_color               = CUBE_BORDER
		style.border_width_left          = int(CUBE_BORDER_W)
		style.border_width_right         = int(CUBE_BORDER_W)
		style.border_width_top           = int(CUBE_BORDER_W)
		style.border_width_bottom        = int(CUBE_BORDER_W)
		style.corner_radius_top_left     = int(CUBE_CORNER / 2)
		style.corner_radius_top_right    = int(CUBE_CORNER / 2)
		style.corner_radius_bottom_left  = int(CUBE_CORNER / 2)
		style.corner_radius_bottom_right = int(CUBE_CORNER / 2)
		panel.add_theme_stylebox_override("panel", style)
		btn.add_child(panel)


func _setup_back_button() -> void:
	_back_btn = TextureButton.new()
	_back_btn.texture_normal      = load(BACK_BTN_TEX) as Texture2D
	_back_btn.ignore_texture_size = true
	_back_btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_back_btn.custom_minimum_size = Vector2(150.0, 150.0)
	_back_btn.size                = Vector2(150.0, 150.0)
	_back_btn.position            = Vector2(20.0, 20.0)
	_back_btn.z_index             = 10
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)


func _setup_eval_button() -> void:
	_eval_btn = TextureButton.new()
	_eval_btn.texture_normal      = load(EVAL_BTN_TEX) as Texture2D
	_eval_btn.ignore_texture_size = true
	_eval_btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_eval_btn.custom_minimum_size = Vector2(150.0, 75.0)
	_eval_btn.size                = Vector2(150.0, 75.0)
	_eval_btn.pivot_offset        = Vector2(75.0, 37.5)   # centre for scale animation
	_eval_btn.z_index             = 10
	_eval_btn.visible             = false
	_eval_btn.pressed.connect(_on_eval_play_pressed)
	add_child(_eval_btn)


# ── Idle hint system ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Move dragged cluster with finger/cursor
	if _sc_dragging and _sc_drag_cluster != null:
		_sc_drag_cluster.position = _drag_pos + _sc_drag_offset

	# Idle hint — disabled during any managed phase (hand is controlled by phase logic)
	if _bw_phase != "" or _id_phase != "":
		return
	if _result_locked or _autoplay_active:
		_idle_time = 0.0
		return
	if _force_hint and _hint_stage == 0:
		_force_hint = false
		_idle_time  = 0.0
	elif _hint_stage >= 1:
		return
	else:
		_idle_time += delta
		if _idle_time < HINT_IDLE_SEC:
			return
		_idle_time = 0.0
	if _hint_stage == 0:
		_hint_stage            = 1
		_hand.modulate.a       = 1.0
		_hand.visible          = true
		_hand.position         = Vector2(1050.0, 280.0)
		_hand.rotation_degrees = -30.0
		_hint_tween = create_tween()
		_hint_tween.tween_interval(2.0)
		_hint_tween.tween_property(_hand, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
		_hint_tween.tween_callback(func(): _hand.visible = false; _hand.modulate.a = 1.0; _hint_tween = null)


func _reset_idle() -> void:
	_idle_time = 0.0
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null
	if _bw_phase == "" and _id_phase == "":
		_hand.visible    = false
		_hand.modulate.a = 1.0


func _input(event: InputEvent) -> void:
	# ─ Motion/drag: update ghost or sc drag position ─
	if event is InputEventMouseMotion:
		var pos := (event as InputEventMouseMotion).position
		if _sc_dragging:
			_drag_pos = pos
		if _bw_dragging:
			_bw_update_drag(pos)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var pos := (event as InputEventScreenDrag).position
		if _sc_dragging:
			_drag_pos = pos
		if _bw_dragging:
			_bw_update_drag(pos)
			get_viewport().set_input_as_handled()
		return

	# ─ Build-word drag: press / release ─
	if _bw_phase == "build" and not _result_locked:
		var pos      : Vector2 = Vector2.ZERO
		var pressed  : bool    = false
		var released : bool    = false
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				pos      = mb.position
				pressed  = mb.pressed
				released = not mb.pressed
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			pos      = st.position
			pressed  = st.pressed
			released = not st.pressed
		if pressed and _bw_try_start_drag(pos):
			get_viewport().set_input_as_handled()
			return
		if released and _bw_dragging:
			_bw_end_drag(pos)
			get_viewport().set_input_as_handled()
			return

	# ─ Sound-count drag ─
	if _result_locked or _current_round.get("mode", "") != "sound_count":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_sc_try_start_drag(mb.position)
			elif _sc_dragging:
				_drag_pos = mb.position
				_sc_end_drag.call_deferred()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_sc_try_start_drag(st.position)
		elif _sc_dragging:
			_drag_pos = st.position
			_sc_end_drag.call_deferred()


# ════════════════════════════════════════════════════════════════════════════
# DATA LOADING
# ════════════════════════════════════════════════════════════════════════════

func _load_data() -> void:
	var f : FileAccess

	f = FileAccess.open(Level15Progress.current_set(), FileAccess.READ)
	_set_def = JSON.parse_string(f.get_as_text())
	f.close()

	f = FileAccess.open(WORDS_PATH, FileAccess.READ)
	_all_words = (JSON.parse_string(f.get_as_text()) as Dictionary)["words"]
	f.close()

	f = FileAccess.open(PHONEMES_PATH, FileAccess.READ)
	_phoneme_data = (JSON.parse_string(f.get_as_text()) as Dictionary)["phonemes"]
	f.close()


func _build_word_pool() -> void:
	var allowed : Array = _set_def.get("allowed_structures", ["CVC"])
	for key : String in _all_words:
		if _all_words[key]["structure"] in allowed:
			_word_pool.append(key)
	_word_pool.shuffle()


# ════════════════════════════════════════════════════════════════════════════
# ROUND GENERATION
# ════════════════════════════════════════════════════════════════════════════

func _generate_rounds() -> void:
	var mode : String = _set_def.get("mode", "")
	match mode:
		"initial_identification": _gen_identification("initial")
		"final_identification":   _gen_identification("final")
		"initial_isolation":      _gen_isolation("initial")
		"final_isolation":        _gen_isolation("final")
		"build_word":             _gen_build_word()
		"sound_count":            _gen_sound_count()
	_total_set_rounds = _rounds.size()

	if Level15Progress.is_retry and Level15Progress.retry_rounds.size() > 0:
		_rounds = Level15Progress.retry_rounds.duplicate()
		Level15Progress.is_retry = false
		Level15Progress.retry_rounds.clear()


# ── Identification: 3 images share a common initial/final phoneme ──────────

func _gen_identification(position: String) -> void:
	var round_count   : int = _set_def.get("rounds", 15)
	var choices_count : int = _set_def.get("choices_count", 3)

	# Group word pool by target phoneme
	var groups : Dictionary = {}
	for key : String in _word_pool:
		var ph : String = _all_words[key][position]
		if not groups.has(ph):
			groups[ph] = []
		groups[ph].append(key)

	# Keep only groups with enough words to form a round
	var valid_phs : Array = []
	for ph : String in groups:
		if groups[ph].size() >= 3:
			valid_phs.append(ph)

	if valid_phs.is_empty():
		push_error("game15: no valid phoneme groups for %s_identification" % position)
		return

	var queue : Array = valid_phs.duplicate()
	queue.shuffle()

	for _i in range(round_count):
		if queue.is_empty():
			queue = valid_phs.duplicate()
			queue.shuffle()

		var target_ph : String = queue.pop_back()

		var word_sample : Array = groups[target_ph].duplicate()
		word_sample.shuffle()
		word_sample = word_sample.slice(0, 3)

		var others : Array = valid_phs.filter(func(p): return p != target_ph)
		others.shuffle()
		var distractors : Array = others.slice(0, choices_count - 1)

		var choices : Array = [target_ph] + distractors
		choices.shuffle()

		_rounds.append({
			"mode":           _set_def["mode"],
			"words":          word_sample,
			"answer_phoneme": target_ph,
			"choices":        choices,
			"position":       position,
		})


# ── Isolation: 1 image, find initial or final phoneme ─────────────────────

func _gen_isolation(position: String) -> void:
	var round_count   : int = _set_def.get("rounds", 15)
	var choices_count : int = _set_def.get("choices_count", 3)

	var all_consonants : Array = []
	for ph_id : String in _phoneme_data:
		if _phoneme_data[ph_id]["type"] == "consonant":
			all_consonants.append(ph_id)

	var pool : Array = _word_pool.duplicate()
	pool.shuffle()

	for i in range(round_count):
		var word_key  : String     = pool[i % pool.size()]
		var word      : Dictionary = _all_words[word_key]
		var answer    : String     = word[position]
		var word_phs  : Array      = word["phonemes"]

		var available : Array = all_consonants.filter(func(p): return p not in word_phs)
		available.shuffle()
		var distractors : Array = available.slice(0, choices_count - 1)

		var choices : Array = [answer] + distractors
		choices.shuffle()

		_rounds.append({
			"mode":           _set_def["mode"],
			"word":           word_key,
			"answer_phoneme": answer,
			"choices":        choices,
			"position":       position,
		})


# ── Build the Word: tap all phonemes in order ──────────────────────────────

func _gen_build_word() -> void:
	var round_count    : int = _set_def.get("rounds", 20)
	var distractor_cnt : int = _set_def.get("distractor_count", 1)

	var all_ph_ids : Array = _phoneme_data.keys()
	var pool       : Array = _word_pool.duplicate()
	pool.shuffle()

	for i in range(round_count):
		var word_key : String     = pool[i % pool.size()]
		var word     : Dictionary = _all_words[word_key]
		var phonemes : Array      = word["phonemes"]

		var available : Array = all_ph_ids.filter(func(p): return p not in phonemes)
		available.shuffle()
		var distractors : Array = available.slice(0, distractor_cnt)

		var choices : Array = phonemes.duplicate() + distractors
		choices.shuffle()

		_rounds.append({
			"mode":     "build_word",
			"word":     word_key,
			"phonemes": phonemes,
			"choices":  choices,
		})


# ── Sound Count: how many phonemes does this word have? ────────────────────

func _gen_sound_count() -> void:
	var round_count : int   = _set_def.get("rounds", 20)
	var pool        : Array = _word_pool.duplicate()
	pool.shuffle()

	for i in range(round_count):
		var word_key : String = pool[i % pool.size()]
		var phonemes : Array  = _all_words[word_key]["phonemes"]

		_rounds.append({
			"mode":         "sound_count",
			"word":         word_key,
			"answer_count": phonemes.size(),
		})


# ════════════════════════════════════════════════════════════════════════════
# ROUND START
# ════════════════════════════════════════════════════════════════════════════

func _start_round() -> void:
	if _round_index >= _rounds.size():
		_do_set_complete()
		return

	_current_round   = _rounds[_round_index]
	_result_locked   = false
	_round_hint_used = false
	_build_index     = 0
	_autoplay_active = false
	_idle_time       = 0.0
	_hint_stage      = 0
	_hand.visible    = false

	# Reset build-word phase state
	_bw_phase        = ""
	# Reset identification phase state
	_id_phase        = ""
	# Reset sound-count drag
	_sc_dragging     = false
	_sc_drag_cluster = null
	if _eval_btn != null:
		if _eval_btn_tween != null:
			_eval_btn_tween.kill()
			_eval_btn_tween  = null
		_eval_btn.scale      = Vector2(1.0, 1.0)
		_eval_btn.position.y = 355.0
		_eval_btn.visible    = false

	_clear_dynamic_nodes()
	_count_area.visible = false

	var mode : String = _current_round["mode"]
	match mode:
		"initial_identification", "final_identification": _setup_identification()
		"initial_isolation",      "final_isolation":      _setup_isolation()
		"build_word":                                     _setup_build_word()
		"sound_count":                                    _setup_sound_count()


func _clear_dynamic_nodes() -> void:
	_bw_cancel_drag()
	if _cube_shake_tween != null:
		_cube_shake_tween.kill()
		_cube_shake_tween = null
	for c in _cube_row.get_children():
		c.queue_free()
	for c in _choice_row.get_children():
		c.queue_free()
	_cube_nodes.clear()
	_choice_nodes.clear()
	if _sc_blink_tween != null:
		_sc_blink_tween.kill()
		_sc_blink_tween = null
	if _sc_drop_target != null:
		_sc_drop_target.queue_free()
		_sc_drop_target = null
	for c in _sc_cluster_nodes:
		if is_instance_valid(c):
			c.queue_free()
	_sc_cluster_nodes.clear()
	_sc_cluster_orig.clear()
	_sc_dragging     = false
	_sc_drag_cluster = null


# ── Identification layout ──────────────────────────────────────────────────

func _setup_identification() -> void:
	var rd       : Dictionary = _current_round
	var words    : Array      = rd["words"]      # 3 word keys
	var position : String     = rd["position"]   # "initial" or "final"

	_id_phase = "image_listen"
	_id_gen  += 1

	var img_btns := [_img1, _img2, _img3]
	for i in range(3):
		var btn       : TextureButton = img_btns[i]
		var word_data : Dictionary    = _all_words[words[i]]
		btn.texture_normal      = load(word_data["image"]) as Texture2D
		btn.custom_minimum_size = Vector2(IMG_SZ_TRIPLE, IMG_SZ_TRIPLE)
		btn.size                = Vector2(IMG_SZ_TRIPLE, IMG_SZ_TRIPLE)
		btn.pivot_offset        = Vector2(IMG_SZ_TRIPLE / 2.0, IMG_SZ_TRIPLE / 2.0)
		btn.position            = IMG_CENTERS_TRIPLE[i] - Vector2(IMG_SZ_TRIPLE, IMG_SZ_TRIPLE) / 2.0
		btn.visible             = true

	var n_cubes      : int = 3
	var highlight_idx : int = 0 if position == "initial" else n_cubes - 1
	_create_cubes(n_cubes, [highlight_idx])

	_create_choices(rd["choices"])

	_eval_btn.position = Vector2(1050.0, 355.0)
	_eval_btn.visible  = false

	_id_image_listen_walk(words, _id_gen)


func _id_image_listen_walk(words: Array, gen: int) -> void:
	_hand.position         = Vector2(1050.0, 280.0)
	_hand.rotation_degrees = -30.0
	_hand.visible          = true
	var img_btns : Array = [_img1, _img2, _img3]
	for i in range(words.size()):
		if _id_phase != "image_listen" or _id_gen != gen:
			return
		var btn     : TextureButton = img_btns[i]
		var pulse_t : Tween         = create_tween().set_loops()
		pulse_t.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_SINE)
		pulse_t.tween_property(btn, "scale", Vector2(1.0,  1.0),  0.18).set_trans(Tween.TRANS_SINE)
		_play_word(words[i])
		await _word_player.finished
		pulse_t.kill()
		btn.scale = Vector2(1.0, 1.0)
		if i < words.size() - 1:
			await get_tree().create_timer(0.3).timeout
	if _id_phase != "image_listen" or _id_gen != gen:
		return
	_hand.visible     = false
	_eval_btn.visible = true
	_start_eval_pulse()
	_id_phase = "phoneme_listen"
	_id_guided_phoneme_walk(_id_gen)


func _id_guided_phoneme_walk(gen: int) -> void:
	var phonemes : Array = _current_round["choices"]
	_hand.rotation_degrees = 180.0
	_hand.visible          = true
	for i in range(phonemes.size()):
		if _id_phase != "phoneme_listen" or _id_gen != gen:
			return
		var btn         : TextureButton = _choice_nodes[i]
		var tile_center : Vector2       = _choice_row.position + btn.position + btn.size / 2.0
		var target_pos  : Vector2       = Vector2(tile_center.x, tile_center.y - 90.0)
		if i == 0:
			_hand.position = target_pos
		else:
			var t := create_tween()
			t.tween_property(_hand, "position", target_pos, 0.18).set_trans(Tween.TRANS_SINE)
			await t.finished
		if _id_phase != "phoneme_listen" or _id_gen != gen:
			return
		_play_phoneme(phonemes[i])
		await _phoneme_player.finished
		if i < phonemes.size() - 1:
			await get_tree().create_timer(0.2).timeout
	if _id_phase == "phoneme_listen" and _id_gen == gen:
		_hand.visible = false
		if _eval_btn_tween != null:
			_eval_btn_tween.kill()
			_eval_btn_tween = null
		_eval_btn.scale   = Vector2(1.0, 1.0)
		_eval_btn.visible = false
		_id_phase         = "choose"


# ── Isolation layout ───────────────────────────────────────────────────────

func _setup_isolation() -> void:
	var rd       : Dictionary = _current_round
	var word_key : String     = rd["word"]
	var position : String     = rd["position"]
	var word     : Dictionary = _all_words[word_key]

	_id_phase = "image_listen"
	_id_gen  += 1

	_show_single_image(word["image"])

	var n_cubes      : int = word["phonemes"].size()
	var highlight_idx : int = 0 if position == "initial" else n_cubes - 1
	_create_cubes(n_cubes, [highlight_idx])

	_create_choices(rd["choices"])

	_eval_btn.position = Vector2(1050.0, 355.0)
	_eval_btn.visible  = false

	_iso_word_listen(word_key, _id_gen)


func _iso_word_listen(word_key: String, gen: int) -> void:
	_hand.position         = Vector2(1050.0, 280.0)
	_hand.rotation_degrees = -30.0
	_hand.visible          = true
	if _id_phase != "image_listen" or _id_gen != gen:
		return
	_play_word(word_key)
	await _word_player.finished
	if _id_phase != "image_listen" or _id_gen != gen:
		return
	_hand.visible     = false
	_eval_btn.visible = true
	_start_eval_pulse()
	_id_phase = "phoneme_listen"
	_id_guided_phoneme_walk(_id_gen)


# ── Build the Word layout ──────────────────────────────────────────────────

func _setup_build_word() -> void:
	var rd       : Dictionary = _current_round
	var word_key : String     = rd["word"]
	var word     : Dictionary = _all_words[word_key]

	_bw_phase = "word_listen"
	_bw_gen  += 1

	_show_single_image(word["image"])

	var n_cubes : int = rd["phonemes"].size()
	_create_cubes(n_cubes, [0])
	_create_choices(rd["choices"])

	_eval_btn.position = Vector2(1050.0, 355.0)
	_eval_btn.visible  = false

	# PointedHand → word image, tilted 30° counterclockwise toward image
	_hand.visible          = true
	_hand.position         = Vector2(1050.0, 280.0)
	_hand.rotation_degrees = -30.0

	_play_word_then_show_eval(word_key, _bw_gen)


func _play_word_then_show_eval(word_key: String, gen: int) -> void:
	_play_word(word_key)
	await _word_player.finished
	if _bw_phase != "word_listen" or _bw_gen != gen:
		return
	await get_tree().create_timer(EVAL_DELAY).timeout
	if _bw_phase == "word_listen" and _bw_gen == gen:
		_eval_btn.visible = true
		_start_eval_pulse()
		_bw_phase = "phoneme_listen"
		_guided_phoneme_walk(_bw_gen)


func _start_eval_pulse() -> void:
	if _eval_btn_tween != null:
		_eval_btn_tween.kill()
	var orig_y : float = _eval_btn.position.y
	_eval_btn.scale      = Vector2(1.0, 1.0)
	_eval_btn.position.y = orig_y
	_eval_btn_tween = create_tween().set_loops()
	# Float up + grow
	_eval_btn_tween.tween_property(_eval_btn, "scale", Vector2(1.18, 1.18), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_eval_btn_tween.parallel().tween_property(_eval_btn, "position:y", orig_y - 8.0, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Settle back down
	_eval_btn_tween.tween_property(_eval_btn, "scale", Vector2(1.0, 1.0), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_eval_btn_tween.parallel().tween_property(_eval_btn, "position:y", orig_y, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ── Sound Count layout ─────────────────────────────────────────────────────

func _setup_sound_count() -> void:
	var rd       : Dictionary = _current_round
	var word_key : String     = rd["word"]

	_show_single_image(_all_words[word_key]["image"])
	_cube_row.visible   = false
	_choice_row.visible = false
	_count_area.visible = false

	_sc_drop_target = _create_sc_drop_target()
	_sc_drop_target.visible = false
	_create_sc_clusters()

	_sc_word_listen(word_key, _round_index)


func _sc_word_listen(word_key: String, round_idx: int) -> void:
	_play_word(word_key)
	await _word_player.finished
	if _round_index != round_idx:
		return

	_sc_drop_target.visible = true
	_sc_blink_target(_sc_drop_target)
	for cluster in _sc_cluster_nodes:
		cluster.visible = true

	_hint_stage      = 1
	_hand.modulate.a = 1.0
	_hand.visible    = true
	_hand.position         = Vector2(1050.0, 280.0)
	_hand.rotation_degrees = -30.0
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(2.0)
	_hint_tween.tween_property(_hand, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_callback(func(): _hand.visible = false; _hand.modulate.a = 1.0; _hint_tween = null)


func _create_sc_drop_target() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(SC_DROP_W, SC_DROP_H)
	panel.size                = Vector2(SC_DROP_W, SC_DROP_H)
	panel.position            = Vector2((CANVAS_W - SC_DROP_W) / 2.0, SC_DROP_Y)
	panel.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color                   = CUBE_EMPTY
	style.border_color               = CUBE_BORDER
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
	return panel


func _sc_blink_target(panel: Panel) -> void:
	_sc_blink_tween = create_tween().set_loops()
	_sc_blink_tween.tween_property(panel, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
	_sc_blink_tween.tween_property(panel, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


func _create_sc_clusters() -> void:
	_sc_cluster_nodes.clear()
	_sc_cluster_orig.clear()
	var counts : Array = [3, 4, 5]
	for i in range(3):
		var count   : int   = counts[i]
		var total_w : float = count * SC_CUBE_SIZE
		var center_x : float = 640.0 + (i - 1) * SC_CLUSTER_SPACING
		var pos      : Vector2 = Vector2(center_x - total_w / 2.0, SC_CLUSTER_Y)

		var cluster := Panel.new()
		cluster.custom_minimum_size = Vector2(total_w, SC_CUBE_SIZE)
		cluster.size                = Vector2(total_w, SC_CUBE_SIZE)
		cluster.position            = pos
		cluster.pivot_offset        = Vector2(total_w / 2.0, SC_CUBE_SIZE / 2.0)
		cluster.mouse_filter        = Control.MOUSE_FILTER_IGNORE

		var bg := StyleBoxFlat.new()
		bg.bg_color = Color.TRANSPARENT
		cluster.add_theme_stylebox_override("panel", bg)

		for j in range(count):
			var cube := _make_sc_cube()
			cube.position = Vector2(j * SC_CUBE_SIZE, 0.0)
			cluster.add_child(cube)

		add_child(cluster)
		_sc_cluster_nodes.append(cluster)
		_sc_cluster_orig.append(pos)


func _make_sc_cube() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(SC_CUBE_SIZE, SC_CUBE_SIZE)
	panel.size                = Vector2(SC_CUBE_SIZE, SC_CUBE_SIZE)
	panel.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color                   = CUBE_EMPTY
	style.border_color               = CUBE_BORDER
	style.border_width_left          = int(CUBE_BORDER_W)
	style.border_width_right         = int(CUBE_BORDER_W)
	style.border_width_top           = int(CUBE_BORDER_W)
	style.border_width_bottom        = int(CUBE_BORDER_W)
	style.corner_radius_top_left     = int(CUBE_CORNER)
	style.corner_radius_top_right    = int(CUBE_CORNER)
	style.corner_radius_bottom_left  = int(CUBE_CORNER)
	style.corner_radius_bottom_right = int(CUBE_CORNER)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _sc_try_start_drag(pos: Vector2) -> void:
	if _sc_dragging:
		return
	for i in range(_sc_cluster_nodes.size()):
		var cluster : Panel = _sc_cluster_nodes[i]
		if not cluster.visible:
			continue
		if Rect2(cluster.position, cluster.size).has_point(pos):
			_sc_dragging     = true
			_sc_drag_cluster = cluster
			_sc_drag_offset  = cluster.position - pos
			_sc_orig_pos     = cluster.position
			_drag_pos        = pos
			return


func _sc_end_drag() -> void:
	if not _sc_dragging:
		return
	_sc_dragging = false
	var cluster : Panel = _sc_drag_cluster
	_sc_drag_cluster = null
	if cluster == null or not is_instance_valid(cluster):
		return

	if _sc_drop_target != null and _sc_drop_target.visible:
		var cluster_center : Vector2 = cluster.position + cluster.size / 2.0
		if Rect2(_sc_drop_target.position, _sc_drop_target.size).has_point(cluster_center):
			_handle_sc_drop(cluster.get_child_count(), cluster)
			return

	var t := create_tween()
	t.tween_property(cluster, "position", _sc_orig_pos, 0.3).set_trans(Tween.TRANS_SINE)


func _handle_sc_drop(count: int, cluster: Panel) -> void:
	if _result_locked:
		return
	_result_locked = true

	if count == _current_round["answer_count"]:
		if _sc_blink_tween != null:
			_sc_blink_tween.kill()
			_sc_blink_tween = null
		if _sc_drop_target != null:
			_sc_drop_target.modulate.a = 1.0
			var snap := create_tween()
			snap.tween_property(cluster, "position",
				_sc_drop_target.position + (_sc_drop_target.size - cluster.size) / 2.0, 0.15)
			await snap.finished
			# cluster fades into rectangle; rectangle flashes filled then settles
			var merge := create_tween()
			merge.tween_property(cluster, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
			_set_panel_color(_sc_drop_target, CUBE_FILLED)
			var settle := create_tween()
			settle.tween_interval(0.2)
			settle.tween_callback(func(): _set_panel_color(_sc_drop_target, CUBE_EMPTY))
		_tally_round()
		_correct_snd.play()
		_blend_round_cube()
		await _correct_snd.finished
		await get_tree().create_timer(0.4).timeout
		_advance_round()
	else:
		_round_hint_used = true
		_result_locked   = false
		var orig_x : float = cluster.position.x
		var shake := create_tween()
		shake.tween_property(cluster, "position:x", orig_x + 14.0, 0.05)
		shake.tween_property(cluster, "position:x", orig_x - 14.0, 0.05)
		shake.tween_property(cluster, "position:x", orig_x +  8.0, 0.04)
		shake.tween_property(cluster, "position:x", orig_x -  8.0, 0.04)
		shake.tween_property(cluster, "position:x", orig_x,        0.03)
		_oops_snd.play()
		await shake.finished
		await _oops_snd.finished
		_wrong_snd.play()
		await _wrong_snd.finished
		await get_tree().create_timer(0.8).timeout
		_clear_dynamic_nodes()
		_hint_stage = 0
		_setup_sound_count()


func _set_panel_color(panel: Panel, col: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = col
	style.border_color               = CUBE_BORDER
	style.border_width_left          = int(CUBE_BORDER_W)
	style.border_width_right         = int(CUBE_BORDER_W)
	style.border_width_top           = int(CUBE_BORDER_W)
	style.border_width_bottom        = int(CUBE_BORDER_W)
	style.corner_radius_top_left     = int(CUBE_CORNER)
	style.corner_radius_top_right    = int(CUBE_CORNER)
	style.corner_radius_bottom_left  = int(CUBE_CORNER)
	style.corner_radius_bottom_right = int(CUBE_CORNER)
	panel.add_theme_stylebox_override("panel", style)


# ════════════════════════════════════════════════════════════════════════════
# DYNAMIC NODE CREATION
# ════════════════════════════════════════════════════════════════════════════

func _show_single_image(image_path: String) -> void:
	_img1.texture_normal      = load(image_path) as Texture2D
	_img1.custom_minimum_size = Vector2(IMG_SZ_SINGLE, IMG_SZ_SINGLE)
	_img1.size                = Vector2(IMG_SZ_SINGLE, IMG_SZ_SINGLE)
	_img1.position            = Vector2((CANVAS_W - IMG_SZ_SINGLE) / 2.0, IMG_Y_SINGLE)
	_img1.visible             = true
	_img2.visible             = false
	_img3.visible             = false


func _create_cubes(count: int, highlighted: Array) -> void:
	_cube_row.visible = true
	var total_w  : float = count * CUBE_SIZE + (count - 1) * CUBE_GAP
	var start_x  : float = (CANVAS_W - total_w) / 2.0

	for i in range(count):
		var is_hi : bool = i in highlighted
		var panel := _make_cube_panel(is_hi)
		panel.position = Vector2(start_x + i * (CUBE_SIZE + CUBE_GAP), 0.0)
		_cube_row.add_child(panel)
		_cube_nodes.append(panel)

		if is_hi:
			_cube_shake_tween = _shake_node(panel)


func _make_cube_panel(highlighted: bool) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(CUBE_SIZE, CUBE_SIZE)
	panel.size                = Vector2(CUBE_SIZE, CUBE_SIZE)

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
	return panel


func _fill_cube(idx: int) -> void:
	if idx >= _cube_nodes.size():
		return
	if _cube_shake_tween != null:
		_cube_shake_tween.kill()
		_cube_shake_tween = null
	var panel : Panel = _cube_nodes[idx]
	panel.position.y  = 0.0   # reset any y drift from shake
	var style := StyleBoxFlat.new()
	style.bg_color                   = CUBE_FILLED
	style.corner_radius_top_left     = int(CUBE_CORNER)
	style.corner_radius_top_right    = int(CUBE_CORNER)
	style.corner_radius_bottom_left  = int(CUBE_CORNER)
	style.corner_radius_bottom_right = int(CUBE_CORNER)
	panel.add_theme_stylebox_override("panel", style)


func _highlight_next_cube() -> void:
	if _build_index >= _cube_nodes.size():
		return
	if _cube_shake_tween != null:
		_cube_shake_tween.kill()
		_cube_shake_tween = null
	var panel : Panel        = _cube_nodes[_build_index]
	panel.position.y         = 0.0   # reset any drift
	var style : StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color        = CUBE_BORDER
	style.border_width_left   = int(CUBE_BORDER_W)
	style.border_width_right  = int(CUBE_BORDER_W)
	style.border_width_top    = int(CUBE_BORDER_W)
	style.border_width_bottom = int(CUBE_BORDER_W)
	panel.add_theme_stylebox_override("panel", style)
	_cube_shake_tween = _shake_node(panel)


func _create_choices(phoneme_ids: Array) -> void:
	_choice_row.visible = true
	var open_hand_tex := load(OPEN_HAND_TEX) as Texture2D
	var n : int        = phoneme_ids.size()
	var total_w : float = n * CHOICE_SIZE + (n - 1) * CHOICE_GAP
	var start_x : float = (CANVAS_W - total_w) / 2.0

	for i in range(n):
		var btn := TextureButton.new()
		btn.texture_normal        = open_hand_tex
		btn.modulate              = OPEN_HAND_COLOR
		btn.ignore_texture_size   = true
		btn.stretch_mode          = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size   = Vector2(CHOICE_SIZE, CHOICE_SIZE)
		btn.size                  = Vector2(CHOICE_SIZE, CHOICE_SIZE)
		btn.position              = Vector2(start_x + i * (CHOICE_SIZE + CHOICE_GAP), 0.0)
		btn.pivot_offset          = Vector2(CHOICE_SIZE / 2.0, CHOICE_SIZE / 2.0)

		var ph_id : String = phoneme_ids[i]
		btn.pressed.connect(_on_choice_pressed.bind(ph_id, i))

		_choice_row.add_child(btn)
		_choice_nodes.append(btn)


# ── Build-word drag helpers ───────────────────────────────────────────────────

func _bw_try_start_drag(pos: Vector2) -> bool:
	for i in range(_choice_nodes.size()):
		var btn       : TextureButton = _choice_nodes[i]
		var tile_rect := Rect2(_choice_row.position + btn.position, btn.size)
		if tile_rect.has_point(pos):
			_bw_drag_choice_idx = i
			_bw_drag_phoneme    = _current_round["choices"][i]
			_bw_dragging        = true
			_play_phoneme(_bw_drag_phoneme)
			btn.modulate.a = 0.35
			_bw_create_ghost(pos)
			return true
	return false


func _bw_create_ghost(pos: Vector2) -> void:
	var ghost := Panel.new()
	ghost.size         = Vector2(CHOICE_SIZE, CHOICE_SIZE)
	ghost.position     = pos - Vector2(CHOICE_SIZE * 0.5, CHOICE_SIZE * 0.5)
	ghost.z_index      = 20
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	ghost.add_theme_stylebox_override("panel", style)
	var tr := TextureRect.new()
	tr.texture      = load(OPEN_HAND_TEX) as Texture2D
	tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size         = Vector2(CHOICE_SIZE, CHOICE_SIZE)
	tr.position     = Vector2.ZERO
	tr.modulate     = OPEN_HAND_COLOR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(tr)
	add_child(ghost)
	_bw_drag_ghost = ghost


func _bw_update_drag(pos: Vector2) -> void:
	if _bw_drag_ghost != null:
		_bw_drag_ghost.position = pos - Vector2(CHOICE_SIZE * 0.5, CHOICE_SIZE * 0.5)


func _bw_end_drag(pos: Vector2) -> void:
	if not _bw_dragging:
		return
	_bw_dragging = false
	if _bw_drag_ghost != null:
		_bw_drag_ghost.queue_free()
		_bw_drag_ghost = null
	if _bw_drag_choice_idx >= 0 and _bw_drag_choice_idx < _choice_nodes.size():
		_choice_nodes[_bw_drag_choice_idx].modulate.a = 1.0

	# Check if dropped on the currently blinking cube
	if _build_index < _cube_nodes.size():
		var cube      : Panel   = _cube_nodes[_build_index]
		var cube_rect := Rect2(_cube_row.position + cube.position, cube.size)
		if cube_rect.has_point(pos):
			var ph := _bw_drag_phoneme
			_bw_drag_phoneme    = ""
			_bw_drag_choice_idx = -1
			_handle_build_tap(ph)
			return

	_bw_drag_phoneme    = ""
	_bw_drag_choice_idx = -1


func _bw_cancel_drag() -> void:
	if not _bw_dragging:
		return
	_bw_dragging = false
	if _bw_drag_ghost != null:
		_bw_drag_ghost.queue_free()
		_bw_drag_ghost = null
	if _bw_drag_choice_idx >= 0 and _bw_drag_choice_idx < _choice_nodes.size():
		_choice_nodes[_bw_drag_choice_idx].modulate.a = 1.0
	_bw_drag_phoneme    = ""
	_bw_drag_choice_idx = -1


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


# ════════════════════════════════════════════════════════════════════════════
# AUDIO
# ════════════════════════════════════════════════════════════════════════════

func _play_word(word_key: String) -> void:
	var path : String = _all_words[word_key]["audio"]
	_word_player.stream = load(path)
	_word_player.play()


func _play_phoneme(phoneme_id: String) -> void:
	if not _phoneme_data.has(phoneme_id):
		return
	var ph : Dictionary = _phoneme_data[phoneme_id]
	if ph.get("missing", false):
		return   # ng.wav not yet recorded — silent fail
	_phoneme_player.stream = load(ph["audio"])
	_phoneme_player.play()


func _autoplay_word(word_key: String) -> void:
	_autoplay_active = true
	var count : int = _set_def.get("autoplay_count", 3)
	for i in range(count):
		if not _autoplay_active:
			return
		_play_word(word_key)
		await _word_player.finished
		if i < count - 1:
			await get_tree().create_timer(0.35).timeout
	_autoplay_active = false


# ════════════════════════════════════════════════════════════════════════════
# INTERACTION
# ════════════════════════════════════════════════════════════════════════════

func _on_img_pressed(idx: int) -> void:
	_reset_idle()
	var mode : String = _current_round.get("mode", "")
	if mode in ["initial_identification", "final_identification"]:
		var words : Array = _current_round.get("words", [])
		if idx < words.size():
			_play_word(words[idx])
	else:
		var word_key : String = _current_round.get("word", "")
		if word_key != "":
			_autoplay_active = false    # cancel ongoing autoplay
			_play_word(word_key)


func _on_choice_pressed(phoneme_id: String, idx: int) -> void:
	_reset_idle()
	# During guided phoneme walk the hand auto-plays each tile — ignore all taps
	if _bw_phase == "phoneme_listen" or _id_phase == "phoneme_listen":
		return
	# Always play the phoneme + tap animation (even if result locked)
	_play_phoneme(phoneme_id)
	_animate_tap(idx)

	if _result_locked:
		return

	var mode : String = _current_round.get("mode", "")
	match mode:
		"initial_identification", "final_identification", \
		"initial_isolation",      "final_isolation":
			if _eval_btn_tween != null:
				_eval_btn_tween.kill()
				_eval_btn_tween = null
			_eval_btn.scale   = Vector2(1.0, 1.0)
			_eval_btn.visible = false
			_handle_single_answer(phoneme_id, idx)
		"build_word":
			pass   # placement handled by drag in _input()


func _handle_single_answer(phoneme_id: String, idx: int) -> void:
	if phoneme_id == _current_round["answer_phoneme"]:
		_result_locked = true
		_tally_round()

		var mode      : String = _current_round["mode"]
		var cube_idx  : int    = 0 if "initial" in mode else _cube_nodes.size() - 1
		_fill_cube(cube_idx)

		_correct_snd.play()
		_blend_round_cube()
		await _correct_snd.finished
		await get_tree().create_timer(0.4).timeout
		_advance_round()
	else:
		_result_locked   = true
		_round_hint_used = true
		_animate_shake(idx)
		await _phoneme_player.finished   # let the tapped phoneme finish before oops
		_oops_snd.play()
		await _oops_snd.finished
		_wrong_snd.play()
		await _wrong_snd.finished
		_result_locked = false
		_force_hint    = true
		var mode : String = _current_round.get("mode", "")
		if mode in ["initial_identification", "final_identification"]:
			_clear_dynamic_nodes()
			_setup_identification()
		elif mode in ["initial_isolation", "final_isolation"]:
			_clear_dynamic_nodes()
			_setup_isolation()


# ── Build the Word: tap to fill ──────────────────────────────────────────────

func _on_eval_play_pressed() -> void:
	pass   # eval btn is visual only — auto-play triggered programmatically


func _handle_build_tap(ph_id: String) -> void:
	if _result_locked or _bw_phase != "build":
		return
	var expected : String = _current_round["phonemes"][_build_index]
	if ph_id == expected:
		_fill_cube(_build_index)
		_build_index += 1
		_correct_snd.play()
		if _build_index >= _current_round["phonemes"].size():
			_result_locked = true
			_hand.visible  = false
			_tally_round()
			_blend_round_cube()
			await _correct_snd.finished
			await get_tree().create_timer(0.6).timeout
			_advance_round()
		else:
			_highlight_next_cube()
	else:
		_result_locked   = true
		_round_hint_used = true
		_oops_snd.play()
		await _oops_snd.finished
		_wrong_snd.play()
		await _wrong_snd.finished
		_result_locked = false
		_force_hint    = true
		_reset_build_round()


func _guided_phoneme_walk(gen: int) -> void:
	var phonemes : Array = _current_round["choices"]
	_hand.rotation_degrees = 180.0
	_hand.visible          = true
	for i in range(phonemes.size()):
		if _bw_phase != "phoneme_listen" or _bw_gen != gen:
			return
		var btn         : TextureButton = _choice_nodes[i]
		var tile_center : Vector2       = _choice_row.position + btn.position + btn.size / 2.0
		var target_pos  : Vector2       = Vector2(tile_center.x, tile_center.y - 90.0)
		if i == 0:
			_hand.position = target_pos
		else:
			var t := create_tween()
			t.tween_property(_hand, "position", target_pos, 0.18).set_trans(Tween.TRANS_SINE)
			await t.finished
		if _bw_phase != "phoneme_listen" or _bw_gen != gen:
			return
		_play_phoneme(phonemes[i])
		await _phoneme_player.finished
		if i < phonemes.size() - 1:
			await get_tree().create_timer(0.2).timeout
	if _bw_phase == "phoneme_listen" and _bw_gen == gen:
		_hand.visible = false
		if _eval_btn_tween != null:
			_eval_btn_tween.kill()
			_eval_btn_tween = null
		_eval_btn.scale   = Vector2(1.0, 1.0)
		_eval_btn.visible = false
		_bw_phase = "build"


func _reset_build_round() -> void:
	_build_index     = 0
	_autoplay_active = false
	_clear_dynamic_nodes()
	_setup_build_word()


func _on_count_pressed(count: int) -> void:
	_reset_idle()
	if _result_locked:
		return

	if count == _current_round["answer_count"]:
		_result_locked = true
		_tally_round()
		_correct_snd.play()
		_blend_round_cube()
		await _correct_snd.finished
		await get_tree().create_timer(0.4).timeout
		_advance_round()
	else:
		_round_hint_used = true
		_oops_snd.play()
		await _oops_snd.finished
		_wrong_snd.play()
		await _wrong_snd.finished
		_clear_dynamic_nodes()
		_hint_stage = 0
		_setup_sound_count()


func _on_back_pressed() -> void:
	if _result_locked or _round_index == 0 or _back_uses >= BACK_USES_MAX:
		return
	_back_uses += 1
	if _back_uses >= BACK_USES_MAX:
		_back_btn.modulate.a = 0.35   # dim to signal disabled
	_autoplay_active = false
	_reset_idle()
	_round_index -= 1
	_start_round()


# ════════════════════════════════════════════════════════════════════════════
# ANIMATIONS
# ════════════════════════════════════════════════════════════════════════════

func _animate_tap(idx: int) -> void:
	if idx >= _choice_nodes.size():
		return
	var btn : TextureButton = _choice_nodes[idx]
	var t   := create_tween()
	t.tween_property(btn, "scale", Vector2(1.3, 1.3), 0.07).set_trans(Tween.TRANS_QUAD)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_QUAD)


func _animate_shake(idx: int) -> void:
	if idx >= _choice_nodes.size():
		return
	var btn   : TextureButton = _choice_nodes[idx]
	var orig_x : float         = btn.position.x
	var t      := create_tween()
	t.tween_property(btn, "position:x", orig_x + 12.0, 0.05)
	t.tween_property(btn, "position:x", orig_x - 12.0, 0.05)
	t.tween_property(btn, "position:x", orig_x +  7.0, 0.04)
	t.tween_property(btn, "position:x", orig_x -  7.0, 0.04)
	t.tween_property(btn, "position:x", orig_x,        0.03)


func _shake_node(node: Control) -> Tween:
	var orig_y : float = node.position.y
	var t := create_tween().set_loops()
	t.tween_property(node, "position:y", orig_y - 5.0, 0.22).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "position:y", orig_y,       0.22).set_trans(Tween.TRANS_SINE)
	return t


# ════════════════════════════════════════════════════════════════════════════
# ROUND FLOW
# ════════════════════════════════════════════════════════════════════════════

func _tally_round() -> void:
	if not _round_hint_used:
		_clean_correct += 1
	else:
		_assisted_rounds.append(_current_round.duplicate())


func _advance_round() -> void:
	_round_index += 1
	_cube_row.visible   = true
	_choice_row.visible = true
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
	if _round_index < _round_cubes.size():
		var t := create_tween()
		t.tween_property(_round_cubes[_round_index], "color", BG_COLOR, 0.8)


func _do_set_complete() -> void:
	_result_locked = true
	if ReviewState.active:
		ReviewState.active = false
		SaveManager.increment_review_count(ReviewState.set_key)
		get_tree().change_scene_to_file("res://gnb_where_am_i.tscn")
		return
	var score_pct : float = float(_clean_correct) / float(_rounds.size()) * 100.0
	Level15Progress.last_score_pct = score_pct
	Level15Progress.retry_rounds   = _assisted_rounds.duplicate()
	Level15Progress.active         = true
	get_tree().change_scene_to_file("res://transition.tscn")
