// Generates the portrait-controls proposal artboards from the app's real values
// (ContentView.swift pill/rail styles, Theme.swift palette, SummerBackground.swift colours).
import { writeFileSync } from 'node:fs';

const W = 390, H = 844, PAD = 6, GAP = 4;
const CARD_W = Math.floor((W - PAD * 2 - GAP * 7) / 8);        // 43 — portraitCardW
const CARD_H = Math.round(CARD_W * (92 / 66) * 1.2);          // 72 — Theme.cardAspect
const OVERLAP = Math.round(CARD_H * 0.40);                      // 29 — portrait fan
const RED = '#B04738', BLK = '#2A3B44', GOLD = '#D9AD55', GOLDTXT = '#3A2B00', INK = '#33403C', CREAM = '#F4EFE2';

// The deal on the simulator screenshot (top → bottom per column).
const deal = [
  ['Q♥','A♣','6♥','2♠','6♠','A♥','5♥'], ['7♥','7♦','9♦','4♠','8♦','K♥','10♥'],
  ['5♣','9♠','2♦','J♦','3♦','7♣','J♥'], ['Q♣','6♦','10♣','A♠','7♠','3♥','4♥'],
  ['K♦','5♦','A♦','4♦','5♠','4♣'], ['9♣','2♥','J♣','8♠','Q♠','K♠'],
  ['8♣','J♠','10♦','8♥','9♥','6♣'], ['3♣','K♣','3♠','Q♦','10♠','2♣'],
];
const isRed = s => s.endsWith('♥') || s.endsWith('♦');

const face = (label, top) => {
  const rank = label.slice(0, -1), suit = label.slice(-1), col = isRed(label) ? RED : BLK;
  return `<div style="position:absolute;left:0;top:${top}px;width:${CARD_W}px;height:${CARD_H}px;box-sizing:border-box;background:linear-gradient(#F8F2E2,#F3ECD9);border:1px solid #000;border-radius:${Math.round(CARD_W*0.11)}px;box-shadow:0 1px 1px rgba(0,0,0,.28);color:${col};font:700 15px/1 system-ui,-apple-system,sans-serif;padding:3px 3px 0 3px;display:flex;justify-content:space-between;align-items:flex-start;letter-spacing:-.5px"><span>${rank}</span><span style="font-size:16px">${suit}</span></div>`;
};
const column = cards => {
  const h = CARD_H + OVERLAP * (cards.length - 1);
  return `<div style="position:relative;width:${CARD_W}px;height:${h}px">${cards.map((c, i) => face(c, i * OVERLAP)).join('')}</div>`;
};
const tableau = () => `<div style="display:flex;gap:${GAP}px;padding:0 ${PAD}px">${deal.map(column).join('')}</div>`;

const ghost = (t, dim) => `<div style="width:${CARD_W}px;height:${CARD_H}px;box-sizing:border-box;border:1.5px solid rgba(255,255,255,.55);border-radius:${Math.round(CARD_W*0.11)}px;background:rgba(255,255,255,.14);color:${dim};font:700 13px Georgia,'Times New Roman',serif;padding:3px 4px;display:flex;flex-direction:column;justify-content:space-between"><span>${t.r}</span><span style="align-self:center;font-size:18px;margin-bottom:10px">${t.s}</span></div>`;
const suits = ['♠','♥','♦','♣'];
const fRow = r => `<div style="display:flex;gap:${GAP}px">${suits.map(s => ghost({r, s}, s==='♥'||s==='♦' ? 'rgba(176,71,56,.45)' : 'rgba(42,59,68,.45)')).join('')}</div>`;
const label = t => `<div style="font:600 10px system-ui,-apple-system,sans-serif;letter-spacing:1px;color:${INK};opacity:.6;white-space:nowrap">${t}</div>`;
const upper = () => `<div style="display:flex;justify-content:space-between;align-items:flex-start;padding:0 ${PAD}px">
  <div style="display:flex;flex-direction:column;gap:${GAP}px">${label('FOUNDATIONS · A↑ / K↓')}${fRow('A')}${fRow('K')}</div>
  <div style="display:flex;flex-direction:column;gap:${GAP}px;align-items:flex-end">${label('FREE CELLS')}<div style="display:flex;gap:${GAP}px">${[0,1,2].map(()=>`<div style="width:${CARD_W}px;height:${CARD_H}px;box-sizing:border-box;border:1.5px solid rgba(255,255,255,.55);border-radius:${Math.round(CARD_W*0.11)}px;background:rgba(255,255,255,.14)"></div>`).join('')}</div></div>
</div>`;

// header — Text("Causeway") 22 bold serif; subtitle 11 @ .65; stats 12 / 18 bold serif
const stat = (l, v) => `<div style="display:flex;flex-direction:column;align-items:center;gap:1px"><span style="font:400 12px system-ui,-apple-system,sans-serif;opacity:.8">${l}</span><span style="font:700 18px Georgia,'Times New Roman',serif">${v}</span></div>`;
const header = (extra = '') => `<div style="display:flex;justify-content:space-between;align-items:${extra?'flex-start':'flex-end'};padding:0 ${PAD}px;color:${INK}">
  <div style="display:flex;flex-direction:column"><div style="font:700 22px Georgia,'Times New Roman',serif">Causeway</div><div style="font:400 11px system-ui,-apple-system,sans-serif;opacity:.65">build each suit from both ends</div>${extra}</div>
  <div style="display:flex;gap:14px">${stat('Moves','0')}${stat('Time','0:00')}${stat('Won','0')}</div>
</div>`;

// icons — stroke SVG on a 16px grid (SF Symbols stand-ins)
const svg = (d, size = 14, extra = '') => `<svg width="${size}" height="${size}" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"${extra}>${d}</svg>`;
const I = {
  undo:  svg('<path d="M6 3 3 6l3 3"/><path d="M3 6h6a4 4 0 0 1 0 8H6"/>'),
  redo:  svg('<path d="M10 3l3 3-3 3"/><path d="M13 6H7a4 4 0 0 0 0 8h3"/>'),
  replay:svg('<path d="M13 8a5 5 0 1 1-1.5-3.6"/><path d="M13 2v3h-3"/>'),
  plus:  svg('<path d="M8 3v10M3 8h10"/>'),
  cal:   svg('<rect x="2.5" y="3.5" width="11" height="10" rx="1.5"/><path d="M2.5 7h11M5.5 2v3M10.5 2v3"/>'),
  trophy:svg('<path d="M5 3h6v4a3 3 0 0 1-6 0V3z"/><path d="M5 4H3v1.5A2.5 2.5 0 0 0 5.5 8M11 4h2v1.5A2.5 2.5 0 0 1 10.5 8"/><path d="M8 10v2M5.5 13.5h5"/>'),
  help:  svg('<circle cx="8" cy="8" r="6"/><path d="M6.2 6.3a1.9 1.9 0 1 1 2.7 1.7c-.6.3-.9.7-.9 1.3"/><path d="M8 11.4h.01"/>'),
  more:  svg('<circle cx="3.5" cy="8" r="1" fill="currentColor"/><circle cx="8" cy="8" r="1" fill="currentColor"/><circle cx="12.5" cy="8" r="1" fill="currentColor"/>'),
  gear:  svg('<circle cx="8" cy="8" r="2.2"/><path d="M8 1.8v1.7M8 12.5v1.7M1.8 8h1.7M12.5 8h1.7M3.6 3.6l1.2 1.2M11.2 11.2l1.2 1.2M3.6 12.4l1.2-1.2M11.2 4.8l1.2-1.2"/>'),
  check: svg('<path d="M3 8.5l3 3 7-7"/>'),
  chev:  svg('<path d="M6 3l5 5-5 5"/>', 12),
  flag:  svg('<path d="M3.5 14V2.5h8l-2 3 2 3h-8"/>'),
};

// pill — Button: 13/600, pad 8×12, Capsule fill 2A3B44@.46 (gold primary), stroke white@.35
const PILL = (t, {primary=false, icon='', disabled=false, extra=''} = {}) =>
  `<div style="display:inline-flex;align-items:center;gap:4px;padding:8px 12px;border-radius:999px;background:${primary?GOLD:'rgba(42,59,68,.46)'};color:${primary?GOLDTXT:CREAM};box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);font:600 13px system-ui,-apple-system,sans-serif;white-space:nowrap;${disabled?'opacity:.4;':''}${extra}">${icon}${t}</div>`;

// background — SummerBackground.swift: sky stops, sun at (50%, 58%), sea at ~72%, sand at ~85%
const bg = () => `<div style="position:absolute;inset:0;overflow:hidden;background:linear-gradient(#FFD777 0%,#FDE6A2 42%,#FDF1D2 72%,#FBF4DC 100%)">
  <div style="position:absolute;left:50%;top:58%;width:${W*1.2}px;height:${W*1.2}px;transform:translate(-50%,-50%);border-radius:50%;background:radial-gradient(circle,rgba(255,246,214,.9),rgba(251,212,95,0) 70%)"></div>
  <div style="position:absolute;left:50%;top:58%;width:${W*0.56}px;height:${W*0.56}px;transform:translate(-50%,-50%);border-radius:50%;background:radial-gradient(circle,#FFF3CC,#FAC74B)"></div>
  <div style="position:absolute;left:14%;top:12%;width:120px;height:44px;border-radius:999px;background:#fff;opacity:.9;filter:blur(6px)"></div>
  <div style="position:absolute;left:74%;top:8%;width:80px;height:30px;border-radius:999px;background:#fff;opacity:.8;filter:blur(6px)"></div>
  <div style="position:absolute;left:56%;top:29%;width:100px;height:36px;border-radius:999px;background:#fff;opacity:.65;filter:blur(6px)"></div>
  <div style="position:absolute;left:0;right:0;top:72%;bottom:0;background:linear-gradient(#A3DBC8,#82CBB6);border-radius:50% 50% 0 0/14px 14px 0 0"></div>
  <div style="position:absolute;left:0;right:0;top:85%;bottom:0;background:linear-gradient(#F4DEA8,#E9CE8F);border-radius:50% 50% 0 0/12px 12px 0 0"></div>
</div>`;

const shell = (title, body, note = '') => `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>
    body { margin: 0; font-family: system-ui, -apple-system, sans-serif; }
    a { color: ${GOLDTXT}; } a:hover { color: #6B4F00; }
  </style>
</helmet>
<div style="position:relative;width:${W}px;height:${H}px;overflow:hidden;background:#FDE6A2;color:${INK}">
  ${bg()}
  <div style="position:absolute;inset:0;display:flex;flex-direction:column;gap:12px;padding-top:62px">
    ${body}
  </div>
  ${note}
</div>
</x-dc>
</body>
</html>`;

// ---------- Current (reference) ----------
const current = shell('Current', `
  ${header()}
  <div style="display:flex;flex-direction:column;gap:8px;padding:0 ${PAD}px">
    <div style="display:flex;gap:8px">${PILL('New game',{primary:true})}${PILL('Undo',{icon:I.undo,disabled:true})}${PILL('Replay',{icon:I.replay})}${PILL('Auto-play: On')}</div>
    <div style="display:flex;gap:8px">${PILL('Auto-finish: Ask')}${PILL('Deal #408843')}${PILL('Daily')}${PILL('Wins')}</div>
    <div style="display:flex;gap:8px">${PILL('How to play')}</div>
  </div>
  ${upper()}
  ${tableau()}
`);

// ---------- A · Deck (bottom bar in the thumb zone) ----------
const deckItem = (t, icon, {primary=false, disabled=false} = {}) =>
  `<div style="flex:1 1 0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:3px;height:52px;border-radius:14px;color:${primary?GOLDTXT:CREAM};background:${primary?GOLD:'transparent'};${primary?'box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);':''}${disabled?'opacity:.4;':''}"><span style="display:flex">${icon}</span><span style="font:600 11px system-ui,-apple-system,sans-serif;letter-spacing:.1px">${t}</span></div>`;
const togglePill = (t, v) => `<div style="flex:1 1 0;display:flex;align-items:center;justify-content:center;gap:7px;height:38px;border-radius:999px;background:rgba(42,59,68,.46);color:${CREAM};box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);font:600 13px system-ui,-apple-system,sans-serif;white-space:nowrap"><span>${t}</span><span style="padding:2px 8px;border-radius:999px;background:rgba(244,239,226,.18);box-shadow:inset 0 0 0 1px rgba(255,255,255,.3);font-weight:700;font-size:12px">${v}</span></div>`;
const toggleRow = () => `<div style="display:flex;gap:8px;width:100%">${togglePill('Auto-play','On')}${togglePill('Auto-finish','Ask')}</div>`;
const deckBar = (finish = false, toggles = false) => `<div style="position:absolute;left:${PAD+2}px;right:${PAD+2}px;bottom:14px;display:flex;flex-direction:column;align-items:center;gap:8px">
  ${finish ? `<div style="display:inline-flex;align-items:center;gap:6px;padding:9px 18px;border-radius:999px;background:${GOLD};color:${GOLDTXT};box-shadow:inset 0 0 0 1px rgba(255,255,255,.35),0 4px 12px rgba(58,43,0,.18);font:700 14px system-ui,-apple-system,sans-serif">${I.flag}Finish the deal</div>` : ''}
  ${toggles ? toggleRow() : ''}
  <div style="display:flex;gap:2px;width:100%;padding:4px;box-sizing:border-box;border-radius:20px;background:rgba(42,59,68,.46);box-shadow:inset 0 0 0 1px rgba(255,255,255,.35),0 6px 18px rgba(42,59,68,.18);backdrop-filter:blur(10px)">
    ${deckItem('New game', I.plus, {primary:true})}${deckItem('Undo', I.undo, {disabled:true})}${deckItem('Replay', I.replay)}${deckItem('Daily', I.cal)}${deckItem('More', I.more)}
  </div>
</div>`;
const dealLine = (extra='') => `<div style="display:flex;align-items:center;gap:6px;margin-top:6px;font:600 12px system-ui,-apple-system,sans-serif;color:${INK}"><span style="display:inline-flex;align-items:center;gap:4px;padding:3px 9px;border-radius:999px;background:rgba(42,59,68,.12);box-shadow:inset 0 0 0 1px rgba(42,59,68,.18)">Deal #408843 ${I.chev}</span>${extra}</div>`;
const optionA = shell('Option A · Deck', `
  ${header(dealLine())}
  ${upper()}
  ${tableau()}
  ${deckBar()}
`);
const optionAFinish = shell('Option A · Finish offered', `
  ${header(dealLine())}
  ${upper()}
  ${tableau()}
  ${deckBar(true)}
`);
// The More menu — iOS Menu anatomy: grouped rows, trailing state / check.
const menuRow = (t, right, icon) => `<div style="display:flex;align-items:center;justify-content:space-between;padding:11px 16px;font:400 17px system-ui,-apple-system,sans-serif;color:#1C1C1E"><span>${t}</span><span style="display:flex;align-items:center;gap:8px;color:#6E6E73;font-size:15px">${right}<span style="display:flex;color:#1C1C1E">${icon}</span></span></div>`;
const optionAMenu = shell('Option A · More menu', `
  ${header(dealLine())}
  ${upper()}
  ${tableau()}
  <div style="position:absolute;inset:0;background:rgba(0,0,0,.06)"></div>
  <div style="position:absolute;right:${PAD+6}px;bottom:84px;width:250px;border-radius:14px;background:rgba(248,246,240,.96);box-shadow:0 10px 30px rgba(0,0,0,.18);overflow:hidden;backdrop-filter:blur(20px)">
    ${menuRow('Auto-play', 'On', I.check)}
    <div style="height:1px;background:rgba(0,0,0,.08);margin-left:16px"></div>
    ${menuRow('Auto-finish', 'Ask', I.gear)}
    <div style="height:8px;background:rgba(0,0,0,.05)"></div>
    ${menuRow('Wins', '', I.trophy)}
    <div style="height:1px;background:rgba(0,0,0,.08);margin-left:16px"></div>
    ${menuRow('How to play', '', I.help)}
  </div>
  ${deckBar()}
`);

// ---------- A2 · Deck + permanent toggle row (owner's request, 2026-09-13) ----------
const optionA2 = shell('Option A2 · Toggle row', `${header(dealLine())}${upper()}${tableau()}${deckBar(false, true)}`);
const optionA2Finish = shell('Option A2 · Finish offered', `${header(dealLine())}${upper()}${tableau()}${deckBar(true, true)}`);
const optionA2Menu = shell('Option A2 · More menu', `
  ${header(dealLine())}
  ${upper()}
  ${tableau()}
  <div style="position:absolute;inset:0;background:rgba(0,0,0,.06)"></div>
  <div style="position:absolute;right:${PAD+6}px;bottom:130px;width:250px;border-radius:14px;background:rgba(248,246,240,.96);box-shadow:0 10px 30px rgba(0,0,0,.18);overflow:hidden;backdrop-filter:blur(20px)">
    ${menuRow('Wins', '', I.trophy)}
    <div style="height:1px;background:rgba(0,0,0,.08);margin-left:16px"></div>
    ${menuRow('How to play', '', I.help)}
  </div>
  ${deckBar(false, true)}
`);

// ---------- B · Two rows (actions + status strip, stays at the top) ----------
const seg = (t, icon, {primary=false, disabled=false, first=false, last=false} = {}) =>
  `<div style="flex:1 1 0;display:flex;align-items:center;justify-content:center;gap:5px;height:36px;font:600 13px system-ui,-apple-system,sans-serif;color:${primary?GOLDTXT:CREAM};background:${primary?GOLD:'transparent'};border-radius:${first?'999px 0 0 999px':last?'0 999px 999px 0':'0'};${disabled?'opacity:.4;':''}">${icon}${t}</div>`;
const chip = (t, v) => `<span style="display:inline-flex;align-items:center;gap:5px;padding:5px 10px;border-radius:999px;background:rgba(42,59,68,.12);box-shadow:inset 0 0 0 1px rgba(42,59,68,.18);font:600 11px system-ui,-apple-system,sans-serif;color:${INK};white-space:nowrap">${t}${v?`<span style="font-weight:700;color:#1F2E36">${v}</span>`:''}</span>`;
const iconBtn = icon => `<span style="display:inline-flex;align-items:center;justify-content:center;width:30px;height:30px;border-radius:999px;background:rgba(42,59,68,.46);color:${CREAM};box-shadow:inset 0 0 0 1px rgba(255,255,255,.35)">${icon}</span>`;
const twoRows = (finish=false) => `
  <div style="display:flex;flex-direction:column;gap:8px;padding:0 ${PAD}px">
    <div style="display:flex;gap:1px;border-radius:999px;background:rgba(42,59,68,.46);box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);overflow:hidden">
      ${seg('New game', I.plus, {primary:true, first:true})}${seg('Undo', I.undo, {disabled:true})}${seg('Replay', I.replay)}${seg('Daily', I.cal, {last:true})}
    </div>
    <div style="display:flex;align-items:center;justify-content:space-between">
      <div style="display:flex;gap:6px">${chip('Deal #408843')}${chip('Auto-play','On')}${chip('Auto-finish','Ask')}</div>
      ${iconBtn(I.more)}
    </div>
    ${finish?`<div style="display:flex;align-items:center;justify-content:center;gap:6px;height:36px;border-radius:999px;background:${GOLD};color:${GOLDTXT};box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);font:700 13px system-ui,-apple-system,sans-serif">${I.flag}Finish the deal</div>`:''}
  </div>`;
const optionB = shell('Option B · Two rows', `${header()}${twoRows()}${upper()}${tableau()}`);

// ---------- C · Grid (same ten pills, snapped to a 5×2 grid) ----------
const cell = (t, {primary=false, disabled=false, icon='', span=1} = {}) =>
  `<div style="grid-column:span ${span};display:flex;align-items:center;justify-content:center;gap:4px;height:34px;border-radius:999px;background:${primary?GOLD:'rgba(42,59,68,.46)'};color:${primary?GOLDTXT:CREAM};box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);font:600 11.5px system-ui,-apple-system,sans-serif;white-space:nowrap;${disabled?'opacity:.4;':''}">${icon}${t}</div>`;
const optionC = shell('Option C · Grid', `
  ${header()}
  <div style="display:grid;grid-template-columns:repeat(4, minmax(0, 1fr));gap:6px;padding:0 ${PAD}px">
    ${cell('New game',{primary:true})}${cell('Undo',{disabled:true,icon:I.undo})}${cell('Replay',{icon:I.replay})}${cell('Daily')}
    ${cell('Auto-play On')}${cell('Auto-finish Ask')}${cell('Deal #408843',{span:2})}
    ${cell('Wins',{span:2})}${cell('How to play',{span:2})}
  </div>
  ${upper()}
  ${tableau()}
`);

// ---------- Landscape (874×402, iPhone 16 Pro): today's rail vs the rail in A2's vocabulary ----------
const LW = 874, LH = 402, SAFE = 59, RAIL = 118;
const LCARD_W = 44, LCARD_H = Math.round(LCARD_W * (92 / 66) * 1.2), LOVER = Math.round(LCARD_H * 0.34);
const lface = (label, top) => {
  const rank = label.slice(0, -1), suit = label.slice(-1), col = isRed(label) ? RED : BLK;
  return `<div style="position:absolute;left:0;top:${top}px;width:${LCARD_W}px;height:${LCARD_H}px;box-sizing:border-box;background:linear-gradient(#F8F2E2,#F3ECD9);border:1px solid #000;border-radius:${Math.round(LCARD_W*0.11)}px;box-shadow:0 1px 1px rgba(0,0,0,.28);color:${col};font:700 15px/1 system-ui,-apple-system,sans-serif;padding:3px 3px 0 3px;display:flex;justify-content:space-between;align-items:flex-start;letter-spacing:-.5px"><span>${rank}</span><span style="font-size:16px">${suit}</span></div>`;
};
const lcolumn = cards => `<div style="position:relative;width:${LCARD_W}px;height:${LCARD_H + LOVER * (cards.length - 1)}px">${cards.map((c, i) => lface(c, i * LOVER)).join('')}</div>`;
const ltableau = () => `<div style="display:flex;gap:${GAP}px">${deal.map(lcolumn).join('')}</div>`;
const lghost = (t, dim) => `<div style="width:${LCARD_W}px;height:${LCARD_H}px;box-sizing:border-box;border:1.5px solid rgba(255,255,255,.55);border-radius:${Math.round(LCARD_W*0.11)}px;background:rgba(255,255,255,.14);color:${dim};font:700 13px Georgia,'Times New Roman',serif;padding:3px 4px;display:flex;flex-direction:column;justify-content:space-between"><span>${t.r}</span><span style="align-self:center;font-size:18px;margin-bottom:10px">${t.s}</span></div>`;
const lfRow = r => `<div style="display:flex;gap:${GAP}px">${suits.map(s => lghost({r, s}, s==='♥'||s==='♦' ? 'rgba(176,71,56,.45)' : 'rgba(42,59,68,.45)')).join('')}</div>`;
const lupper = () => `<div style="display:flex;flex-direction:column;gap:${GAP}px">${label('FOUNDATIONS')}${lfRow('A')}${lfRow('K')}<div style="height:4px"></div>${label('FREE CELLS')}<div style="display:flex;gap:${GAP}px">${[0,1,2].map(()=>`<div style="width:${LCARD_W}px;height:${LCARD_H}px;box-sizing:border-box;border:1.5px solid rgba(255,255,255,.55);border-radius:${Math.round(LCARD_W*0.11)}px;background:rgba(255,255,255,.14)"></div>`).join('')}</div></div>`;
// railPill: 12/600, icon 11 bold, pad 6×10, left-aligned, full rail width, spacing 6
const railPill = (t, {primary=false, icon='', disabled=false, badge=''} = {}) =>
  `<div style="display:flex;align-items:center;gap:4px;padding:6px 10px;border-radius:999px;background:${primary?GOLD:'rgba(42,59,68,.46)'};color:${primary?GOLDTXT:CREAM};box-shadow:inset 0 0 0 1px rgba(255,255,255,.35);font:600 12px system-ui,-apple-system,sans-serif;white-space:nowrap;${disabled?'opacity:.4;':''}">${icon}<span>${t}</span>${badge?`<span style="margin-left:auto;padding:1px 6px;border-radius:999px;background:rgba(244,239,226,.18);box-shadow:inset 0 0 0 1px rgba(255,255,255,.3);font-weight:700;font-size:11px">${badge}</span>`:''}</div>`;
const railToday = () => `<div style="display:flex;flex-direction:column;gap:6px;width:${RAIL}px">
  ${railPill('New game',{primary:true})}${railPill('Undo',{icon:svg('<path d="M6 3 3 6l3 3"/><path d="M3 6h6a4 4 0 0 1 0 8H6"/>',11),disabled:true})}${railPill('Replay',{icon:svg('<path d="M13 8a5 5 0 1 1-1.5-3.6"/><path d="M13 2v3h-3"/>',11)})}
  ${railPill('Auto-play: On')}${railPill('Auto-finish: Ask')}${railPill('Deal #408843')}${railPill('Daily')}${railPill('Wins')}${railPill('How to play')}
</div>`;
const railA2 = (finish=false) => `<div style="display:flex;flex-direction:column;gap:6px;width:${RAIL}px">
  ${railPill('New game',{primary:true,icon:svg('<path d="M8 3v10M3 8h10"/>',11)})}${railPill('Undo',{icon:svg('<path d="M6 3 3 6l3 3"/><path d="M3 6h6a4 4 0 0 1 0 8H6"/>',11),disabled:true})}${railPill('Replay',{icon:svg('<path d="M13 8a5 5 0 1 1-1.5-3.6"/><path d="M13 2v3h-3"/>',11)})}${railPill('Daily',{icon:svg('<rect x="2.5" y="3.5" width="11" height="10" rx="1.5"/><path d="M2.5 7h11M5.5 2v3M10.5 2v3"/>',11)})}
  <div style="height:4px"></div>
  ${railPill('Auto-play',{badge:'On'})}${railPill('Auto-finish',{badge:'Ask'})}
  <div style="height:4px"></div>
  ${railPill('More',{icon:svg('<circle cx="3.5" cy="8" r="1" fill="currentColor"/><circle cx="8" cy="8" r="1" fill="currentColor"/><circle cx="12.5" cy="8" r="1" fill="currentColor"/>',11)})}
  ${finish?`<div style="flex:1 1 0"></div>${railPill('Finish the deal',{primary:true,icon:svg('<path d="M3.5 14V2.5h8l-2 3 2 3h-8"/>',11)})}`:''}
</div>`;
const lheader = (extra='') => `<div style="display:flex;justify-content:space-between;align-items:flex-end;color:${INK}">
  <div style="display:flex;align-items:flex-end;gap:22px"><div style="display:flex;flex-direction:column"><div style="font:700 22px Georgia,'Times New Roman',serif">Causeway</div><div style="font:400 11px system-ui,-apple-system,sans-serif;opacity:.65">build each suit from both ends</div></div>${extra?extra.replace('margin-top:6px','margin-bottom:-2px'):''}</div>
  <div style="display:flex;gap:14px">${stat('Moves','0')}${stat('Time','0:00')}${stat('Won','0')}</div>
</div>`;
const lbg = () => `<div style="position:absolute;inset:0;overflow:hidden;background:linear-gradient(#FFD777 0%,#FDE6A2 42%,#FDF1D2 72%,#FBF4DC 100%)">
  <div style="position:absolute;left:50%;top:58%;width:${LW*1.2}px;height:${LW*1.2}px;transform:translate(-50%,-50%);border-radius:50%;background:radial-gradient(circle,rgba(255,246,214,.9),rgba(251,212,95,0) 70%)"></div>
  <div style="position:absolute;left:50%;top:58%;width:${LW*0.56}px;height:${LW*0.56}px;transform:translate(-50%,-50%);border-radius:50%;background:radial-gradient(circle,#FFF3CC,#FAC74B)"></div>
  <div style="position:absolute;left:14%;top:8%;width:150px;height:50px;border-radius:999px;background:#fff;opacity:.9;filter:blur(7px)"></div>
  <div style="position:absolute;left:0;right:0;top:72%;bottom:0;background:linear-gradient(#A3DBC8,#82CBB6);border-radius:50% 50% 0 0/10px 10px 0 0"></div>
  <div style="position:absolute;left:0;right:0;top:85%;bottom:0;background:linear-gradient(#F4DEA8,#E9CE8F);border-radius:50% 50% 0 0/8px 8px 0 0"></div>
</div>`;
const lshell = (rail, extra='') => `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <style>
    body { margin: 0; font-family: system-ui, -apple-system, sans-serif; }
    a { color: ${GOLDTXT}; } a:hover { color: #6B4F00; }
  </style>
</helmet>
<div style="position:relative;width:${LW}px;height:${LH}px;overflow:hidden;background:#FDE6A2;color:${INK}">
  ${lbg()}
  <div style="position:absolute;inset:0;display:flex;flex-direction:column;gap:12px;padding:8px ${SAFE+PAD}px 0">
    ${lheader(extra)}
    <div style="display:flex;gap:10px;align-items:flex-start;flex:1 1 0;min-height:0">
      ${rail}
      ${lupper()}
      <div style="flex:1 1 0;display:flex;justify-content:flex-end">${ltableau()}</div>
    </div>
  </div>
</div>
</x-dc>
</body>
</html>`;
const landToday = lshell(railToday());
const landA2 = lshell(railA2(), dealLine());
const landA2Finish = lshell(railA2(true), dealLine());

const out = { 'Current.dc.html': current, 'Main.dc.html': optionA, 'DeckFinish.dc.html': optionAFinish, 'DeckMenu.dc.html': optionAMenu, 'DeckToggles.dc.html': optionA2, 'DeckTogglesFinish.dc.html': optionA2Finish, 'DeckTogglesMenu.dc.html': optionA2Menu, 'LandscapeToday.dc.html': landToday, 'LandscapeA2.dc.html': landA2, 'LandscapeA2Finish.dc.html': landA2Finish, 'OptionB.dc.html': optionB, 'OptionC.dc.html': optionC };
for (const [f, s] of Object.entries(out)) writeFileSync(new URL(f, import.meta.url), s);

const row = (files, y) => files.map((file, i) => ({ file, x: i * 480, y, w: W, h: H }));
const canvas = {
  artboards: [
    { file: 'Current.dc.html', title: 'Current portrait', x: 0, y: 0, w: W, h: H },
    { file: 'Main.dc.html', title: 'Option A · Deck (recommended)', x: 560, y: 0, w: W, h: H },
    { file: 'DeckFinish.dc.html', title: 'Option A · Finish offered', x: 1040, y: 0, w: W, h: H },
    { file: 'DeckMenu.dc.html', title: 'Option A · More menu', x: 1520, y: 0, w: W, h: H },
    { file: 'DeckToggles.dc.html', title: 'Option A2 · Toggle row', x: 560, y: 1000, w: W, h: H },
    { file: 'DeckTogglesFinish.dc.html', title: 'Option A2 · Finish offered', x: 1040, y: 1000, w: W, h: H },
    { file: 'DeckTogglesMenu.dc.html', title: 'Option A2 · More menu', x: 1520, y: 1000, w: W, h: H },
    { file: 'LandscapeToday.dc.html', title: 'Landscape · today', x: 560, y: 2000, w: LW, h: LH },
    { file: 'LandscapeA2.dc.html', title: 'Landscape · rail in A2 dress', x: 1520, y: 2000, w: LW, h: LH },
    { file: 'LandscapeA2Finish.dc.html', title: 'Landscape · Finish offered', x: 2480, y: 2000, w: LW, h: LH },
    { file: 'OptionB.dc.html', title: 'Option B · Two rows', x: 560, y: 2600, w: W, h: H },
    { file: 'OptionC.dc.html', title: 'Option C · Grid', x: 1040, y: 2600, w: W, h: H },
  ],
  annotations: [
    { id: 'why', x: 0, y: 1000, w: 440, text: 'What the current toolbar gets wrong\n\n• Ten pills of ten widths wrap 4 / 4 / 1, leaving "How to play" orphaned on its own row.\n• Actions (New game, Undo, Replay), settings (Auto-play, Auto-finish), pages (Daily, Wins, How to play) and a readout (Deal #) all wear the same pill, so nothing reads as more important than anything else.\n• Finish appears mid-flow and reflows every pill after it.\n• The most-used control, Undo, sits at the top of the screen while the thumb zone below the tableau is empty.\n\nLandscape already solves this with a single ordered column; portrait needs the equivalent.' },
    { id: 'a2-note', x: 0, y: 1000, w: 440, text: 'Option A2 · Deck + toggle row (owner\'s request, 2026-09-13)\n\nOption A with Auto-play and Auto-finish as a PERMANENT second tier above the bar: two equal-width pills in the bar\'s own material, the state in a small badge (On / Ask) so a glance reads it and a tap cycles it, exactly as today. More now holds only Wins and How to play.\n\nFinish, when offered, rises as a third tier above the toggles — nothing below it moves.\n\nCost: ~46 pt more of the bottom than A (bar 60 + row 38 + gaps), still ~14 pt less than the three-row toolbar it replaces, and the tiers sit on sand the tableau rarely reaches. Everything is under the thumb.' },
    { id: 'land-note', x: 0, y: 2000, w: 440, text: 'Landscape\n\nHeight is the scarce dimension here (402 pt; the rail exists because moving the toolbar off the top is what made the board fit). A2\'s bottom deck would cost ~110 pt of that — a quarter of the board — so the rail stays. It already IS A2 turned on its side: one ordered column, one gold primary.\n\nRight: the same rail in A2\'s dress, so both orientations read as one design — icons on the play actions, state badges on the toggles, Wins / How to play behind More, Deal # beside the title (the header has spare width here, not height — under the subtitle it would cost the board 26 pt). Seven pills instead of nine, so the rail no longer overflows on short phones or with the Daily HUD showing (the WF-12 / RL-5 family). Finish, when offered, docks gold at the foot of the rail.\n\nOr keep it exactly as today — nothing in A2 requires a landscape change.' },
    { id: 'a-note', x: 560, y: -250, w: 900, text: 'Option A · Deck — recommended\n\nThe three play actions plus Daily move into a bottom bar that sits on the sand band, under the thumb. New game keeps its gold. Settings and the two reference pages go behind More, where iOS Menu rows show their state (Auto-play ✓ On, Auto-finish Ask). Deal # becomes a small readout under the subtitle. Finish, when offered, rises as a gold pill above the bar so nothing else moves.\n\nGains ~60 pt of board height in portrait. Tradeoff: the two auto settings are one tap further away, and the bar covers part of the sand.' },
    { id: 'b-note', x: 560, y: 3480, w: 420, text: 'Option B · Two rows\n\nEverything stays at the top, but in two fixed-height rows: a segmented control for New game / Undo / Replay / Daily, then a quiet status strip — chips for Deal / Auto-play / Auto-finish on the left, a More button (Wins, How to play) on the right. Finish, when offered, appears as a full-width gold bar under the strip. Least disruptive to existing tests and muscle memory; saves ~30 pt.' },
    { id: 'c-note', x: 1040, y: 3480, w: 420, text: 'Option C · Grid\n\nThe same ten pills, snapped to a 4-column grid with equal cells (wide cells span two). Nothing changes but rhythm. Honest but weakest: still three rows of same-weight buttons, and Finish still has to squeeze in when it is offered.' },
  ],
  launch: { view: 'canvas' },
};
writeFileSync(new URL('canvas.json', import.meta.url), JSON.stringify(canvas, null, 2));
console.log('wrote', Object.keys(out).join(', '), 'card', CARD_W, 'x', CARD_H, 'overlap', OVERLAP);
