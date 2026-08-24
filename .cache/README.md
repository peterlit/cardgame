# Certification cache

`month-certs-*.jsonl` — one JSON record per candidate deal seed, as produced by
`tools/solver/build-month.mjs` phase 1: whether the seed is winnable, its reference par, and every
`(objective family, parameter)` variant it certifies.

**This is committed on purpose.** It is ~240 KB and represents several CPU-hours of search. With it
present, re-running the month generator is instant:

```bash
node tools/solver/build-month.mjs --select-only          # re-choose a month from the cache
node tools/solver/build-month.mjs --candidates 400       # certify only the seeds not yet cached
```

The candidate list is a deterministic function of `--sample-seed` and `--candidates`, and a longer
list extends the shorter one, so raising `--candidates` re-uses every record already here.

**Invalidate it** whenever `VARIANTS` in `tools/solver/solve.mjs` changes: a cached record only
lists the variants that existed when it was written, so new parameter values will simply never be
offered until the affected seeds are re-certified (delete the files and re-run).
