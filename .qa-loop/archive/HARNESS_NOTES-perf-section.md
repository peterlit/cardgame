## Performance measurement (PERF lane only)

- The orchestrator runs `nfr_sampler.sh` in the background; mark your action windows in
  `marks.jsonl` and read numbers from `nfr_analyze.py`. Do not do sampler arithmetic in
  your own context.
- Instantaneous CPU: `ps -o time=,rss= -p <pid>` at both window ends ÷ wall clock; resolve the
  pid on the **host** via `pgrep -f "Causeway.app/Causeway"`.
- Baselines, uncontended iPhone 17 Pro (342e3c0): cold launch→painted board ≤0.9 s; sheets
  ~1.0-1.1 s; New game redeal 1.65 s; demo auto-advance 0.250-0.259 s/move (design 0.24);
  auto-finish ~0.18 s/card +0.38 s to overlay; idle CPU 0-1%. Only slow path: **first Export
  after a cold launch, ~1.8 s, no spinner**.
- **Timing recipe that needs no tap timestamp (loop 4).** Run the filmstrip in a background
  bash turn, fire the MCP action in the next turn, then md5 every frame: a static screen gives
  byte-identical PNGs, so change-points ARE the animation boundaries. `touch` = first frame that
  differs from the resting frame (press highlight / note-line change); `settled` = first frame of
  the final identical run. md5 is ~free next to `imgcrop_diff.py` on 70+ frames — diff only the
  2-3 frames you must attribute.
- **You cannot timestamp an MCP tap from bash** (assistant-turn overhead t_pre->tap measured
  4.0-4.3 s, and it varies). Do not quote tap latency off a bash `date`. Calibrate instead: run
  the same t_pre->visible-change measurement on an instantaneous control (the Auto-play pill is a
  pure @State flip) and quote the DIFFERENCE.
- Baselines re-measured uncontended on b2ce1a4: cold launch->painted board 0.89 s; Daily sheet
  open 0.93 s first-of-process / 0.70 s after; sheet dismiss->board 1.3 s; how-to-win pill->
  confirm dialog 0.51 s; dialog->demo bar ~1.1 s; auto-finish 0.210 s/card (4 cards 1.57 s,
  29 cards 6.10 s, continuous animation); first Export of a process touch->Files sheet 2.26 s
  (0.96 s frozen, but the "Opening Files..." note IS up). Idle CPU 0.0 %, net 0 all session.
- **nfr_analyze.py will flag a cold-launch window as a suspected leak** — a window that opens at
  `simctl launch` starts at 60-110 MB RSS and warms to ~190-235 MB. Always mark loop windows so
  they START on a warm process, and dismiss any candidate whose rss_start is below ~150 MB.
- A landscape relayout stress test needs a **13+ card column** (11+ with the daily HUD);
  below that the width term binds and nothing resizes.
- **Latency: use `tap X Y`, never `tapid`/`tapbtn`.** Driver round-trip is ~0.10 s (`ping`), a
  coordinate `tap` ~0.6 s, but `tapid`/`tapbtn` add ~1 s of element-query time BEFORE the touch —
  that faked a "1.7 s Daily-sheet open" (coordinate tap: 0.93 s first-of-process, 1.00 s later).
  Board pills by coordinate on 1a63ce2: Daily 288,174 · Undo 141,134 · Auto-play 334,134 · sheet Done 348,100.
- md5 change-point detection (changes.py) is a SCREEN, not proof: identical-looking frames sometimes
  hash differently (PNG encoder), and once a game is live the 1 Hz clock changes every frame — confirm
  every boundary with `imgcrop_diff.py` on a region that excludes the header (px 0 700 1206 2100).
- Contended-rig numbers, 5 sims booted (1a63ce2): cold launch->painted board 2.23 s (baseline 0.89);
  restore->Auto-finish alert 1.6 s; cascade 4.34 s/19 cards + 5.32 s/23 cards = 0.23 s/card, linear,
  no stall; idle CPU 0.0 % (0.4 % with the clock running); 12x New game +0.3 MB, 10x rotate +0.9 MB,
  24x Daily open/dismiss +8.5 MB decelerating (no leak). Landscape vs portrait, same 16-move
  relayout loop on a 15-card column: CPU mean 26.2 % vs 18.4 %.
- Deep-column fixture (landscape rescale stress): hand-build the save JSON — 8 columns, 52 cards,
  `"up":[0,0,0,0],"down":[14,14,14,14],"cells":[null,null,null]`, tallest column 15 with a bottom card
  that legally stacks on another column's bottom, then loop `tap <card>` + `tap <Undo>` (net 0 moves).
- **Resolving YOUR app pid:** `pgrep -f "Causeway.app/Causeway"` matches every booted device's app,
  and `pgrep -fl Causeway | grep <UDID>` ALSO matches `nfr_sampler.sh` (its command line carries your
  udid) — both make `ps -o time=` read ~0 CPU. Only this works: `pgrep -fl Causeway |
  grep "Devices/<UDID>/data" | head -1 | cut -d' ' -f1`. (Cost a measurement loop in rounds 2 AND 3.)
- The 1 Hz sampler ran at ~0.16 Hz under 6 booted sims (84 samples/534 s), so analyzer `cpu_mean_pct`
  on a <30 s window is 2-5 samples of noise. For CPU **ratios** use the ps CPU-time delta over an
  identical driver command sequence in both conditions; quote the analyzer only for RSS.
- Driver `tap X Y` on a CARD did not register (3 tries, tapid on the same frame moved it immediately);
  pills take coordinate taps fine. Use `tapid card.*` for card moves in timing loops — the ~1 s
  element query is identical in both arms of a ratio, so it does not bias the ratio.
- Round-2 contended perf numbers (9ab79f1): cascade 4.46 s/19 cards; Daily open 1.21 s first / 0.90 s
  later, dismiss 1.14-1.21 s; demo Prev settles 0.6-0.9 s at idx 87 AND idx 6 (no index scaling);
  export touch->Files sheet ~3.0-3.2 s; landscape/portrait 16-move CPU 15.06 %/10.35 % = 1.46x.
- **Cascade timing: full-frame md5 overstates it by ~3 s** — the 1 Hz clock changes the frame every
  second before your tap, so the first md5 change is a clock tick, not the touch. Confirm the start
  with `imgcrop_diff.py 0 700 1206 2100` (board crop, header excluded) and bound the tap with
  `mark` lines written in the SAME bash call as the `tap` (bash timestamps are valid there).
- On de5e5d0 a demo **starts PAUSED at 0/N** (`demo.start` reads "Start"); it does not auto-run from
  the pill. Resume with `tapid demo.start`; auto-run then advances 54 steps in a 12 s window (4.5/s).
- Round-3 contended numbers (de5e5d0/836434d, 6 sims): cascade 4.45 s/19 cards = 0.234 s/card (r2 4.46);
  demo auto-run CPU 🌟/🥇 = 1.32-1.35x (86 vs 65 ms CPU/step) at an IDENTICAL step rate — real but
  invisible; landscape rail vertical swipe 0.386 s CPU/gesture vs 0.290 for a horizontal no-scroll
  control on the same target; daily open/dismiss x12 = +6 MB TWICE, each fully reclaimed by a rotate
  (cache, not a leak); idle 64 s = 0.0 % CPU, RSS flat; analyzer candidates [].
