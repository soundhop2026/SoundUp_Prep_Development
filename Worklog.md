# SoundHop — Worklog

Living record of work sessions, kept in git so work can continue seamlessly between machines
(Windows and Mac) — Claude Code sessions themselves don't carry over across machines, but this
file does. Newest entries at the top. See `CLAUDE.md` for the standing project reference and
locked design rules; this file is for session-by-session history and handoff notes instead.

**Entry format** — each dated entry uses this structure:

```
## YYYY-MM-DD

### Completed
- what actually got done, finished and verified

### Decisions
- any call made along the way and the reasoning, especially non-obvious ones

### Risks / Gotchas
- anything that could trip up a future session (on either machine)

### Next Session
- what's still open, what to pick up next
```

---

## Before switching machines — read this first

**Everything in git is portable. A few things are not, and need separate handling:**

- **Production keystore** (`learningsounds-upload.jks`) — deliberately kept **outside** the
  repo (`C:\Users\user\AndroidKeystores\soundhop-learningsounds\` on this Windows machine) so it
  can never end up committed. Moving to Mac requires transferring this file through a secure,
  separate channel (not git, not email) — see `SoundHop_Releases/v1.0.0/RELEASE_NOTES.md` for
  the keystore's alias/purpose. Signing is passed at export time via
  `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`/`_USER`/`_PASSWORD` env vars, never stored in
  `export_presets.cfg`.
- **Machine-specific tool paths** — Godot executable location, JDK path, Android SDK path are
  all local to this Windows setup and will differ on Mac. On this machine: Godot 4.5.1 at
  `C:\Users\user\Downloads\Godot_v4.5.1-stable_win64.exe\`, JDK via Android Studio's bundled JBR
  (`C:\Program Files\Android\Android Studio\jbr`, **not** the system JDK — see below), Android
  SDK Platform 35 + Build-Tools 35.0.0 installed alongside the machine's existing 36.1.
- **`android/` folder is gitignored** (Godot-regenerated build template) — including a local fix
  inside it: `checkReleaseBuilds false` added to `android/build/build.gradle`'s `lintOptions`
  block, working around an AGP/lint tooling crash (`lintVitalAnalyzeStandardRelease` failing with
  `MessageBus... Already disposed`). This will need reapplying on Mac too if/when the Android
  build template gets (re)installed there.
- **Gradle/JDK compatibility**: this project's gradle template (AGP 8.6.1 / Gradle 8.11.1)
  requires **JDK 21**, not newer — JDK 25's class file version isn't supported by Gradle 8.11.1.
  Whatever JDK Mac's Godot export ends up pointing at needs to satisfy this too.
- **`debug_config.gd`'s `DEBUG_MODE` flag** — deliberately kept **uncommitted** locally, same
  reasoning as the keystore: `title.gd` only creates the title-screen debug menu button when
  `DebugConfig.DEBUG_MODE` is true, but the committed value is `false` (so a stray commit can
  never accidentally ship a release with the debug menu exposed). This Windows machine has had it
  locally flipped to `true` for testing all session, never pushed — so a fresh clone/pull on
  another machine (confirmed on Mac, 2026-08-07) correctly comes in at `false` and shows no debug
  button. Not a bug: just flip the same line locally on each new machine, don't commit it.

---

## 2026-08-06

### Completed
Pure design session — no code changed. Investigated Level 1.5's real structure, reviewed the
user's first-draft Level 1.5 Sound Quest spec, and locked the round-generation rules plus
Set/round counts for Quest A and Quest B, grounded in the actual word data (not the doc's
illustrative examples).

**Level 1.5 structure (investigated, not previously documented anywhere in this repo):**
- Main scene `game15.gd` (1717 lines), tracked by `Level15Progress` (13 Sets across 6 Groups
  A–F, same 3-star scoring as Level 1). Reuses `transition.gd`/`transition.tscn` internally via
  a `_for_l15` flag rather than having its own transition scene.
- Unlike Level 1 (one skill: hear phoneme, pick word), Level 1.5 covers **four different
  skills**: initial/final identification (A/B, tap-choice), initial/final isolation (C/D,
  tap-choice), build-the-word (E, drag phoneme tiles to assemble a word), sound-count (F,
  drag/tap to count a word's sounds).
- Data model is entirely different from Level 1's per-phoneme-folder scan: `data/words.json`
  (130 words, keyed by word, each with explicit precomputed `initial`/`final`/`vowel`/
  `phonemes[]`/`structure` fields — CVC=70, CCVC=28, CVCC=19, CCVCC=13) + `data/phonemes.json`
  (pure metadata, audio path + consonant/vowel type, no word back-references). A Set's word
  pool = every word whose `structure` is in that Set's `allowed_structures` array — no
  target-phoneme field anywhere in the round configs, it's derived from pooled words'
  `initial`/`final` at runtime.
- New asset folders, both **flat, organized by whole word** (not per-phoneme like Level 1):
  `SoundUp_level1.5_word_images/{word}.png`, `BGM&effect/SoundUp_level1.5_word_sounds/{word}.wav`.
  Consonant phoneme audio is reused directly from Level 1's existing `SoundUp_level1_phonemes/`
  folder (not duplicated); only the 5 short-vowel clips are new, living in the 1.5 sounds folder.

**Quest A/B locked design** (Quest A = initial-phoneme identification, Quest B = final-phoneme):
- Both draw from the same 117-word pool (CVC+CCVC+CVCC).
- **Target phoneme selection**: a phoneme is eligible as a round's target only if it has ≥3
  *usable* words — critically, usable = total matching words **minus 1**, since the target
  word itself is never included in its own correct pool (its picture is the thing being
  revealed, not a patch). This "minus 1" shift actually flips a few phonemes below the floor
  that looked valid at first glance (`w`, `g` for Quest A; `b`, `ng` for Quest B — each had
  exactly 3 total words, only 2 once the target is excluded).
- **Correct pool (floor/ceiling)**: usable 3–5 → use all as a smaller valid round; usable 6–10
  → use all; usable >10 → randomly redraw a fresh 6–10 subset each time (not fixed), so repeat
  visits to a rich phoneme surface different words over time.
- **Distractors**: floor/ceiling only ever gates the *correct* pool — any word is eligible as a
  distractor regardless of its own phoneme's frequency, as long as it doesn't share the
  round's actual target phoneme (same Phoneme-Based Distractor Rule already locked for Level 1
  — spelling-independent). Target pool size: ~14–18 distractors per round.
- **Patch logic**: Option A confirmed — the target image's patch layout is driven by the
  image's own predefined regions (e.g. fish = head/body/tail/fin), not a generic grid; correct
  words are selected to match however many regions that specific image has, not the other way
  around. Flagged, not yet resolved: this implies per-word custom patch-region art (106 eligible
  words for Quest A, 109 for Quest B could each need bespoke regions under a literal reading) —
  open question whether that's really per-word bespoke or a small set of reusable N-region
  templates shared across words needing the same patch count.
- **Round/Set structure — locked**: Quest A = 4 Sets × 8 rounds = 32 total (12 eligible initial
  phonemes fit inside this cleanly, avg ~2.7 rounds/phoneme). Quest B = 5 Sets × 8 rounds = 40
  total (revised down from an initial 5×10=50 after a pacing discussion — 8 eligible final
  phonemes divides Quest B's 8-rounds-per-Set exactly evenly, no leftover-round weighting
  needed, avg 5.0 rounds/phoneme). The revision wasn't a word-pool problem (the data was fine)
  — it was a pacing call: a Quest A/B round is a heavier task than a Level 1 round (sift 14-18
  distractors, drag multiple correct words, watch an image build), so raw round-count parity
  with Level 1 isn't the right comparison.

**Real per-phoneme data** (117-word A/B/C/D pool, eligible = usable ≥3 after target exclusion):
- Quest A eligible (12): `s:16, k:12, b:10, p:10, m:9, t:9, h:6, d:6, l:5, j:4, r:4, f:3`.
  Excluded entirely (usable ≤2, can only ever be a distractor): `v, n, z`.
- Quest B eligible (8): `p:22, t:19, g:16, n:16, d:10, m:8, k:7, x_ks:3`.
  Excluded entirely: `s, l, b, ng`.
- Flagged as a possible real gap (not fixable in round-generation logic, a data-coverage
  question): Quest A's `f/j/r/l` only ever get 1 round each (thin, no repeat value) despite
  being fairly fundamental sounds for early readers — just thin *in this specific word list*.

Assets already uploaded and present in `soundquest/assets/`, ready for whenever building
starts: `playbutton_bridge_level15_soundquest_transition.png.png`,
`playbutton_level15_soundquest_F_bleh.wav`, `playbutton_level15_soundquest_F_nom.wav`,
`quest_level15_bgm.mp3`. Not yet uploaded: Quest E's ladder frame/branch PNGs.

**Later the same day: Quest C/D, E, F, and the Transition scene all locked too — all six Quest
types plus the Transition are now fully spec'd, nothing left open for the design phase.**

**Quest C/D locked** (initial/final isolation — continuously-rising phoneme bubbles, tap to
hear, drag the correct one to Play Button):
- Confirmed no letters shown — single reusable `bubble_level15_soundquest_C_D.png` for every
  phoneme, told apart only by tap-to-hear audio, same pattern as Level 1's bins.
- Unlike A/B, **no floor-based exclusion needed at all** — bubbles are repeated audio copies of
  a phoneme, not distinct words, so even a 1-word phoneme (`z`, `s`, `l`) can still anchor a
  round. All 17 initial and all 12 final phonemes are valid C/D targets.
- **Target bubble count (4–10)**: linear-scaled from each phoneme's real word-frequency (reusing
  the same A/B data) — richest phoneme in each quest maps to 10, rarest to 4.
- **Bubble pool**: fixed at 20 total; distractor count = 20 − target count (confirmed fixed-total
  over fixed-distractor-count).
- **Distractors**: any of the full 24-phoneme pool (19 consonants + 5 vowels), target excluded,
  each distractor phoneme appears at most once per round (only the target phoneme repeats).
  Verified always feasible (max 16 distractor slots needed, 23 phonemes available after
  excluding target).
- Wrong drag: silent bump-away animation, bubble keeps rising, never destroyed.
- **Structure — locked**: 4 Sets × 14 rounds = 56 rounds each for both C and D (reconsidered up
  from an initially-proposed 3 Sets after a pedagogical-weight discussion — wanted Isolation to
  carry similar overall weight to Identification, not just minimum data coverage). Resulting
  averages (C: 3.29x, D: 4.67x) stay comfortably under the 6.25x ceiling that got Quest B trimmed
  earlier, so no pacing concern despite the higher Set count.

**Quest E locked** (Build the Word — drag phoneme branches onto a ladder, bottom-to-top):
- **Order enforced live**: next branch slot only unlocks after the previous one is filled;
  out-of-sequence placement is rejected outright, not just checked at the end.
- **Distractor branches**: total 12 branches per round, fixed regardless of word length (correct
  = word's own phoneme count, 3-5; rest are distractors) — deliberately fixed total rather than
  fixed distractor count, so a harder (longer) word's difficulty comes from the sequencing task
  itself, not also a bigger field to search. Distractors drawn from the full 24-phoneme pool,
  excluding ALL of the target word's own phonemes (not just one, unlike C/D) — verified feasible
  even in the worst case (CCVCC, 5 target phonemes to avoid, still 19 other phonemes free to
  draw 7 unique distractors from).
- **Layout**: target image top; ladder (built from a single reusable frame PNG, stacked as needed
  to reach 3-5 rungs) + Play Button waiting below it on the left; bobbing branch pool on the
  right.
- **Completion sequence**: climb ladder -> touch image (word plays once) -> hop to the image's
  right side (staging to lead) -> walk right together, image following -> exit past the
  viewport, no fade -> destroy and regenerate fresh next round. Play Button's size is fixed to
  match the target image's size for the entire round, no scaling at any point (needed since it's
  now visually paired with the image while walking).
- **Structure**: covers all four word structures (CVC through CCVCC), 10 Sets x 10 rounds = 100
  rounds, drawing from the ~117-130-word pool.

**Quest F locked** (Sound Count — drag word images sharing the target's phoneme *count* to Play
Button, who eats or rejects them):
- **Growth mechanic**: Play Button grows 30% of its original size per correct word eaten,
  cumulative, never shrinks within a round (e.g. 4 correct = 220%, 8 correct = 340%).
- **Exit animation tiers** by how many were eaten: 1-4 = hop hop, 5-6 = waddle, 8+ = roll —  all
  the way off the viewport.
- **Round pool**: 20 total word images; 3- and 4-phoneme-count targets use up to 14 correct
  words per round; **5-phoneme-count targets are deliberately capped lower (8-10, randomized)**
  rather than using the full pool every time.
- This cap was verified necessary, not just a stylistic choice: a headless simulation (Python
  against the real 130-word dataset, not Godot) showed that without it, every one of the
  5-phoneme bucket's 13 words gets used in literally every round targeting that bucket (flat
  10/10 usage, zero variety) — capping at 8-10 dropped usage to a genuinely varied 3-9 range
  per word. 3- and 4-phoneme buckets don't need the same cap; they're large enough (70 and 47
  words) to rotate naturally at the 14-correct level.
- **Target distribution across 100 rounds**: proportional to real bucket size (54 rounds target
  3-phoneme words, 36 target 4-phoneme, 10 target 5-phoneme) rather than an even split, to avoid
  over-relying on the thin bucket.
- **Structure**: 10 Sets x 10 rounds = 100 rounds, verified generatable with real variety via
  the same simulation.

**Level 1.5 Transition scene locked** — a genuinely different, two-tier model from Level 1's
single hidden-object hunt:
- **Short Transition** (Play Button walks left to right, exits, no bridge/group/story/music)
  plays between every Sound Quest Set **within** a Quest type (e.g. A1->A2, A2->A3, A3->A4).
- **Long Story Transition** (large Play Button hesitates 4x at a bridge, fails a first attempt,
  succeeds on a second while a ~20-strong friend group's energy visibly shifts from nervous
  bouncing to celebration, joins them at ~80% across, camera pans to follow the group's exit)
  plays only when a Quest type's **final** Set completes (e.g. A4 completing -> Long Transition
  -> B1 starts) — the Short Transition does NOT also play at that boundary, the two are mutually
  exclusive per Set boundary. Uses the existing transition BGM. This happens once per Quest type
  (A-F), **6 times total** across all of Level 1.5 Sound Quest — not a one-time onboarding moment.
- **Correction (same day, later pass, during Quest A/B implementation)**: the original write-up
  above had this backwards, describing the Long Transition as playing "exactly once — first
  entry into Level 1.5 Sound Quest ever." That was wrong. The Long Transition plays at every
  Quest-type boundary (A->B, B->C, C->D, D->E, E->F, and after F), not just the very first one.
  Corrected directly by the user after `level15_sound_quest_ab.gd`'s Set-boundary logic had
  already been built the wrong way (Short firing at every boundary including the Quest-final
  one) — fixed same pass, see Completed entry below.

Update within this same entry: all remaining Sound Quest assets have since been uploaded —
`bubble_level15_soundquest_C_D.png`, `drop_zone_level15_soundquest_F.png`,
`ladder_frame_level15_soundquest_E.png`, `ladder_rung_level15_soundquest_E.png`, and a new
`bridge_level15_soundquest_transition.png` (alongside the earlier
`playbutton_bridge_level15_soundquest_transition.png.png` — both present, not yet clear if one
supersedes the other). Every quest now has its real art ready; nothing left blocking
implementation on the asset side.

**Implementation progress (same day, later pass)**: built Quest A/B (initial/final
identification), the one shared implementation the user confirmed works for both — identical
mechanic, only the `position` field ("initial"/"final") and round count differ.
- `level15_sound_quest_state.gd` (data layer): pool builder, eligible-phoneme/floor-ceiling
  correct-pool logic, distractor selection, target-phoneme schedule — verified headless against
  the real word data, matching every hand-computed number from the design pass exactly.
- `level15_sound_quest_ab.gd`/`.tscn` + `level15_sound_quest_ab_state.gd` (round shell): faint
  target image revealed via an NxM grid mask, scattered correct + distractor word pool with
  drag-and-drop (correct hop+reveal, wrong resist-bounce, empty glide-back) — reusing Level 1
  Sound Quest's proven patterns including the bob-tween-kill fix.
- Round-to-round advance, Sound Quest Set boundaries (every 8 rounds — Quest A = 4 Sets, Quest B
  = 5 Sets, both exact), and the Quest A -> B handoff (state reset + scene reload) — all wired
  and verified headless via controlled mini-schedules (timing deltas confirming each transition
  actually fired, not just that code ran without error).
- Built the Short Transition (Play Button walks across) for real. Short-vs-Long **branching
  logic** at Set boundaries: initially built wrong (Short firing at every boundary including a
  Quest's final Set), caught and corrected by the user (see the Transition-rule correction note
  above), re-verified headless afterward (mid-quest boundary -> Short only; quest-final boundary
  -> Long only, never both).
- **Long Story Transition built for real** (same pass as the three open-question answers below):
  bridge background (`bridge_level15_soundquest_transition.png`), Play Button hesitates 4x, fails
  a first attempt, succeeds on the second while a 20-strong `louisfaces/` crowd shifts from
  nervous bob (neutral face) to celebration bob (happy face) partway through, joins the crowd at
  ~80% across, whole group exits together; music is `quest_level15_bgm.mp3`, same fade-in/loop/
  fade-out pattern as Level 1 Sound Quest's own Quest Transition (`_qt_` functions in
  `level1_sound_quest.gd`). First-pass sizing/timing, headless-verified (clean run, correct
  ~7.3s duration, symmetric node count before/after, no leftover crowd/bridge/playbutton nodes)
  but **not yet seen live** — expect a visual-feel iteration pass once the user can watch it,
  same as Level 1's Quest Transition needed.
- Patch-reveal art: confirmed **simple NxM grid, not bespoke per-word regions** — this is now the
  real, permanent implementation, comments updated accordingly (was previously flagged as a
  placeholder pending this decision).
- Quest E's ladder rungs/branches: confirmed same no-letters/audio-only approach as Quest C/D's
  bubbles (generic rung shape, phoneme told apart by tap-to-hear only) — no code yet, Quest E
  hasn't been started, but the design risk flagged earlier this entry is resolved.
- Not yet wired: the handoff after Quest B completes (back into `game15.gd`/`Level15Progress`'s
  own Set/Group flow) — deliberately left a stubbed print, since Level 1.5 doesn't have Level 1's
  `MAIN_SET_BOUNDARIES`-style boundary model built for it yet and that needs its own
  investigation, not an assumption.

**Refactor (same pass)**: extracted the Short/Long Transition choreography out of
`level15_sound_quest_ab.gd` into a new shared `level15_sound_quest_transitions.gd`
(`Level15SoundQuestTransitions`, instantiated as a child, `play_short()`/`play_long()`) —
Quest C/D needed the identical behavior, and duplicating ~200 lines of choreography across
quest types would mean every future tweak has to land in multiple places. No behavior change,
re-verified headless against Quest A/B afterward.

**Quest C/D built** (initial/final isolation — continuously-rising phoneme bubbles):
- `level15_sound_quest_state.gd` gained `phoneme_frequencies()`, `cd_target_bubble_count()`
  (linear-scaled 4-10), `cd_build_distractor_phonemes()` — verified headless against the real
  117-word pool: 17 eligible initial phonemes, 12 eligible final, every distractor set correctly
  excludes the target with no duplicates.
- `level15_sound_quest_cd.gd`/`.tscn` + `level15_sound_quest_cd_state.gd`: 20 bubbles per round
  (a single reusable `bubble_level15_soundquest_C_D.png`, phonemes told apart only by
  tap-to-hear audio) continuously rise from the bottom and loop back if uncollected; drag a
  matching bubble onto Play Button to collect, wrong drags silently bump away and keep rising,
  never destroyed. Reuses the new shared Transitions component
  (`ROUNDS_PER_SET = 14`, 4 Sets x 14 = 56 rounds) and the same state-reset-plus-reload handoff
  pattern for Quest C -> D.
- Verified: windowed-mode simulated drag/drop confirms both correct collection and wrong-drop
  bump-away; headless direct-call tests confirm bubble/target counts match the data layer exactly
  and Set-boundary/quest-complete timing and state handoff are correct.

**Real finding, worth remembering**: `--headless` mode's `push_input()` reports a broken/sentinel
mouse position (`(2000, 2000)`, regardless of what's set on the event) for
`InputEventMouseButton`/`InputEventMouseMotion` in this Godot build — not a bug in game code.
Windowed mode reports positions correctly and is the only reliable way to verify real drag input.
This means every "headless, verified via real simulated `push_input()`" claim earlier in this
session's Quest A/B work actually used **direct function calls** (`_try_start_drag()`,
`_on_correct_drop()`, etc.), not real `push_input()` — those were still valid tests of the logic,
just not of input *routing* specifically. The only two-sided routing verification (headless AND
windowed, both agreeing) happened for Quest C/D's drag test, which is what surfaced this.
Future sessions: use windowed mode (drop `--headless`) for any test that needs to prove
`push_input()` actually reaches `_input()` with the right coordinates.

**Quest E built** (build-the-word — drag phoneme branches onto a ladder, bottom-to-top):
- `level15_sound_quest_state.gd` gained `build_pool_e()` (all 130 words, all 4 structures — wider
  than A/B/C/D's 117-word CVC/CCVC/CVCC-only pool), `build_word_schedule()` (100-round schedule,
  no repeats since 100 < 130), `e_build_distractor_phonemes()` (excludes ALL of the target word's
  own phonemes, not just one) — verified headless against the real dataset, matching the design
  lock's own numbers exactly (19 available distractor phonemes in the CCVCC worst case).
- `level15_sound_quest_e.gd`/`.tscn`: target image top; 12-branch bobbing pool on the right
  (correct = word's own ordered `phonemes[]`, one branch per occurrence — so a word like "skunk"
  with two k's spawns two separate k-branches, either one usable for either slot); ladder on the
  left with Play Button waiting below it. Order enforced live against
  `_target_phonemes[_filled_count]` — a mismatch (distractor OR a correct-word phoneme presented
  out of turn) bounces back via the same resist-twice idiom as Quest A/B's wrong-drop, never
  destroyed. On completion: Play Button climbs the ladder rung by rung, touches the image (word
  audio once), hops beside it, both walk off together — Play Button's size is fixed to the target
  image's size for the whole round, no scaling ever, per the locked design. Reuses
  `Level15SoundQuestTransitions` (`ROUNDS_PER_SET = 10`, 100 total rounds); Quest E->F handoff is
  a stub since Quest F doesn't exist yet.
- **Real correction caught via screenshot before committing**: `ladder_frame_level15_soundquest_E.png`
  is a single straight vertical bar, not a ladder shape. First implementation stacked N copies of
  it to reach 3-5 rungs, per an over-literal reading of the design summary's "stacked as needed"
  phrasing — this rendered as one indistinguishable thin line, not a ladder. Corrected to two
  stretched rail instances (the two vertical sides), with `ladder_rung_level15_soundquest_E.png`
  (a horizontal bar, already correctly used for the branch pool) crossing between them as rungs
  fill in — matches the earlier live layout description ("2 ladder frames... on the left") more
  literally than the compressed Worklog summary did. Also fixed a real off-screen bug caught the
  same way: Play Button's waiting position (`LADDER_BASE_Y + 90`) landed at y=730, past the 720px
  canvas — tightened the layout so it sits fully on-screen.
- Verified: windowed-mode drag/drop confirms an out-of-turn drop bounces back without advancing
  (branch survives); an extended real run through ~10 consecutive rounds (many different words,
  including duplicate-phoneme words) placed every rung correctly and advanced rounds cleanly with
  no corruption. An early version of this same test used a fixed post-drag wait instead of polling
  `_busy`, which raced with the in-flight `_on_correct_drop()` animation and produced a confusing
  (but harmless — purely a test-pacing artifact, not a game bug) "placed same phoneme twice"
  printout; fixed by polling `_busy` instead of guessing a wait duration.

**Quest F built** (sound count — drag word images sharing the target's phoneme COUNT, not
identity, onto Play Button, who eats or rejects them):
- `level15_sound_quest_state.gd` gained `f_bucket_by_count()` (words grouped by `phonemes[]`
  length: 3/4/5, matching structure exactly — 70/47/13 words), `f_correct_pool()` (up to 14 for
  the 3/4-count buckets, randomized 8-10 for the thin 5-count bucket per the locked variety fix),
  `f_build_distractors()`, `f_build_count_schedule()` (100 rounds, 54/36/10 proportional to real
  bucket size) — verified headless against the real dataset, matching the design lock's own
  numbers exactly.
- `level15_sound_quest_f.gd`/`.tscn`: Play Button top-center with a fixed drop-zone slot below it
  (`drop_zone_level15_soundquest_F.png`); 20-word bobbing pool (rejection-sampled spacing, same
  `_pick_pool_center()` idiom as Quest A/B and E) drags into the drop zone. Correct (matching
  phoneme count) -> "nom" sound, word consumed, Play Button grows 30% cumulative (`scale`
  property, not `size`, so it grows around a fixed anchor). Wrong -> "bleh" sound, resist-bounce
  back, never destroyed — same idiom as every other quest's wrong-drop. On round completion
  (every correct word eaten), Play Button exits via a tier scaled to how many were eaten (1-4 hop
  hop, 5-6 waddle, 8+ roll — count 7 was left unassigned in the locked spec, extended waddle to
  5-7 as the most conservative reading) before the next round starts fresh (`eaten_count` and
  scale both reset). This is the last of the six Quest types, so its own completion is the final
  stub in the chain.
- **Flagged for the user**: since a round only completes after eating the ENTIRE correct pool
  (8-14 words, always >=8), the hop and waddle exit tiers may rarely or never actually fire in
  real play — only the 8+ "roll" tier is reachable under the current "collect everything"
  completion rule. Worth confirming this is intended, or whether completion should work
  differently (e.g., a smaller required count) if the lighter tiers are meant to be seen.
- Verified: windowed-mode drag/drop confirms reject (word survives, Play Button unchanged) and
  eat (word consumed, Play Button grows following the `1 + 0.3*n` formula) both work; an extended
  run eating all 14 correct words in one round confirmed the exit sequence and a clean reset for
  the next round.

**All six Quest types (A-F) now exist and are functionally verified** (none seen live/on-device
yet). Design phase and implementation phase are both complete for the core Quest mechanics.

Commits: `8cdecd2`, `ab0dc86`, `ba98132`, `a5193e4`, `2c9a06b`, `bdc6e3a`, `1df7ef7`, `6d187e6`,
`01424c3`, `75ffcb9`, `925d642`, `f52d24c` — pushed and verified against `origin/main`.

Commit: (this entry, updated) — pushed and verified against `origin/main`.

### Decisions
- Design work for Level 1.5 Sound Quest is happening in conversation + real-data verification
  (Python scripts against `data/words.json`/`phonemes.json`, not Godot) before any code gets
  written — same "verify real numbers before building" discipline as Level 1's Sound Quest,
  just applied earlier in the process since the mechanic itself is still being designed.
- "Sound Quest Set" (this session's agreed term) = a single 14-round-equivalent replay cycle,
  matching what Level 1's code calls a "Quest" internally (e.g. `_quest_index`) — potential
  future naming collision to watch for if/when Level 1.5 code actually gets written, since
  Level 1.5 also has its own native "Set" concept (`set_1a`, `set_1b`, etc.) meaning something
  different (a Group's own sub-unit, not a Sound Quest replay cycle).
- Floor/ceiling rules apply only to the correct (patch) pool — distractor eligibility is
  governed only by the existing Phoneme-Based Distractor Rule, never by word-frequency.
- Every quest's distractor-count/target-count numbers were pressure-tested against the real
  dataset before being locked (not just reasoned about abstractly) — same discipline that caught
  Quest F's 5-phoneme-bucket repetition problem before it became a real content issue.
- Pacing (how much repetition a Set/round structure produces) was treated as a first-class
  design concern throughout, not just data coverage — multiple quests got their round/Set counts
  revised after checking the resulting repeat-exposure average against Quest B's original 50-
  round proposal (6.25x), which was explicitly called "too much" and became the informal ceiling
  every later quest got checked against.

### Risks / Gotchas
- The "no letters, ever" rule (CLAUDE.md, locked) is confirmed satisfied for Quest C/D (single
  generic bubble, audio-only) **and now Quest E too** (confirmed same day, later pass: generic
  ladder rung shape, phoneme told apart by tap-to-hear only, no visual distinguishing content).
- Terminology overload: "Quest A" in this conversation's shorthand = the whole Group A Sound
  Quest activity; within it, "Sound Quest Set" = one replay cycle. Keep these distinct in any
  future spec doc — conflating them caused one real back-and-forth this session already.
- Quest E's distractor-exclusion rule is broader than C/D's — must avoid ALL of the target word's
  own phonemes (up to 5 for a CCVCC word), not just one. Easy to under-implement this if copying
  C/D's simpler single-phoneme-exclusion logic without adjusting it.

### Next Session
- **Design phase for Level 1.5 Sound Quest is complete** — all six Quest types (A-F) and the
  two-tier Transition scene are fully locked, verified against real data where it mattered
  (A/B/C/D/E/F all pressure-tested, not just designed on paper).
- **Implementation of all six Quest types (A/B, C/D, E, F) is functionally complete**: round
  shells, drag/drop, round advance, Set boundaries, Short Transition, real Long Story Transition
  (bridge/crowd/hesitate/fail/succeed/join/exit, shared via `Level15SoundQuestTransitions`), and
  the Quest A->B / C->D handoffs — all built and verified (Quest C/D, E, and F's drag/drop
  specifically windowed-mode-verified with real `push_input()`, see the headless `push_input`
  finding above). **No live/on-device playthrough of ANY of it yet** — this is the single biggest
  open item. Specifically flagged as needing a live pass:
  - The Long Story Transition (sizing, hesitation feel, crowd density) — same as Level 1's Quest
    Transition needed several rounds of iteration to land.
  - Quest E's ladder layout (two stretched rails, not stacked segments) — only seen via
    screenshot.
  - Quest F's exit-tier gap (hop/waddle tiers may never fire in practice since a round only
    completes after eating the whole correct pool, 8-14 words) — worth confirming with the user
    whether that's intended.
- All three open questions from the design pass are answered: patch-reveal art stays a simple
  grid (not bespoke), the current bridge PNG is `bridge_level15_soundquest_transition.png` (the
  older `playbutton_bridge_...png.png` has been deleted from disk), and Quest E's ladder rungs
  are confirmed no-letters/audio-only like Quest C/D's bubbles.
- **Not yet designed, the main remaining architecture gap**: how the six Quest types actually
  chain together and hand off back into normal Level 1.5 play. Right now each pair/type's
  completion (`_on_quest_complete()` in A/B and C/D, `_on_quest_complete()` in E and F) is a
  stubbed print — none of them route anywhere. Needs: Quest B->C, Quest D->E, and Quest F->(back
  into `game15.gd`/`Level15Progress`'s own Set/Group flow) handoffs, plus Level 1.5's own version
  of Level 1's `MAIN_SET_BOUNDARIES` boundary model (which Group triggers which Quest type, and
  when in the Set/Group progression Sound Quest gets inserted at all). This is genuinely
  undesigned, not just unimplemented — needs a real conversation with the user before building.
- Quest C/D's bubble spawn uses pure random placement, no minimum-spacing rejection sampling like
  Quest A/B's word pool, Quest E's branch pool, Quest F's word pool, or Level 1's Word Cloud all
  use — worth checking live whether 20 bubbles in the field ever visually overlap enough to
  confuse which one a child is tapping; easy to add the same `_pick_pool_center()`-style spacing
  logic if it turns out to matter.
- Given six genuinely different mechanics all got built in one extended session, a careful
  full-playthrough live pass (one Quest type at a time, screenshot/video-driven iteration same as
  Level 1's Sound Quest needed) should be the very next priority before any further building —
  there's a real risk of compounding first-pass sizing/timing guesses across six quest types
  without ever having seen one actually played.

**Session close**: Sully moved to Mac to continue (Godot + this GitHub repo both set up there)
partway through wrapping up this session. First thing hit: the title-screen debug button was
missing after a fresh pull — root-caused to `debug_config.gd`'s `DEBUG_MODE` flag being locally
flipped to `true` on Windows all session (never committed; the real committed value is `false`,
by design — see "Before switching machines" above for the fix and the reasoning). Not a bug, just
the first real instance of a machine-local setting tripping up a switch.

**Going forward, Mac becomes the primary machine, not just an occasional second one** — shipping
to the Apple App Store needs Xcode, which only runs on Mac, so Sully will be there more often than
Windows from here on (Windows still used sometimes). Nothing about how this project works changes
because of that, but it raises the stakes on this Worklog and the "Before switching machines"
section specifically being complete and accurate, since Mac will now carry more of the day-to-day
load. Also worth flagging early: iOS export setup (Xcode signing, certificates, provisioning
profiles) hasn't been started at all yet — everything release-related so far has been Android/
Google-Play-specific. That'll need its own from-scratch setup on Mac whenever it comes up, likely
mirroring the same committed-vs-local-secure split the Android keystore already uses.

Claude Code sessions don't carry across machines — this file is what does. Whoever picks this up
next (same machine or Mac) should start by reading `CLAUDE.md` and this entry in full.

---

## 2026-08-04

### Completed
Built the entire Level 1 Sound Quest **Rounds** activity — the core word-cloud-into-bins
gameplay — on top of the Quest Transition piece from the previous session, and wired the
whole thing into normal Level 1 progression. Full design structure and scale below.

**Design structure**
```
Level 1 Group (A–G, 7 total)
  → 1 word pool built once, from every phoneme in the Group
  → split into 1+ phoneme-balanced chunks if the pool is large (a chunk never splits
    one phoneme's words across two chunks)
  → N Quests, each replaying one chunk (Quest i uses chunk (i mod chunk_count),
    cycling back to the first chunk once every chunk has had a turn)
      → 14 Rounds per Quest, each fully self-contained (nothing carries over):
          - fresh Word Cloud: every word in that Quest's chunk, scattered (not a grid,
            natural "wagle-wagle" overlap allowed)
          - fresh 4 phoneme Bins, this Round's active phonemes from a round-robin
            schedule built once per Quest
          - tap a Word Cloud face -> word audio; tap a Bin -> phoneme audio; drag a
            face onto its matching Bin -> collected
          - a Bin "breathes" once every word for its phoneme is collected; the Round
            ends once all 4 active Bins are breathing
      → after Round 14: Quest Transition (the "find the Play Button" hidden-object
        hunt, reused as-is from last session) -> next Quest
  → after the Group's last Quest's Transition: LevelProgress.advance() (deferred until
    exactly this point, same pattern Prep's Sound Quest already used) -> next Group's
    first Set, or Level 1.5 if this was the last Group
```

**Scale — real per-Group numbers** (word counts are each Group's actual, unpadded word
bank; no artificial repeats to hit a round number):

| Group | Words | Phonemes | Chunks | Quests | Chunk breakdown |
|---|---|---|---|---|---|
| A | 54 | 6 | 1 | 4 | 54 |
| B | 49 | 6 | 1 | 4 | 49 |
| C | 43 | 6 | 1 | 4 | 43 |
| D | 100 | 12 | 2 | 8 | 51 / 49 |
| E | 32 | 5 | 1 | 4 | 32 |
| F | 178 | 23 | 3 | 3 | 61 / 61 / 56 |
| G | 95 | 11 | 2 | 8 | 51 / 44 |

D and G get extra Quests (8, not the standard 4) purely for deeper repetition — contrast
pairs and ending sounds specifically benefit from more passes. F gets fewer (3, not 4) since
it's "all sounds mixed," material kids already drilled individually elsewhere; each of its 3
chunks is shown once, no repeats, just full coverage.

**Correct-drop choreography** — seven distinct beats, not one blended motion (pause -> hop
straight up -> arc down into the Bin -> land at full size -> brief squash on impact -> shrink
to 80% of original size -> settle into the same gentle bob, now anchored in the Bin). Wrong
drop onto a Bin: resists twice, bounces back, never enters, no sound. Wrong drop into empty
space: simple glide back.

**Layout scale**: Word Cloud faces at `CLOUD_FACE_SCALE 0.085` (smaller than the Transition's
decoys, since up to 178 need to fit); Bins at `BIN_SCALE 0.4` bounding box, but the bin PNG's
drawn cup only fills ~32%/40% of its own canvas width/height, so all Bin hit-testing (tap AND
drag-drop landing) uses a measured visible-content rect, not the full padded box — two real
bugs (a Cloud tap near a Bin also firing that Bin's audio; a correct drag landing in the wrong
neighboring Bin) both traced to using the padded box for hit-testing instead.

**Files**: new `level1_sound_quest_state.gd` (Group handoff + per-Group Quest counts), major
rewrite of `level1_sound_quest.gd` (now two phases in one script — Rounds + the existing
Transition), `sound_quest_state.gd` generalized (`build_word_pool` takes a JSON path list
instead of hardcoding Prep, new `split_pool_by_phoneme_balanced`/`build_round_schedule`,
`pad_pool_to_size` added then removed same session once padding was reversed), `level_progress.gd`
gained `MAIN_SET_BOUNDARIES`/`is_main_set_boundary()`/`current_group_range()` mirroring Prep's,
`transition.gd` gained the routing hook, `debug_menu.gd` gained two shortcuts (full Group-A
flow, and transition-only preview).

Commits: `4873059`, `045878f`, `d69bc23`, `498ff08`, `dd8cdb4`, `1d2fdbb`, `2dc722e`, `964da38`,
`336ab87`, `c306125` — pushed and verified against `origin/main`.

### Decisions
- **Chunking is by whole phoneme, never by word count alone splitting mid-phoneme** — a Bin
  needs its full word set available in whichever single chunk/Quest features it.
- **Word pool padding was tried, then explicitly reversed**: an early version padded any
  Group's pool up to a 56-word target (repeating a couple of representative words), matching
  the original design doc. Live testing surfaced this as a real, confusing "two kangaroos"
  moment, so it was removed entirely — every Group's Word Cloud now shows its exact, real word
  count, no repeats within a single cloud. Repetition across rounds/Quests (the same word
  reappearing in a fresh cloud next round) is still the core mastery mechanic and is unaffected.
- **All Bin/drag hit-testing uses a manual visible-content Rect2, not Godot's `TextureButton`
  click detection** — tried `texture_click_mask` (a `BitMap` from the texture's alpha) first,
  but it didn't behave predictably with `ignore_texture_size`/custom `stretch_mode`; fell back
  to the same manual-Rect2 approach already proven for the Word Cloud instead. Bins ended up as
  plain `TextureRect` (like Word Cloud faces), not `TextureButton`, for the same reason.
- **A face's Word Cloud bob tween must be explicitly killed, not just left paused, when it's
  correctly dropped** — relying on `_try_start_drag()`'s pause (which only fires on a real
  drag-start) left a live bug risk for any code path that could reach `_on_correct_drop()`
  another way; now killed unconditionally at the top of that function regardless of entry path.
- **Collected-Louis placement is rejection-sampled with a "least-bad fallback,"** not pure
  random jitter — a Bin can hold up to ~11 words but its visible cup only has room for ~6-8
  non-overlapping full-size faces, so once genuinely crowded, no candidate satisfies the target
  spacing; tracking the least-bad attempt (most breathing room found) instead of just taking
  the last random try keeps a full Bin at ~50% overlap instead of an unreadable stack.

### Risks / Gotchas
- **Godot's GUI hit-testing for overlapping Controls resolves by scene-tree child order, not
  z_index or bounding-box precision** — worth remembering for any future scene stacking visual
  elements with padded/transparent textures; the Bin bugs this session were exactly this.
- A newly added `.gd` file with `class_name` (like `level1_sound_quest_state.gd`) needs an
  editor scan (`godot --headless --path . --editor --quit-after 60`) before a headless test can
  reference it — otherwise `Identifier "X" not declared in the current scope`.
- `SHRINK_DUR`/`COLLECTED_SCALE` naming in code: "shrink to 70%" and "shrink by 20%" are very
  different outcomes (end at 0.7 vs end at 0.8) — worth double-checking which convention is
  meant whenever a percentage-based visual change is requested, this session got it wrong once
  before confirming via a screenshot.

### Next Session
- **No live playthrough yet** — everything this session was verified headlessly (real simulated
  input, not calling handlers directly) and via windowed screenshots, but nobody has played a
  full Quest start-to-finish, a full Group through to the next one, or touched Groups D/F/G
  live at all (only Group A). Planned for tomorrow.
- Watch specifically for: the Quest-to-Quest and Group-to-Group handoffs under real play (only
  structurally verified via a headless force-completed test), and how the bigger Word Clouds
  (D: 100, G: 95, F: up to 178) actually feel to search through on a real device.
- Mobile-device check still outstanding (raised, not yet verifiable from this environment) —
  the canvas is logical-resolution-scaled so relative sizing should hold, but worth a real
  device pass regardless.

---

## 2026-08-03

### Completed
- Fixed a real rounding/sampling bug: `SoundQuestState.build_word_pool()` was reading each
  Prep sub-set JSON's *round* data and collecting only the words that happened to be a round's
  correct-answer choice — but Prep's rounds only sample a subset of each phoneme's real word
  bank (some words only ever appear as a distractor, or never at all). For Group A this
  silently undercounted the pool at 38 words when the actual complete bank across M/S/T/B/V/K
  is 54. Rebuilt to read Prep JSON only to determine which *phonemes* a Group covers, then pull
  the real word list for each phoneme straight from its image folder — the true complete bank —
  deriving `word_audio`/`phoneme_audio` from the matching asset folders. Along the way, found
  and handled two asset-naming quirks: duplicate-cased word-sounds folders for B/M
  (`B.wav`/`b.wav`, byte-identical), and image folder names that don't match their
  `phoneme_audio` basename for special phonemes (`G-hard` vs `G_hard.wav`, and a couple also
  lowercase: `c-soft`, `x-gz`) — resolved via trying plausible variants and using whichever
  folder actually exists, rather than guessing one substitution rule.
- Redesigned Sound Quest's round model around repetition rather than consume-once, per direct
  design discussion: `split_into_quests()` now tops up any quest smaller than the largest one
  (borrowed words from elsewhere in the pool) so all 4 quests in a Group are the same size
  (Group A: 54 words -> 14/14/14/14, was 14/14/13/13). A Quest's round *count* now equals its
  own word count (14 words -> 14 rounds), and every round draws 4 words at random from that
  same fixed pool instead of consuming a shrinking list — words repeating across rounds is the
  actual mastery mechanic here, not a fallback. The only constraint: a round never repeats the
  exact same word from the round immediately before it, when the pool is large enough to allow
  that. Removed `_pick_review_word()`/`_group_mastered`/`_quest_remaining` entirely — dead now
  that rounds never run short of content to draw from.
- Fixed a layout bug found via screenshot: the completed-row images overlapped the exit
  pointed-hand, since the maze's right edge (x=840) plus `EXIT_HAND_OFFSET` put the hand around
  x=890 (spanning ~854-926), right inside the completed row's old start x=900. Pushed the row
  out to x=960 and tightened its spacing (90/70 -> 80/65) so all 4 slots still fit the canvas
  while clearing the hand.
- Fixed the Listen bar (Level 1's `$ListenButton`) drifting away from the (fixed-position) back
  button under rapid repeated taps — `_bob_listen_bar()` re-read the button's current position
  as its bounce anchor every call, and wasn't guarded against a second tap starting a second
  bounce loop while the first was still running; overlapping loops each captured an
  already-displaced position as their new "true" anchor, compounding drift. Fixed by always
  bouncing relative to one fixed canonical position and guarding against re-entrant calls.
- Commits: `ec492a9`, `18253fc`, `d478610`, `cbe8ecf` — pushed and verified against
  `origin/main` via `git fetch`.
- Built the Level 1 Sound Quest **Quest Transition** (new `level1_sound_quest.gd`/`.tscn`): a
  "find the Play Button" hidden-object search mirroring Prep Sound Quest's Quest Transition
  celebration pattern — decoy Louis faces (`louisfaces/happylouis3-Photoroom.png`) plus the real
  Play Button, all bobbing continuously; a wrong tap freezes every face for a beat, the correct
  tap grows/dances/fades the whole crowd out. Reachable standalone via DEBUG -> Demo Shortcuts
  -> "Test L1 Sound Quest Transition" (4th shortcut added to `debug_menu.gd`). This is only the
  transition piece — the core Level 1 Sound Quest gameplay (54-face word-cloud sorting into
  phoneme boxes) is a separate, larger, not-yet-started piece, deliberately deferred until the
  transition felt right end to end.
- Found and fixed a real click-routing bug during this build, only caught by testing genuine
  simulated input (`push_input()` with real `InputEventMouseButton`s), never by calling the
  `pressed`-bound handler directly (which bypasses Godot's actual input routing entirely):
  overlapping `Control`s under a plain `Node2D` resolve hit-testing by **scene-tree child order**
  (last child wins), **not** `z_index` — so the real face, at a random array index, could lose
  taps to a later-added overlapping decoy. Verified 0/20 clicks landing before the fix, 60/60
  after, once the real face was guaranteed to always be the last child.
- Iterated through several rounds of user playtesting/feedback to land on the final feel:
  corrected a wrong assumption that "Louis" was a re-skinned Play Button (it's a genuine
  separate character asset); made the real face show `playbutton.png` from spawn instead of
  swapping textures on tap, since the user wanted the actual Play Button visibly present in the
  crowd rather than a transform-on-tap surprise; fixed the real face rendering much smaller than
  every decoy despite an identical scale factor (`playbutton.png`'s drawn face fills only a
  small fraction of its own canvas vs. Louis filling nearly all of its own — added a separate
  `REAL_FACE_SCALE` derived from the measured content-size ratio); added, then fully removed, an
  escalating "hint" pulse on the real face after 7s unresolved, once the user pointed out that
  *any* motion distinguishing it from the bobbing crowd makes it too easy to find and defeats the
  point of a hide-and-seek for kids; fixed the real face occasionally landing alone in open space
  with no neighbors (reads as obviously separate even at matched size) by always nestling its
  placement against a random already-placed decoy at a small offset; bumped decoy count 45 -> 65
  for a busier, more fun crowd once size/blending/placement were all correct.
- Commits: `4e08f0d` (this session's final polish pass) plus several prior commits earlier in
  the same build (`c3e9c5a`, `ec25d89`, `61d32c6`, `90a5d14`, `86467b2`) — all pushed and verified
  against `origin/main`.

### Decisions
- Sound Quest's word pool is now sourced from each phoneme's actual image folder, not from
  Prep's round data — Prep round data is only used to detect *which phonemes* are in scope for
  a Group range, never as the word list itself. This generalizes correctly to every Group,
  including the special-case phonemes in D/E/F, verified across all 6 Groups.
- Sound Quest's mastery model is intentionally repetition-heavy: a Quest is a small fixed word
  set (matched in size across all 4 Quests in a Group) drilled for as many rounds as it has
  words, with the same words deliberately resurfacing round after round rather than being
  "used up." This was a genuine design clarification, not an assumption — my first read of the
  intended round count was wrong (I assumed round count derived from word count via
  `ceil(words/4)`) until walked through explicitly.
- Level 1 Sound Quest's Quest Transition intentionally has **zero** distinguishing motion or
  texture difference on the real face beyond its (matched) size and (nestled) placement — the
  entire difficulty is "look carefully," not a special-cased hint animation. A stuck search is
  fine; a giveaway is not.
- Real click-routing in any scene stacking overlapping `Control`s under a `Node2D` must be
  verified via genuine simulated input events, never by calling the bound handler directly —
  this session's actual root-cause bug would have been invisible to the latter.

### Risks / Gotchas
- None new from Prep's fixes beyond the asset-naming quirks noted above (documented in
  `sound_quest_state.gd`'s `_resolve_word_audio()`/`_resolve_image_folder()` comments for future
  reference if a new Group's phonemes hit a naming variant not yet seen).
- Worth remembering for any future scene that stacks overlapping `Control`s under a `Node2D`:
  `z_index` will **not** resolve input priority there — scene-tree child order does.

### Next Session
- Prep's Sound Quest feature (word pool, round/repetition model, layout) is considered settled
  as of this entry — no outstanding Sound Quest follow-up flagged.
- Level 1 Sound Quest's Quest Transition is done and playtested to the user's satisfaction as of
  this entry. Next up (explicitly deferred, not yet started): the core Level 1 Sound Quest
  word-cloud sorting gameplay itself (54 static faces, drag into 4 phoneme-labeled boxes per
  round, across 7 Groups / 17 Sets).

---

## 2026-08-01

### Completed
- Sound Quest exploration flow refinement — Sound Quest clarified as a mastery exploration
  activity, not an assessment:
  - Maze solution path is hidden — no route line inside the maze. There is no approach path
    either, hidden or visible: reaching the maze is a plain free-drag with no guide line or path
    concept at all, since the maze's entry gap is already fully visible on its own.
  - Each image attempt generates a new maze layout (`_reshape_maze()` per attempt).
  - Wrong-route exploration inside the maze is allowed — wandering into a dead-end branch never
    fails or resets the attempt.
  - Wall crossing is blocked (the drag holds at its last valid cell), but exploring any real
    open corridor, dead ends included, is never treated as failure.
  - Target word audio continues during maze exploration, tied to active movement, for natural
    sound repetition.
  - Exit success triggers only after the image is dragged fully through and slightly past the
    maze's exit boundary (tolerance zone, not pixel-perfect).
  - Completed images move to the completed row after successfully exiting.
- Commits: `886058f`, `795cad8`, `85b9d6b`, `f735219`, `df16b29`, `8401c29`, `14c54de`,
  `53c4f26`, `e928c8d`, `c452774` — pushed and verified against `origin/main` via `git fetch`.
- Pointed-hand guides added at the maze's entry and exit gaps (`sound_quest.gd`): entry hand
  hides the instant a real drag toward the maze begins, exit hand stays up longer — hiding only
  once the drag actually arrives at the goal cell, not on release/success — and both reappear
  fresh on the next attempt's reshape. Rotation values were computed from the asset's own
  fingertip pixel position rather than eyeballed, verified by rendering each candidate rotation
  with the computed fingertip marked on top before wiring it in.
- Evened out the 4-image top row's spacing (was 339/215/341px gaps between images, now a
  consistent ~298px).
- Quest Transition (the decorative Play-Button-walks-a-maze celebration between Quests)
  completely redesigned into a 6-beat sequence: a big, noticeable bob at the top; an
  entrance approach that traces the maze's own outline (2 jumps to clear the corner, then 2
  straight axis-aligned walks — down, then across — never diagonal, never hopping past the
  corner); ~8s of wandering the maze like a kid exploring, with dead-end detours and wall-bang
  "struggle" bumps; an exit hop; and a grow/bob/fade close.
- Fixed a real bug found along the way: the decorative maze's `generate()` call never forced
  start/goal onto boundary edges, so most runs had no actual visible exit door at all. Fixed
  with explicit entry/exit cells, plus a retry loop avoiding the case where the exit lands on a
  corner cell (which cuts two boundary walls at once instead of one clean door).
- Fixed a z-order bug where the Play Button rendered underneath the maze walls near the
  entrance — explicit `z_index = 5`, matching the convention already used by the entry/exit hand
  sprites.
- Added a "Test Quest Transition" debug shortcut (Demo Shortcuts) to preview the celebration
  directly without playing through a full Quest first.
- Commits: `1c7ad9b`, `372ffd0`, `6d4d328`, `93bfb92`, `2a19a6b`, `f88da17`, `3e3a8d9`, `243fb83`,
  `24e3dec`, `7ac133f`, `a0d0fc3`, `31e501a`, `5c4eb62`, `d5db92f` — pushed and verified against
  `origin/main` via `git fetch`.
- **Prep's Sound Quest feature (gameplay + Quest Transition) is considered complete** as of this
  entry, confirmed via hands-on playtesting across every round of feedback above.

### Decisions
- Sound Quest's collision model tracks which maze *cell* the drag currently occupies and only
  allows moving into an adjacent cell when that specific wall is open (`can_move_between()` in
  `maze_generator.gd`) — an earlier rect-union approach (`full_corridor_rects()`) looked
  correct but couldn't actually distinguish a real closed wall from a dead-end branch, since
  adjacent cells' rects always touch regardless of wall state. Caught by a headless test before
  it shipped.
- No fail sound anywhere in Sound Quest — a wrong turn is discovery, not a mistake, so nothing
  plays to signal it.
- No pointed-hand guide in the Quest Transition, unlike the real gameplay maze — it's purely
  decorative with nothing for the child to act on, and a hand cue's whole purpose elsewhere is
  prompting an interaction that doesn't exist here.
- Quest Transition's Play Button never hops the entire way in — once it clears the maze's
  corner it switches to a plain walk (no arc, no scale/rotation change), split into two
  axis-aligned legs rather than one diagonal cut, reading as it following the maze's actual
  shape rather than beelining across it.

### Risks / Gotchas
- None new from this entry; see prior entries for keystore/tool-path/Gradle notes.

### Next Session
- Sound Quest itself is done for now — next session should pick up whatever the user directs;
  no specific Sound Quest follow-up is flagged as outstanding.

---

## 2026-07-29

### Completed
- Found and fixed a same-phoneme distractor bug: a Level 1F/Prep 1F "sounds mixed" round
  targeted J (`jeep` correct) but included `genie` (soft G) as a distractor — both are /dʒ/,
  the identical phoneme. Replaced `genie` with `hat` across `level_1f.json`, `level_1f_2.json`,
  `prep_1f_4.json`.
- Checked S/soft-C and K/hard-C pairs for the same class of conflict — none found elsewhere.
- Documented the Phoneme-Based Distractor Rule in `CLAUDE.md` (locked design rule).
- Fixed `G_soft.wav` — replaced with the already-verified clean J recording (same /dʒ/ sound).
- Fixed `choose_plan.gd` — Yearly card's "Full Access" label was positioned after the price
  instead of between the title and price; reordered to match the Monthly card.
- Started this worklog.
- Commits: `1abf39f`, `7c9fdb9`, `dc2881d`, `6268dba` — pushed and verified against
  `origin/main` via `git fetch`, not just trusted from local output.

### Decisions
- Choice validation is a two-level model: **phoneme level** (classify each word's actual sound
  once, independent of any round) and **round level** (a distractor must not share the
  *target's* phoneme within that specific round's choice set).
- Grapheme/spelling overlap between distractors is explicitly **not** a violation by itself —
  only a phoneme match against the target is.
- `G_soft.wav` reuses J's exact recording rather than a separate take — /dʒ/ is one sound
  regardless of spelling, so a second recording session risked introducing an audible
  inconsistency between two spellings of the identical phoneme.
- `Worklog.md` adopted as the mechanism for cross-machine (Windows/Mac) continuity, linked from
  `CLAUDE.md`.

### Risks / Gotchas
- Production keystore lives outside git by design — needs a separate, secure transfer when
  moving to Mac (not git, not email).
- Machine-specific tool paths (Godot executable, JDK, Android SDK) will differ on Mac and need
  re-establishing there.
- `android/` folder is gitignored; the `checkReleaseBuilds false` lint-crash workaround in
  `android/build/build.gradle` will need reapplying if the build template is ever reinstalled,
  on either machine.
- Gradle 8.11.1 requires JDK 21, not JDK 25 (class file version incompatibility) — whatever JDK
  Mac's Godot export points to needs to satisfy this too.

### Next Session
- Roll the genie/jeep, G_soft, and choose_plan fixes into a fresh AAB/APK build when ready.
- AAB still not yet uploaded to Google Play Console as of this entry.
- Consider a broader audit of the remaining phoneme-pair groups (/ɡ/ G vs. hard G, /ks/ X) if
  time allows, beyond the S/soft-C and K/hard-C spot-check done today.

---

## Earlier — SoundHop v1.0.0 release cycle (through 2026-07-28)

Full detail in `SoundHop_Releases/v1.0.0/RELEASE_NOTES.md`. Summary: built and verified the
first signed production AAB (`com.acron.learningsounds`, versionCode 1, versionName 1.0.0),
implemented the Parent Gate + Choose Plan flow (billing intentionally stubbed), fixed the
round-scoring-on-replay bug across all round-based levels, locked in the Back Button Philosophy
as a product-wide rule, and did a large image/phoneme-audio QA pass. Tagged `v1.0.0` at commit
`aaa7349`. AAB not yet uploaded to Play Console as of this entry.
