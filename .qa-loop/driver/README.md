# QADriver — drive the shipped Causeway build from Bash

A scriptable XCUITest (`Sources/QADriver.swift`) that runs as a long-lived server on ONE
simulator and executes commands a client writes to `/private/tmp/causeway-qa/<udid>/cmd/`.
It exists because the MCP simulator-control tool needs a per-device access grant that only a
human at the keyboard can give; the driver needs none, and it can do things the MCP tool cannot
(launch with an environment such as `CAUSEWAY_TODAY_OVERRIDE`, rotate the device, query
accessibility identifiers, dump every visible label in one call).

```bash
bash .qa-loop/driver/start.sh <udid>          # build once (cached in dd/), serve in the background
python3 .qa-loop/driver/qa.py <udid> <cmd…>   # one command; prints "OK …" or "ERR …"
python3 .qa-loop/driver/qa.py <udid> --alive  # is it serving?
bash .qa-loop/driver/stop.sh <udid>
```

Coordinates are DEVICE POINTS in the app's frame (iPhone 17 Pro: 402×874 portrait, 874×402
after `rotate landscapeLeft`). Commands:

| command | what it does |
|---|---|
| `launch [K=V …]` | (re)launch the app with that environment, e.g. `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15` |
| `activate` / `terminate` / `home` / `state` / `frame` | lifecycle; `terminate`+`launch` = the real relaunch path |
| `tap X Y`, `doubletap X Y`, `press X Y SECS` | coordinate touches |
| `drag X1 Y1 X2 Y2 [HOLD]`, `swipe …` | press-hold then drag (hold 0.15 s / 0.05 s default) — drives the card DragGesture |
| `dragslow X1 Y1 X2 Y2 VELOCITY HOLD` | drag at a set points/sec |
| `type TEXT`, `key return\|delete\|space` | keyboard into the focused field |
| `shot /abs/path.png` | full-resolution screenshot (1206×2622 @3x) written to the HOST path |
| `find ID`, `findall ID`, `wait ID [SECS]` | element by accessibility identifier: exists / hittable / frame / label / value |
| `tapid ID`, `tapbtn LABEL`, `taptext LABEL`, `btn LABEL`, `text LABEL` | tap or inspect by identifier / button label / static-text label |
| `labels [texts\|buttons\|textfields\|images\|any] [SUBSTRING]` | every matching element's `[x,y,w,h] #id label`, ONE snapshot (≈0.3 s) — the cheapest assertion there is |
| `alert` | the frontmost alert's title, texts and buttons with frames |
| `tree [DEPTH]` | indented accessibility hierarchy |
| `rotate portrait\|landscapeLeft\|landscapeRight` | device orientation (WF-12 is testable with this) |
| `sleep SECS`, `ping`, `quit` | |

XCUITest "issues" (not hittable, snapshot failed) never kill the server: they come back
appended to the reply as `issues=…`. One server per simulator; parallel workers never share a
directory. The server exits by itself after 5 h — `start.sh` is idempotent, call it again.
