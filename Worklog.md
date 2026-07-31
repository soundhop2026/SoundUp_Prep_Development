# SoundHop — Worklog

Living record of work sessions, kept in git so work can continue seamlessly between machines
(Windows and Mac) — Claude Code sessions themselves don't carry over across machines, but this
file does. Newest entries at the top. See `CLAUDE.md` for the standing project reference and
locked design rules; this file is for session-by-session history and handoff notes instead.

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

## 2026-07-29 — Content validation rules, phoneme fixes, cross-platform worklog setup

**Found and fixed a same-phoneme distractor bug**: a Level 1F/Prep 1F "sounds mixed" round
targeted J (`jeep` correct) but included `genie` (soft G) as a distractor — both are /dʒ/, the
identical phoneme, so a child correctly identifying the sound and picking `genie` would've been
marked wrong. Replaced `genie` with `hat` across `level_1f.json`, `level_1f_2.json`,
`prep_1f_4.json`. Checked S/soft-C and K/hard-C pairs too — no other conflicts found.

**Documented this as a permanent rule in CLAUDE.md** — `## Phoneme-Based Distractor Rule
(locked)`: validation happens at two levels (phoneme classification, independent of any round;
then round-level — no distractor may share the *target's* phoneme within that specific round).
Grapheme/spelling overlap between distractors is explicitly never itself the problem.

**`G_soft.wav` fix**: was never updated when `J.wav` got its noise fix earlier this session,
despite representing the identical /dʒ/ sound. Reused the already-verified clean J recording
byte-for-byte rather than a separate take (same intentional-duplicate pattern as
`short_i`/`short_u` between Level 2 and Level 1.5).

**`choose_plan.gd` fix**: Yearly card's "Full Access" label was in the wrong position (after
the price instead of between the title and price, unlike the Monthly card). Reordered to match.

**Commits**: `1abf39f`, `7c9fdb9`, `dc2881d` — all pushed, verified against `origin/main` via
`git fetch` (not just trusted from local output).

**Started this worklog** — going forward, add a dated entry per work session so context carries
across Windows/Mac.

---

## Earlier — SoundHop v1.0.0 release cycle (through 2026-07-28)

Full detail in `SoundHop_Releases/v1.0.0/RELEASE_NOTES.md`. Summary: built and verified the
first signed production AAB (`com.acron.learningsounds`, versionCode 1, versionName 1.0.0),
implemented the Parent Gate + Choose Plan flow (billing intentionally stubbed), fixed the
round-scoring-on-replay bug across all round-based levels, locked in the Back Button Philosophy
as a product-wide rule, and did a large image/phoneme-audio QA pass. Tagged `v1.0.0` at commit
`aaa7349`. AAB not yet uploaded to Play Console as of this entry.
