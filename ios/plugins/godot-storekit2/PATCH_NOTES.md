# godot-storekit2 — SoundHop patch notes

## Source

Forked from https://github.com/godot-sdk-integrations/godot-storekit2
at commit `beabb04` (2026-08-27), Godot engine submodule pinned to
`4.5.1-stable` (`f62fdbde`) — the exact engine build SoundHop ships on.

Upstream is a single-maintainer, early-stage plugin (~10 commits over
7 months as of this fork). It has an open, unresolved issue (#1) reporting
the same class of linker failure this patch fixes, filed Dec 2025.

## What was broken

A clean `xcodebuild archive` of SoundHop failed to link, with:

```
Undefined symbols for architecture arm64:
  "(extension in Swift):Swift.AsyncIteratorProtocol.next(isolation: isolated Swift.Actor?) ..."
  referenced from: ... GodotStoreKit2Proxy.getProductInfo(...) in GodotStoreKit2Swift.o
```

This was **not** caused by anything in SoundHop's own code or by a toolchain
version change (verified: Xcode 26.6/17F113, macOS 26.6/25G72, and the
plugin binary were all unchanged between the last successful build and the
first failing one — confirmed via two independent clean-cache rebuilds that
both reproduced the failure deterministically). It was a latent defect in
the plugin's compiled binary, previously masked by incremental build reuse.

## Root cause

`GodotStoreKit2Swift.swift`, inside `getProductInfo()`:

```swift
if #available(iOS 18.4, *) {
    for await verificationResult in product.currentEntitlements {
        ...
    }
} else {
    let entitlement = await product.currentEntitlement
    ...
}
```

`#available` only defers **execution** to runtime — Swift must still fully
compile and link the `iOS 18.4` branch for every build, regardless of the
project's deployment target. Doing so requires the
`AsyncIteratorProtocol.next(isolation:)` witness, a Swift 6.0 stdlib
addition with no back-deployment shim below iOS ~18.5 (confirmed: Apple's
own `libswiftCompatibilityConcurrency.a` for iOS in this toolchain defines
essentially nothing — 1 exported symbol total). So the branch could never
link for any deployment target under ~18.5, even though on SoundHop's actual
minimum (iOS 15.0) it could also never *execute*.

The other `for await` loop in this file (`newTransactionListenerTask`,
iterating `Transaction.updates`/`.unfinished`) does **not** have this
problem — it iterates a concrete Apple type whose `next()` resolves
directly, not through a generic default-witness thunk. That loop was left
untouched.

## The fix

Removed the `#available(iOS 18.4, *)` branch and its `for await` loop
entirely, keeping only the `else` branch's logic (the singular
`product.currentEntitlement` check) unconditionally. See
`patched-source/GodotStoreKit2Swift.swift` for the exact diff (search for
"PATCHED (SoundHop, 2026-08-27)").

This is a pure dead-code removal for us: SoundHop's minimum target is 15.0,
so the 18.4-only branch could never have executed on any device this app
actually supports, even in a successful build. Every device SoundHop runs
on already used the singular-entitlement path unconditionally. No
subscription logic, entitlement behavior, or product/purchase flow changed.

## How to rebuild

```bash
git clone https://github.com/godot-sdk-integrations/godot-storekit2.git
cd godot-storekit2
git submodule update --init --depth 1
cd godot && git fetch --depth 1 origin 4.5.1-stable && git checkout FETCH_HEAD && cd ..
# apply the same patch as patched-source/GodotStoreKit2Swift.swift
pip3 install scons   # if not already installed
cd godot && scons platform=ios target=template_debug -j4   # can be interrupted once
                                                            # *.gen.h files exist —
                                                            # full engine compile
                                                            # is not needed, only
                                                            # early-stage codegen
cd ..
bash scripts/make_release.sh
```

Then copy `bin/godot-storekit2/godot-storekit2.{debug,release}.xcframework/ios-arm64/libgodot-storekit2.a`
over the corresponding files in this project's
`ios/plugins/godot-storekit2/godot-storekit2.*.xcframework/ios-arm64/`.

**Do not** leave a copy of `godot-storekit2.gdip` anywhere else under
`ios/plugins/` (e.g. in a backup folder) — Godot's iOS export scans for
`*.gdip` files there, and a stray copy registers as a duplicate plugin,
causing `xcodebuild archive` to fail with "Unexpected duplicate tasks".

## Original (pre-patch) binaries

Preserved at commit `b5548d7` in this repo's git history
(`ios/plugins/godot-storekit2/` as it existed before this patch), and as a
local backup made before this change (not committed — kept outside the
plugin-scanning path, see note above).
