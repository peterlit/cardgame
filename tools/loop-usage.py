#!/usr/bin/env python3
"""Token accounting for the review/QA loops, from raw session transcripts.

Kept in the repo on purpose: the previous two measurements (docs/loop-token-usage.md,
docs/qa-loop-feedback.md) were made with throwaway scratchpad scripts that did not survive
the session, so each new measurement started from scratch.

    python3 tools/loop-usage.py --since $(date -v-3H +%s)   # last 3 hours of transcripts

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

PROJ = os.path.expanduser('~/.claude/projects/-Users-plit-Documents-src-cardgame')
since = 0.0
args = sys.argv[1:]
for i, a in enumerate(args):
    if a == '--since': since = float(args[i+1])
    if a == '--dir': PROJ = args[i+1]

IMG = 1600
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
    n_req = n_img = 0
    tot = defaultdict(float)
    sidechain = False
    with open(path) as f:
        for line in f:
            try: r = json.loads(line)
            except Exception: continue
            if r.get('isSidechain'): sidechain = True
            m = r.get('message') or {}
            u = m.get('usage') or r.get('usage')
            rid = r.get('requestId') or m.get('id')
            if u and rid and rid not in seen:
                seen.add(rid); n_req += 1
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
                 'agent': agent_type_of(path), **{k: int(v) for k, v in tot.items()}})

rows.sort(key=lambda r: -r['effective'])
print(json.dumps(rows, indent=1))
