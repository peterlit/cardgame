const SUITS=["S","H","D","C"], RANKS=["","A","2","3","4","5","6","7","8","9","10","J","Q","K"];
const RED=new Set([1,2]);
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return ((t^t>>>14)>>>0)/4294967296;};}
export function deal(seed){const rng=mulberry32(seed>>>0);const d=[];for(let s=0;s<4;s++)for(let r=1;r<=13;r++)d.push({suit:s,rank:r,color:RED.has(s)?"red":"black"});
for(let i=d.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[d[i],d[j]]=[d[j],d[i]];}
const t=Array.from({length:8},()=>[]);let k=0;for(let c=0;c<8;c++){const n=c<4?7:6;for(let i=0;i<n;i++)t[c].push(d[k++]);}return t;}
export const nm=c=>RANKS[c.rank]+SUITS[c.suit];
