#!/usr/bin/env python3
"""Inject a Causeway SavedGame (stdin JSON, from make_save.mjs) into a booted simulator's app
preferences, so the next launch restores that board. Fixture harness for win-time surfaces.

    node .qa-loop/tools/make_save.mjs --day 29 --tier flawless | \
        python3 .qa-loop/tools/inject_save.py <udid>

Terminates the app first (a running app would overwrite the plist from memory) and kills
cfprefsd inside the simulator so the daemon's cache cannot resurrect the old value.
Add --clear to wipe the save instead of writing one.
"""
import json, os, plistlib, subprocess, sys, glob

BUNDLE = "com.whimsicaldistractions.Causeway"
udid = sys.argv[1]
clear = "--clear" in sys.argv
root = os.path.expanduser(f"~/Library/Developer/CoreSimulator/Devices/{udid}/data/Containers/Data/Application")
subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE], capture_output=True)
subprocess.run(["xcrun", "simctl", "spawn", udid, "launchctl", "stop", "com.apple.cfprefsd.xpc.daemon"],
               capture_output=True)
paths = glob.glob(os.path.join(root, "*", "Library", "Preferences", BUNDLE + ".plist"))
if not paths:
    sys.exit("no preferences plist for " + BUNDLE + " on " + udid + " (launch the app once first)")
path = max(paths, key=os.path.getmtime)
with open(path, "rb") as f:
    pl = plistlib.load(f)
if clear:
    pl.pop("causeway.game", None)
else:
    pl["causeway.game"] = json.dumps(json.load(sys.stdin), separators=(",", ":")).encode()
with open(path, "wb") as f:
    plistlib.dump(pl, f)
print(("cleared" if clear else "wrote") + " causeway.game in " + path)
