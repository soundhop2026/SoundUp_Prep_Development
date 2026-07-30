# SoundUp — Project Reference

## Philosophy (read this first)

**Sound comes first. Letters are symbols.**

SoundUp begins where language begins — before writing existed. Children hear, respond,
and speak long before they read. Every design decision flows from this.

- The LISTEN button is always a deliberate press — never auto-play on round start
- No letters, no written words, ever appear inside SoundUp
- The birds-flocking SOUNDUP title animation is philosophically accurate: sounds drift before settling
- When a decision is unclear, return to this compass

The companion app **Glide** (separate project, not yet built) bridges sound → print for
parents and adults who want to see the written words.

---

## Project Location

**Active folder:** `C:\Users\user\Documents\SoundUp_Prep_Development`
(NOT the older `sound-up` folder — never work there)

Engine: **Godot 4.5**, GDScript 2.0, mobile renderer, 1280×720 canvas.

---

## Scene Map

```
title.tscn / title.gd
    ↓ (prep_completed == false)
prep_game.tscn / prep_game.gd  ←─────────────────────────────┐
    ↓ (each set done)                                         │ retry loop
prep_transition.tscn / prep_transition.gd ────────────────────┘
    ↓ (all 26 sets done, accuracy ≥ 85%)
level_transition.tscn / level_transition.gd   ← plays ONCE in a child's lifetime
    ↓
game.tscn / game.gd  ←───────────────────────────────────────┐
    ↓ (each set done)                                         │ retry / replay
transition.tscn / transition.gd ──────────────────────────────┘
```

---

## Title Scene (`title.tscn` / `title.gd`)

**Purpose:** Entry point. SOUNDUP letters flock in, face waits, then routes based on progress.

### Layout ("one character")
```
S O U N D U P   ← arc of letters (hair)
     😊         ← PlayButton face (TextureButton)
 Start with Sounds  ← subtitle
```

### Key constants
| Constant | Value | Notes |
|---|---|---|
| BG_COLOR | #4B0082 | Deep purple |
| LOGO_COLOR | #FFB703 | Amber — SOUNDUP + subtitle |
| FACE_COLOR | #F5E6CC | Cream beige shader on face |
| LETTER_SIZE | 86pt | |
| ARC_CENTER | (618, 400) | x=618 not 640 — face oval is slightly left |
| ARC_RADIUS | 300 | |
| BTN_SCALE | 0.90 | |
| FACE_CENTER_Y | 250 | |

### Animation sequence
1. Letters appear scattered, fade in (0.5s)
2. Drift freely as birds flocking (3s)
3. Land one by one S→O→U→N→D→U→P (0.65s stagger, EASE_OUT BACK)
4. "Start", "with", "Sounds" fly up from below (0.5s tween each)
5. 3s hold → `_can_press = true`

### Exit animation
- Letters scatter away, words slide off left/right
- Routes to `prep_game.tscn` or `game.tscn` based on `SaveManager.is_prep_completed()`

### Routing
```gdscript
if SaveManager.is_prep_completed():
    LevelProgress.current_index = SaveManager.get_level1_set_index()
    get_tree().change_scene_to_file("res://game.tscn")
else:
    PrepLevelProgress.load_from_save()
    get_tree().change_scene_to_file("res://prep_game.tscn")
```

---

## Prep Level (`prep_game.tscn` / `prep_game.gd`)

**Purpose:** Sound-only phonemic awareness training. No letters. No Louis. No PlayButton.

### Key differences from game.gd
- Phoneme auto-plays ×2 (child does NOT press Listen)
- Word sounds auto-play ×1 per image with bounce animation
- Pointed hand guides attention, disappears before choice window
- Wrong answer → full loop replay (not try-again screen)
- 3-second choice window, then auto-replay if no answer
- No idle hint timer
- Back button — see [Back Button Philosophy](#back-button-philosophy-locked) for the product-wide rule. Prep-specific: works throughout the auto-play narration (not just the final choice window), guarded by `_resolving`/`round_index==0` rather than `result_locked`. `_resolving` is true only during `_do_correct()`/`_do_wrong()`'s own result sound effects, since those are about to change round_index themselves; a `_seq_gen` counter (bumped on every `_start_round()`) cancels any in-flight auto-play sequence Back interrupts, so it can't race the new round's sequence. Nothing is ever forced — auto-play stays the default.

### 26 Prep Sets
Originally scoped at 33 sets (through a 1G "ending sounds" group), deliberately
trimmed to 26 — kids meet those sounds again in Level 1, so Prep saves the more
complicated phonemes for there instead and stays lighter. `prep_1e_3.json`,
`prep_1e_4.json`, and `prep_1g_1.json`–`prep_1g_5.json` still exist on disk as
leftovers from the original 33-set scope but are intentionally unused —
`prep_level_progress.gd`'s `sets` array is the source of truth for what's
actually playable.

| Group | Chunks | Phonemes | Choices |
|---|---|---|---|
| 1A | prep_1a_1 → prep_1a_4 | M S T B V K | 3 |
| 1B | prep_1b_1 → prep_1b_4 | N F P D G J | 4 |
| 1C | prep_1c_1 → prep_1c_6 | H W Y L R Z | 4 |
| 1D | prep_1d_1 → prep_1d_6 | Contrast pairs | 4 |
| 1E | prep_1e_1 → prep_1e_2 | C-soft G-soft X Q | 3 |
| 1F | prep_1f_1 → prep_1f_4 | All sounds mixed | 5 |

### Accuracy tracking (`PrepLevelProgress`)
- `pass_total` — total rounds completed
- `pass_wrong` — rounds where child pressed wrong at least once
- `accuracy()` = `(pass_total - pass_wrong) / pass_total`
- A "wrong round" = any round with at least one wrong press

### 85% gate
- After all 26 sets: if `accuracy() >= 0.85` → cube dance → `level_transition.tscn`
- If `< 0.85` → wrong-round retry (flat, continuous, no new cubes)
- Retry loops until accuracy reaches 85%+

---

## Prep Transition (`prep_transition.tscn` / `prep_transition.gd`)

**Purpose:** Between-set celebration inside Prep Level.

- Background: baby green `#A8E063`
- Sets 1–25: PlayButton bounces ×6 → earned cubes dance → next set
- Set 26: bounce → accuracy check → cubes dance → route
- Retry graduation (`is_retry=true`): no bounce → all 26 cubes dance → `level_transition`

### Cube board
- Same system as Level 1's `transition.gd` cube board (reused, not reimplemented separately) —
  same asset, deep-blue filled / faint-white-outline colors, 40px cubes on a 48px step, two
  rows split by `(total+1)/2`, centred at x=640.
- 26 cubes total — one per **individual set**, not per main group; `earned = PrepLevelProgress.current_index + 1`
- Whole board is created (hidden) in `_ready()`; `_show_cubes(earned)` reveals it on a pass,
  and only the newly-earned cube plays the continuous wiggle dance (`_dance_cube`) — same
  behavior as Level 1, not a full-board group dance

### CRITICAL routing rule
`has_next()` MUST be called BEFORE `advance()` — reversed order silently routes to title.

---

## Level Transition (`level_transition.tscn` / `level_transition.gd`)

**Purpose:** Coronation. Plays ONCE when a child graduates from Prep to Level 1.

### Visual design
- Background: cream `#EDE4D3`
- Face: `UI_assets/playbutton.png`, scale 0.585, centre (640, 265)
- Crown: `UI_assets/level_transition_crown/SoundUp_crown.png`, scale 0.189, tilt 1°
- White-strip shader on crown: keys on blue channel `smoothstep(0.35, 0.65, tex.b)`
- "Level 1" label: font_size 28, PURPLE (#4B0083), at y=355
- "Ready to Play" button: PURPLE bg, GOLD (#FFB703) text, font_size 50, at y=510

### Sequence timing
| Time | Event |
|---|---|
| 0–2s | Still face, anticipation |
| 2s | Music starts + crown begins descent |
| 2–6s | Crown descends (4s, EASE_OUT CUBIC) |
| 6–10s | Celebration: 8 bounces, face+crown+label dance |
| 10–13s | Still with crown — admire |
| Music end | "Ready to Play" fades in, slow pulse begins |

### Celebration dance
- Face + crown: bounce ±55px, tilt ±15° / ±10.5°, scale 1.10×
- "Level 1" label: gentle sway only — 8px rise, ±4.5° tilt, no scale change
- 8 bounces × 0.5s = 4s total

### Music
- `BGM&effect/SoundUp_level_transition_bgm.wav` (~11s)
- Starts at 2s into the sequence
- `await _music_player.finished` before showing Ready button

### Routes to
```gdscript
LevelProgress.current_index = SaveManager.get_level1_set_index()
get_tree().change_scene_to_file("res://game.tscn")
```

---

## Level 1 Game (`game.tscn` / `game.gd`)

**Purpose:** Main gameplay — child hears a phoneme, taps the matching image.

### Core flow
1. `phase = "wait_listen"` — child presses LISTEN bar
2. Phoneme plays
3. Choice window opens — child taps an image
4. Correct → next round; Wrong → penalty, retry same round

### LISTEN button rule
**Deliberate press only — never auto-play on round start.** This is locked design.
The `phase = "wait_listen"` flow and `$ListenButton` must be preserved.

### Accuracy / mastery
- `clean_correct_count` — rounds answered correctly with NO wrong clicks
- `_round_hint_used` — set `true` ONLY in `_do_wrong()` (wrong click = only penalty)
- `_assisted_rounds` — rounds where `_round_hint_used` was true
- `mastery_accuracy = clean_correct_count / rounds.size() * 100.0`
- Passed to `LevelProgress.last_score_pct` at level complete

### Shuffle
`_shuffle_no_consecutive()` ensures no two consecutive rounds share the same phoneme.

### Back button
See [Back Button Philosophy](#back-button-philosophy-locked) for the product-wide rule and
implementation details (shared `back_button.gd` component, unlimited navigation, first-attempt
scoring lock-in). Level-1-specific: `_round_hint_used` resets when going back (clean slate for
that round).

### 17 Level 1 Sets (331 total rounds)
| Set | Phonemes | Choices | Rounds |
|---|---|---|---|
| 1A-1, 1A-2 | m s t b k v | 3 | 20 each |
| 1B-1, 1B-2 | n f p d g-hard j | 4 | 20 each |
| 1C-1, 1C-2, 1C-3 | h w y l z r | 4 | 20 each |
| 1D-1, 1D-2, 1D-3 | contrast pairs | 4 | 19/19/18 |
| 1E-1, 1E-2 | c-soft g-soft x q | 3 | 20 each |
| 1F-1, 1F-2 | all 21 mixed | 5 | 20 each |
| 1G-1, 1G-2, 1G-3 | ending sounds | 4 | 19/18/18 |

### Audio / asset folder naming
- Word audio: `res://BGM&effect/SoundUp_level1_word sounds/`
- Word images: `res://SoundUp_level1_word images/`
- Phoneme audio: `res://BGM&effect/SoundUp_level1_phonemes/`
- Special cases: `G-hard` (dash in folder), `G_hard.wav` (underscore in audio)
- `X-ks`, `x-gz`, `c-soft`, `G_soft`, `C-hard` follow same pattern

---

## Level 1 Transition (`transition.tscn` / `transition.gd`)

**Purpose:** Between-set celebration inside Level 1. Full star + coronation ceremony.

### Sequence
1. Music starts immediately in `_ready()`
2. Stars dance wildly (gold, all 3)
3. PlayButton heartbeat pulse ×10 + rubber-ball bounce ×10
4. Stars settle (0.4s)
5. Slot machine: 30 bitmask states, slow→fast, sudden stop
6. Stars hidden briefly (0.35s)
7. Earned stars drop in with impact flash+shake
8. POP ×10 (first 5 fast, last 5 slow)
9. 5s hold → track 1 ends → track 2 plays → track 2 ends → route

### Score thresholds
- ≥ 95% → 3 stars → advance
- 85–94% → 2 stars → retry wrong rounds
- ≤ 84% → 1 star → replay full set

### Music
- Track 1: `BGM&effect/transition_fanfare.wav`
- Track 2: `BGM&effect/transition_fanfare_2.wav` (plays immediately when track 1 ends, zero gap)

### PlayButton constants
- BASE_SCALE 0.80, PULSE_SCALE 1.76
- BOUNCE_UP −180px, apex at y=110

---

## Save System (`save_manager.gd`)

Autoload singleton. Saves to `user://soundup_save.json`.

| Key | Type | Purpose |
|---|---|---|
| `prep_completed` | bool | true after graduating to Level 1 |
| `prep_set_index` | int | current Prep set index |
| `level1_set_index` | int | current Level 1 set index |

**Save file location (for testing):**
`C:\Users\user\AppData\Roaming\Godot\app_userdata\SoundUp_Prep_Development\soundup_save.json`

Delete this file for a clean test from the beginning.

**Known bug (fixed):** `PrepLevelProgress.reset()` must call `SaveManager.set_prep_set_index(0)` — it previously forgot to save index 0, causing stale routing.

---

## Progress Singletons

### `LevelProgress` (level_progress.gd)
- `current_index` — which Level 1 set is active
- `last_score_pct` — mastery accuracy from last set (default 0.0 = 1 star)
- `is_retry` — if true, `game.gd` loads `retry_rounds` instead of JSON
- `retry_rounds` — array of wrong round dicts for 2-star path
- `sets` — array of 17 JSON paths (adding a set = one line here, nothing else)

### `PrepLevelProgress` (prep_level_progress.gd)
- `pass_total`, `pass_wrong`, `wrong_round_dicts`
- `retry_rounds`, `is_retry`
- `accuracy()` → float
- `load_from_save()` — restores index from SaveManager on title press

---

## Key Assets

| Asset | Path |
|---|---|
| Face (PlayButton) | `UI_assets/playbutton.png` |
| Crown | `UI_assets/level_transition_crown/SoundUp_crown.png` |
| Prep cube (filled) | `UI_assets/preplevel_set_counting_cube.png` |
| Prep cube (empty) | `UI_assets/preplevel_set_counting_cube_empty.png` |
| Star | `UI_assets/star.png` |
| Back button | `UI_assets/back_button.png` |
| Font | `UI_assets/210 연필스케치R.ttf` |
| Transition BGM 1 | `BGM&effect/transition_fanfare.wav` |
| Transition BGM 2 | `BGM&effect/transition_fanfare_2.wav` |
| Level transition BGM | `BGM&effect/SoundUp_level_transition_bgm.wav` |

---

## Shaders Used

### Cream tint (title.gd — face)
Replaces all visible pixels with a flat tint color. Used because PNG strokes don't respond to modulate.
```glsl
shader_type canvas_item;
uniform vec4 tint_color : source_color;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(tint_color.rgb, tex.a);
}
```

### White strip (level_transition.gd — crown)
Strips white background from crown PNG by keying on the blue channel.
```glsl
shader_type canvas_item;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float a = 1.0 - smoothstep(0.35, 0.65, tex.b);
    COLOR = vec4(tex.rgb, tex.a * a);
}
```

---

## Design Rules (locked)

1. **LISTEN button = deliberate press.** Never auto-play on round start. `phase = "wait_listen"` is correct.
2. **No letters in SoundUp.** Ever. Glide is the letters companion.
3. **`has_next()` before `advance()`** in all transition routing — reversed order silently goes to title.
4. **Never invent timing values.** Use `await sound.finished` for audio sync. Only change a timing if it violates the locked design.
5. **`_round_hint_used` set ONLY in `_do_wrong()`** — pressing Listen again, tapping images, taking time — none of these are penalties.
6. **DEBUG_FAST constant** in `level_transition.gd` — set `false` before any release build.
7. **Back is unlimited review, never scoring.** See [Back Button Philosophy](#back-button-philosophy-locked) — applies to every round-based level, current and future, unless there's a specific gameplay reason not to.
8. **Distractors must be phonemically different from the target.** See [Phoneme-Based Distractor Rule](#phoneme-based-distractor-rule-locked) — never pair a target and a distractor that share the same actual sound, even if their spelling differs.

---

## Phoneme-Based Distractor Rule (locked)

Found via a real bug: a Level 1F/Prep 1F "sounds mixed" round targeted **J** (`jeep` as the
correct answer) but included **`genie`** as a distractor. Soft G and J are both /dʒ/ — the
exact same phoneme, just spelled differently. A child who correctly identified the sound and
picked `genie` would have been marked wrong for a right answer. Fixed by swapping `genie` for
`hat` in the three files sharing that round (`level_1f.json`, `level_1f_2.json`,
`prep_1f_4.json`); confirmed no other files pair a J-word with a soft-G word.

**Rule:** choice validation happens at two levels, both required:
1. **Phoneme level** — classify every word by its actual sound, not its spelling. This is a
   property of the word itself, checked once, independent of any round.
2. **Round level** — within one round's actual choice set, no distractor may share the
   **target's phoneme**, regardless of how it's spelled.

**Grapheme overlap is irrelevant and never the problem.** Two distractors spelled with the same
letter (e.g. two different C-words) are completely fine together, even if one is hard C and one
is soft C — they don't share a phoneme with each other. The only thing that matters is whether
a distractor's *actual sound* matches the *target's actual sound* — spelling never enters into
whether a pairing is valid.

**Known same-phoneme spelling groups in this curriculum:**
- **/dʒ/** — J (`jeep`, `jump`, `jacket`) and soft G (`genie`, `giant`, `gym`, `giraffe`)
- **/s/** — S (`sun`, `sock`) and soft C (`city`, `cereal`, `cent`, `circus`, `celery`, `circle`)
- **/k/** — K (`kite`) and hard C (`cat`, `cup`)
- **/ɡ/** — G (`go`) and hard G (`game`) — don't mix if the round's goal is phoneme
  discrimination between them
- **/ks/** — X (`box`) and other spellings representing the same sound — check before using as
  a distractor pair

**Before approving any round's choices, validate:**
1. The target phoneme
2. The correct answer's actual phoneme (not just its target letter/spelling)
3. Every distractor's actual phoneme, checked against the target specifically — not against
   each other, and not against spelling

When adding a new word to the word bank, classify its phoneme once (level 1), then re-check it
against the target every time it's used as a distractor in a specific round (level 2) — passing
one check doesn't exempt it from the other.

---

## Back Button Philosophy (locked)

Product-wide navigation rule — applies to every round-based level, current and future,
unless there's a very specific gameplay reason not to:

- Back is a **review feature, never a scoring feature.**
- Back is **unlimited** in every round-based level — no per-set or per-press cap.
- Players may return to any previous round within the current set.
- Players can **never skip forward** — after going back, they must replay forward through
  every round in order to reach where they were.
- A round contributes to scoring **only once, on its first completed attempt.** Replay never
  changes score, pass percentage, stars, completion status, or gate decisions.
- Completed round-progress cubes remain visible while replaying, so the player can always see
  where they are relative to their previous furthest point.

### Implementation
- Shared button: `back_button.gd` (`class_name BackButton extends TextureButton`) — same
  position, size, appearance everywhere it's used (`game.gd`, `prep_game.gd`, `game2.gd`,
  `game25.gd`, `game15.gd`). Each screen instantiates `BackButton.new()` and wires its own
  `pressed` handler; only the guard logic differs per screen, never the button itself.
- Navigation: `round_index -= 1` (`_round_index` in `game15.gd`), guarded only by
  `result_locked`/`_resolving` (mid-flight result animation) and `round_index == 0` — no
  press-count cap on any screen. (`game15.gd` previously had a `BACK_USES_MAX = 2` cap;
  removed for consistency with this rule.)
- Scoring lock-in: every screen tracks a `_scored_rounds` dictionary (`round_index -> true`),
  reset per set. The correct-answer handler (`_do_correct()` / `_tally_round()` in
  `game15.gd`) only increments the score counters and appends to the wrong/assisted-rounds
  list the *first* time a given `round_index` is scored — replays after that still play the
  sound/cube-blend/round-advance as normal, but never touch score state again.
- New round-based levels should follow this same `_scored_rounds`-guarded pattern rather than
  inventing a new one.

---

## Planned / Pending

- **Glide companion app** (separate project, new chat): same phoneme sounds but with letters shown — for parents/adults/kids who want to see written words. Mirrors SoundUp's Prep + Level 1 sound sets.
- **Level 1 persistent save**: Level 1 progress save across app restarts (in progress).
- **Transition scene rename**: `prep_transition` → `prep_set_transition`, `transition` → `level1_set_transition` (deferred).
- **Tablet end-to-end test**: all 17 Level 1 sets on device (deferred).
- **Level 2+**: not yet designed.

## Update — June 2026
Companion app renamed: Glide → SoundBuddy
SoundBuddy planning complete. See sound-buddy/CLAUDE.md for full spec.
