# SoundUp Level 1.5 — Sound Builder
## FINAL DESIGN DOCUMENT

---

# Position in Curriculum

```
Prep1 → Level1 → Level1.5 → Prep2 → Level2 → SoundBuddy
```

Level 1.5 serves two purposes:
- **Graduation stage** — final and most advanced stage of consonant mastery
- **Bridge** — prepares the ear for short vowel isolation in Level 2

By the end of Level 1.5, children have heard CVC words from every angle — beginning, ending, whole word, broken apart, reassembled. The vowel in the middle becomes the only unknown. Level 2 is ready.

---

# Core Philosophy

**Words are made of multiple sound pieces.**

This level is NOT about:
- Letters
- Spelling
- Phonics rules
- Rhyme
- Long vowels
- R-controlled vowels

This level IS about helping children experience that words can be broken into separate sounds.

**No letters appear. Ever.**

---

# Visual Style

- **Background:** Brick red (#A83A22)
- **Art style:** Colorful cartoon illustrations — completely different from Level 1's hand-drawn sketches
- **UI:** Same consistent layout across all sets (see below)

---

# Format

Follows **Level 1 format** — NOT Prep Level 1.
- No Listen Bar — images act as listening buttons
- Child interacts deliberately
- This is the ADVANCED stage — no hand-holding auto-play forcing

---

# Global UI Layout

Every set uses the same consistent layout:

```
TOP:    Images (1 or 3 depending on set)
MIDDLE: Sound Cubes
BOTTOM: Open Hand sound choices
```

## Open Hand Sound Choices
- Use existing Open Hand asset from Level 1
- No letters, no text, no symbols
- When tapped: phoneme audio plays + hand briefly enlarges
- Randomized positions each round
- Children discover sounds by listening, not memorizing positions

### Number of choices per difficulty
- 3 choices — easier rounds
- 4 choices — medium difficulty
- 5 choices — advanced rounds

### Correct selection
1. Open Hand moves into target cube
2. Cube becomes filled
3. Positive feedback plays

### Wrong selection
1. Phoneme sound plays
2. Oops sound plays
3. Full round resets from beginning

---

# EvalPlayButton

A special replay button available in all sets.
- Appears after initial word presentation
- Child taps to trigger guided phoneme walk
- Hand slides across each Open Hand tile playing each phoneme in sequence
- After walk, EvalPlayButton reappears — child can re-listen as many times as needed
- Then child makes their choice

---

# "Gain and Move" Routing

- ≥85% accuracy → earn cube → advance to next set
- <85% accuracy → replay wrong rounds only
- No dead ends — every path leads forward
- 13-cube board fills as child progresses (one cube per set)

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
| 5D | Build the Word Challenge (CCVCC) | 20 |
| 6  | Sound Count | 20 |

**Total: 220 rounds**

---

# Word Structure Per Set

| Set | CVC | CCVC | CVCC | CCVCC |
|-----|-----|------|------|-------|
| 1A | ✅ | ✅ | ✅ | ❌ |
| 1B | ✅ | ✅ | ✅ | ❌ |
| 2A | ✅ | ✅ | ✅ | ❌ |
| 2B | ✅ | ✅ | ✅ | ❌ |
| 3A | ✅ | ✅ | ✅ | ❌ |
| 3B | ✅ | ✅ | ✅ | ❌ |
| 4A | ✅ | ✅ | ✅ | ❌ |
| 4B | ✅ | ✅ | ✅ | ❌ |
| 5A | ✅ | ❌ | ❌ | ❌ |
| 5B | ✅ | ✅ | ✅ | ❌ |
| 5C | ✅ | ✅ | ✅ | ❌ |
| 5D | ✅ | ✅ | ✅ | ✅ |

---

# MODE 1 — Identification (Sets 1A / 1B / 2A / 2B)

## 1A / 1B — Initial Phoneme Identification
**Task:** Find the common BEGINNING sound across 3 images.

**Round flow:**
1. 3 images shown simultaneously
2. Pointed hand sits at right side pointing toward images
3. Each word plays in sequence with pulse animation on image
4. EvalPlayButton appears — guided phoneme walk (hand slides across Open Hand tiles playing each phoneme)
5. EvalPlayButton reappears — child can re-listen as many times as needed
6. Child taps correct Open Hand
7. Correct → sound moves into Cube #1 → round ends
8. Wrong → phoneme plays → oops → full round resets

**Example:**
- 🐱 Cat / 🧢 Cap / 🥤 Cup
- Cubes: ⬜ ⬜ ⬜ — Only Cube #1 shakes
- Choices: /k/ /m/ /t/
- Answer: /k/

## 2A / 2B — Final Phoneme Identification
Same flow as 1A/1B but finding common ENDING sound.

**Example:**
- 🐱 Cat / 🎩 Hat / 🟫 Mat
- Cubes: ⬜ ⬜ ⬜ — Only Cube #3 shakes
- Choices: /t/ /p/ /m/
- Answer: /t/

---

# MODE 2 — Isolation (Sets 3A / 3B / 4A / 4B)

## 3A / 3B — Initial Phoneme Isolation
**Task:** Hear ONE word, find the FIRST sound.

**Round flow:**
1. Single image shown
2. Word plays automatically
3. Child may tap image anytime to replay
4. EvalPlayButton appears — phoneme walk plays
5. Child taps correct Open Hand
6. Correct → sound moves into Cube #1
7. Wrong → phoneme plays → oops → full round resets

**Example:**
- 🐶 Dog
- Cubes: ⬜ ⬜ ⬜ — Only Cube #1 shakes
- Choices: /d/ /g/ /m/
- Answer: /d/

## 4A / 4B — Final Phoneme Isolation
Same flow as 3A/3B but finding the LAST sound.

**Example:**
- 🐶 Dog
- Cubes: ⬜ ⬜ ⬜ — Only Cube #3 shakes
- Choices: /g/ /d/ /m/
- Answer: /g/

---

# MODE 3 — Build the Word (Sets 5A / 5B / 5C / 5D)

**Task:** Drag phoneme tiles into cube slots to build the word LEFT TO RIGHT.

**Round flow:**
1. Single image shown
2. Word plays automatically
3. Hand slides across each Open Hand tile auto-playing each phoneme in sequence
4. EvalPlayButton available — replays target word during build phase
5. Child drags tiles into cube slots in LEFT-TO-RIGHT order
6. Correct tile fills next cube
7. Wrong tile → shakes → returns to original position
8. All cubes filled → word complete → positive feedback

**Example (Set 5A — CVC):**
- 🐷 Pig
- Cubes: ⬜ ⬜ ⬜ — all shake
- Choices: /p/ /i/ /g/ /m/
- Fill order: /p/ → Cube 1, /i/ → Cube 2, /g/ → Cube 3 ✅

**Set complexity:**
- 5A — CVC only
- 5B — CVC + CCVC + CVCC
- 5C — Advanced (larger word bank, more distractors)
- 5D — Includes CCVCC (5 cubes, 5-7 sound choices)

---

# MODE 4 — Sound Count (Set 6)

**Task:** Count how many sounds are in the word.

**Round flow:**
1. Single image shown
2. Word plays automatically with hand pointing at image
3. Child may tap image to replay
4. Three buttons appear — each showing filled orange cube tiles:
   - ⬛⬛⬛ (3 sounds) — tapping plays "three"
   - ⬛⬛⬛⬛ (4 sounds) — tapping plays "four"
   - ⬛⬛⬛⬛⬛ (5 sounds) — tapping plays "five"
5. Child taps correct count
6. Wrong → oops → resets

**Note:** Buttons show CUBE TILES not numbers. Children count sounds, not read digits.

**Examples:**
- pig → 3
- frog → 4
- plant → 5

---

# Word Rules

**Allowed:**
- ✅ Short vowels (a, e, i, o, u)
- ✅ CVC, CCVC, CVCC, CCVCC
- ✅ Single consonant phonemes

**Not Allowed:**
- ❌ Digraphs (sh, ch, th, wh, ph)
- ❌ Long vowels
- ❌ R-controlled vowels
- ❌ Silent letters
- ❌ Vowel teams
- ❌ Diphthongs

---

# Word Bank Summary

| Structure | Count | Have ✅ | New 🆕 |
|-----------|-------|---------|--------|
| CVC | 68 | 55 | 13 |
| CCVC | 23 | 3 | 20 |
| CVCC | 21 | 11 | 10 |
| CCVCC | 18 | 5 | 13 |
| **Total** | **130** | **74** | **56** |

Full word list: see `SoundUp_Level1.5_WordBank_Final.md`

---

# Audio Production

## Word audio (Speaktor)
- Voice: Chloe (young girl)
- Speed: 25% slower than original
- 56 new word recordings needed
- Location: `res://BGM&effect/SoundUp_level1.5_word_sounds/`

## Short vowel phonemes (Sully records in Audacity)
- a_sound.wav — short /a/ as in cat
- e_sound.wav — short /e/ as in bed
- i_sound.wav — short /i/ as in pig
- o_sound.wav — short /o/ as in dog
- u_sound.wav — short /u/ as in cup

---

# Educational Outcome

By the end of Level 1.5, children should NOT be expected to identify short vowels.

Instead they will have naturally discovered:
- Words contain multiple sounds
- Words can be broken apart
- Words have beginning, middle, and ending sounds
- Words can contain 3, 4, or 5 sounds

**Level 2 short vowel discrimination follows.**

**Sound first. Always.**
