# Level 1.5 Sound Quest — Design Reference

Implementation-accurate reference for the six Sound Quest types (A–F) and the two Set
Transitions (Short/Long) inside Level 1.5. This is separate from `SoundUp_Level1.5_Design.md`
and `SoundUp_Level1.5_Design_1.md`, which are the original curriculum-level drafts — those cover
the pedagogical goal of Level 1.5 as a whole; this doc covers what Sound Quest specifically *is*,
as built, kept current with the code. See `Worklog.md` for the session-by-session history of how
it got here (the 2026-08-06 and 2026-08-08 entries cover almost all of it).

**Philosophy compass** (same as the rest of SoundUp — see `CLAUDE.md`): sound before letters, no
letters ever, no auto-play — every tap is a deliberate press.

---

## System overview

```
Group's last-but-one Set completes
    ↓
Quest A (initial-ID) → Quest B (final-ID) → Short Transition between each internal Set,
    ↓                                        Long Transition on each Quest type's own final Set
Quest C (initial isolation) → Quest D (final isolation)
    ↓
Quest E (build-the-word)
    ↓
Quest F (sound-count)
    ↓
back into game15.gd / Level15Progress (NOT YET WIRED — see "Open architecture gap" below)
```

Each pair (A/B, C/D) is one scene with a `position` flag ("initial"/"final") switching which
word field drives the target; the second half is reached by reloading the same scene with the
flag flipped. E and F are each their own scene. All four scene scripts instantiate
`Level15SoundQuestTransitions` as a child and call `play_short()` / `play_long()` at Set
boundaries — see the [Transitions](#short--long-set-transitions) section.

Shared data layer: `level15_sound_quest_state.gd` (static functions only, no state) reads
`data/words.json` (130 words) and `data/phonemes.json`, and provides pool-building,
target-schedule, and distractor helpers used across all six Quest types.

**Open architecture gap** (unchanged since 2026-08-06, not addressed 2026-08-08): the handoff
between Quest types (B→C, D→E, F→back into `game15.gd`) is a stubbed `print()` in each scene's
`_on_quest_complete()`. There is no in-game path from one Quest type to the next yet — every
Quest type can currently only be reached by launching its scene directly
(`godot --path . res://level15_sound_quest_XX.tscn`), bypassing the title screen. This needs a
real design conversation (which Group triggers which Quest type, and when) before it's built —
flagged, not started.

---

## Quest A / B — Initial / Final Identification

`level15_sound_quest_ab.gd` / `.tscn`. Not touched 2026-08-08 (verified working). BG color: sky
blue `Color(0.431, 0.710, 1.0, 1.0)`.

- Faint target image (`TARGET_SIZE 220x220` at `TARGET_POS (530, 40)`, alpha 0.12) reveals via an
  NxM patch grid as correct words are dragged in.
- Scattered word pool (correct + distractors) below; tap a face to hear its word, drag onto the
  faint image to check.
- 4 Sets × 8 rounds = 32 total (Quest A); 5 Sets × 8 rounds = 40 total (Quest B).
- Target-word selection: `Level15SoundQuestState.words_for_phoneme()` then random pick; correct
  pool floor/ceiling 3–10 words per round (all used if ≤10, fresh random 6–10 subset if the
  phoneme has more).

---

## Quest C / D — Initial / Final Isolation

`level15_sound_quest_cd.gd` / `.tscn`. **Substantially rebuilt 2026-08-08** — the 2026-08-06
version had no way for a child to know the round's target phoneme at all (bubbles are
audio-only by design; nothing announced what to listen for). BG color: light cyan
`Color(0.545, 0.816, 0.882, 1.0)`.

### Layout (top to bottom)
| Element | Position | Size |
|---|---|---|
| Target image | `(565, 50)` | `150x120` |
| Play Button | `(565, 180)` | `150x72` (10px gap below image) |
| Bubble field | starts `y=330` | spans `x: 60–950`, `y: 330–700` |

Bubble field's top boundary sits 78px below Play Button's bottom edge (`180+72=252`) —
deliberately generous so rising bubbles never visually crowd Play Button (an earlier 18px buffer
read as bubbles "auto-popping on their own" near it).

### Interaction (both tap-anytime, no auto-play)
- **Tap target image** → plays the target word's audio (e.g. "mop"). Word is picked fresh each
  round via `words_for_phoneme()`.
- **Tap Play Button** → plays the target phoneme in isolation — resolves the initial-vs-final
  ambiguity a raw word alone can't ("is it the beginning or ending sound of mop?").
- **Drag a bubble to Play Button**: correct → pops in place (quick scale+fade, `POP_SCALE 1.35`,
  `POP_DUR 0.14`) — the phoneme's own audio IS the feedback, no separate chime — then a fresh
  distractor bubble rises from the bottom so the field never visibly thins out. Wrong → silent
  bump-away (`24px` push, resist-twice), never destroyed.
- Bubbles rise at `20px/sec`, loop back to the bottom if uncollected.

### Round-complete: signature "piggyback ride" ending
Deliberately distinct from every other Quest's exit (Quest F rolls; reusing that for C/D was
tried and explicitly reversed — each Quest keeps its own personality):
1. Target image + Play Button both breathe 3x together (`BREATHE_SCALE 1.08`, `BREATHE_DUR 0.6`).
2. Play Button hops up (`JUMP_UP_DUR 0.6`) and lands on the image's own topmost point —
   **computed per-round from the actual image pixels**, not a fixed spot (see below).
3. Target image reacts with a tiny squash (`SQUASH_SCALE (1.08, 0.85)`, `0.12s`) and recovers.
4. Play Button is reparented onto the target image (so it moves as part of the image's own
   transform) and the pair waddles off together (`WADDLE_DUR 2.4`, `WADDLE_SWAY 14°`, reused from
   Quest F's own waddle tier) to `WALK_OFF_X 1450`.

**Per-image landing-spot detection**: every round shows a different word's image (a mop, a pump,
a lion cub...), each with a different shape, so one fixed landing spot only looked right on
roundish/centered images. `_find_tip_landing_pos()` loads the actual texture, scans for the
topmost non-transparent pixels (averaged across a few rows for stability, not one stray pixel),
and maps that source-pixel coordinate through the same scale+letterbox math
`STRETCH_KEEP_ASPECT_CENTERED` uses, so the computed point matches where the tip actually renders
inside `TARGET_SIZE`. Falls back to bounding-box center-top if a texture's pixel data isn't
readable (`tex.get_image()` returns null).

`playbutton.png` itself has real vertical padding — its drawn face content only spans **80.1% of
its texture height** (measured directly: content stops at pixel row 350 of 437), so anchoring by
the padded bounding box left a visible gap between Play Button's visible chin and the tip.
`PLAYBUTTON_CONTENT_BOTTOM_FRAC = 350.0/437.0` corrects for this. `TIP_SIT_OVERLAP = 6.0`px is a
small additional overlap so it reads as sitting *on* the tip, not balanced exactly at its edge.

### Structure
Locked 2026-08-06: 4 Sets × 14 rounds = 56 rounds each for both C and D. Every phoneme is a
valid target (no floor, unlike A/B) since bubbles are repeated audio copies of a phoneme, not
distinct words. Target bubble count linear-scaled 4–10 by phoneme word-frequency; bubble pool
fixed at 20 total (distractor count = 20 − target count).

---

## Quest E — Build the Word

`level15_sound_quest_e.gd` / `.tscn`. Minor fixes only 2026-08-08. BG color: cream/tan
`Color(0.996, 0.918, 0.729, 1.0)`.

- Target image top (`TARGET_POS (560, 20)`, `TARGET_SIZE 140x110`) — **tap anytime to hear the
  word** (fixed 2026-08-08; was previously wired for nothing, no-op on tap).
- Ladder (two stretched rail instances + rung images filling in) on the left, Play Button waiting
  below it; 12-branch bobbing phoneme pool on the right — correct = the word's own ordered
  `phonemes[]`, one branch per occurrence (e.g. "skunk" spawns two separate k-branches).
- Order enforced live: a mismatched branch (distractor OR a correct-word phoneme out of turn)
  bounces back, never destroyed.
- Round-complete: Play Button climbs the ladder rung-by-rung
  (`CLIMB_HOP_DUR 0.8`, slowed twice from an original `0.3` per live feedback — "each rung climb
  should read clearly, not flash by"), touches the image (word audio plays), hops beside it, and
  they walk off together (`WALK_OFF_DUR 2.2`, slowed from `1.1` — "shouldn't feel rushed"). Play
  Button's size stays fixed to the target image's size for the whole round (visually paired once
  walking).
- Structure: 10 Sets × 10 rounds = 100 rounds, covering all four word structures (CVC–CCVCC),
  drawn from the ~130-word pool. No-letters/audio-only confirmed for the ladder rungs (generic
  shape, phoneme told apart by tap-to-hear only, same as Quest C/D's bubbles).

---

## Quest F — Sound Count

`level15_sound_quest_f.gd` / `.tscn`. **Two real bugs fixed 2026-08-08**, plus reactive-animation
and pacing polish. BG color: pale green `Color(0.827, 0.929, 0.827, 1.0)`. The one Quest type
where the target is a NUMBER (3, 4, or 5 phonemes), not a specific phoneme or word — matching is
"does this word have the same sound-count," judged by the whole word's own audio.

### Bugs found and fixed
1. **Round-breaking bug**: the round's target-example word was picked FROM the correct pool but
   never removed from it, so it appeared twice (once as intended reference, once as a duplicate
   draggable choice) — and the round's required catch-count still included it even though the
   visible pool now offered one fewer choice than that total required, meaning some rounds could
   never mathematically complete. Fixed: `_correct_pool.erase(_target_word)` at selection time
   (word is now purely a reference, not also a choice).
2. **Pre-existing spawn-overlap bug** (unrelated to anything built in this session, just never
   caught before live testing): the word pool's vertical spawn range (`POOL_Y_MIN`/`MAX`) was
   never fenced off from the drop zone above it (`DROP_ZONE_POS.y=260` to `323`) — a word's
   bounding box could land with its top edge inside the tray purely by chance. Fixed by raising
   `POOL_Y_MIN` to `390` (78+ clear of the drop zone's bottom edge) and extending `POOL_Y_MAX`
   down to `660` to keep 20 words packable in the reduced vertical range.
3. **Spacing math gap**: `MIN_SPACING` (100) was a straight-line center-to-center distance, which
   doesn't guarantee two 90×90 square boxes never overlap — the worst case (diagonal alignment)
   needs the box's own diagonal (`90×√2 ≈ 127.3`) as minimum separation. Raised to `130`.

### Layout
| Element | Position | Size |
|---|---|---|
| Play Button | center `(640, 160)` | base `150x72`, grows 30%/eaten word, cumulative |
| Drop zone | `(490, 260)` | `300x63` (hit-test grown by 60px margin on all sides — see below) |
| Word pool | `x: 40–1240` (center 640, ±600), `y: 390–660` | `90x90` each |

### Interaction
- **Tap Play Button** (any size, hit-test accounts for current grown scale) → plays this round's
  target word's audio. Replaced two earlier attempts at a separate target image (corner, then
  above Play Button) — both ran into real layout problems (Play Button's own growth ate into
  whatever space was reserved above it); tapping Play Button itself sidesteps that entirely, same
  fix pattern as Quest C/D.
- **Drag a word to the drop zone**: correct (matching phoneme count) → Play Button hops to meet
  it (`EAT_HOP_HEIGHT 20`, `EAT_HOP_DUR 0.3` — previously only the word moved, Play Button sat
  static), "nom" sound, word consumed, Play Button grows. Wrong → Play Button flinches
  (`REJECT_RECOIL_ANGLE 12°`, `0.3s` — previously only the word resisted) + "bleh" sound, word
  bounces back, never destroyed.
- **Drop-zone hit-test is generous**: grown by a flat 60px margin beyond the visual tray graphic
  (`Rect2(...).grow(60.0)`) — a kid dropping a word anywhere reasonably near the tray counts, not
  just pixel-precise on its drawn line (found live: a child naturally drops "in the tray," not
  exactly on its bottom bracket line).

### Round-complete exit tiers
1–4 eaten = hop, 5–7 = waddle, 8+ = roll (`ROLL_DUR` slowed `1.0→2.2`, "make the playbutton roll
slowly"). **Known gap, not yet resolved**: since a round only completes after eating the ENTIRE
correct pool (always ≥8 words), the hop/waddle tiers may rarely or never actually fire in real
play — only "roll" is reliably reachable under the current "collect everything" completion rule.
Flagged 2026-08-06, still unconfirmed whether that's intended.

### Structure
10 Sets × 10 rounds = 100 rounds. Target distribution proportional to real bucket size (54 target
3-phoneme, 36 target 4-phoneme, 10 target 5-phoneme). Correct pool: up to 14 for 3-/4-count
buckets, randomized 8–10 for the thin 5-count bucket (deliberately capped — verified via
simulation that using the full bucket every time flattens word variety to zero).

---

## Short & Long Set Transitions

`level15_sound_quest_transitions.gd` — `class_name Level15SoundQuestTransitions`, instantiated
as a child by every Quest scene, called via `play_short()` / `play_long()`. **Both rebuilt
2026-08-08.**

### When each plays
- **Short**: every Set boundary WITHIN a Quest (e.g. A1→A2, A2→A3, A3→A4).
- **Long**: a Quest type's FINAL Set boundary only (e.g. A4's completion) — Short does NOT also
  play there, mutually exclusive per boundary. Plays once per Quest type (A–F), 6 times total
  across all of Sound Quest.
- **Background rule (locked 2026-09-17): every Set Transition — Short and Long — uses the same
  background color as the Sound Quest Set it belongs to.** The component never paints its own
  background; the calling Quest scene's `BG_COLOR` shows through (A/B `#6EB5FF`, C/D `#8BD0E1`,
  E `#FEEABA`, F `#D3EDD3` — one color per Quest *scene*, no per-Set variation). This supersedes
  the 2026-08-08 request to cover both transitions with `game15.gd`'s main-gameplay `#A83A22`;
  that cover has been removed. Sound Quest has its own palette, separate from the parent Level's
  main gameplay color — see the "Main Game vs Sound Quest color" rule in `CLAUDE.md`.

### Short Transition
Play Button (`SHORT_SIZE 288x288` — 6x-then-shrunk-70% from an original `160x160`, net 1.8x)
hops across the screen left to right in 8 bounces (`SHORT_HOP_COUNT`) over 5 seconds
(`SHORT_DUR`, slowed from an original `1.4` — "slowly slowly... slowly"). No target/bubble
content shown, just the hop.

### Long Transition
**Rebuilt 2026-09-17 — the earlier "courage story" is deprecated and deleted.** (Large Play Button
hesitating toward a waiting crowd of smaller Play Buttons, talk / breathe / group dance / group
hop-off exit, `quest_level15_bgm.mp3` — all gone. That version had itself drifted through several
wrong turns on 2026-08-08: an interim Louis-face crowd, a dropped group, a bridge whose asset was
a placeholder line. See `Worklog.md` 2026-08-08 for that history; none of it is current.)

Current choreography is deliberately minimal — **ENTER LEFT → HOP ACROSS → EXIT RIGHT**:

1. One Play Button (`LONG_SIZE 360x173`, true aspect of `playbutton.png`'s 907x437) starts fully
   off-screen left (`x = -LONG_SIZE.x`), centred vertically on `LONG_GROUND_Y 400`.
2. Travels continuously left → right in a single linear `position:x` tween over `long_dur 8.0s`
   (4 bars of the BGM — see below), ending at the real viewport width
   (`SceneBackground.viewport_size().x`, not a hardcoded 1280 — so it fully exits on
   wider-than-16:9 phones too).
3. While travelling, a looping `position:y` tween hops it up and down the whole way
   (`LONG_HOP_HEIGHT 70`, `LONG_HOP_PERIOD 0.5s`, sine ease out/in). The hop and travel tweens
   act on different sub-properties, so they never fight.
4. Once the travel tween finishes the hop tween is killed and the node freed.

**BGM**: `soundquest/assets/quest_level15_bgm.mp3` starts with the crossing. Timing is
music-derived, not arbitrary — librosa analysis 2026-09-17: 30.77s, 120.2 BPM dead steady, 4/4 →
beat 0.499s, bar 1.997s, downbeats at 1.93 / 3.91 / 5.92 / **7.92** / 9.91 …; key G major, opening
harmony V | I | I | IV | **I** …; entry accent and brightness jump at 3.9s, main body 8–21s, V→I
cadence and wind-down at 21.9s, quiet outro from 23.9s.
- `long_dur 8.0` — 4 bars. Play Button exits on the bar-5 downbeat, the IV→I plagal return to G
  that closes the opening phrase. (The first-pass 6.0s exited on bar 4 = the C/IV chord at near-peak
  loudness — the most unresolved bar line in the opening, which is why it felt cut short.)
- `long_bgm_fade_lead 0.0` / `long_bgm_fade_len 0.5` — the fade **starts on** the exit downbeat
  and lasts one beat, so the arrival chord is heard at full volume and tails off after the button
  is gone; `play_long()` returns after the tail (8.5s total). Fading *through* the cadence instead
  would have muted the very chord that resolves it.
- `LONG_HOP_PERIOD 0.5` = exactly one beat, so the hops are beat-locked; keep any future
  `long_dur` a whole number of bars (multiple of 2.0s).
- Other valid endpoints if this is ever revisited: 10.0s (5 bars, tonic, no event) or 22.0s
  (11 bars, the track's own cadence). 16.0s is *not* — it's a half cadence on D.
- Implementation note: with `lead == 0` the fade timer and travel tween end on the same frame;
  `play_long()` guards `await travel.finished` with `is_running()` so it can't hang if the tween
  got there first.

The three timing values are per-instance `var`s (not `const`) so the throwaway harness can A/B an
endpoint through the exact code path the Quest scenes use; Quest scenes never set them.

No crowd, no hesitation, no background cover — nothing else, by design. Further beats are added
only on explicit request.

**Throwaway test harness**: `level15_long_transition_test.tscn` / `.gd` — instantiates the
component alone and loops `play_long()` forever at the production defaults (Esc quits). Background is Quest A/B's `#6EB5FF`,
i.e. it represents the Long as triggered from Quest A/B; not part of the game, safe to delete.
Run: `/Applications/Godot.app/Contents/MacOS/Godot --path . res://level15_long_transition_test.tscn`

---

## Reused idioms (for consistency in future Quest-type work)

- **Word/target images**: `res://SoundUp_level1.5_word_images/{word}.png`,
  `res://BGM&effect/SoundUp_level1.5_word_sounds/{word}.wav` — flat, organized by whole word (A/B,
  C/D, E, F all use these directly).
- **Pop/consume feedback**: quick scale-up + fade (Quest C/D's bubble pop, `POP_SCALE`/`POP_DUR`)
  reads better than a fade-only removal for something being "consumed."
- **Hop-while-advancing**: alternate up/down `Vector2` position tweens per discrete step (used in
  Quest E's ladder climb history, Quest F's exit hop tier, and the Short Transition) — simpler and
  more reliable than trying to sync a continuous hop curve to a continuous horizontal tween.
  The one exception is the rebuilt Long Transition (2026-09-17), which *does* run a continuous
  linear `position:x` tween with a separate looping `position:y` hop tween — that works cleanly
  there because the two tweens touch different sub-properties and the travel is a single
  uninterrupted line, no per-step targets to keep in sync.
- **Breathing**: `scale` tween to ~1.08–1.18x and back, `TRANS_SINE`/`EASE_IN_OUT`. Intensity
  scales with the moment — gentle (1.08) for patient waiting, energetic (1.18) for active
  celebration.
- **`get_meta()` gotcha**: `node.get_meta("key", default)` still logs an error to the console if
  the key was genuinely never set on that node — always guard with `node.has_meta("key")` first
  when a node might legitimately never have had the meta set (first hit in `level15_sound_quest_ab.gd`,
  re-hit in the since-deleted 2026-08-08 Long Transition crowd code).
- **Per-texture pixel measurement over guessed coordinates**: when a layout depends on an asset's
  actual visible content (not just its bounding box — Quest C/D's per-image tip detection,
  `playbutton.png`'s content-padding fraction, the Long Transition bridge's now-removed arc
  shape), write a small headless Godot script that loads the real texture and scans pixel alpha
  values rather than eyeballing numbers from a screenshot.
