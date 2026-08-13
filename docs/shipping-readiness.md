# Causeway — App Store Shipping Readiness

A deep review of what's left before submitting Causeway (iOS) to the App Store, with a plan and
status. Rollback point: git tag **`pre-ship-prep`** (HEAD `08ad4a6`).

The app is offline, SwiftUI, iPhone-only, iOS 17.0+. No network, no tracking, no third-party SDKs,
"Data Not Collected." Two thorough audits (App-Store readiness + test coverage) informed this plan.

## Status legend
✅ done · 🔧 in progress · ⛔ needs the owner (external) · 🕒 deferred (with reason)

---

## 1. Release blockers (must fix to ship)

| # | Item | Status | Notes |
|---|------|--------|-------|
| B1 | **Debug memory HUD ships in Release.** `DebugFlags.memoryHUD = true` renders a "MEM/PEAK/FREE" overlay in a Release build (not `#if DEBUG`-gated). | ✅ | Flipped to `false`. This is the one code blocker the code itself flags as a release-checklist toggle. |

## 2. Owner action items (external — I cannot complete these)

| # | Item | Status | Notes |
|---|------|--------|-------|
| O1 | **Support URL** (required by App Review) | ⛔ | `store/app-store-listing.md` has a placeholder. A missing/broken support URL is an auto-rejection. |
| O2 | **Privacy Policy URL** (required) + host `store/privacy-policy.md` at a real URL | ⛔ | Placeholder in the listing; policy has a placeholder contact email (`privacy-policy.md`). |
| O3 | **Contact email** in the privacy policy | ⛔ | `<your support email>` placeholder. |
| O4 | **Test on real iOS 17 / 18 devices** before submission | ⛔ | See §5 — only the iOS 26.5 simulator runtime is installed here; I verified source-level compatibility, but a real 17/18 device pass is the owner's to do. |
| O5 | **App Store Connect metadata / screenshots / age rating** | ⛔ | Content in `store/`; the submission itself is manual. |
| O6 | (Optional, repo hygiene) Remove committed `DEVELOPMENT_TEAM` before making the repo public | ⛔ | `project.pbxproj`. |

## 3. Features requested for this pass

| # | Item | Status | Notes |
|---|------|--------|-------|
| F1 | **Landscape support (iOS)** | ✅ code / 🕒 visual | Enabled landscape orientations (Info.plist, both configs). In landscape the board is wrapped in a vertical `ScrollView` and centred, with card width capped at 64pt so the wide viewport doesn't blow cards up; **portrait is byte-identical** (branch on `geo.size.width > geo.size.height`). Build-verified. **On-device landscape screenshot deferred** until the simulator is healthy (§6) — one visual pass recommended before shipping. |
| F2 | **Copyright / About screen** | ✅ | Added an "About" section — app name, version (`CFBundleShortVersionString (CFBundleVersion)`), © line, one-line credit — to the iOS How-to-play (`Views/Extras.swift`) and the web rules panel (`index.html`). |
| F3 | **Test on different iOS versions** | 🕒 | Documented compatibility (deployment target 17.0; no `#available` guards; no >17 APIs; `onChange(of:){_,_ in}` is 17+, matching target; appearance locked to `.light`). Only iOS 26.5 runtime is installed locally → a real 17/18 pass is owner action O4. |
| F4 | **Expand test coverage to guard regressions** | ✅ | Done (T1/T2/T4 + T3's once-only gate). 67 tests green. See §4. |

## 4. Test-coverage expansion (guard regressions, not speed)

Current: 55 Node tests (engine, solver, daily) + web drift guards. **Biggest structural gap: the iOS
Swift port has ZERO drift guards** — web and Swift can silently diverge on deal order, calendar math,
or checkers with green CI. Plan, highest value first:

| # | Addition | Status | Rationale |
|---|----------|--------|-----------|
| T1 | **Swift drift guards** — `tests/ios-parity.test.mjs` pins mulberry32, `daysFromCivil`/`floorDiv`, `dailyChallenge` RNG-seed + pools, the checkers, `mergeTiers`, `streaks` in the Swift port | ✅ | Highest blast radius: now catches web↔iOS divergence without an Xcode test target. |
| T2 | **Baked-solution validator** — `tests/solutions.test.mjs` replays every tier line and asserts win + objective (366 seeds) | ✅ | Build-time check is now a CI regression guard; a stale/regenerated solutions file can't ship a broken "Show me how to win" line. |
| T3 | **Auto-finish win-record / deferred-overlay timing** (BACKLOG AF-test) | 🔧 partial | The once-only `winRecorded` gate is now pinned (iOS parity guard); the full deferred-overlay *timing* test (record-exactly-once / not-before-cascade) is app/UI timing and remains an app-level task. |
| T4 | **`applyDemoToken` token-format drift guard** across web/iOS/solver | ✅ | Pinned in `tests/ios-parity.test.mjs` (iOS + web copies) so a one-sided edit trips CI. |
| T5 | **XCTest target** (native Swift unit tests) | 🕒 | Recommended eventually, but adding a target to the hand-authored `project.pbxproj` without Xcode is error-prone (BACKLOG F6). The Swift drift guards (T1) are the mandatory fallback and cover the same logic cheaply. Deferred with that rationale. |

## 5. iOS version compatibility (analysis)

Deployment target **iOS 17.0**. Audit found **no** version-fragile code: no `#available`/`@available`
guards, no iOS 18/26-only APIs; `onChange(of:){ _, _ in }` (two-param) is iOS 17+ and matches the
target; `MemoryFootprint` uses long-available mach APIs; `preferredColorScheme(.light)` removes
dark-mode variance. Conclusion: source is 17.0-safe. Local limitation: only the **iOS 26.5** simulator
runtime is installed, so a real iOS 17/18 device/simulator pass remains owner action **O4**.

## 6. Environment note — simulator

During this work the host **CoreSimulator wedged**: launching the Causeway app was denied by
SpringBoard (`FBSOpenApplicationServiceErrorDomain`/`SBMainWorkspace`) on both the existing device and
a freshly-created clean simulator, and screenshots returned "No Image available to encode" — while
Safari launched fine (so the infra partly works). A **parallel Claude session is running its own iOS
simulator on this host**, and the fix (restarting the shared CoreSimulator service) would disrupt it,
so per instruction it was avoided. The app is unaffected: it launched fine earlier this session, the
changes here are post-`main` Swift/layout code, and every change is verified by a successful
`xcodebuild` compile plus (for shared logic) the web app and the Node suite. **Deferred to a healthy
simulator:** the on-device landscape screenshot and a final visual smoke test.

## 7. Verified-OK (no action needed)

App icon 1024² no-alpha; `PrivacyInfo.xcprivacy` present (UserDefaults reason `CA92.1`, no tracking);
`ITSAppUsesNonExemptEncryption = NO`; LaunchScreen wired; metadata consistent (v1.0/build 1, iPhone-only,
bundle `com.whimsicaldistractions.Causeway`); persistence resilient (guarded decodes, `.unreadable`
stash, `uniquingKeysWith:`); no network / no stray `print` / no hidden test data.
