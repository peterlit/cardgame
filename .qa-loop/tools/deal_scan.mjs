import {deal,nm} from './deal_model.mjs';
function isSeqHead(t,col,idx){const c=t[col];if(idx===c.length-1)return true;const a=c[idx],b=c[idx+1];
 if(a.color===b.color)return false;let dir;if(a.rank===b.rank+1)dir='desc';else if(a.rank===b.rank-1)dir='asc';else return false;
 for(let i=idx;i<c.length-1;i++){const x=c[i],y=c[i+1];if(x.color===y.color)return false;
  if(dir==='desc'&&x.rank!==y.rank+1)return false;if(dir==='asc'&&x.rank!==y.rank-1)return false;}return true;}
function runDir(cards){if(cards.length<2)return 'single';return cards[0].rank===cards[1].rank+1?'desc':'asc';}
function tailDir(c){if(c.length<2)return 'single';const a=c[c.length-2],b=c[c.length-1];
 if(a.color!==b.color&&a.rank===b.rank+1)return 'desc';if(a.color!==b.color&&a.rank===b.rank-1)return 'asc';return 'single';}
function canStack(cards,c){if(c.length===0)return true;const top=c[c.length-1],head=cards[0];
 if(head.color===top.color)return false;if(Math.abs(head.rank-top.rank)!==1)return false;
 const conn=head.rank===top.rank-1?'desc':'asc';const rd=runDir(cards);if(rd!=='single'&&rd!==conn)return false;
 const td=tailDir(c);if(td!=='single'&&td!==conn)return false;return true;}
for(let s=1;s<=40000;s++){const t=deal(s);const bots=t.map(c=>c[c.length-1]);
 const ace=bots.findIndex(c=>c.rank===1),king=bots.findIndex(c=>c.rank===13);
 if(ace<0||king<0)continue;
 let best=null;
 for(let col=0;col<8;col++){const c=t[col];
  for(let idx=0;idx<c.length-1;idx++){ if(!isSeqHead(t,col,idx))continue;
   const cards=c.slice(idx); if(cards.length<3)continue;
   for(let d=0;d<8;d++){ if(d===col)continue; if(canStack(cards,t[d])){best={col,idx,len:cards.length,dst:d,cards:cards.map(nm)};break;} }
   if(best)break;}
  if(best)break;}
 if(best){console.log(s,'ace c'+ace,nm(bots[ace]),'king c'+king,nm(bots[king]),JSON.stringify(best));}
}
