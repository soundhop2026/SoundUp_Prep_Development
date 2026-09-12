#!/usr/bin/env python3
"""Post-export correction for Godot's iOS Release export.

Godot's iOS export always writes an explicit CODE_SIGN_IDENTITY = "Apple
Distribution" into the Release configuration alongside CODE_SIGN_STYLE =
Automatic. Modern Xcode treats that combination as a conflict ("SoundHop is
automatically signed for development, but a conflicting code signing
identity Apple Distribution has been manually specified") and blocks
archiving, even with a valid Distribution certificate present. This script
blanks just that one value so Automatic signing can resolve it itself,
matching how a native Xcode-created Automatic-signing project looks.

Verified end-to-end: with this correction applied, `xcodebuild archive`
produces an (expectedly unsigned -- this is normal) raw .xcarchive, and a
subsequent `xcodebuild -exportArchive` with an App Store exportOptionsPlist
(see ios/exportOptions.plist) has Xcode apply real Apple Distribution
signing during export, producing a correctly signed, submittable IPA. The
raw .xcarchive's own signing state is not the thing to check -- only the
final exported IPA is.

Run this after every `godot --export-release "iOS" ...`, before archiving.
Does not touch Debug signing, CODE_SIGN_STYLE, Team ID, Bundle ID,
entitlements, or anything else -- fails loudly and changes nothing if the
expected pattern isn't found exactly once, rather than guessing.

Release workflow:
    1. godot --headless --export-release "iOS" ./build/ios/SoundHop
    2. python3 tools/ios_fix_release_signing.py build/ios/SoundHop.xcodeproj/project.pbxproj
    3. xcodebuild archive -project build/ios/SoundHop.xcodeproj -scheme SoundHop \
         -configuration Release -destination "generic/platform=iOS" \
         -archivePath <path>.xcarchive -allowProvisioningUpdates
    4. xcodebuild -exportArchive -archivePath <path>.xcarchive \
         -exportPath <output dir> -exportOptionsPlist ios/exportOptions.plist \
         -allowProvisioningUpdates
"""

import re
import shutil
import sys
from pathlib import Path

TARGET_BUNDLE_MARKER = "PRODUCT_BUNDLE_IDENTIFIER = com.acron.learningsounds;"
EXPECTED_PLAIN = 'CODE_SIGN_IDENTITY = "Apple Distribution";'
EXPECTED_SDK   = '"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";'

CONFIG_PATTERN = re.compile(
    r'(\t\t([0-9A-F]{24}) /\* (Debug|Release) \*/ = \{\n'
    r'\t\t\tisa = XCBuildConfiguration;\n'
    r'\t\t\tbuildSettings = \{\n'
    r'(.*?)'
    r'\n\t\t\t\};\n'
    r'\t\t\tname = (Debug|Release);\n'
    r'\t\t\};\n)',
    re.DOTALL,
)


def fail(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: ios_fix_release_signing.py <path to project.pbxproj>")

    path = Path(sys.argv[1])
    if not path.is_file():
        fail(f"file not found: {path}")

    original = path.read_text()
    matches = list(CONFIG_PATTERN.finditer(original))
    if not matches:
        fail("no XCBuildConfiguration objects found -- pbxproj format may have changed")

    target = None
    for m in matches:
        body, name = m.group(4), m.group(5)
        if TARGET_BUNDLE_MARKER in body and name == "Release":
            target = m
            break

    if target is None:
        fail(
            "could not uniquely identify the target-level Release build "
            f"configuration (expected {TARGET_BUNDLE_MARKER!r} and name = Release;). "
            "Refusing to make any changes."
        )

    full_block = target.group(1)
    body = target.group(4)

    if body.count(EXPECTED_PLAIN) != 1 or body.count(EXPECTED_SDK) != 1:
        fail(
            "expected exactly one occurrence each of:\n"
            f"  {EXPECTED_PLAIN}\n  {EXPECTED_SDK}\n"
            "in the target Release block, but did not find that. Refusing to "
            "change anything (Godot's default output may have changed)."
        )

    new_body = body.replace(EXPECTED_PLAIN, 'CODE_SIGN_IDENTITY = "";', 1)
    new_body = new_body.replace(EXPECTED_SDK, '"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "";', 1)

    new_block = full_block.replace(body, new_body, 1)
    new_content = original.replace(full_block, new_block, 1)

    if new_content == original:
        fail("substitution produced no change -- aborting")

    backup_path = path.with_name(path.name + ".before-signing-fix")
    shutil.copy2(path, backup_path)
    path.write_text(new_content)

    print(f"OK: patched {path}")
    print(f"Backup written to {backup_path}  (restore with: cp {backup_path} {path})")
    print()
    print("--- Changed (target Release block only) ---")
    print(f"BEFORE: {EXPECTED_PLAIN}")
    print('AFTER:  CODE_SIGN_IDENTITY = "";')
    print(f"BEFORE: {EXPECTED_SDK}")
    print('AFTER:  "CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "";')


if __name__ == "__main__":
    main()
