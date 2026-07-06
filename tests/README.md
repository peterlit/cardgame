# Causeway tests

Lightweight, dependency-free test harness for the **shared, pure game engine** —
the highest-risk logic because web (`index.html`) and iOS
(`ios/Causeway/Causeway/`) must stay in lockstep.

## Run

From the repo root:

```sh
npm test
# equivalently:
node --test "tests/**/*.test.mjs"
```

Exits non-zero on any failure. No dependencies, no install step (Node >= 18).

## What's covered

- **Deal / RNG determinism** — `mulberry32` purity and "golden" 52-card orders
  for known seeds. These lock the web↔iOS parity contract: any change to the RNG,
  the Fisher–Yates shuffle, or the 7/7/7/7/6/6/6/6 layout breaks them.
- **`isSafeAutoplay` soundness** — the two-way-tableau counterexamples from earlier
  reviews (an Ace is *not* auto-safe while an opposite-color 2 could ascend onto it;
  a black 2 is unsafe until both red neighbours are home).
- **Restore-save validator** — accepts fresh and partial games; rejects duplicates,
  out-of-range suit (F3 regression) / rank, crossed foundations, completed boards,
  and wrong-shaped saves.

## How the engine copy stays honest (drift guard)

`index.html` is a single-file `file://` app with one inline `<script>`, so it can't
`import` a module at runtime. `tests/engine.mjs` is therefore a **hand-copy** of the
relevant pure functions. The final test in `engine.test.mjs` ("no drift") reads
`index.html` and asserts the canonical function bodies still appear verbatim there.
If you edit the logic in `index.html`, mirror it in `engine.mjs` or the tests fail.

## Not covered here

The iOS engine is exercised indirectly: it must produce the same golden deal orders
by construction (same algorithm), but there is no XCTest target yet — adding one to a
hand-authored `.pbxproj` without Xcode is risky. See BACKLOG.md ("XCTest target").
