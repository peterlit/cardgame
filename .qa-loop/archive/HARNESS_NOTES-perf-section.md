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
