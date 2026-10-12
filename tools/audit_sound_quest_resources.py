#!/usr/bin/env python3
"""Case-sensitive resource audit for every Sound Quest (Prep, Level 1, Level 1.5).

Why this exists: Windows and macOS file systems ignore case, Android's (and the exported
.pck's) does not. A path that differs from the real file only by case works in the editor and
on desktop but fails on a device (the Prep Sound Quest Group F images "C-soft" / "X-gz" did
exactly that). This audit resolves every path component by its EXACT spelling.

Checks
  1. Every fixed res:// path written in the Sound Quest scripts / scenes.
  2. Prep + Level 1 (sound_quest_word_manifest.json): every phoneme in every Set JSON has a
     manifest entry; its image folder, every word image, the phoneme audio, and every word
     audio (resolved exactly the way SoundQuestState._resolve_word_audio does: "<Letter>.wav"
     folder first, then lower case) exist with exact case. Every audio/image file has its
     .import sidecar (an un-imported file is missing from an export).
  3. Level 1.5 (data/words.json, data/phonemes.json): every word's image / audio, both the
     explicit fields and the paths the Quest scripts build from the word key.

Run from anywhere:   python tools/audit_sound_quest_resources.py
Exit code 0 = clean, 1 = problems found (each is printed).
Complements tools/verify_sound_quest_resources.gd, which checks the same things against an
exported .pck (the real Android lookup rules).
"""
import glob
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

problems = []


def nfc(s):
    return unicodedata.normalize("NFC", s)


_listing_cache = {}


def listing(directory):
    if directory not in _listing_cache:
        try:
            _listing_cache[directory] = {nfc(n) for n in os.listdir(directory)}
        except OSError:
            _listing_cache[directory] = None
    return _listing_cache[directory]


def exact_exists(res_path):
    """True only if every component of res://... exists with exactly this spelling."""
    rel = res_path[len("res://"):]
    cur = ROOT
    parts = rel.split("/")
    for i, part in enumerate(parts):
        names = listing(cur)
        if names is None or nfc(part) not in names:
            return False
        cur = os.path.join(cur, part)
    return True


def case_hint(res_path):
    """When exact_exists fails: the real spelling, if only the case differs."""
    rel = res_path[len("res://"):]
    cur = ROOT
    real = []
    for part in rel.split("/"):
        names = listing(cur)
        if names is None:
            return None
        match = [n for n in names if n.lower() == nfc(part).lower()]
        if not match:
            return None
        real.append(match[0])
        cur = os.path.join(cur, match[0])
    return "res://" + "/".join(real)


def need(res_path, why, imported=False):
    if not exact_exists(res_path):
        hint = case_hint(res_path)
        extra = "  (real spelling: %s)" % hint if hint else "  (no such file)"
        problems.append("MISSING  %s  [%s]%s" % (res_path, why, extra))
        return False
    if imported and not exact_exists(res_path + ".import"):
        problems.append("NOT IMPORTED  %s  [%s]  (no .import sidecar, absent from an export)" % (res_path, why))
        return False
    return True


def read_json(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8-sig") as f:
        return json.load(f)


# ── 1. fixed paths in the Sound Quest scripts / scenes ───────────────────────
def audit_fixed_paths():
    files = set()
    for pat in ("sound_quest*.gd", "level1_sound_quest*.gd", "level15_sound_quest*.gd",
                "sound_quest*.tscn", "level1_sound_quest*.tscn", "level15_sound_quest*.tscn"):
        files.update(glob.glob(os.path.join(ROOT, pat)))
    seen = {}
    for path in sorted(files):
        with open(path, encoding="utf-8") as f:
            text = f.read()
        for m in re.finditer(r'"(res://[^"]*)"', text):
            lit = m.group(1)
            if "%s" in lit or lit.endswith("/"):
                continue            # built at run time: covered by checks 2 and 3
            seen.setdefault(lit, os.path.basename(path))
    for lit, src in sorted(seen.items()):
        need(lit, "fixed path in " + src, imported=lit.lower().endswith((".png", ".wav", ".mp3", ".ttf")))
    # Directory constants the Level 1.5 scripts append a word key to.
    for d in ("res://SoundUp_level1.5_word_images", "res://BGM&effect/SoundUp_level1.5_word_sounds",
              "res://SoundUp_level1_word images", "res://BGM&effect/SoundUp_level1_word sounds",
              "res://BGM&effect/SoundUp_level1_phonemes"):
        need(d, "asset directory")
    return len(seen)


# ── 2. Prep + Level 1 ────────────────────────────────────────────────────────
def set_json_paths():
    paths = []
    for gd in ("prep_level_progress.gd", "level_progress.gd"):
        with open(os.path.join(ROOT, gd), encoding="utf-8") as f:
            text = f.read()
        paths += re.findall(r'"(res://[^"]*\.json)"', text)
    return paths


def audit_prep_level1():
    manifest = read_json("sound_quest_word_manifest.json")
    letters_in_sets = set()
    for p in set_json_paths():
        if not need(p, "Set JSON"):
            continue
        data = read_json(p[len("res://"):])
        for rd in data.get("rounds", []):
            pa = rd.get("phoneme_audio", "")
            if pa:
                letters_in_sets.add(os.path.splitext(os.path.basename(pa))[0])
    for letter in sorted(letters_in_sets):
        if letter not in manifest:
            problems.append("NO MANIFEST ENTRY  phoneme '%s' is used by a Set JSON but has no entry in "
                            "sound_quest_word_manifest.json (its Sound Quest pool would be empty)" % letter)

    word_audio_root = "res://BGM&effect/SoundUp_level1_word sounds"
    audio_dirs = listing(os.path.join(ROOT, "BGM&effect", "SoundUp_level1_word sounds")) or set()
    words = images = audio = 0
    for letter, entry in sorted(manifest.items()):
        need("res://BGM&effect/SoundUp_level1_phonemes/%s.wav" % letter, "phoneme audio", imported=True)
        folder = entry.get("folder", letter)
        need("res://SoundUp_level1_word images/%s" % folder, "image folder for '%s'" % letter)
        # Mirrors SoundQuestState._resolve_word_audio: "<Letter>.wav" first, then lower case.
        adir = next((c for c in (letter, letter.lower()) if c + ".wav" in audio_dirs), None)
        if adir is None:
            problems.append("MISSING  %s/%s.wav (and lower case)  [word-sound folder for '%s']" %
                            (word_audio_root, letter, letter))
        for w in entry.get("words", []):
            words += 1
            if need("res://SoundUp_level1_word images/%s/%s.png" % (folder, w), "word image", imported=True):
                images += 1
            if adir is not None and need("%s/%s.wav/%s.wav" % (word_audio_root, adir, w), "word audio", imported=True):
                audio += 1
    return len(manifest), words, images, audio


# ── 3. Level 1.5 ─────────────────────────────────────────────────────────────
def audit_level15():
    words = read_json("data/words.json")["words"]
    n = 0
    for key, w in sorted(words.items()):
        n += 1
        need("res://SoundUp_level1.5_word_images/%s.png" % key, "L1.5 image built from word key", imported=True)
        need("res://BGM&effect/SoundUp_level1.5_word_sounds/%s.wav" % key, "L1.5 audio built from word key", imported=True)
        if w.get("image"):
            need(w["image"], "L1.5 words.json image field of '%s'" % key)
        if w.get("audio"):
            need(w["audio"], "L1.5 words.json audio field of '%s'" % key)
    phonemes = read_json("data/phonemes.json")["phonemes"]
    for key, p in sorted(phonemes.items()):
        for field in ("audio", "image"):
            v = p.get(field) if isinstance(p, dict) else None
            if isinstance(v, str) and v.startswith("res://"):
                need(v, "phonemes.json %s of '%s'" % (field, key))
    return n


def main():
    fixed = audit_fixed_paths()
    letters, words, images, audio = audit_prep_level1()
    l15 = audit_level15()
    print("fixed paths checked: %d" % fixed)
    print("Prep/Level 1 manifest: %d phonemes, %d words, %d images, %d word audio files resolved" %
          (letters, words, images, audio))
    print("Level 1.5 words checked: %d" % l15)
    if problems:
        print("\n%d PROBLEM(S):" % len(problems))
        for p in problems:
            print("  " + p)
        return 1
    print("\nOK: every Sound Quest resource resolves with exact case.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
