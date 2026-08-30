#!/usr/bin/env python3
"""Token accounting for the review/QA loops, from raw session transcripts.

Kept in the repo on purpose: the previous two measurements (docs/loop-token-usage.md,
docs/qa-loop-feedback.md) were made with throwaway scratchpad scripts that did not survive
the session, so each new measurement started from scratch.

    python3 tools/loop-usage.py --since $(date -v-3H +%s)   # last 3 hours of transcripts

`--since` is PER RECORD, not per file: a transcript's file mtime is only a cheap pre-filter (a file
last written before the cutoff cannot hold a record after it), and every usage record is then kept
or dropped on its own `timestamp`. A long session touched five minutes ago therefore contributes
only the requests made inside the window. A record with no parsable timestamp is COUNTED (dropping
it would silently under-report) and tallied in the row's `undated` key, with a note on stderr.

Each row is one transcript: `sidechain: true` marks a subagent, and `agent` names its type
where the transcript records it. Sum the sidechain rows for a loop's subagent cost.

Effective tokens weight the billed classes by relative cost:
    input x1 + cache_read x0.1 + cache_write x2 + output x5
Usage records are deduplicated by requestId; images count a flat 1,600 tokens each.
(Method as documented in docs/loop-token-usage.md.)

usage:  usage.py [--since EPOCH_SECONDS] [--dir PROJECT_DIR]
"""
import json, os, sys, glob, time
from collections import defaultdict
from datetime import datetime

PROJ = os.path.expanduser('~/.claude/projects/-Users-plit-Documents-src-cardgame')
since = 0.0
args = sys.argv[1:]
for i, a in enumerate(args):
    if a == '--since': since = float(args[i+1])
    if a == '--dir': PROJ = args[i+1]

IMG = 1600

def rec_time(r):
    """Epoch seconds for one transcript record, or None if it has no usable timestamp."""
    ts = r.get('timestamp')
    if isinstance(ts, bool):
        return None
    if isinstance(ts, (int, float)):
        return float(ts) / 1000.0 if ts > 1e11 else float(ts)   # tolerate epoch millis
    if isinstance(ts, str) and ts:
        try:
            return datetime.fromisoformat(ts.replace('Z', '+00:00')).timestamp()
        except ValueError:
            return None
    return None

def eff(u):
    return (u.get('input_tokens',0)
            + 0.1*u.get('cache_read_input_tokens',0)
            + 2*u.get('cache_creation_input_tokens',0)
            + 5*u.get('output_tokens',0))

def agent_type_of(path):
    """A subagent transcript records its own type; fall back to the sidechain's first prompt."""
    try:
        with open(path) as f:
            for line in f:
                try: r = json.loads(line)
                except Exception: continue
                for k in ('subagent_type','agentType','subagentType'):
                    if r.get(k): return r[k]
                m = r.get('message') or {}
                for c in (m.get('content') or []) if isinstance(m.get('content'), list) else []:
                    if isinstance(c, dict) and c.get('type') == 'tool_use' and c.get('name') == 'Agent':
                        st = (c.get('input') or {}).get('subagent_type')
                        if st: return st
    except Exception:
        pass
    return None

rows = []
for path in glob.glob(os.path.join(PROJ, '**', '*.jsonl'), recursive=True):
    st = os.stat(path)
    if st.st_mtime < since: continue
    seen = set()
    n_req = n_img = n_undated = 0
    tot = defaultdict(float)
    sidechain = False
    with open(path) as f:
        for line in f:
            try: r = json.loads(line)
            except Exception: continue
            # A subagent transcript is one whatever the window: decide `sidechain` before filtering,
            # so a partially-in-window subagent still reports as one.
            if r.get('isSidechain'): sidechain = True
            # --since is honoured per RECORD. An undated record is KEPT (a silent drop under-reports
            # and makes a loop look cheaper than it was) and tallied in `undated` if it is billed.
            undated = False
            if since:
                t = rec_time(r)
                if t is None: undated = True
                elif t < since: continue
            m = r.get('message') or {}
            u = m.get('usage') or r.get('usage')
            rid = r.get('requestId') or m.get('id')
            if u and rid and rid not in seen:
                seen.add(rid); n_req += 1
                if undated: n_undated += 1
                for k in ('input_tokens','cache_read_input_tokens','cache_creation_input_tokens','output_tokens'):
                    tot[k] += u.get(k,0)
                tot['effective'] += eff(u)
            content = m.get('content')
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'image': n_img += 1
            # tool results carry images too
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'tool_result':
                        cc = c.get('content')
                        if isinstance(cc, list):
                            for x in cc:
                                if isinstance(x, dict) and x.get('type') == 'image': n_img += 1
    if not n_req: continue
    tot['effective'] += n_img * IMG
    rows.append({'path': path, 'file': os.path.basename(path), 'mtime': st.st_mtime,
                 'sidechain': sidechain, 'requests': n_req, 'images': n_img,
                 'undated': n_undated,
                 'agent': agent_type_of(path), **{k: int(v) for k, v in tot.items()}})

rows.sort(key=lambda r: -r['effective'])
undated = sum(r['undated'] for r in rows)
if undated:
    print(f'note: {undated} record(s) had no parsable timestamp and were COUNTED regardless of '
          f'--since (per-row `undated`).', file=sys.stderr)
print(json.dumps(rows, indent=1))
