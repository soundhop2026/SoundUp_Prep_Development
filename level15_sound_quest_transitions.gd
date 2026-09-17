class_name Level15SoundQuestTransitions
extends Node2D

# ─── Level 1.5 Sound Quest — shared Short/Long Set Transitions ─────────────
# Extracted from level15_sound_quest_ab.gd once Quest C/D needed the exact
# same choreography — every Level 1.5 Sound Quest type instantiates this as
# a child and calls play_short()/play_long() rather than duplicating this
# code per quest type.
#
# Two-tier Transition rule (locked 2026-08-06, corrected same day — the
# original design draft had this backwards, treating the Long Transition as
# a one-time first-entry moment; it is NOT):
#   - Short Transition: every Set boundary WITHIN a Quest (e.g. A1->A2,
#     A2->A3, A3->A4).
#   - Long Transition: a Quest type's FINAL Set boundary only (e.g. A4's
#     completion) — the Short Transition does NOT also play there. Plays
#     once per Quest type (A-F), 6 times total across all of Level 1.5
#     Sound Quest.
#     Choreography replaced entirely 2026-09-17 — the earlier "courage
#     story" (large Play Button hesitating toward a waiting crowd, talk /
#     breathe / group dance / group exit) is deprecated and gone. The new
#     Long Transition is deliberately minimal: ONE Play Button enters from
#     the left, hops continuously while travelling right, and keeps going
#     until it has fully left the viewport. ENTER LEFT -> HOP ACROSS ->
#     EXIT RIGHT, nothing else (yet).
# Callers decide WHICH one to play (mutually exclusive per boundary) — see
# each quest scene's own _on_round_complete()-equivalent.
#
# ─────────────────────────────────────────────────────────────────────────

const PLAYBUTTON_TEXTURE_PATH : String = "res://UI_assets/playbutton.png"

# Background rule (locked 2026-09-17): every Level 1.5 Sound Quest Set
# Transition — Short and Long alike — uses the same background color as
# the Sound Quest Set it belongs to. This component never paints its own
# background; it's a child node layered on top of the calling Quest scene,
# so the Quest's own BG_COLOR (sky blue for A/B, pale blue for C/D, cream
# for E, pale green for F) simply shows through. Do NOT cover with
# game15.gd's main-gameplay #A83A22 — that was a 2026-08-08 request,
# superseded by this rule; Sound Quest has its own palette, separate from
# the parent Level's main gameplay color.

# ─── Short between-Set Transition (no letters n/a — no target/bubble ────────
# ─── content shown, just Play Button hopping) ───────────────────────────────
# The 6x (960x960) size read as too big live — shrunk 70% down to 288x288
# (30% of 960, i.e. 1.8x the original 160x160). playbutton.png's drawn face
# only fills its own box's ~20%-80% vertically (measured earlier for the
# Quest C/D landing-spot work) — positioned so the actual visible face, not
# the box edges, centers around y=400 (roughly matching the Long
# Transition's ground level).

const SHORT_SIZE       : Vector2 = Vector2(288, 288)   # 960 shrunk 70% (960*0.3)
const SHORT_START_X    : float = -220.0
const SHORT_END_X      : float = 1450.0
const SHORT_Y          : float = 256.0   # top-left, chosen so the face's visible content centers near y=400
const SHORT_DUR        : float = 5.0     # slowed from 1.4 — "slowly slowly... slowly"
const SHORT_HOP_COUNT  : int   = 8
const SHORT_HOP_HEIGHT : float = 60.0

func play_short() -> void:
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	var face := TextureRect.new()
	face.texture = tex
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size = SHORT_SIZE
	face.pivot_offset = SHORT_SIZE / 2.0
	face.position = Vector2(SHORT_START_X, SHORT_Y)
	add_child(face)

	var base_y : float = face.position.y
	var step_dur : float = SHORT_DUR / float(SHORT_HOP_COUNT)
	for i in range(SHORT_HOP_COUNT):
		var frac : float = float(i + 1) / float(SHORT_HOP_COUNT)
		var target_x : float = lerp(SHORT_START_X, SHORT_END_X, frac)

		var up := create_tween()
		up.tween_property(face, "position", Vector2(target_x, base_y - SHORT_HOP_HEIGHT), step_dur * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await up.finished

		var down := create_tween()
		down.tween_property(face, "position", Vector2(target_x, base_y), step_dur * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await down.finished

	face.queue_free()


# ─── Long Transition ────────────────────────────────────────────────────────
# ENTER LEFT -> HOP ACROSS -> EXIT RIGHT. One Play Button, continuous
# linear travel from fully off-screen left to fully off-screen right, with
# a looping up/down hop layered on top for the whole trip, and the Sound
# Quest BGM underneath. No crowd, no hesitation, no background cover —
# nothing else, by design (2026-09-17). Sized independently from the
# Short Transition so the two can be tuned separately.
#
# BGM: quest_level15_bgm.mp3 (30.77s, 120.2 BPM, 4/4 -> beat 0.499s,
# bar 1.997s; downbeats at 1.93, 3.91, 5.92, 7.92, 9.91 ... — librosa
# analysis 2026-09-17). Starts with the crossing. LONG_HOP_PERIOD 0.5s is
# exactly one beat, so as long as the crossing is a whole number of bars
# (multiple of 2.0s) every hop stays beat-locked.
#
# Fade is described by two numbers so the harness can A/B endpoints
# without a code fork:
#   long_bgm_fade_lead — seconds BEFORE the Play Button exits that the
#                        fade starts (0.0 = fade starts on the exit
#                        downbeat itself, so the arrival chord is heard
#                        at full volume and decays as a tail after exit)
#   long_bgm_fade_len  — fade duration; if it outlasts the exit,
#                        play_long() waits for it before returning
# Production values (approved live 2026-09-17, after a librosa pass on the
# track): a 4-bar / 8.0s crossing so the Play Button exits on the bar-5
# downbeat (7.92s — the IV->I plagal return to G that closes the opening
# phrase); the fade starts ON that downbeat and runs one beat, so the
# arrival chord is heard in full and tails off after the button is gone.
# The first-pass 6.0s cut landed on bar 4 (the C / IV chord, near peak
# loudness and brightness) — harmonically the most unresolved bar line in
# the opening, which is exactly why it felt "too strong, cut short."
# Other musically valid endpoints, if this ever needs to change: 10.0s
# (5 bars, tonic, no event) or 22.0s (11 bars, the track's own V->I
# cadence and wind-down). 16.0s is NOT one — it's a half cadence on D.

const LONG_BGM         : String = "res://soundquest/assets/quest_level15_bgm.mp3"
const LONG_BGM_FADE_DB : float  = -40.0

const LONG_SIZE       : Vector2 = Vector2(360, 173)   # playbutton.png is 907x437 — same aspect, no letterboxing
const LONG_GROUND_Y   : float = 400.0   # centre of the Play Button while on the ground
const LONG_HOP_HEIGHT : float = 70.0
const LONG_HOP_PERIOD : float = 0.5     # one full up+down hop == one beat at 120 BPM — keep

# Overridable per instance (the test harness sets these before calling
# play_long()); every real Quest scene uses the defaults.
var long_dur           : float = 8.0    # full left-edge -> right-edge travel time — 4 bars
var long_bgm_fade_lead : float = 0.0    # fade starts on the exit downbeat
var long_bgm_fade_len  : float = 0.5    # one beat

var _long_music : AudioStreamPlayer = null

func play_long() -> void:
	_long_start_music()
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	var pb := TextureRect.new()
	pb.texture = tex
	pb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pb.size = LONG_SIZE
	pb.pivot_offset = LONG_SIZE / 2.0
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Real viewport width, not a hardcoded 1280 — on wider-than-16:9
	# devices the exit point is further right (see SceneBackground notes).
	var start_x : float = -LONG_SIZE.x
	var exit_x  : float = SceneBackground.viewport_size().x
	var ground_top_y : float = LONG_GROUND_Y - LONG_SIZE.y / 2.0
	pb.position = Vector2(start_x, ground_top_y)
	add_child(pb)

	# Hop loops on position:y independently of the travel tween on
	# position:x — two tweens on different sub-properties never fight.
	var hop := create_tween()
	hop.set_loops()
	hop.tween_property(pb, "position:y", ground_top_y - LONG_HOP_HEIGHT, LONG_HOP_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(pb, "position:y", ground_top_y, LONG_HOP_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var travel := create_tween()
	travel.tween_property(pb, "position:x", exit_x, long_dur).set_trans(Tween.TRANS_LINEAR)

	# Start the fade long_bgm_fade_lead seconds before exit (0 = on the
	# exit downbeat), wait for the Play Button to finish leaving, then wait
	# out whatever tail of the fade is still running before stopping.
	await get_tree().create_timer(maxf(long_dur - long_bgm_fade_lead, 0.0)).timeout
	var fade : Tween = _long_fade_music()
	# With lead == 0 the timer and the travel tween end on the same frame —
	# if the tween got there first, awaiting its `finished` would hang
	# forever, so only await it while it's genuinely still running.
	if travel.is_valid() and travel.is_running():
		await travel.finished

	hop.kill()
	pb.queue_free()
	if fade != null and fade.is_valid() and fade.is_running():
		await fade.finished
	_long_stop_music()


func _long_start_music() -> void:
	if not ResourceLoader.exists(LONG_BGM):
		return
	_long_music = AudioStreamPlayer.new()
	_long_music.stream = load(LONG_BGM)
	_long_music.volume_db = 0.0
	add_child(_long_music)
	_long_music.play()


func _long_fade_music() -> Tween:
	if _long_music == null:
		return null
	var fade := create_tween()
	fade.tween_property(_long_music, "volume_db", LONG_BGM_FADE_DB, long_bgm_fade_len)
	return fade


func _long_stop_music() -> void:
	if _long_music == null:
		return
	_long_music.stop()
	_long_music.queue_free()
	_long_music = null
