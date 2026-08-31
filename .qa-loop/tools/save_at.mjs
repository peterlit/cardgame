// Park a save at an arbitrary point of a day's certified line.
//   node save_at.mjs --day 29 --tier flawless --mode autoplaybreak|firstfinish|move --at <n>
import { readFileSync } from 'node:fs';
import { applyMove, isWon } from '../../../tools/solver/rules.mjs';
import { dealState } from '../../../tools/solver/solve.mjs';
import { dailyChallenge, evaluateChallenge } from '../../../tests/daily.mjs';
import { simulateAutoFinish, isSafeAutoplay, canFoundationUp } from '../../../tests/engine.mjs';
const args=Object.fromEntries(process.argv.slice(2).join(' ').split('--').filter(Boolean).map(s=>s.trim().split(/\s+/)).map(([k,v])=>[k,v]));
const pool=JSON.parse(readFileSync(new URL('../../../data/daily-pool.json',import.meta.url)));
const sol=JSON.parse(readFileSync(new URL('../../../data/daily-solutions.json',import.meta.url)));
const day=+args.day, tier=args.tier||'flawless', mode=args.mode||'move';
const ch=dailyChallenge(day,pool); const seed=ch.seed;
const tokens=sol.solutions[String(seed)][tier].split(' ');
function parseToken(tok){const f=tok.split(',');switch(f[0]){
 case 'F':return {k:'F',from:{col:+f[1]},end:+f[2]?'down':'up'};
 case 'G':return {k:'F',from:{cell:+f[1]},end:+f[2]?'down':'up'};
 case 'T':return {k:'T',src:+f[1],idx:+f[2],dst:+f[3]};
 case 'C':return {k:'C',src:+f[1]};
 case 'X':return {k:'X',cell:+f[1],dst:+f[2]};}throw new Error(tok);}
const clone=s=>({tableau:s.tableau.map(c=>c.slice()),cells:s.cells.slice(),up:s.up.slice(),down:s.down.slice()});
let s=dealState(seed);
const t={won:false,moves:0,elapsed:0,cellUses:0,undos:0,foundationOrder:[],maxRunMoved:0};
let picked=null, note='';
function consider(){
  if(picked) return;
  if(mode==='move' && t.moves===+args.at){ picked={state:clone(s),telem:JSON.parse(JSON.stringify(t))}; return; }
  if(mode==='firstfinish'){
    const sim=simulateAutoFinish(s,t.moves);
    if(sim.won && sim.events.length>0){
      const after=evaluateChallenge(ch,{...t,won:true,moves:sim.moves,foundationOrder:t.foundationOrder.concat(sim.events)});
      note=`firstfinish at move ${t.moves}: cascade -> bronze=${after.bronze} silver=${after.silver} gold=${after.gold} finalMoves=${sim.moves}`;
      picked={state:clone(s),telem:JSON.parse(JSON.stringify(t))};
    }
  }
  if(mode==='autoplaybreak'){
    const cards=[...s.cells.map((c,i)=>c&&{c,where:'cell'+i}),...s.tableau.map((col,i)=>col.length&&{c:col[col.length-1],where:'col'+i})].filter(Boolean);
    for(const {c,where} of cards){
      if(!isSafeAutoplay(s,c)) continue;
      const toUp=canFoundationUp(s,c);
      const fo=t.foundationOrder.concat([{suit:c.suit,rank:c.rank,end:toUp?'up':'down',moveIdx:t.moves+1}]);
      const before=evaluateChallenge(ch,{...t,won:true,moves:t.moves,foundationOrder:t.foundationOrder});
      const after=evaluateChallenge(ch,{...t,won:true,moves:t.moves+1,foundationOrder:fo});
      // fail-fast style: would the send make gold/silver unreachable? use the sim of finishing the line? Use violation proxy: evaluate on the truncated telemetry won't work; use objViolated-like below.
      void before; void after;
      // Use canonical violation: replay the REST of the line after this send is impossible; instead
      // use the split/rank rules via evaluateChallenge on the completed line is not available.
      // Practical proxy for split-at gold on day 29 (matches the pinned test):
      if(ch.gold.id==='split-at'){
        const R=ch.gold.param.R;
        const u=[0,0,0,0],d=[0,0,0,0];
        for(const e of fo){ if(e.end==='up')u[e.suit]++; else d[e.suit]++; }
        if(u.some(x=>x>R)||d.some(x=>x>13-R)){
          note=`autoplaybreak at move ${t.moves}: safe send ${JSON.stringify(c)} from ${where} to ${toUp?'up':'down'} breaks gold split R=${R}`;
          picked={state:clone(s),telem:JSON.parse(JSON.stringify(t))};
          return;
        }
      }
    }
  }
}
consider();
for(const tok of tokens){
  if(picked) break;
  const f=tok.split(',');
  t.moves++;
  if(f[0]==='F'){const col=s.tableau[+f[1]];const c=col[col.length-1];t.foundationOrder.push({suit:c.suit,rank:c.rank,end:+f[2]?'down':'up',moveIdx:t.moves});}
  else if(f[0]==='G'){const c=s.cells[+f[1]];t.foundationOrder.push({suit:c.suit,rank:c.rank,end:+f[2]?'down':'up',moveIdx:t.moves});}
  else if(f[0]==='C'){t.cellUses++;}
  else if(f[0]==='T'){t.maxRunMoved=Math.max(t.maxRunMoved,s.tableau[+f[1]].length-(+f[2]));}
  s=applyMove(s,parseToken(tok));
  if(isWon(s)) break;
  consider();
}
if(!picked) throw new Error('no position found for mode '+mode);
const card=c=>({suit:c.suit,rank:c.rank});
const cd=args.challengeDay==='none'?null:(args.challengeDay!==undefined?+args.challengeDay:day);
const sd=args.startDay==='none'?null:(args.startDay!==undefined?+args.startDay:cd);
const save={seed,tableau:picked.state.tableau.map(col=>col.map(card)),cells:picked.state.cells.map(c=>c?card(c):null),
  up:picked.state.up,down:picked.state.down,moveCount:picked.telem.moves,elapsed:90,started:true,
  telem:{cellUses:picked.telem.cellUses,undos:0,maxRunMoved:picked.telem.maxRunMoved,foundationOrder:picked.telem.foundationOrder},
  autoFinishDeferred:false};
if(cd!==null) save.challengeDay=cd;
if(sd!==null) save.challengeStartDay=sd;
console.error(`[save_at] day ${day} seed ${seed} tier ${tier} mode ${mode} -> stop at move ${picked.telem.moves}/${tokens.length}. ${note}`);
console.log(JSON.stringify(save));
