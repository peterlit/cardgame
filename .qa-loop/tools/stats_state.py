#!/usr/bin/env python3
"""Read or write the Causeway stats stores (`causeway.daily` v3 / `causeway.wins`) in a booted
simulator's app preferences — the fixture + assertion channel for WF-11 (Export/Import).

    python3 stats_state.py <udid> dump                 # print both stores as JSON
    python3 stats_state.py <udid> load < state.json     # {"daily": {...}, "wins": {...}} -> stores
    python3 stats_state.py <udid> clear                 # remove both keys (and .v2/.unreadable stashes)

`daily` is the raw dayIndex->TierResult map (the tool wraps it in {"version":3,"days":...});
`wins` is seed->{moves,secs,date} where date is a Codable Double (secs since 2001-01-01).
Terminates the app and stops cfprefsd first so the daemon cache cannot resurrect old values.
"""
import json, os, plistlib, subprocess, sys, glob

BUNDLE = "com.whimsicaldistractions.Causeway"
udid, cmd = sys.argv[1], sys.argv[2]
root = os.path.expanduser(f"~/Library/Developer/CoreSimulator/Devices/{udid}/data/Containers/Data/Application")
subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE], capture_output=True)
subprocess.run(["xcrun", "simctl", "spawn", udid, "launchctl", "stop", "com.apple.cfprefsd.xpc.daemon"],
               capture_output=True)
paths = glob.glob(os.path.join(root, "*", "Library", "Preferences", BUNDLE + ".plist"))
if not paths:
    sys.exit("no preferences plist for " + BUNDLE + " (launch the app once first)")
path = max(paths, key=os.path.getmtime)
with open(path, "rb") as f:
    pl = plistlib.load(f)

if cmd == "dump":
    out = {}
    for k in ("causeway.daily", "causeway.wins"):
        v = pl.get(k)
        out[k] = json.loads(bytes(v).decode()) if v else None
    for k in list(pl.keys()):
        if k.startswith("causeway.daily.") or k.startswith("causeway.wins."):
            out[k] = json.loads(bytes(pl[k]).decode())
    print(json.dumps(out, indent=1, sort_keys=True))
    sys.exit(0)

if cmd == "clear":
    for k in [k for k in pl if k.startswith("causeway.daily") or k.startswith("causeway.wins")]:
        pl.pop(k)
elif cmd == "load":
    st = json.load(sys.stdin)
    if "daily" in st:
        pl["causeway.daily"] = json.dumps({"version": 3, "days": st["daily"]}, separators=(",", ":")).encode()
    if "wins" in st:
        pl["causeway.wins"] = json.dumps(st["wins"], separators=(",", ":")).encode()
else:
    sys.exit("usage: stats_state.py <udid> dump|load|clear")
with open(path, "wb") as f:
    plistlib.dump(pl, f)
print(cmd + " ok: " + path)
