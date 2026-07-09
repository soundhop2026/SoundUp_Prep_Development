# SoundUp — Complete Curriculum Arc
## MASTER DESIGN DOCUMENT

Last updated: June 2026

---

# Philosophy

**Sound first. Always.**

Children hear and speak long before they read. Every level in SoundUp builds the ear before the eye ever sees a written word. Letters are symbols. Sounds are real.

Before writing existed, humans lived in a world of sound. Sound is invisible — it moves through space as powerful waves. We cannot hold it, see it, or stop it. The moment a sound is spoken, it begins to disappear. Writing may have been humanity's attempt to capture sound and preserve it through time.

**This is why SoundUp begins with sounds rather than letters.**

Each level introduces exactly ONE new concept.
Each .5 level bridges and graduates the level before it.
The .5 levels are discovered through building and testing — not assumed in advance.

*"I feel like I can experience a new realm in my brain through sounds."*

When a design decision is unclear — return here.

---

# The Full Arc

```
Prep 1
  ↓
Level 1    — consonant isolation
  ↓
Level 1.5  — phonemic manipulation (bridge to vowels)
  ↓
Level 2    — short vowel isolation
  ↓
Level 2.5  — rime families (bridge to digraphs)
  ↓
Level 3    — digraphs + blends
  ↓
Level 3.5  — TBD (discovered after building Level 3)
  ↓
Level 4    — diphthongs + long vowels
  ↓
Level 4.5  — TBD (discovered after building Level 4)
  ↓
SoundBuddy — letters + spelling (mirrors all levels)
```

---

# Confirmed Levels

## Prep 1
- **Purpose:** Build sound discrimination and vocabulary before Level 1
  - If a child does not know the image names in Prep, they will struggle in Level 1
- **Format:** Auto-play (phoneme ×3, image ×2), pointed hand guides — no deliberate press required
- **Content:** All 21 consonant phonemes, same images as Level 1
- **Background:** Baby green `#A8E063`
- **Art style:** Hand-drawn black-and-white sketches
- **Gate:** 85% accuracy per sub-set ("Gain and Move")
- **Sets:** 33 sub-sets across 7 main groups

| Group | Indices | Content | Choices |
|-------|---------|---------|---------|
| 1A | 0–3 | M S T B V K | 3 |
| 1B | 4–7 | N F P D G J | 4 |
| 1C | 8–13 | H W Y L R Z | 4 |
| 1D | 14–19 | Contrast pairs | 4 |
| 1E | 20–23 | C-soft G-soft X Q | 3 |
| 1F | 24–27 | All sounds mixed | 5 |
| 1G | 28–32 | Ending sounds | 4 |

- **Cube board:** 7 cubes (one per main group), shown only at main set boundaries with ≥85%
- **Transition:** `prep_transition.tscn` → `level_transition.tscn` (graduation, once per lifetime)
- **Status:** ✅ BUILT

---

## Level 1 — Consonant Isolation
- **Purpose:** Child hears a phoneme, picks the matching image from a row of choices
- **Format:** Deliberate LISTEN press — never auto-play on round start
- **Content:** 21 consonant phonemes, initial sounds
- **Background:** Sky blue `#6EB5FF`
- **Art style:** Hand-drawn black-and-white sketches (same images as Prep)
- **Gate:** 95% = advance (earn cube), 85% = retry wrong rounds, below 85% = replay full set
- **Sets:** 17 sets, 331 rounds

| Sets | Content | Choices | Rounds |
|------|---------|---------|--------|
| 1A-1, 1A-2 | m s t b k v | 3 | 40 |
| 1B-1, 1B-2 | n f p d g j | 4 | 40 |
| 1C-1, 1C-2, 1C-3 | h w y l z r | 4 | 60 |
| 1D-1, 1D-2, 1D-3 | contrast pairs | 4 | 56 |
| 1E-1, 1E-2 | c-soft g-soft x q | 3 | 40 |
| 1F-1, 1F-2 | all 21 mixed | 5 | 40 |
| 1G-1, 1G-2, 1G-3 | ending sounds | 4 | 55 |

- **Cube board:** 17 cubes, deep blue, earned only on 3-star (≥95%)
- **Transition:** `transition.tscn` with `_for_l15 = false`
- **Key feature:** Shuffle with no-consecutive-same-phoneme algorithm
- **Status:** ✅ BUILT

---

## Level 1.5 — Sound Builder (Phonemic Manipulation)
- **Purpose:** Graduate consonant mastery + bridge to vowel isolation
  - New concept: words are built from multiple sound pieces
- **Format:** Deliberate interaction — no auto-play on round start
- **Content:** Same words and images as Level 1 — no new vocabulary
- **Background:** Brick red `#A83A22`
- **Art style:** Colorful cartoon illustrations
- **Gate:** 85% Gain and Move
- **Sets:** 13 sets

| Sets | Mode | Content | Rounds |
|------|------|---------|--------|
| 1A, 1B | Initial Phoneme Identification | Find common beginning sound from 3 images | 15 each |
| 2A, 2B | Final Phoneme Identification | Find common ending sound from 3 images | 15 each |
| 3A, 3B | Initial Phoneme Isolation | Isolate first sound from single word | 15 each |
| 4A, 4B | Final Phoneme Isolation | Isolate last sound from single word | 15 each |
| 5A, 5B, 5C, 5D | Build the Word | Drag phoneme tiles into cube slots left-to-right | 20 each |
| 6 | Sound Count | How many sounds in this word? (3/4/5) | 20 |

- **4 Modes (all in game15.gd):**
  1. **Identification** — 3 images auto-play, find common initial or final sound
  2. **Isolation** — single word, find first or last sound
  3. **Build the Word** — drag phoneme tiles into cube slots in order; left-to-right always
  4. **Sound Count** — tap orange cube buttons (3/4/5) — not numbers, visual cubes

- **EvalPlayButton:** Always at position (1050, 380) — never moves
- **Pointed hand:**
  - Toward images: position (1050, 280), rotation −30°
  - Phoneme walk (tiles): rotation 180°, slides between tile centers
- **Cube board:** 13 cubes, two rows, earned on ≥85%
- **Transition:** `transition.tscn` with `_for_l15 = true` (MUST set `Level15Progress.active = true` before routing)
- **Status:** 🔨 DESIGNED — assets in production

---

## Level 2 — Short Vowel Isolation
- **Purpose:** Child identifies short vowel sounds in real words
- **Format:** Deliberate LISTEN/cube press — never auto-play on round start
- **Content:** 5 short vowels — CVC, CCVC, CVCC, CCVCC words
- **No digraphs, no long vowels**
- **Background:** Olive green `#7A8C2E`
- **Art style:** Colorful cartoon illustrations (reuses Level 1.5 images)
- **Gate:** 85% Gain and Move
- **Vowel order:** a → i → o → u → e
  - /e/ introduced last — most confusing for Korean ears
  - /e/ vs /i/ is the hardest contrast pair
- **Sets:** 12 sets (indices 0–11), ~270 rounds total

### Two game modes

**Option 2 — Hear Word → Pick Vowel** (`game2.gd`, sets 2A–2H, indices 0–7)

Child hears a word and sees its image. A row of vowel buttons (a / e / i / o / u) sits below. A phoneme cube blinks on the correct vowel's position.

- **Dynamic cube row:** Number of cubes and the blinking position reflect the word's actual phoneme structure
  - CVC (3 phonemes, vowel_pos 2): ● ◆ ●  ← middle blinks
  - CCVC (4 phonemes, vowel_pos 3): ● ● ◆ ●  ← third blinks
  - CVCC (4 phonemes, vowel_pos 2): ● ◆ ● ●  ← second blinks
  - CCVCC (5 phonemes, vowel_pos 3): ● ● ◆ ● ●  ← third blinks
- **JSON fields per round:** `word`, `word_audio`, `word_image`, `correct_vowel`, `phonemes`, `vowel_pos`
- **x-ending words** (six, fix, box) treated as CVCC — x = /k/+/s/ = 2 phonemes

| Set | Index | Content | Rounds |
|-----|-------|---------|--------|
| 2A | 0 | /a/ only | 20 |
| 2B | 1 | /i/ only | 20 |
| 2C | 2 | /a/ vs /i/ contrast | 20 |
| 2D | 3 | /o/ only | 20 |
| 2E | 4 | /o/ vs /a/ vs /i/ | 20 |
| 2F | 5 | /u/ only | 20 |
| 2G | 6 | /u/ vs /o/ | 20 |
| 2H | 7 | All 5 vowels mixed | 30 |

**Option 1 — Hear Vowel → Find Matching Image** (`game25.gd`, sets 2I–2L, indices 8–11)

Child hears an isolated vowel sound. Four (or five) images are shown. The child drags the vowel cube onto the image whose word contains that vowel.

- **Educational intent:** The child holds the vowel sound (the cube) and carries it to the word that owns it. The gesture encodes the lesson — the vowel is the primary object, not the word.
- **Drag mechanic:** Press the blinking cube → ghost cube follows finger/cursor → drop on correct image
  - Drop on correct image → correct sound + advance
  - Drop on wrong image → oops/wrong sound + retry round
  - Drop on empty space → cube restores, blink resumes, no penalty
- **Phase state machine:** `wait_listen` → `vowel_playing` → `wait_eval` → `walk` → `wait_answer`
- **Images shown from round start** — safe because phase check blocks early taps
- **During walk:** hand visits each image in order, speaks the word aloud
- **JSON fields per round:** `target_vowel`, `correct_word`, `correct_audio`, `correct_image`, `distractors[]`

| Set | Index | Content | Images | Rounds |
|-----|-------|---------|--------|--------|
| 2I | 8 | /a/ vs /e/ | 4 | 25 |
| 2J | 9 | /o/ vs /u/ | 4 | 25 |
| 2K | 10 | /i/ focus, mixed distractors | 3 | 25 |
| 2L | 11 | All 5 vowels mixed | 5 | 25 |

- **`Level2Progress.is_option1()`** returns true when `current_index >= 8`
- **Audio:** 5 isolated short vowel recordings (Sully, Audacity) — `short_a.wav` through `short_u.wav`
- **Transition:** `transition.tscn` (Level 2 branch — not _for_l15)
- **Status:** ✅ BUILT

---

## Level 2.5 — Rime Families
- **Purpose:** Bridge from short vowel isolation to digraphs/blends
- **Content:** Rime families (-at, -ig, -og, -ug, -ed etc.)
- **No digraphs** — pure consonant + short vowel + consonant only
- **Vowel order follows Level 2:** a → i → o → u → e

| Vowel | Families |
|-------|---------|
| /a/ | -at, -an, -ap, -ag, -am, -and, -amp |
| /i/ | -ig, -in, -ip, -it, -ix, -id |
| /o/ | -og, -op, -ot, -ob, -ock, -omp |
| /u/ | -ug, -un, -up, -ut, -ub, -ump, -unk, -ust |
| /e/ | -ed, -en, -et, -eg, -ell, -est, -ent |

- **Status:** 📋 DRAFT — mechanic and word bank to be designed

---

## Level 3 — Digraphs + Blends
- **Purpose:** Introduce consonant digraphs and blends
- **Content:** sh, ch, th, wh, ng + bl, cr, str, etc.
- **Status:** 💡 CONCEPT ONLY — design after Level 2.5 is built

---

## Level 3.5 — TBD
- **Purpose:** Unknown — will be discovered after building and testing Level 3
- **Philosophy:** Kids' struggles reveal the gaps. Build Level 3 first.
- **Status:** ❓ TBD

---

## Level 4 — Diphthongs + Long Vowels
- **Purpose:** Introduce complex vowel sounds
- **Content:** oi, ou, ow, ay, ee, oa, ai, etc.
- **Status:** 💡 CONCEPT ONLY — design after Level 3 is built

---

## Level 4.5 — TBD
- **Purpose:** Unknown — will be discovered after building and testing Level 4
- **Status:** ❓ TBD

---

# SoundBuddy — Letters + Spelling
- **Purpose:** Visual companion to SoundUp — same phonemes, now with letters shown
- **Platform:** Godot 4.5, Google Play
- **3 phases per phoneme set:**
  1. Hear letter name → tap the letter
  2. Hear phoneme → tap the letter
  3. See picture → spell word left-to-right
- **Mirrors SoundUp levels** — unlocks as SoundUp levels are cleared
- **V1 sync:** 6-character import code
- **Status:** 🔨 DESIGNED — builds after Level 1.5 assets ready

---

# Scene Architecture

## Gameplay scenes

| Scene | Level | Purpose |
|-------|-------|---------|
| `prep_game.tscn` | Prep 1 | Prep gameplay (auto-play) |
| `game.tscn` | Level 1 | Hear phoneme → pick image |
| `game15.tscn` | Level 1.5 | 4 modes (identification/isolation/build/count) |
| `game2.tscn` | Level 2 (2A–2H) | Hear word → pick vowel |
| `game25.tscn` | Level 2 (2I–2L) | Hear vowel → drag cube to image |

## Transition scenes (THREE — never confuse them)

| Scene | Used by | Key detail |
|-------|---------|------------|
| `prep_transition.tscn` | Prep 1 only | Bounce ×6; cube board at main set boundaries only |
| `transition.tscn` | Level 1 + Level 1.5 | Branched by `_for_l15` flag; star dance + slot machine |
| `level_transition.tscn` | Prep → Level 1 graduation | Crown descends; plays once per lifetime |

## Progress singletons (autoloads)

| Singleton | Level |
|-----------|-------|
| `PrepLevelProgress` | Prep 1 |
| `LevelProgress` | Level 1 |
| `Level15Progress` | Level 1.5 |
| `Level2Progress` | Level 2 |

---

# Shared Game Features (all main levels)

- **LISTEN button = deliberate press.** Never auto-play on round start.
- **Mastery accuracy:** `clean_correct_count / rounds.size()`. Only a wrong click sets `_round_hint_used`. Replaying audio, thinking time, and hint animations are penalty-free.
- **Gain and Move routing:** ≥85% → advance; <85% → retry wrong rounds (loop until ≥85%)
- **Back button:** Position (108, 25), always visible. Backs one round; clears hint state for that round.
- **Shuffle:** No consecutive same phoneme/vowel within a set.
- **CRITICAL routing rule:** `has_next()` must be checked BEFORE `advance()` in all transition scenes.

---

# Audio Production Pipeline

## Speaktor (Chloe voice, 25% slower)
- All word audio for every level
- Letter names for SoundBuddy Phase 1 (typed as words: "ay" "bee" "see")

## Sully records in Audacity
- All isolated phoneme sounds
- Short vowel sounds: /a/ /e/ /i/ /o/ /u/
- These 5 files serve Level 1.5 + Level 2 + SoundBuddy Phase 2

---

# Design Rules (global, never broken)

1. **Sound first. Always.** No letters ever appear in SoundUp.
2. **LISTEN button = deliberate press.** Never auto-play on round start in main levels.
3. **One new concept per level.** Never introduce two things at once.
4. **.5 levels are discovered, not assumed.** Build first, then decide.
5. **/e/ always after /i/.** Never reverse this order.
6. **No digraphs before Level 3.** Keep levels pure.
7. **No long vowels or diphthongs before Level 4.**
8. **Left to right always.** Directionality is the lesson.
9. **Never invent timing values.** Use `await sound.finished` for audio. Only change a tuned value if it violates the locked design.

---

# New Concept Per Level

| Level | New concept introduced |
|-------|----------------------|
| Prep 1 | Pure sound discrimination (scaffolded) |
| Level 1 | Consonant isolation |
| Level 1.5 | Phonemic manipulation — words have multiple sound pieces |
| Level 2 | Short vowel isolation — hold the vowel, find its word |
| Level 2.5 | Rime pattern recognition |
| Level 3 | Digraphs + blends |
| Level 3.5 | TBD |
| Level 4 | Diphthongs + long vowels |
| Level 4.5 | TBD |
| SoundBuddy | Print — letters + spelling |
