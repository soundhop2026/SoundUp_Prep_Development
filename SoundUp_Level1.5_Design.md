# SoundUp Level 1.5 – Sound Builder

## FINAL DESIGN DOCUMENT

---

# Core Goal

Level 1 taught children individual consonant sounds.

Level 2 will teach short vowel discrimination.

Level 1.5 exists to teach one important idea:

**Words are made of multiple sound pieces.**

This level is NOT about:
- spelling
- letters
- phonics rules
- rhyme
- long vowels
- r-controlled vowels

This level is about helping children experience that words can be broken into separate sounds.

---

# Format

Level 1.5 follows the **Level 1 format** — NOT Prep Level 1.
- Child interacts deliberately (no auto-play forced)
- Same game loop and UI discipline as Level 1
- This is the ADVANCED and FINAL stage of consonant mastery
- Also serves as the BRIDGE to Level 2 short vowels

---

# Global Design Rules

## No Listen Bar
Remove the Listen Bar completely.
Images act as listening buttons.
Children tap images to hear words.

## Consistent UI Across All Sets
Every set uses the same layout:
- Top: Images
- Middle: Sound Cubes
- Bottom: Sound Choices (Open Hands)

The gameplay changes, but the UI stays consistent.

## Sound Choices — Open Hand Asset
All sound choices use the existing Open Hand asset.
- No letters displayed
- No text labels displayed
- The Open Hand represents a sound container
- When tapped: phoneme audio plays + hand briefly enlarges
- Children discover sounds by listening, not memorizing positions
- Randomize Open Hand positions each round

### Number of choices
- 3 choices — easier rounds
- 4 choices — medium difficulty
- 5 choices — advanced rounds

### Interaction
Correct selection:
1. Open Hand moves into the target cube
2. Cube becomes filled
3. Positive feedback plays

Wrong selection:
1. Open Hand shakes briefly
2. Wrong feedback plays
3. Hand returns to original position

### Design Philosophy
The child is not selecting letters.
The child is not selecting symbols.
The child is grabbing sounds and placing them into sound cubes.
This should feel like building words from sound pieces.

---

# Set Structure

| Set | Skill | Rounds |
|-----|-------|--------|
| 1A | Initial Phoneme Identification | 15 |
| 1B | Initial Phoneme Identification | 15 |
| 2A | Final Phoneme Identification | 15 |
| 2B | Final Phoneme Identification | 15 |
| 3A | Initial Phoneme Isolation | 15 |
| 3B | Initial Phoneme Isolation | 15 |
| 4A | Final Phoneme Isolation | 15 |
| 4B | Final Phoneme Isolation | 15 |
| 5A | Build the Word (CVC only) | 20 |
| 5B | Build the Word (CVC + CCVC + CVCC) | 20 |
| 5C | Build the Word Advanced | 20 |
| 5D | Build the Word Challenge (CCVCC included) | 20 |
| 6 | Sound Count | 20 |

**Total: 220 Rounds**

---

# Word Structure Usage

| Set | Skill | CVC | CCVC | CVCC | CCVCC |
|-----|-------|-----|------|------|-------|
| 1A | Initial Identification | ✅ | ✅ | ✅ | ❌ |
| 1B | Initial Identification | ✅ | ✅ | ✅ | ❌ |
| 2A | Final Identification | ✅ | ✅ | ✅ | ❌ |
| 2B | Final Identification | ✅ | ✅ | ✅ | ❌ |
| 3A | Initial Isolation | ✅ | ✅ | ✅ | ❌ |
| 3B | Initial Isolation | ✅ | ✅ | ✅ | ❌ |
| 4A | Final Isolation | ✅ | ✅ | ✅ | ❌ |
| 4B | Final Isolation | ✅ | ✅ | ✅ | ❌ |
| 5A | Build the Word | ✅ | ❌ | ❌ | ❌ |
| 5B | Build the Word | ✅ | ✅ | ✅ | ❌ |
| 5C | Build the Word Advanced | ✅ | ✅ | ✅ | ❌ |
| 5D | Build the Word Challenge | ✅ | ✅ | ✅ | ✅ |

---

# SET 1A / 1B — Initial Phoneme Identification

**Task:** Find the common BEGINNING sound across 3 images.

**Example:**
- 🐱 Cat / 🧢 Cap / 🥤 Cup

**UI:**
- Top: 3 images
- Middle: ⬜ ⬜ ⬜ — Only Cube #1 shakes
- Bottom: /k/ /m/ /t/

**Gameplay:**
1. Child taps images to hear words
2. Child figures out common beginning sound
3. Child taps correct Open Hand sound
4. Correct sound moves into Cube #1
5. Round ends

**Correct answer:** /k/

---

# SET 2A / 2B — Final Phoneme Identification

**Task:** Find the common ENDING sound across 3 images.

**Example:**
- 🐱 Cat / 🎩 Hat / 🟫 Mat

**UI:**
- Top: 3 images
- Middle: ⬜ ⬜ ⬜ — Only Cube #3 shakes
- Bottom: /t/ /p/ /m/

**Gameplay:**
1. Child taps images to hear words
2. Child finds common ending sound
3. Child taps correct sound
4. Sound moves into Cube #3
5. Round ends

**Correct answer:** /t/

---

# SET 3A / 3B — Initial Phoneme Isolation

**Task:** Hear one word, find the FIRST sound.

**Example:**
- 🐶 Dog

**UI:**
- Top: 1 image
- Middle: ⬜ ⬜ ⬜ — Only Cube #1 shakes
- Bottom: /d/ /g/ /m/

**Gameplay:**
1. Word automatically plays 3 times
2. Child may tap image anytime to replay
3. Child finds first sound
4. Child taps correct sound
5. Sound moves into Cube #1
6. Round ends

**Correct answer:** /d/

---

# SET 4A / 4B — Final Phoneme Isolation

**Task:** Hear one word, find the LAST sound.

**Example:**
- 🐶 Dog

**UI:**
- Top: 1 image
- Middle: ⬜ ⬜ ⬜ — Only Cube #3 shakes
- Bottom: /g/ /d/ /m/

**Gameplay:**
1. Word automatically plays 3 times
2. Child may replay by tapping image
3. Child finds last sound
4. Child taps correct sound
5. Sound moves into Cube #3
6. Round ends

**Correct answer:** /g/

---

# SET 5A — Build the Word (CVC only)

**Task:** Tap sounds in order to build the word.

**Example:**
- 🐷 Pig

**UI:**
- Top: 1 image
- Middle: ⬜ ⬜ ⬜ — All cubes shake
- Bottom: /p/ /i/ /g/ /m/

**Gameplay:**
1. Word automatically plays 3 times
2. Child may replay by tapping image
3. Child taps sound buttons to hear phonemes
4. Child selects sounds in LEFT-TO-RIGHT order
5. Correct sound automatically fills next empty cube
6. All cubes filled correctly → word completed

**Example fill order:**
- /p/ → Cube 1
- /i/ → Cube 2
- /g/ → Cube 3
- Complete ✅

---

# SET 5B — Build the Word (CVC + CCVC + CVCC)

Same UI and gameplay as Set 5A.
Only word complexity increases.

**Example words:**
- frog, drum, sand, kick, dress

---

# SET 5C — Build the Word Advanced

Same gameplay as 5A/5B.
Larger word bank. More distractor sounds.

---

# SET 5D — Build the Word Challenge (CCVCC included)

**Example words:**
- plant, stamp, clamp, grand, blend, stand, trust, spend, twist, crust

**UI:**
- Top: Image
- Middle: ⬜ ⬜ ⬜ ⬜ ⬜ (5 cubes)
- Bottom: 5–7 sound choices

**Goal:** Expose children to 5-sound words. Help children experience that words can contain different numbers of sounds.

---

# SET 6 — Sound Count

**Purpose:** Children discover that words can contain 3, 4, or 5 sounds.

**UI:**
- Top: Image
- Middle: Count buttons (each plays audio when tapped)
  - ⚪⚪⚪ → plays "three"
  - ⚪⚪⚪⚪ → plays "four"
  - ⚪⚪⚪⚪⚪ → plays "five"

**Gameplay:**
1. Word automatically plays 3 times
2. Child may replay by tapping image
3. Child counts sounds
4. Child chooses correct sound count

**Examples:**
- pig → 3
- frog → 4
- plant → 5

---

# Word Rules

**Allowed:**
- ✅ Short vowels
- ✅ Single consonant phonemes
- ✅ CVC
- ✅ CCVC
- ✅ CVCC
- ✅ CCVCC

**Not Allowed:**
- ❌ Digraphs
- ❌ Long vowels
- ❌ R-controlled vowels
- ❌ Silent letters
- ❌ Vowel teams
- ❌ Diphthongs

---

# Word Bank Status

**Current:**
- CVC: ~31 words
- CCVC: ~3 words
- CVCC: ~3 words

**Needed:**
- CVC: 80+ words
- CCVC: 40 words
- CVCC: 40 words
- CCVCC: 10 words

**Audio needed:**
- Short vowel sounds: /a/ /e/ /i/ /o/ /u/
- All added word audio files (.wav)

---

# 85% Accuracy Gate

Same gate as Level 1 — child must achieve 85% accuracy across Level 1.5 sets before advancing to Prep 2 / Level 2.

---

# Educational Outcome

By the end of Level 1.5, children should NOT be expected to identify short vowels.

Instead, they should naturally discover:
- Words contain multiple sounds
- Words can be broken apart
- Words have beginning, middle, and ending sounds
- Words can contain 3, 4, or 5 sounds

**Level 2 will then teach short vowel discrimination.**
