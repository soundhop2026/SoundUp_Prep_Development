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

**Working across Windows and Mac:** see [`Worklog.md`](Worklog.md) at the project root before
starting a session on a new machine — it has machine-portable session history plus what does
*not* travel via git (the production keystore, local tool paths) and needs separate handling.

---

## Scene Map

```
title.tscn / title.gd
    ↓ (prep_completed == false)
prep_game.tscn / prep_game.gd  ←─────────────────────────────┐
    ↓ (each set done)                                         │ retry loop
prep_transition.tscn / prep_transition.gd ────────────────────┘
    ↓ (every Prep Set passed — the Level's first full completion)
level_transition.tscn / level_transition.gd   ← plays ONCE per Level, on its first full completion
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
| 1E | prep_1e_1 → prep_1e_2 | K Q S W X (/ks/) | 3 |
| 1F | prep_1f_1 → prep_1f_4 | All sounds mixed | 5 |

### Accuracy tracking (per Set)
- Computed in `prep_game.gd` for the run just played, and stored in `PrepLevelProgress.last_score_pct`.
- A "wrong round" = any round with at least one wrong press (a round is counted on its first completion only).
- Score = `(rounds − wrong rounds) / rounds`. `PrepLevelProgress.retry_rounds` holds the wrong rounds.

### 85% pass criterion (per Set — not across all 26 Sets)
- Each Set passes at **≥ 85%** (no stars in Prep). A pass is recorded in `sets_completed`; what follows is
  decided by [Progress & Access](#progress--access-locked).
- Below 85%: only that Set's wrong rounds are retried (flat, continuous, no new cubes), looping until the
  Set reaches 85%.
- There is no accuracy gate across the whole Level. The Level is complete when every one of its 26 Sets has
  been passed.

---

## Prep Transition (`prep_transition.tscn` / `prep_transition.gd`)

**Purpose:** Between-set celebration inside Prep Level.

- Background: baby green `#A8E063`
- Every Set: PlayButton bounces ×6 → the pass is recorded → cube board → routing per
  [Progress & Access](#progress--access-locked) (Coronation on first full completion, else the following
  Set, else the subscription paywall, else Where Am I)
- Below 85%: no cubes; back to `prep_game.tscn` to retry the wrong rounds

### Cube board
- Same system as Level 1's `transition.gd` cube board (reused, not reimplemented separately) —
  same asset, deep-blue filled / faint-white-outline colors, 40px cubes on a 48px step, two
  rows split by `(total+1)/2`, centred at x=640.
- 26 cubes total — one per **individual set**, not per main group. A cube is filled only if that Set is
  recorded as passed (`sets_completed`), so a Set passed out of order never lights earlier cubes.
- Whole board is created (hidden) in `_ready()`; `_show_cubes()` reveals it on a pass, and only the Set
  just passed plays the continuous wiggle dance (`_dance_cube`) — same behavior as Level 1, not a
  full-board group dance

### CRITICAL routing rule
`has_next()` MUST be called BEFORE `advance()` — reversed order silently routes to title. Routing now goes
through `ProgressStatus.next_step()`, which checks that a following Set exists before any advance.

---

## Level Transition (`level_transition.tscn` / `level_transition.gd`)

**Purpose:** Coronation. Plays ONCE per Level, on that Level's first full completion (Prep → Level 1,
Level 1 → 1.5, 1.5 → 2, 2 → 2.5). The Level Transition scene is shared; `LevelTransition.next_level_id`
says where it leads. It never repeats when an already-completed Set is replayed. See
[Progress & Access](#progress--access-locked).

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

### Score thresholds and the retry loop
- **Initial ≥ 95% → 3 stars → Set passed.**
- **Initial 85–94% → 2 stars → retry the incorrect rounds only.** Once an incorrect-rounds retry has begun,
  any result below 95% (1★ or 2★) keeps retrying only the rounds still incorrect — never the whole Set. A
  retry run is scored over the retry rounds only (unchanged calculation); ≥ 95% passes. The marker is
  `LevelProgress.last_run_was_retry`, assigned by `game.gd` on every Set load (true only when it loaded
  `retry_rounds`), so it can never carry into a new Set.
- **Initial below 85% → 1 star → replay the whole Set.**
- A below-65% score is an ordinary 1-star result. The old rule that sent a child who scored under 65% on
  the first Level 1 Set back to Prep was removed: children no longer choose between Prep and Level 1, so
  a low Level 1 score never sends a child anywhere else.
- Levels 1.5 and 2 are unchanged: ≥ 85% (2★ or better) passes ("Gain and Move"); below that retries.

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
| `prep_completed`, `level1_completed`, `level15_completed`, `level2_completed` | bool | set once, on that Level's first full completion; guards the Coronation |
| `prep_set_index`, `level1_set_index`, `level15_set_index`, `level2_set_index` | int | **resume cursor**: the Set last actually played, or after a pass the Set that follows. Reset to 0 on a Level's first completion. Never evidence of entry or completion |
| `levels_entered` | dict | per-Level entry flag, written only by the Level Intro's Ready button; drives Where Am I's Level lock |
| `sets_entered`, `sets_completed` | dict | **explicit per-Set records**, keyed `<level_id>_<label>` (e.g. `prep_A1`, `level15_E3`, `level2_L`); the only evidence a Set was entered / passed |
| `progress_records_version` | int | `1` once the records exist; an older save is migrated exactly once on load |
| `review_counts` | dict | ×N counts shown in Where Am I (display only; never evidence) |
| `subscribed` | bool | **display mirror only** of the last store-verified state; never read for access (see Subscription Entitlement & Premium Gameplay) |
| `path_chosen`, `chose_level1_path` | bool | legacy path flags; nothing sets `chose_level1_path` any more |

**Migration (one time, additive):** a save without `progress_records_version` gets records from the only
reliable pre-record evidence — a Level's completed flag marks all its Sets; otherwise Sets before the
saved cursor are marked. It never reads `review_counts`, never removes or lowers anything, and never
touches cursors, flags, counts or subscription. The Set the cursor points at, and any Set that was
entered but never passed, stay NOT STARTED (that history cannot be reconstructed).

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
- `retry_rounds` — array of wrong round dicts for the incorrect-rounds retry path
- `last_run_was_retry` — true only for the run just played when it replayed `retry_rounds` (see Level 1 retry loop)
- `sets` — array of 17 JSON paths (adding a set = one line here, nothing else)

### `PrepLevelProgress` (prep_level_progress.gd)
- `current_index`, `last_score_pct` (per-Set accuracy), `retry_rounds`, `is_retry`
- `FREE_SET_COUNT` (2), `is_set_accessible()`, `is_group_accessible()`, `next_set_locked()` — subscription access
- `load_from_save()` — restores the cursor from SaveManager; for a player who cannot enter that Set it displays
  the last accessible Set instead, without rewriting the saved cursor

### `Level15Progress`, `Level2Progress`
Same shape as `LevelProgress` (13 and 12 Sets); Level 1.5 and Level 2 pass at ≥ 85%.

### `ProgressStatus` (progress_status.gd)
Pure functions, no writes: `needs_subscription()`, `is_set_accessible()`, `set_status()` / `group_status()` /
`level_status()`, `all_required_completed()`, `first_completion_ready()`, `next_step()`, `clear_retry()`.

### `ReleaseScope` helpers (release_scope.gd)
`set_keys(level_id)` / `set_key(level_id, index)` build the record keys; `record_cursor(level_id, index)`
saves the resume cursor.

### `PremiumIntroState` (premium_intro_state.gd)
Context for the subscription flow: `CONTEXT_PREP_BOUNDARY` (passed the last free Set → continue to the next),
`CONTEXT_PREP_LOCKED` (tried a premium Prep Set → back to Where Am I), `CONTEXT_PREMIUM_LOCKED` (premium
gameplay refused or interrupted → back to Where Am I), `CONTEXT_GNB` (opened from GNB Home → back there).
Granting access never writes progress by itself.

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
9. **Never auto-advance past the highest publicly released Level.** After any Level's Coronation, the game continues into the next Level only if it's within the current build's release scope — otherwise the player returns to Title instead. See [Release Scope Gate](#release-scope-gate-locked) — this is a generic framework rule, not a one-off patch for any specific Level.
10. **A Set Transition always matches the background color of the gameplay it belongs to.** See [Background Color Rule](#background-color-rule-locked) — main gameplay and Sound Quest are two separate palettes, and a Sound Quest Set Transition follows its Sound Quest Set's color, never the parent Level's main color.
11. **Typography is assigned by semantic role, never by screen.** Schoolbell = character/logo text · Andika Regular = information content · Andika Bold = information structure · JetBrains Mono Regular/Bold = action/transaction. The SOUNDHOP wordmark in the PlayButton logo system is Schoolbell text; existing lettering artwork is not automatically protected. Never synthesize bold; never do a repository-wide font replacement. Full rules: [`SOUNDHOP_UI_FONT_FRAMEWORK.md`](SOUNDHOP_UI_FONT_FRAMEWORK.md); implementation: `ui_fonts.gd`.
12. **Progress and access are separate; the explicit Set records are the only evidence of progress.** The resume cursor and the ×N counts are never evidence of entry or completion, and locking a Set never changes a record. See [Progress & Access](#progress--access-locked).
13. **×N counts full Set attempts only.** Entering and leaving, incorrect-rounds retry runs and QA debug launches never count. See [Progress & Access](#progress--access-locked).
14. **A Coronation plays once per Level, on its first full completion, and no Level advances while a required Set is incomplete.** See [Progress & Access](#progress--access-locked).

---

## Progress & Access (locked)

Locked 2026-10 (stages C1–C6). Terminology is Level → Group → Set → Round.

### Three separate things
| Thing | Where | Meaning |
|---|---|---|
| **Progress records** | `SaveManager` `sets_entered` / `sets_completed` | The only evidence a Set was entered / passed. Entry is written at actual gameplay entry (the first round of a real play); completion when a Set is passed by its Level's own criterion. Records only grow: replays, failures and access changes never clear one. |
| **Resume cursor** | `*_set_index` | The Set last actually played; after a pass, the Set that follows. Title resumes here. A real entry may overwrite it, including when replaying an earlier Set. |
| **×N counts** | `review_counts` | Display only. |

### Access (separate from progress)
- A Level's first Set is always open. Once it has actually been attempted, **every** Set in that Level is
  open for free selection, whatever else has been passed. Before that, the other Sets are LOCKED.
- **Prep subscription takes precedence:** free users reach only Sets A1–A2 (`PrepLevelProgress.FREE_SET_COUNT`);
  Set 3 onward needs a subscription, and a subscriber reaches every Prep Set immediately. Completing a free
  Set never unlocks a paid Set. **Prep Sound Quest A is free; Sound Quest B–F need a subscription** (a Group
  is free only if it contains a free Set). Sound Quest A does not require completing A1 or A2.
- Enforced at every route: Where Am I locks the cards, and every premium gameplay scene checks access in
  `_ready()` (a blocked entry goes to the premium screen and touches no progress). See Subscription Entitlement
  & Premium Gameplay for the full model, including Levels 1+. Title shows the last
  accessible Set to a player who cannot enter their saved one, without rewriting the cursor.
- A completed Set that becomes inaccessible keeps its completion and shows LOCKED.
- Level prerequisites are enforced by the existing layers: Where Am I's lock cascade, Title's forward routing
  and the Coronation hand-off. Locked Group tiles stay tappable so a child can see the locked Set cards;
  gameplay access stays blocked.

### Passing a Set, and what follows
- Pass criteria, unchanged: **Prep ≥ 85%** (per Set, no stars); **Level 1 ≥ 95% (3★)**; **Level 1.5 and Level 2
  ≥ 85% (2★ or better)**. The pass is recorded as soon as the result is known.
- After a pass, in this order (`ProgressStatus.next_step`):
  1. The Level has just become fully completed for the first time → the Coronation (the existing flow).
  2. Otherwise, a following Set exists and is accessible → go to it, **even if it was passed before**.
  3. A following Set exists but needs a subscription → the existing paywall (Prep: Keep Hopping → Parent Gate →
     Choose Plan; Levels 1 / 1.5 / 2: straight to the subscription flow, pass already recorded).
  4. Otherwise (the final Set was reached) → Where Am I.
- The next Level is never entered while any required Set is incomplete. Required Sets: Prep 26, Level 1 17,
  Level 1.5 13, Level 2 12. **Sound Quest is never part of Level completion.**
- **Coronation guard:** it fires only when every required Set is recorded *and* the Level's own completed
  flag is not yet set, so replaying completed Sets — including Title's "new Prep cycle" — never repeats it.
- A Set chosen in Where Am I starts as a real, scored attempt that follows the rules above (any stale retry is
  cleared first). Sound Quest cards keep their own review flow back to Where Am I.
- Cube boards fill from the records, never from a Set index.

### ×N play counts
- One count when a **full** Set attempt finishes (every round of the full Set reached), **whether it passes
  or fails**. Entering and abandoning, incorrect-rounds-only retry runs and QA debug launches never count.
- Applies to Prep, Level 1, Level 1.5 and Level 2 (including `game25.gd`, which serves Level 2 Sets I–L).
- Counts stored by earlier builds (which counted at entry) are preserved exactly as stored; the corrected
  rule applies from now on. **Sound Quest counting is unchanged** (one count at the quest's first round).
- Where Am I display unchanged: shown only for completed Sets and Sound Quest cards, and only when above 0.

### Where Am I states
Derived only from the records and the access rules — never from the cursor.

| State | Color | Meaning |
|---|---|---|
| NOT STARTED | `#FFFFFF` | accessible, never actually entered |
| IN PROGRESS | `#F4EEFA` | actually entered, not yet passed |
| COMPLETED | `#E8DCF5` | passed by its Level's criterion |
| LOCKED | `#AAAAAA` + lock | cannot be entered; takes precedence over everything |

- A **Group** is LOCKED only when none of its Sets can be entered, COMPLETED only when every one is passed,
  IN PROGRESS once any has been entered or passed, otherwise NOT STARTED. A **Level** reflects all its Sets
  the same way (its own lock cascade applies on top). Sound Quest cards keep the plain white card.

---

## Background Color Rule (locked)

Locked 2026-09-17. Two separate palettes; never cross them.

### Main gameplay path
The Game scene and its Set Transition scene must use the same Level background color:

| Level | Color | Game scene | Set Transition |
|---|---|---|---|
| Prep | `#A8E063` baby green | `prep_game.gd` | `prep_transition.gd` (hardcoded) |
| Level 1 | `#6EB5FF` sky blue | `game.gd` | `transition.gd` `else` branch |
| Level 1.5 | `#A83A22` deep red-brown | `game15.gd` `BG_COLOR` | `transition.gd` `elif _for_l15` (via `Level15Progress.active`) |
| Level 2 | `#7A8C2E` olive green | `game2.gd` `BG_COLOR` | `transition.gd` `if _for_l2` (via `Level2Progress.active`) |
| Level 2.5 | `#B8631A` burnt orange | not built yet | not built yet |

Level 2.5's `#B8631A` is locked (2026-10-07). Its Game scene and Set Transition do not exist yet; when
they are built, both must use this color. Today it is applied only to Level 2.5's Where Am I level card
(`gnb_where_am_i.gd`, `_build_level_meta()`, replacing the old `#7B68EE` placeholder). It has no Level Intro
copy yet, so `level_intro.gd`'s `LEVEL_DATA` has no entry to color.

`transition.tscn`'s editor-default background (`#A8E063`) is dead data — `transition.gd._ready()`
always overwrites it from the `active` flags. Level 1's sky blue is written as
`Color(0.431, 0.710, 1.0)` in several files with no shared constant; keep the literal identical.

### Sound Quest path — separate palette
Sound Quest never has to use its parent Level's main gameplay color. Each Sound Quest scene owns
its `BG_COLOR`, and **every Sound Quest Set Transition uses the same background color as the Sound
Quest Set it belongs to** — the transition never paints its own background.

| Level | Sound Quest scene | Color | Set/Quest Transition |
|---|---|---|---|
| Prep | `sound_quest.gd` | `#A8E063` | in-scene, inherits |
| Level 1 | `level1_sound_quest.gd` | `#6EB5FF` | in-scene, inherits |
| Level 1.5 Quest A/B | `level15_sound_quest_ab.gd` | `#6EB5FF` | `Level15SoundQuestTransitions` child node, inherits |
| Level 1.5 Quest C/D | `level15_sound_quest_cd.gd` | `#8BD0E1` | same, inherits |
| Level 1.5 Quest E | `level15_sound_quest_e.gd` | `#FEEABA` | same, inherits |
| Level 1.5 Quest F | `level15_sound_quest_f.gd` | `#D3EDD3` | same, inherits |

Level 1.5's color is fixed per Quest *scene* — every Set within a Quest type shares it. The
2026-08-08 change that covered Level 1.5's Short/Long Transitions with main-gameplay `#A83A22`
was wrong under this rule and has been removed; do not reintroduce a cover in
`level15_sound_quest_transitions.gd`. Full Sound Quest detail: `SoundUp_Level1.5_SoundQuest_Design.md`.

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

## Release Scope Gate (locked)

Product-wide framework rule — applies to every Level's Coronation, current and future:

- **Never auto-advance past the highest publicly released Level.** After any Level's
  Coronation finishes, the game continues into the next Level only if that next Level is
  within the current build's public release scope. Otherwise the player returns to the
  Title Scene instead of entering unreleased content.
- **Completion is still recorded** even when advancement is blocked — `SaveManager`'s
  `set_*_completed()` call always happens before the gate check, so the moment a later
  build raises the release scope, players who already finished the gated Level unlock the
  next one immediately. No save migration is ever needed.
- **Where Am I respects the same scope** — a Level beyond the release scope stays locked
  there regardless of actual progression state (shown with the existing padlock treatment,
  not hidden), so there's no second, inconsistent path to reach unreleased content.
- **Generic, not a one-off patch.** Advancing the release scope for a newly-shipped Level
  is a one-line constant change with no other code touched anywhere in the framework.

### Implementation
- `release_scope.gd` (`class_name ReleaseScope`) — `PROGRESSION_ORDER` is the full Level
  sequence in curriculum order **and is the Coronation hand-off chain itself**: the Level
  after a completed Level is simply the next entry (`next_level_id()`); no Level-to-Level route
  is hardcoded anywhere. `HIGHEST_RELEASED_LEVEL_ID` is the single constant to change when a
  new Level ships publicly. `is_level_released(level_id)` is the one function everything else
  calls (it reads the runtime copy `released_boundary_id`, which always starts at the constant;
  only tests assign it, to simulate a later release).
- `ReleaseScope.begin_coronation(level_id)` — called by `prep_transition.gd` and `transition.gd`
  on a Level's first full completion (`ProgressStatus.next_step` → CORONATION): sets that Level's
  completed flag (the guard that stops the Coronation repeating), rewinds its runtime position,
  and sets `LevelTransition.next_level_id` / `level_name` from the chain. It never marks the next
  Level entered; only the Level Intro's Ready button does.
- Coronation exit (`level_transition.gd` → `_route_after_coronation()` →
  `ReleaseScope.coronation_exit_scene(next_id)`): the next Level's Intro if that Level is released
  **and has a scene to enter**, otherwise Title (also after the last Level). The Coronation
  choreography itself is untouched. A Level completed before the next one shipped is entered later
  through Title's forward routing → Intro → Ready, with no Coronation replay.
- Where Am I's lock cascade (`gnb_where_am_i.gd`, `_build_level_meta()`): each of `l15_lock`/`l2_lock`/`l25_lock` independently ORs in `not ReleaseScope.is_level_released(<that level's id>)` alongside its existing progression-based term. Prep and Level 1 are never gated this way — Prep is never locked at all, and Level 1's own lock (`l1_lock`) is purely progression-based, since Level 1 is always in scope for this framework's earliest possible release.

---

## Subscription Entitlement & Premium Gameplay (C7, locked)

Policy: a valid subscription gives premium access; an expired one does not. **Access is whatever Google Play /
the App Store last verified.** No app-managed grace periods, no legacy allowances, no time extensions; a
connectivity problem never creates or extends an entitlement. (Billing grace period, retry and account hold are
the *store's* behavior: the store keeps or drops the subscription and the app only reads the answer.)

**Free vs premium.** Free: Prep Sets A1/A2 and Prep Sound Quest A. **Premium: everything else** — every other
Prep Set and Prep Sound Quest, and **all of Level 1, 1.5, 2, 2.5 and every future Level and Sound Quest**.

**`EntitlementService`** (`entitlement_service.gd`, hosted as a child of the `SaveManager` autoload — no new
autoload, `project.godot` untouched; reach it with `SaveManager.entitlement()`):
- `SaveManager.is_subscribed()` is the single choke point = "the store said ENTITLED this session". A fresh launch
  is UNVERIFIED (no premium) until the store answers; the saved `subscribed` key is never evidence.
- Verified at launch, on app resume, on entering premium gameplay, every 15 min while entitled, on
  purchase/restore/transaction events, and on explicit Restore. Android: `BillingClient.query_purchases(SUBS)`;
  iOS: StoreKit 2 `ProductInfo.is_purchased`; Restore calls the real `AppStore.sync()`.
- An answer is ENTITLED, NOT_ENTITLED, or UNKNOWN. **UNKNOWN (offline, store error, time-out) changes nothing and
  interrupts nothing** — it is not confirmed loss. Requests are generation-numbered: only the latest generation
  may change state, and an answer issued before a purchase/restore/refund event is discarded and re-asked. The
  first NOT_ENTITLED right after an event-confirmed entitlement is verified once more. No silence timers.
- **One shared** `BillingClient` / `GDScriptStoreKit2` for the whole app (a second instance double-fires native
  callbacks). `choose_plan.gd` only attaches its UI handlers and detaches in `_exit_tree`.
- Restore always asks the store: ENTITLED → continue; NOT_ENTITLED → "No Purchases Found"; UNKNOWN →
  "Couldn't Check Purchases" (try again).
- `DebugConfig.DEBUG_MODE` (false in every committed build) entitles desktop builds that have no store.

**`PremiumGameplay`** (`premium_gameplay.gd`): registry `SCENE_PATHS` of the 11 premium gameplay scenes
(`prep_game`, `sound_quest`, `game`, `level1_sound_quest`, `game15`, `level15_sound_quest_ab/cd/e/f`, `game2`,
`game25`), plus `level_scene_admitted()`, `join()`, `refuse()`, `route_to_paywall()`.
- **Entry guard**: each Level scene's `_ready()` starts with `level_scene_admitted()` (verified subscription, or a
  QA `DebugConfig.debug_launch`); Prep scenes keep their access check and add the group join only for premium
  content. A refused entry writes nothing and goes to the subscription flow.
- **Interruption**: on a confirmed loss, every scene in group `premium_gameplay` runs
  `interrupt_for_entitlement_loss()` — stops immediately (does not wait for the Set / Quest to end), locks input,
  stops audio, clears any retry state, and routes to `premium_intro.tscn` (`CONTEXT_PREMIUM_LOCKED`). It never
  terminates the app. **Nothing is written**: the interrupted attempt is not recorded complete and not counted;
  records, resume cursor and ×N counts are preserved. A registered scene that forgot the method is still routed
  by the service. Free Prep content and Set Transitions are never interrupted.
- After subscribing or Restoring, access returns and the subscription flow goes back to Where Am I.
- **New Level or Sound Quest scene: add its path to `SCENE_PATHS`, add the entry guard, join the group, and
  implement `interrupt_for_entitlement_loss()`** (the C7 test scans `*.tscn` and fails on an unregistered one).
- Where Am I locks every Level tile (and so every Sound Quest card) without a verified subscription and re-renders
  when `entitlement_changed` fires; Title waits (bounded) for the launch check, and sends a lapsed player to free
  Prep content instead of Level 1+; Level Intro refuses to mark a Level entered without a subscription.

## Planned / Pending

- **Glide companion app** (separate project, new chat): same phoneme sounds but with letters shown — for parents/adults/kids who want to see written words. Mirrors SoundUp's Prep + Level 1 sound sets.
- **Level 1 persistent save**: Level 1 progress save across app restarts (in progress).
- **Transition scene rename**: `prep_transition` → `prep_set_transition`, `transition` → `level1_set_transition` (deferred).
- **Tablet end-to-end test**: all 17 Level 1 sets on device (deferred).
- **Level 2+**: not yet designed.
- **Subscription entitlement (C7) — implemented and verified on Windows only; physical-device verification is
  still REQUIRED before the Level 1.5 release.** See Subscription Entitlement & Premium Gameplay. Device checks:
  active / cancelled-but-paid / expired / refunded / grace / hold on both stores, offline launch (iOS product
  lookup needs the network → UNKNOWN → no premium until online), the shared Android client reconnect, the
  resume notification, iOS Restore through the real `AppStore.sync()`, and the Android purchase dictionary keys
  (`product_ids`, `purchase_state`).

## Update — June 2026
Companion app renamed: Glide → SoundBuddy
SoundBuddy planning complete. See sound-buddy/CLAUDE.md for full spec.
