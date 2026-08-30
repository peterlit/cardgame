#!/usr/bin/env python3
"""Derive a Causeway daily challenge card from data/daily-pool.json (schema v4, epoch 2026-08-01).

REWRITTEN 2026-08-30 (round-0 WF-13 exploration). The previous version derived the day's
objectives with a local copy of an rng formula that NO LONGER EXISTS: pool v4 stores each day's
silver/gold spec explicitly, and it dropped the `seeds` array the old script read (it crashed with
KeyError: 'seeds' against every current build). This version shells out to `tests/daily.mjs` — the
same module the web twin and the pool generator use — so the labels printed here are the shipped
label strings, never a re-derivation that can drift.

Usage:
    derive_daily.py                # today
    derive_daily.py 12             # dayIndex 12
    derive_daily.py 2026-08-03     # a calendar date
Also prints the "Show me how to win" pill set the day card must render, and the calendar cell
coordinates (device points, iPhone 17 Pro portrait, Daily sheet scrolled to the bottom).
"""
import json, sys, os, subprocess, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
POOL = os.environ.get("POOL", os.path.join(ROOT, "data", "daily-pool.json"))
SOLS = os.environ.get("SOLS", os.path.join(ROOT, "data", "daily-solutions.json"))
EPOCH = datetime.date(2026, 8, 1)

arg = sys.argv[1] if len(sys.argv) > 1 else None
if arg is None:
    di = (datetime.date.today() - EPOCH).days
elif "-" in arg:
    di = (datetime.date.fromisoformat(arg) - EPOCH).days
else:
    di = int(arg)

js = ("Promise.all([import('./tests/daily.mjs'),import('fs')]).then(([m,fs])=>"
      "console.log(JSON.stringify(m.dailyChallenge(%d,JSON.parse(fs.readFileSync(%r,'utf8'))))))" % (di, POOL))
out = subprocess.run(["node", "-e", js], cwd=ROOT, capture_output=True, text=True)
if out.returncode != 0:
    sys.exit("node failed: " + out.stderr.strip())
c = json.loads(out.stdout.strip() or "null")
if c is None:
    sys.exit("dayIndex %d is outside the seeded pool (0…60 = 2026-08-01…2026-09-30)" % di)

date = EPOCH + datetime.timedelta(days=di)
sol = json.load(open(SOLS))["solutions"].get(str(c["seed"]), {})
pills = ["🥉 Clear"] + (["🥈 Silver"] if sol.get("silver") else []) + \
        (["🥇 Gold"] if sol.get("gold") else []) + (["🌟 Flawless"] if sol.get("flawless") else [])

# Calendar cell for this date, Daily sheet scrolled fully to the bottom (one 700→300 swipe).
d = date.day
col = (datetime.date(date.year, date.month, d).weekday() + 1) % 7   # 0 = Sunday
row = (d + (datetime.date(date.year, date.month, 1).weekday() + 1) % 7 - 1) // 7
print("dayIndex   %d   (%s)" % (di, date.isoformat()))
print("deal       #%s   par %d" % (f"{c['seed']:,}", c["par"]))
print("card head  %s" % ("Today" if di == (datetime.date.today() - EPOCH).days else date.strftime("%b %-d")))
print("Bronze     Clear the deal")
print("Silver     %s   [%s]" % (c["silver"]["label"], c["silver"]["id"]))
print("Gold       %s   [%s]" % (c["gold"]["label"], c["gold"]["id"]))
print("pills      %s" % "  ".join(pills))
if not sol.get("silver"):
    print("           (no 🥈 pill is CORRECT here: universal Silver family, silver line == bronze)")
print("cal cell   x=%d  y=%d   (device pt, sheet scrolled to bottom)" % (round(40 + 53.5 * col), 471 + 44 * row))
print("line len   " + ", ".join("%s=%d" % (k, len(v.split())) for k, v in sol.items() if isinstance(v, str)))
