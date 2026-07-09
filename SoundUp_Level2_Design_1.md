# SoundUp Level 2 — Short Vowels
## FINAL DESIGN DOCUMENT

---

# Position in Curriculum

```
Prep → Level1 → Level1.5 → Level2 → Level2.5 → ...
```

By the time a child reaches Level 2:
- All consonant phonemes solid (Level 1)
- Words can be broken apart and built (Level 1.5)
- The frame [consonant] - ? - [consonant] is familiar
- The vowel is the ONLY unknown

**Level 2's job: make the vowel as solid as the consonants.**

---

# Visual Style

- **Background:** Warm olive green #7A8C2E
- **Art style:** Colorful cartoon illustrations (same as Level 1.5)
- **Images:** Reuses Level 1.5 CVC word images — no new art needed

### Color progression
```
Prep 1    → Baby green  #A8E063  — pencil drawings (consonants)
Level 1   → Sky blue    #6EB5FF  — pencil drawings (consonants)
Level 1.5 → Brick red   #A83A22  — colorful cartoons
Level 2   → Warm olive  #7A8C2E  — colorful cartoons (vowels)
Level 3   → TBD                  — pencil drawings (digraphs + blends)
```

**Art style meaning:**
- Pencil drawings = consonant-focused levels
- Colorful cartoons = vowel-focused levels

---

# Core Challenge

English short vowels are NOT pure sounds — they shift depending on surrounding consonants. Especially hard for Korean kids:

| Vowel | Challenge |
|-------|-----------|
| /a/ as in cat | Easily confused with /e/ |
| /e/ as in bed | Most confusing — introduced last |
| /i/ as in pig | Clearest — closest to Korean 이 |
| /o/ as in dog | Easily confused with /u/ |
| /u/ as in cup | Hard — /ʌ/ doesn't exist in Korean |

**Key confusion pairs:**
- /a/ vs /e/ — contrast early and often
- /o/ vs /u/ — contrast early and often
- /e/ introduced after /i/ is solid

---

# Two Game Formats

## Option 2 — Hear word → Identify vowel (comes FIRST)
**Purpose:** Child isolates the vowel sound from the word

```
Round flow:
1. Pointed hand → points to LISTEN bar
2. Child presses LISTEN → hears word (e.g. "cat")
3. Three cubes appear — middle cube blinks 🔲
4. EvalPlayButton → child can replay word anytime
5. Open hands at bottom — each plays a vowel sound
6. Child taps open hands to hear /a/ /e/ /i/ /o/ /u/
7. Child selects correct vowel sound
8. Correct → vowel moves into middle cube ✅
9. Wrong → oops → try again same round
```

**Why first:** Child learns to ISOLATE the vowel before recognizing it in new words.

---

## Option 1 — Hear vowel → Find matching image (comes SECOND)
**Purpose:** Child applies vowel knowledge to recognize words

```
Round flow:
1. Pointed hand → points to LISTEN bar
2. Child presses LISTEN → hears vowel sound (e.g. /a/)
3. Three cubes — middle cube blinks 🔲
4. EvalPlayButton → child can replay vowel anytime
5. Images shown as answer choices (3-4 images)
6. Child taps image → hears word play
7. Child selects image whose middle sound matches
8. Correct → positive feedback → next round
9. Wrong → oops → try again same round
```

**Why second:** Child now APPLIES vowel knowledge — recognizes vowels inside real words.

---

# Interaction Logic (consistent throughout)

- **Pointed hand** → guides to LISTEN bar on round start
- **Idle hint system** → if child doesn't act, hand points
- **EvalPlayButton** → child can independently re-listen anytime
- **Open hands** → tap to hear vowel phoneme sound
- **Middle cube blinks** → visual cue: "find THIS sound"
- **Wrong answer** → oops → try again same round (no reset)

---

# Vowel Introduction Order

## a → i → o → u → e

| Vowel | Why this position |
|-------|-----------------|
| /a/ | Most open, easiest to feel |
| /i/ | Very distinct from /a/, clear and bright |
| /o/ | Round, back vowel — different from /a/ /i/ |
| /u/ | Similar to /o/ — contrast immediately after |
| /e/ | LAST — introduced after /i/ is rock solid |

---

# Set Structure

**Philosophy: Tight with Option 2, light but quality with Option 1**
- Option 2 — deep, thorough, every vowel + contrast sets
- Option 1 — fewer sets, high quality, kids already know vowels

| Set | Format | Content | Rounds |
|-----|--------|---------|--------|
| 2A | Option 2 | /a/ only | 20 |
| 2B | Option 2 | /i/ only | 20 |
| 2C | Option 2 | /a/ vs /i/ contrast | 20 |
| 2D | Option 2 | /o/ only | 20 |
| 2E | Option 2 | /u/ only | 20 |
| 2F | Option 2 | /o/ vs /u/ contrast | 20 |
| 2G | Option 2 | /e/ only | 20 |
| 2H | Option 2 | All 5 mixed | 25 |
| 2I | Option 1 | /a/ + /e/ | 20 |
| 2J | Option 1 | /o/ + /u/ | 20 |
| 2K | Option 1 | /i/ only | 20 |
| 2L | Option 1 | All 5 mixed | 25 |

**Total: 12 sets, 250 rounds**

---

# Number of Choices

| Sets | Format | Choices | Reason |
|------|--------|---------|--------|
| 2A, 2B, 2D, 2E, 2G | Option 2 single vowel | 2-3 open hands | Intro — don't overwhelm |
| 2C, 2F | Option 2 contrast | 3 open hands | Two target vowels + distractor |
| 2H | Option 2 all mixed | 5 open hands | Full vowel set |
| 2I, 2J | Option 1 paired | 3-4 images | Two vowel groups |
| 2K | Option 1 single | 3 images | /i/ focus |
| 2L | Option 1 all mixed | 4-5 images | Full mastery check |

---

# Word Bank

Reuses Level 1.5 CVC words — no new images needed ✅

| Vowel | Words |
|-------|-------|
| /a/ | cat, bag, cap, hat, ham, jam, man, map, mat, pan, rat, van, ram, fan, bat, can |
| /i/ | pig, bin, dig, fix, hit, kid, lid, lip, mix, pin, sit, six, wig, win, zip |
| /o/ | dog, box, cot, hop, jog, log, mop, pod, pot, rod, top |
| /u/ | bug, bun, bus, cub, cup, cut, gum, hug, jug, mud, mug, nut, pup, rug, run, sun, tub |
| /e/ | bed, hen, jet, leg, net, pen, ten, vet, web |

---

# Audio Needed

## Short vowel isolated sounds (Sully records in Audacity)
- a_sound.wav — short /a/ as in cat
- e_sound.wav — short /e/ as in bed
- i_sound.wav — short /i/ as in pig
- o_sound.wav — short /o/ as in dog
- u_sound.wav — short /u/ as in cup

**Note:** Same 5 files serve Level 1.5 + Level 2 + SoundBuddy Phase 2.
Record once — use everywhere. 🎯

---

# Prep Level 2

Same rounds as Level 2 but fully scaffolded:
- Vowel sound plays ×3 automatically
- Each image word plays ×2 automatically
- Pointed hand guides throughout
- 85% accuracy gate before entering Level 2

---

# Accuracy Gate

- ≥85% → advance to next set
- <85% → replay wrong rounds only
- Gain and Move philosophy (same as Level 1.5)

---

# Educational Outcome

By the end of Level 2, children can:
- Recognize all 5 short vowel sounds in isolation
- Isolate the middle sound in CVC words
- Distinguish confusing pairs (/a/ vs /e/, /o/ vs /u/)
- Handle all 5 vowels mixed together

**Level 2.5 rime families follow.**

**Sound first. Always.**
