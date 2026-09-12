extends Node2D
class_name LevelTransition

# ─── Routing (set before changing to this scene) ──────────────────────────────
static var next_level_id : String = "level1"   # matches LevelIntroState.level_id
static var level_name    : String = "Level 1"

# ─── Debug ────────────────────────────────────────────────────────────────────
# Set true to skip all waits and test the scene instantly with F6.
# Set false before release.
const DEBUG_FAST : bool = false

# ─── Colors ───────────────────────────────────────────────────────────────────
const BG_COLOR     : Color = Color("#EDE4D3")
const GOLD_COLOR   : Color = Color("#FFB703")
const PURPLE_COLOR : Color = Color("#4B0083")

# ─── Face ─────────────────────────────────────────────────────────────────────
const FACE_SCALE  : float   = 0.90                  # matches Title Scene PlayButton scale
var FACE_CENTER : Vector2 = Vector2(640.0, 400.0) # shifted down 100px from title's FACE_CENTER_Y — see crown note below
                                                   # mobile-alignment fix: recentered in _ready()
const FACE_ABOVE_OFFSET : float = 700.0  # how far above FACE_CENTER the entrance descent starts

# ─── Crown ────────────────────────────────────────────────────────────────────
const CROWN_SCALE   : float = 0.291  # scaled with face: 0.189 × (0.90 / 0.585)
var CROWN_X       : float = 615.0   # mobile-alignment fix: recentered in _ready(), same as
									 # FACE_CENTER — must land directly above the (recentered)
									 # face, and this offset gets locked in permanently once
									 # the crown attaches to the crowned group (see _lock_crown_to_face)
const CROWN_START_Y : float = -300.0
# The crown PNG's visible art sits in the upper portion of its 2000x2000 canvas
# (lots of empty space below, since the white background is keyed out at
# runtime), so Sprite2D's texture-center pivot sits well below the actual
# crown graphic. At the original CROWN_LAND_Y=126 the crown was cropped by
# the top of the screen even at rest, and worse during the celebration
# bounce. Shifted the whole face+crown+label group down 100px to fix it.
const CROWN_LAND_Y  : float = 226.0
const CROWN_TILT    : float = 1.0     # slight clockwise tilt

# ─── Layout ───────────────────────────────────────────────────────────────────
# Shifted up from the original 615 — with two lines of text (see
# _setup_label_group()) the block sits noticeably lower, and the celebration
# bounce was bringing it uncomfortably close to the bottom screen edge.
const LEVEL1_Y      : float = 575.0
const LEVEL1_LINE1_FONT : int = 34   # "You made it!" — larger, the headline
const LEVEL1_LINE2_FONT : int = 22   # "Keep hopping!" — smaller, the follow-on

# ─── Music-aligned choreography timing ─────────────────────────────────────────
# Derived from a Librosa analysis of the Coronation BGM (onset/beat detection +
# chroma-based structural segmentation) on 2026-09-12. All times are seconds
# since the sequence starts (t=0 at scene entry). See ARTHUR_WORKLOG.md for the
# analysis this was approved against. Do not retime these ad hoc — they were
# matched against real musical accents, not chosen for visual convenience.
const T_DESCEND_END        : float = 5.0     # PlayButton finishes descending
const T_CROWN_LAND         : float = 12.0    # crown lands — 11.947s structural boundary
const T_BREATHE_END        : float = 16.2    # end of gentle breathing — real structural boundary
const T_SWAY_END           : float = 20.4    # end of gentle sway — real structural boundary
const T_PRE_LEFT_END       : float = 21.351  # settle out of sway, no forced bounce here
const GROUP_A : Array[float] = [21.351, 21.850, 22.349, 23.092, 23.348]   # bounce moving left
const GROUP_B : Array[float] = [24.346, 24.845, 25.345, 25.844, 26.355]   # bounce traversal left → right
const T_FINALE             : float = 27.098  # prominent finale bounce/accent — first step right
const T_FLOURISH_A         : float = 28.862  # paired flourish — treated as ONE continuous exit,
const T_FLOURISH_B         : float = 29.118  # not two bounces; lands mid-flight off the right edge

const LEFT_X_OFFSET : float = -220.0   # how far left of FACE_CENTER.x the character travels
const EXIT_DUR       : float = 1.338   # 28.862s -> ~30.2s, one continuous flight off-screen

# ─── State ────────────────────────────────────────────────────────────────────
var _face         : Sprite2D          = null
var _crown        : Sprite2D          = null
var _crowned_group : Node2D           = null   # created once the crown lands —
                                                 # from that point on, _face and
                                                 # _crown are reparented into this
                                                 # single container and ALWAYS
                                                 # animated as one rigid unit
                                                 # (position/rotation/scale on the
                                                 # group only, never on the two
                                                 # nodes independently)
var _label_group  : Node2D            = null   # kept separate and static — only
                                                 # the crowned face+crown unit
                                                 # moves after landing
var _music_player : AudioStreamPlayer = null
var _font         : Font              = null
var _gnb_btn      : Button            = null

var _seq_gen    : int  = 0      # bumped when Where Am I is pressed — lets any
                                 # in-flight await/tween in _play_sequence()
                                 # detect it's been superseded and bail out,
                                 # instead of later auto-advancing to Level Intro
var _audio_dead : bool = false  # set true once Where Am I is pressed — after
                                 # this, the Coronation BGM may not play again
                                 # for this scene instance (see _safe_play_music)

# ─── Ready ────────────────────────────────────────────────────────────────────
func _ready() -> void:
	var _center_offset : float = SceneBackground.center_offset()
	FACE_CENTER.x += _center_offset
	CROWN_X       += _center_offset   # must match FACE_CENTER's recentering — the crown
									   # descends to this X and then locks to the face
									   # permanently at whatever offset exists at that moment
	SceneBackground.set_color(BG_COLOR)
	$background.color        = BG_COLOR
	$background.size         = get_viewport_rect().size
	$background.position     = Vector2(0, 0)
	$background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var font_path := "res://UI_assets/210 연필스케치R.ttf"
	if ResourceLoader.exists(font_path):
		_font = load(font_path)

	_setup_face()
	_setup_crown()
	_setup_label_group()
	_create_gnb_flag()
	_play_sequence()

# ─── Node setup ───────────────────────────────────────────────────────────────
func _setup_face() -> void:
	_face          = Sprite2D.new()
	_face.texture  = load("res://UI_assets/playbutton.png")
	_face.position = FACE_CENTER + Vector2(0.0, -FACE_ABOVE_OFFSET)
	_face.scale    = Vector2(FACE_SCALE, FACE_SCALE)
	_face.z_index  = 4
	add_child(_face)

func _setup_crown() -> void:
	_crown                  = Sprite2D.new()
	_crown.texture          = load("res://UI_assets/level_transition_crown/SoundUp_crown.png")
	_crown.position         = Vector2(CROWN_X, CROWN_START_Y)
	_crown.scale            = Vector2(CROWN_SCALE, CROWN_SCALE)
	_crown.rotation_degrees = CROWN_TILT
	_crown.z_index          = 5
	_apply_white_strip_shader(_crown)
	add_child(_crown)

func _apply_white_strip_shader(node: CanvasItem) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = 1.0 - smoothstep(0.35, 0.65, tex.b);
	COLOR = vec4(tex.rgb, tex.a * a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	node.material = mat

func _setup_label_group() -> void:
	_label_group          = Node2D.new()
	_label_group.position = Vector2(0.0, LEVEL1_Y)
	_label_group.z_index  = 3
	add_child(_label_group)

	var line1 := _make_label_line("You made it!", 0.0, 44.0, LEVEL1_LINE1_FONT)
	var line2 := _make_label_line("Keep hopping!", 42.0, 34.0, LEVEL1_LINE2_FONT)
	_label_group.add_child(line1)
	_label_group.add_child(line2)

func _make_label_line(text: String, y: float, h: float, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(SceneBackground.viewport_size().x, h)
	lbl.position              = Vector2(0.0, y)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", PURPLE_COLOR)
	if _font:
		lbl.add_theme_font_override("font", _font)
	return lbl

# ─── Where Am I — fixed navigation UI, present from the start, takes no part
# in the Coronation animation itself ─────────────────────────────────────────
func _create_gnb_flag() -> void:
	const BTN_W  : float = 72.0
	const BTN_H  : float = 56.0

	_gnb_btn              = Button.new()
	_gnb_btn.text         = ""
	_gnb_btn.size         = Vector2(BTN_W, BTN_H)
	_gnb_btn.position     = Vector2(SceneBackground.viewport_size().x - BTN_W - 20.0, 20.0)
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
	_seq_gen += 1                # cancel the active sequence — every pending
								  # await/tween in _play_sequence() checks this
								  # and bails out instead of auto-advancing
	_kill_coronation_audio()
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	overlay.name  = "GNBOverlay"
	var wai : Node = load("res://gnb_where_am_i.tscn").instantiate()
	wai.set("is_overlay", true)
	wai.connect("close_requested", func():
		overlay.queue_free()
		# Back/Return starts a NEW Coronation session from 0.0s. This is a
		# one-shot celebration, not a repeatable Round — there is no partial
		# state worth resuming, so a full scene reload is the correct
		# "restart", not exact-time pause/resume. next_level_id/level_name
		# are static and survive the reload untouched, so it still celebrates
		# the same level. Selecting a Set instead of Back never reaches this
		# closure — gnb_where_am_i.gd's own replay flow calls
		# change_scene_to_file() directly, which ends this Coronation session
		# for good (nothing here routes back to it).
		get_tree().reload_current_scene()
	)
	overlay.add_child(wai)
	add_child(overlay)

# ─── Music ────────────────────────────────────────────────────────────────────
func _safe_play_music() -> void:
	if _audio_dead or _music_player == null:
		return
	_music_player.play()

func _kill_coronation_audio() -> void:
	_audio_dead = true
	if _music_player != null:
		_music_player.stop()

func _start_music() -> void:
	_music_player           = AudioStreamPlayer.new()
	_music_player.stream    = load("res://BGM&effect/SoundUp_level_coronation_bgm.wav")
	_music_player.volume_db = 0.0
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	_safe_play_music()

func _on_music_finished() -> void:
	# The sequence always advances once the crowned unit clears the right
	# edge (~30.2s), well before the file's natural end (~33s), so this
	# should not normally fire — guarded the same way as every other
	# playback call in case it ever does.
	_safe_play_music()

# ─── Main sequence ────────────────────────────────────────────────────────────
func _t(seconds: float) -> float:
	return 0.01 if DEBUG_FAST else seconds

# Cancellation-aware wait: returns true if the sequence is still current and
# should continue, false if Where Am I has since bumped _seq_gen (or the node
# has left the tree) and the caller should stop immediately.
func _wait(seconds: float, gen: int) -> bool:
	await get_tree().create_timer(_t(seconds)).timeout
	return gen == _seq_gen and is_inside_tree()

func _play_sequence() -> void:
	var gen := _seq_gen
	var center_x : float = FACE_CENTER.x   # stable reference — _bounce_at mutates
											# FACE_CENTER.x as the traversal moves,
											# so later phases must not re-derive
											# their targets from the live value

	# 0.0-5.0s: PlayButton slowly descends from above the viewport — music
	# starts right away, from the very first frame, not once the crown appears
	_start_music()
	var descend_t := create_tween()
	descend_t.tween_property(_face, "position", FACE_CENTER, _t(T_DESCEND_END)) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	if not await _wait(T_DESCEND_END, gen): return

	# 5.0-12.0s: crown slowly descends and lands
	_descend_crown(T_CROWN_LAND - T_DESCEND_END)
	if not await _wait(T_CROWN_LAND - T_DESCEND_END, gen): return

	# Crown has landed — from here on, face and crown are one rigid unit.
	# Reparenting with keep_global_transform (the default) means both keep
	# their exact current on-screen position/rotation/scale; nothing jumps.
	_lock_crown_to_face()

	# 12.0-16.2s: crowned PlayButton breathes gently
	if not await _breathe(T_BREATHE_END - T_CROWN_LAND, gen): return

	# 16.2-20.4s: crowned PlayButton sways gently left/right
	if not await _sway(T_SWAY_END - T_BREATHE_END, gen): return

	# 20.4-21.351s: settle out of the sway, no forced bounce here
	if not await _settle(T_PRE_LEFT_END - T_SWAY_END, gen): return

	# Known durations of the fixed-shape gestures below, used to keep every
	# subsequent phase landing on its real musical timestamp instead of
	# drifting later as each gesture's own up/down time eats into the gap.
	const BOUNCE_DUR    : float = 0.32    # 0.12 up + 0.20 down, used per Group A/B bounce
	const FINALE_DUR    : float = 0.40    # 0.16 up + 0.24 down

	# 21.351-23.348s: bounce while moving left — Group A musical accents
	if not await _bounce_traverse(GROUP_A, center_x, center_x + LEFT_X_OFFSET, gen):
		return
	var t_now : float = GROUP_A[GROUP_A.size() - 1] + BOUNCE_DUR

	# 23.35-24.346s: short transition / direction change
	if not await _settle(max(24.346 - t_now, 0.0), gen): return
	t_now = 24.346

	# 24.346-26.355s: left → right bounce traversal — Group B musical accents
	if not await _bounce_traverse(GROUP_B, center_x + LEFT_X_OFFSET, center_x, gen):
		return
	t_now = GROUP_B[GROUP_B.size() - 1] + BOUNCE_DUR

	# 27.098s: prominent finale bounce/accent — first step of the rightward
	# exit. From here the character bounces/travels right and off the edge
	# of the viewport instead of returning to center.
	if not await _wait(max(T_FINALE - t_now, 0.0), gen): return
	var vp_w     : float = SceneBackground.viewport_size().x
	var exit_x   : float = vp_w + 300.0   # well past the right edge — guarantees fully off-screen
	var finale_x : float = lerpf(center_x, exit_x, 0.35)
	if not await _bounce_at(finale_x, 55.0, 0.16, 0.24, gen): return
	t_now = T_FINALE + FINALE_DUR

	# 28.862s + 29.118s + exit: one continuous rightward flight, not two
	# independent bounces. The unit keeps moving right and off-screen — there
	# is no in-place fade; leaving the viewport IS the disappearance. Timed to
	# clear the right edge around the musical ending (~30.1-30.3s).
	if not await _wait(max(T_FLOURISH_A - t_now, 0.0), gen): return
	if not await _exit_right(finale_x, exit_x, gen): return

	# Fully off-screen — complete the Coronation immediately. Do not hold an
	# empty screen out to the WAV's own ~33s endpoint.
	if _music_player != null:
		_music_player.stop()

	# Auto-advance to Level Intro
	LevelIntroState.level_id = next_level_id
	get_tree().change_scene_to_file("res://level_intro.tscn")

# ─── Crown descent ────────────────────────────────────────────────────────────
func _descend_crown(dur_seconds: float) -> void:
	var dur : float = _t(dur_seconds)
	var t := create_tween()
	t.tween_property(_crown, "position:y", CROWN_LAND_Y, dur) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# ─── Lock crown to face — from this point on, both are children of one
# container and are ONLY ever animated by moving/rotating/scaling that
# container. keep_global_transform (reparent()'s default) means neither
# node's on-screen position changes at the moment of reparenting. ────────────
func _lock_crown_to_face() -> void:
	_crowned_group = Node2D.new()
	_crowned_group.z_index = 4
	_crowned_group.position = FACE_CENTER   # group's own origin IS the resting
											 # center every later phase targets;
											 # set BEFORE reparenting so the
											 # face's local offset comes out as
											 # (0,0), not FACE_CENTER again
	add_child(_crowned_group)
	_face.reparent(_crowned_group)
	_crown.reparent(_crowned_group)

# ─── Breathing (12.0-16.2s) ───────────────────────────────────────────────────
func _breathe(duration: float, gen: int) -> bool:
	var breathe_tween := create_tween().set_loops()
	breathe_tween.tween_property(_crowned_group, "scale", Vector2.ONE * 1.035, 1.05) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	breathe_tween.tween_property(_crowned_group, "scale", Vector2.ONE, 1.05) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var ok := await _wait(duration, gen)
	breathe_tween.kill()
	_crowned_group.scale = Vector2.ONE
	return ok

# ─── Sway (16.2-20.4s) ────────────────────────────────────────────────────────
func _sway(duration: float, gen: int) -> bool:
	var sway_tween := create_tween().set_loops()
	sway_tween.tween_property(_crowned_group, "rotation_degrees", 4.0, 1.05) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	sway_tween.chain().tween_property(_crowned_group, "rotation_degrees", -4.0, 2.1) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	sway_tween.chain().tween_property(_crowned_group, "rotation_degrees", 0.0, 1.05) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	var ok := await _wait(duration, gen)
	sway_tween.kill()
	_crowned_group.rotation_degrees = 0.0
	return ok

# ─── Settle to neutral — used both after sway and as the short mid-transition
# between the two bounce groups. No bounce, just an ease back to rest. ────────
func _settle(duration: float, gen: int) -> bool:
	var t := create_tween()
	t.tween_property(_crowned_group, "rotation_degrees", 0.0, _t(duration * 0.6)) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	return await _wait(duration, gen)

# ─── Bounce-while-traversing — used for both Group A (left) and Group B
# (left→right). One bounce per accent timestamp in `accents`, with the
# resting X position interpolating linearly across the group. ────────────────
func _bounce_traverse(accents: Array[float], from_x: float, to_x: float, gen: int) -> bool:
	var n : int = accents.size()
	for i in range(n):
		var target_x : float = lerpf(from_x, to_x, float(i) / float(n - 1))
		if not await _bounce_at(target_x, 42.0, 0.12, 0.20, gen):
			return false
		if i < n - 1:
			var gap : float = accents[i + 1] - accents[i]
			var bounce_dur : float = 0.32   # 0.12 up + 0.20 down
			if not await _wait(max(gap - bounce_dur, 0.0), gen):
				return false
	return true

# ─── Single bounce — animates the crowned group as one rigid body. `target_x`
# becomes the group's new resting X; a bounce is a jump up then a return to
# that resting position. ──────────────────────────────────────────────────────
func _bounce_at(target_x: float, height: float, up_dur: float, down_dur: float, gen: int) -> bool:
	var base_pos : Vector2 = Vector2(target_x, FACE_CENTER.y)
	var tilt : float = 10.0 if randf() > 0.5 else -10.0

	var t_up := create_tween()
	t_up.set_parallel(true)
	t_up.tween_property(_crowned_group, "position", base_pos + Vector2(0.0, -height), _t(up_dur)) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t_up.tween_property(_crowned_group, "rotation_degrees", tilt, _t(up_dur))
	if not await _wait(up_dur, gen): return false

	var t_dn := create_tween()
	t_dn.set_parallel(true)
	t_dn.tween_property(_crowned_group, "position", base_pos, _t(down_dur)) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t_dn.tween_property(_crowned_group, "rotation_degrees", 0.0, _t(down_dur))
	if not await _wait(down_dur, gen): return false

	FACE_CENTER.x = target_x
	return true

# ─── Exit right (28.862s + 29.118s → ~30.2s) — one continuous flight off the
# right edge of the viewport, not two separate bounces and not an in-place
# fade. The crowned unit physically leaves the visible frame; that departure
# IS the disappearance. The 29.118s accent lands mid-flight as a brief scale
# pulse, not a second bounce, keeping this one gesture. ──────────────────────
func _exit_right(from_x: float, exit_x: float, gen: int) -> bool:
	var target_y : float = FACE_CENTER.y - 40.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_crowned_group, "position", Vector2(exit_x, target_y), EXIT_DUR) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	t.tween_property(_crowned_group, "rotation_degrees", 18.0, EXIT_DUR)
	if not await _wait(0.256, gen): return false   # reaches the 29.118s accent mid-flight

	var pulse := create_tween()
	pulse.tween_property(_crowned_group, "scale", Vector2.ONE * 1.05, 0.10) \
		.set_ease(Tween.EASE_OUT)
	pulse.tween_property(_crowned_group, "scale", Vector2.ONE, EXIT_DUR - 0.256 - 0.10)
	if not await _wait(EXIT_DUR - 0.256, gen): return false

	_crowned_group.visible = false   # fully clear of the viewport — no fade needed
	return true
