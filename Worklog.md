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
  - Maze solution path is hidden; the approach to the maze is a plain free-drag with no guide
    line at all (the maze's entry gap is already fully visible, so no path indicator is needed).
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

### Decisions
- Sound Quest's collision model tracks which maze *cell* the drag currently occupies and only
  allows moving into an adjacent cell when that specific wall is open (`can_move_between()` in
  `maze_generator.gd`) — an earlier rect-union approach (`full_corridor_rects()`) looked
  correct but couldn't actually distinguish a real closed wall from a dead-end branch, since
  adjacent cells' rects always touch regardless of wall state. Caught by a headless test before
  it shipped.
- No fail sound anywhere in Sound Quest — a wrong turn is discovery, not a mistake, so nothing
  plays to signal it.

### Risks / Gotchas
- None new from this entry; see prior entries for keystore/tool-path/Gradle notes.

### Next Session
- Continue hands-on playtesting of Sound Quest (DEBUG → Demo Shortcuts → "Test Sound Quest
  (Group A)") for any further exploration-flow feedback.

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
