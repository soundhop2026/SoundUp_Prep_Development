# SoundUp — Prep Level & Level 1 Detail Reference
Last updated: June 2026

---

# Title Scene

## Purpose
Entry point of SoundUp. Routes the child to Prep or Level 1 depending on save data.

## Files
- Scene: `res://title.tscn`
- Script: `res://title.gd`

## Visual Design — "One Character" Layout
```
 S O U N D U P   ← hair (arc of amber letters)
     😊          ← head (PlayButton face, cream beige)
 Start with Sounds  ← shoulders (amber words)
```
- Background: deep purple `#4B0082`
- Letters + subtitle: amber `#FFB703`
- PlayButton face: cream beige `#F5E6CC` (applied via cream shader — not modulate)

## Animation Sequence
1. Letters appear scattered across upper screen, all invisible
2. All 7 letters fade in simultaneously (0.5s)
3. 0.7s pause → birds-flocking drift begins (each letter drifts independently, ±18° rotation, 1.1–2.0s per move)
4. After 3.0s of drift, letters land one by one S→O→U→N→D→U→P (0.65s stagger, 0.85s ease-out-back per letter)
5. "Start", "with", "Sounds" fly up from below one by one (0.5s tween, 0.5s stagger each)
6. 3-second hold — button not active during entire intro
7. `_can_press = true` — PlayButton now active

## On Play Pressed
- Letters scatter away, words slide off screen
- **Routing:**
  - `SaveManager.is_prep_completed()` → `game.tscn` (Level 1)
  - else → `prep_game.tscn` (Prep Level)

---

# Prep Level

## Purpose
Two goals before Level 1:
1. **Sound discrimination** — train the ear to hear and distinguish phonemes
2. **Vocabulary foundation** — ensure kids know the names of Level 1 images

If a child does not recognise the images in Prep, they will struggle in Level 1.

## Files
- `prep_game.tscn` / `prep_game.gd` — Prep gameplay
- `prep_transition.tscn` / `prep_transition.gd` — Between sub-sets
- `level_transition.tscn` / `level_transition.gd` — Graduation to Level 1 (once per lifetime)
- `PrepLevelProgress` autoload

## Visual Theme
- Background: baby green `#A8E063`
- Art style: hand-drawn black-and-white sketches (same images as Level 1)

## Format — Auto-Play
Unlike Level 1, Prep auto-plays sounds. No deliberate press required.
- Phoneme plays ×3
- Image names play ×2
- Pointed hand guides the child throughout
- Child never needs to press LISTEN — this scaffolds attention before introducing deliberate action

## 33 Sub-sets in 7 Main Groups

| Group | Indices | Phonemes | Choices |
|-------|---------|----------|---------|
| 1A | 0–3 | M S T B V K | 3 |
| 1B | 4–7 | N F P D G J | 4 |
| 1C | 8–13 | H W Y L R Z | 4 |
| 1D | 14–19 | Contrast pairs (all previous) | 4 |
| 1E | 20–23 | C-soft G-soft X Q | 3 |
| 1F | 24–27 | All sounds mixed | 5 |
| 1G | 28–32 | Ending sounds | 4 |

Main set boundaries (last sub-set index of each group): `[3, 7, 13, 19, 23, 27, 32]`

## Gate — 85% "Gain and Move" (per sub-set)
- ≥ 85% → pass, advance to next sub-set
- < 85% → retry only the wrong rounds from that sub-set; loop until ≥ 85%
- Mastery is enforced at every sub-set, not globally

## PrepLevelProgress Static Vars
| Var | Purpose |
|-----|---------|
| `current_index` | Current sub-set (0–32) |
| `last_score_pct` | Accuracy % from last sub-set |
| `cubes_earned` | Main-set cubes earned so far (0–7) |
| `retry_rounds` | Wrong round dicts for current retry |
| `is_retry` | True when in wrong-round replay mode |
| `MAIN_SET_BOUNDARIES` | Const `[3, 7, 13, 19, 23, 27, 32]` |

## prep_game.gd — _do_level_complete()
Sets `last_score_pct` and `retry_rounds`, then always routes to `prep_transition.tscn`.
No routing logic inside prep_game — all routing is handled by prep_transition.

## 7-Cube Board (prep_transition.gd)
- 7 cubes in a single row, centred at x=640, y=625, 80px spacing
- Faint (0.25 alpha) until earned; full opacity when earned
- **Only shown** when: it is a main set boundary AND `last_score_pct >= 85%`
- Between sub-sets: bounce animation only — cube board not visible
- Newly earned cube dances; all previously earned cubes also dance

## prep_transition.gd — Routing Logic
1. Always play bounce animation (×6, ~3s)
2. Fade in result labels
3. If `last_score_pct < 85%` → set `is_retry = true` → back to `prep_game.tscn`
4. If `last_score_pct >= 85%`:
   - If main set boundary → award cube, dance, then advance
   - Advance `current_index` → back to `prep_game.tscn`
   - If no next sub-set (after 1G last) → route to `level_transition.tscn` (graduation)

**CRITICAL:** `has_next()` must be checked BEFORE `advance()`. Reversed order silently routes to title instead of next sub-set.

## level_transition.tscn — Graduation (once per lifetime)
- Cream background `#EDE4D3`, gold/purple palette
- Crown descends onto PlayButton face — coronation moment
- ~13s sequence: 2s still → crown descends + music → 4s celebration → 3s admire
- "Ready to Play" button → routes to `game.tscn` (Level 1)
- Music: `BGM&effect/SoundUp_level_transition_bgm.wav`

## Save Data
- `prep_completed` (bool)
- `prep_set_index` (int) — current sub-set index
- Save file: `C:\Users\user\AppData\Roaming\Godot\app_userdata\SoundUp_Prep_Development\soundup_save.json`

---

# Level 1 — Consonant Isolation

## Purpose
Child hears a phoneme and picks the matching image from a row of choices.
New concept introduced: a sound can be isolated and matched to a picture.

## Files
- `game.tscn` / `game.gd` — Level 1 gameplay
- `transition.tscn` / `transition.gd` — Between sets (shared with Level 1.5)
- `LevelProgress` autoload (`level_progress.gd`)

## Visual Theme
- Background: sky blue `#6EB5FF`
- Art style: hand-drawn black-and-white sketches (same as Prep)

## Format — Deliberate LISTEN Press
Unlike Prep, nothing auto-plays. The child must press LISTEN to hear the phoneme.
This is intentional: the LISTEN press is the moment of deliberate attention.
The pointed hand appears as an idle hint only — it never auto-plays for the child.

## 17 Sets, 331 Rounds

| Set | File | Phonemes | Choices | Rounds |
|-----|------|----------|---------|--------|
| 1A-1 | level_1a_1.json | m s t b k v | 3 | 20 |
| 1A-2 | level_1a_2.json | m s t b k v | 3 | 20 |
| 1B-1 | level_1b_1.json | n f p d g j | 4 | 20 |
| 1B-2 | level_1b_2.json | n f p d g j | 4 | 20 |
| 1C-1 | level_1c_1.json | h w y l z r | 4 | 20 |
| 1C-2 | level_1c_2.json | h w y l z r | 4 | 20 |
| 1C-3 | level_1c_3.json | h w y l z r | 4 | 20 |
| 1D-1 | level_1d_1.json | contrast pairs | 4 | 19 |
| 1D-2 | level_1d_2.json | contrast pairs | 4 | 19 |
| 1D-3 | level_1d_3.json | contrast pairs | 4 | 18 |
| 1E-1 | level_1e_1.json | c-soft g-soft x q | 3 | 20 |
| 1E-2 | level_1e_2.json | c-soft g-soft x q | 3 | 20 |
| 1F-1 | level_1f_1.json | all 21 mixed | 5 | 20 |
| 1F-2 | level_1f_2.json | all 21 mixed | 5 | 20 |
| 1G-1 | level_1g_1.json | ending sounds | 4 | 19 |
| 1G-2 | level_1g_2.json | ending sounds | 4 | 18 |
| 1G-3 | level_1g_3.json | ending sounds | 4 | 18 |
| **Total** | | | | **331** |

## Phoneme Coverage
| Group | Phonemes |
|-------|---------|
| 1A | m, s, t, b, k, v |
| 1B | n, f, p, d, g-hard, j |
| 1C | h, w, y, l, z, r |
| 1D | contrast pair review (no new phonemes) |
| 1E | c-soft, g-soft, x-ks, x-gz, q |
| 1F | all 21 mixed (5-choice) |
| 1G | ending sounds — 11 phonemes (m n p b t d k g f v s) |

## Audio / Asset Folder Naming Conventions
| Asset | Path convention |
|-------|----------------|
| Word audio | `res://BGM&effect/SoundUp_level1_word sounds/` |
| Word images | `res://SoundUp_level1_word images/` |
| Phoneme audio | `res://BGM&effect/SoundUp_level1_phonemes/` |
| g-hard | Image: `G-hard/` (dash) · Audio: `G_hard.wav` (underscore) |
| x-ks | Image: `X-ks/` · Audio: `X_ks.wav` |
| x-gz | Image: `x-gz/` · Audio: `X_gz.wav` |
| c-soft | Image: `c-soft/` · Audio: `C_soft.wav` |
| g-soft | Image: `G_soft/` · Audio: `G_soft.wav` |
| c-hard | Image: `C-hard/` |

## Gate — Three-Star System
| Score | Stars | Action |
|-------|-------|--------|
| ≥ 95% | 3★ | Advance to next set (earn cube) |
| 85–94% | 2★ | Retry only wrong rounds |
| ≤ 84% | 1★ | Replay full set from scratch |

## LevelProgress Static Vars
| Var | Purpose |
|-----|---------|
| `current_index` | Current set index (0–16) |
| `last_score_pct` | Accuracy % from last set |
| `retry_rounds` | Wrong round dicts for 2★ retry |
| `is_retry` | True when loading wrong rounds only |

## game.gd — Scoring System
- `clean_correct_count` — rounds answered correctly with NO prior wrong click
- `_round_hint_used : bool` — set true ONLY in `_do_wrong()` (wrong click is the only penalty)
- `_assisted_rounds : Array` — collects round dicts where `_round_hint_used` was true at correct answer
- Formula: `mastery_accuracy = clean_correct_count / rounds.size() * 100.0`

**What does NOT set `_round_hint_used` (penalty-free):**
- Pressing LISTEN again
- Taking time to think
- Pointed hand appearing
- Any image hint
- EvalPlayButton appearing

## game.gd — Key Features
- **Shuffle:** No consecutive same phoneme within a set (`_shuffle_no_consecutive()`)
- **Back button:** Position (108, 25), always visible. Goes back one round; clears hint state for that round. Disabled if `result_locked` or `round_index == 0`.
- **Retry loading:** If `LevelProgress.is_retry = true`, `_load_rounds()` loads `retry_rounds` instead of JSON

## 17-Cube Board (transition.gd — Level 1 branch)
- 17 cubes, deep blue, single row
- Earned ONLY on 3★ (≥ 95%)
- Cube board shows every set; only earned cubes light up

## transition.gd — Level 1 Branch

**Full celebration sequence:**
1. 0.4s pause — 2-track music starts immediately
2. Stars dance wildly (gold, all 3, concurrent with pulse+bounce)
3. PlayButton heartbeat pulse ×10 (BASE→PEAK→BASE, 0.10s grow / 0.08s shrink)
4. PlayButton rubber-ball bounce ×10 (180px up, flash+shake on each landing)
5. Stop star dance (0.40s settle)
6. Slot machine: 30 bitmask states (10 cycles), slow→fast, sudden stop + big flash
7. Stars hidden briefly (0.35s)
8. Final reveal: earned stars only, centred, drop in from above with impact flash+shake
9. POP ×10 (first 5 fast 0.10s, last 5 slow 0.14s, scale 1.0→1.8→1.0)
10. 5-second hold
11. Track 1 finishes → track 2 plays → track 2 finishes → routing

**Music:**
- Track 1: `res://BGM&effect/transition_fanfare.wav`
- Track 2: `res://BGM&effect/transition_fanfare_2.wav`
- Zero gap between tracks

**Routing:**
| Stars | Action |
|-------|--------|
| 3★ | Advance to next set (or title if last set) |
| 2★ | `is_retry = true` → `game.tscn` loads only wrong rounds |
| 1★ | `is_retry = false`, `retry_rounds.clear()` → `game.tscn` replays full set |

**CRITICAL:** `has_next()` must be checked BEFORE `advance()`.

**Key constants:**
```
BASE_SCALE = 0.80    PULSE_SCALE = 1.76
BOUNCE_UP = -180px   BOUNCE_LAND = +25px
PlayButton position: Vector2(640, 290)
Star display size: 220px
Star lottery positions: (440,490), (640,490), (840,490)
```
