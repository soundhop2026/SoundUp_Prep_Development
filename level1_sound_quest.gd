extends Node2D

# ─── Level 1 Sound Quest — Quest Transition ("Find the Play Button") ───────
# Mirrors Prep Sound Quest's Quest Transition (a decorative celebration
# between Sets/Quests), but the mechanic here is a hidden-object search
# instead of a maze-hop: 25 decoy faces plus one real Play Button, all
# sharing the exact same texture and all bobbing continuously — the ONLY
# way to tell them apart is by tapping.
#
#   - Wrong tap: every face freezes in place for a beat, no sound, no
#     penalty — just a wordless "not that one" — then resumes bobbing.
#   - Correct tap (the real Play Button): it grows, does a little
#     celebratory dance, then every face fades out together.
#
# The real texture (playbutton.png) has its "play" triangle baked directly
# into the art, which would make the real one instantly spottable — so
# decoy faces render through a shader that masks that triangle's UV region
# to transparent, leaving an otherwise-identical face. No second asset
# needed; verified by rendering both side by side before wiring this in.
#
# NOTE: this file currently implements ONLY the transition. The actual
# Level 1 Sound Quest gameplay (a word-cloud sorting activity — dragging
# words into phoneme-labeled cubes) is being built separately and isn't
# wired in yet. Reachable standalone via DEBUG -> Demo Shortcuts -> "Test
# Level 1 Sound Quest Transition" for isolated preview/testing.
# ─────────────────────────────────────────────────────────────────────────

const FONT_PATH         : String = "res://UI_assets/210 연필스케치R.ttf"
const FACE_TEXTURE_PATH : String = "res://UI_assets/playbutton.png"
const BG_COLOR          : Color  = Color("#A8E063")   # same baby-green as Prep Sound Quest

const DECOY_COUNT : int    = 25
const FACE_SCALE  : Vector2 = Vector2(0.09, 0.09)

# The real texture's play-triangle sits in this UV rect (measured directly
# against the asset: bbox x[415,519] y[185,274] of a 907x437 image, padded
# slightly) — masked to transparent on decoy faces so all 26 faces are
# visually identical until tapped. Left alone on the one real face.
const TRIANGLE_MASK_RECT : Vector4 = Vector4(0.455, 0.42, 0.575, 0.63)

const CLUSTER_CENTER       : Vector2 = Vector2(640, 340)
const CLUSTER_HALF_EXTENTS : Vector2 = Vector2(420, 220)

const BOB_AMPLITUDE : float = 8.0
const BOB_HALF_DUR  : float = 0.3   # one bob = up then down, each half this long

const FREEZE_DURATION : float = 0.5   # how long ALL faces hold still after a wrong tap

const GROW_SCALE_MULT : float = 2.4
const GROW_DUR   : float = 0.4
const DANCE_DUR  : float = 1.2
const FADE_DUR   : float = 0.8

var _font  : Font = null
var _faces : Array = []   # Array[TextureButton]
var _bob_tweens : Array = []   # Array[Tween], parallel to _faces
var _real_index : int  = -1
var _frozen    : bool  = false
var _resolved  : bool  = false   # true once the real one's been found, ignore further taps


func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	var bg := ColorRect.new()
	bg.color        = BG_COLOR
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_spawn_faces()
	for i in range(_faces.size()):
		_start_bob(i)


# ─── Face spawning ──────────────────────────────────────────────────────────

func _spawn_faces() -> void:
	var total : int = DECOY_COUNT + 1
	_real_index = randi() % total

	var tex : Texture2D = load(FACE_TEXTURE_PATH)
	var mask_shader := Shader.new()
	mask_shader.code = """shader_type canvas_item;
uniform vec4 mask_rect;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (UV.x > mask_rect.x && UV.x < mask_rect.z && UV.y > mask_rect.y && UV.y < mask_rect.w) {
		tex.a = 0.0;
	}
	COLOR = tex;
}"""

	for i in range(total):
		var btn := TextureButton.new()
		btn.texture_normal      = tex
		btn.ignore_texture_size = true
		btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var tex_size : Vector2 = tex.get_size() * FACE_SCALE
		btn.size         = tex_size
		btn.pivot_offset = tex_size / 2.0

		if i != _real_index:
			var mat := ShaderMaterial.new()
			mat.shader = mask_shader
			mat.set_shader_parameter("mask_rect", TRIANGLE_MASK_RECT)
			btn.material = mat

		var offset : Vector2 = Vector2(
			randf_range(-1.0, 1.0) * CLUSTER_HALF_EXTENTS.x,
			randf_range(-1.0, 1.0) * CLUSTER_HALF_EXTENTS.y
		)
		var center : Vector2 = CLUSTER_CENTER + offset
		btn.position = center - btn.pivot_offset
		btn.set_meta("base_pos", btn.position)

		btn.pressed.connect(_on_face_pressed.bind(i))
		add_child(btn)
		_faces.append(btn)
		_bob_tweens.append(null)


# ─── Bobbing (the camouflage) ───────────────────────────────────────────────
# Slight per-face phase offset (a random interval before each cycle) so all
# 26 faces don't bob in lockstep — a more organic, harder-to-read crowd.
func _start_bob(i: int) -> void:
	var btn  : TextureButton = _faces[i]
	var base : Vector2 = btn.get_meta("base_pos")
	var t := create_tween()
	_bob_tweens[i] = t
	t.set_loops()
	t.tween_interval(randf() * BOB_HALF_DUR * 2.0)
	t.tween_property(btn, "position:y", base.y - BOB_AMPLITUDE, BOB_HALF_DUR).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(btn, "position:y", base.y, BOB_HALF_DUR).set_ease(Tween.EASE_IN_OUT)


# ─── Input ──────────────────────────────────────────────────────────────────

func _on_face_pressed(i: int) -> void:
	if _resolved:
		return
	if i == _real_index:
		_on_found_real(i)
	else:
		_on_wrong_tap()


# A wrong tap freezes every face mid-bob for a beat — no sound, no
# penalty, just a wordless "not that one" — then everything resumes. A
# second wrong tap while already frozen is a no-op rather than stacking.
func _on_wrong_tap() -> void:
	if _frozen:
		return
	_frozen = true
	for t in _bob_tweens:
		if t != null and t.is_valid():
			t.pause()
	await get_tree().create_timer(FREEZE_DURATION).timeout
	for t in _bob_tweens:
		if t != null and t.is_valid():
			t.play()
	_frozen = false


func _on_found_real(i: int) -> void:
	_resolved = true
	for t in _bob_tweens:
		if t != null and t.is_valid():
			t.kill()

	var real_btn : TextureButton = _faces[i]

	var grow := create_tween()
	grow.tween_property(real_btn, "scale", Vector2(GROW_SCALE_MULT, GROW_SCALE_MULT), GROW_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await grow.finished

	# 3 loops x 3 segments = 9 segments total, so each is DANCE_DUR/9 —
	# not /6, which would have made the real total 1.8s instead of DANCE_DUR.
	var dance := create_tween()
	dance.set_loops(3)
	dance.tween_property(real_btn, "rotation_degrees", 8.0, DANCE_DUR / 9.0)
	dance.tween_property(real_btn, "rotation_degrees", -8.0, DANCE_DUR / 9.0)
	dance.tween_property(real_btn, "rotation_degrees", 0.0, DANCE_DUR / 9.0)
	await dance.finished

	var fade := create_tween()
	fade.set_parallel(true)
	for f in _faces:
		fade.tween_property(f, "modulate:a", 0.0, FADE_DUR)
	await fade.finished

	_on_transition_finished()


# Standalone for now — real integration will hand off to the next Set's
# setup here instead, once the core word-cloud gameplay exists.
func _on_transition_finished() -> void:
	print("Level 1 Sound Quest transition finished.")
