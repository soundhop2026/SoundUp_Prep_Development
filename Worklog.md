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
