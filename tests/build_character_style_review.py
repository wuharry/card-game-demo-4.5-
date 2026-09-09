"""Embed existing PNG bytes in an offline animation review; does not edit images."""
import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/sprite-style-20260909"
OUT = ROOT / "docs/art/character-style-review.html"


def image_data(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def sheets(directory, stem):
    return {
        p.stem.removeprefix(stem + "_"): image_data(p)
        for p in sorted(directory.glob(stem + "_*.png"))
        if "preview" not in p.stem and not p.stem.endswith("Static")
    }


old_audit = json.loads((WORK / "audit.json").read_text())
new_audit = json.loads((WORK / "stage_audit/audit.json").read_text())
old_by_stem = {Path(x["path"]).stem: x for x in old_audit}
new_by_stem = {Path(x["path"]).stem: x for x in new_audit}
manifest = json.loads((ROOT / "assets/characters/style_generation_20260909.json").read_text())
characters = []
for c in sorted(manifest["characters"], key=lambda c: c["id"]):
    stem = c["stem"]
    relative = Path(c["destination"]).relative_to("assets/characters")
    characters.append({
        "id": c["id"], "stem": stem,
        "before": sheets(WORK / "before" / relative, stem),
        "after": sheets(ROOT / c["destination"], stem),
        "beforeStats": old_by_stem[stem + "_Idle"],
        "afterStats": new_by_stem[stem + "_Idle"],
    })
references = []
for ref in old_audit:
    if not ref["reference"]:
        continue
    path = ROOT / ref["path"].removeprefix("res://")
    stem = path.stem.removesuffix("_Idle")
    references.append({"id": stem, "sheets": sheets(path.parent, stem), "stats": ref})

payload = json.dumps({"characters": characters, "references": references}, ensure_ascii=False)
html = r'''<!doctype html>
<html lang="zh-Hant"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>角色動畫・Tiny RPG 風格比較</title>
<style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#171b23;color:#e7eaf0}
body{max-width:1240px;margin:40px auto;padding:0 24px}h1{font-size:30px;margin-bottom:10px}
p{color:#acb7c9;line-height:1.7}small{color:#a5b0c2}.toolbar{position:sticky;top:0;z-index:2;background:#171b23f5;padding:16px 0;display:flex;gap:10px;flex-wrap:wrap;border-bottom:1px solid #39414f}
button,select,input{font:inherit}button,select{padding:9px 13px;border:1px solid #49556b;background:#272f3d;color:#fff;border-radius:7px;cursor:pointer}button.active{background:#265c52;border-color:#67b39e}
label{display:flex;align-items:center;gap:8px}#refs{display:flex;flex-wrap:nowrap;overflow-x:auto;gap:12px;margin:20px 0 35px}.ref{background:#222832;border-radius:10px;padding:12px;text-align:center}
#cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,500px),1fr));gap:22px}.card{background:#222832;border:1px solid #36404f;border-radius:12px;padding:18px}.card h2{font-size:18px;margin:0 0 16px}.pair{display:flex;justify-content:space-around;gap:10px}.sample{min-width:0;text-align:center}.sample canvas{max-width:100%;height:auto;background:#30323c;border-radius:8px;image-rendering:pixelated}.caption{font-size:12px;color:#a5b0c2;margin-top:8px}.tag{color:#83d2b9}.missing{color:#d8ac76}footer{margin-top:35px;color:#a5b0c2}
</style>
<h1>角色動畫・Tiny RPG 風格比較</h1>
<p>上方是原素材，下方逐角色比較重繪前後。可播放待機、普攻、技能、受傷、倒地與冰霜女巫的專屬動作。<br>預設用相同像素倍率檢查筆法；切換「相同角色高度」可接近牌桌的顯示比例。這是檢視工具，並非盲測通過的證明。</p>
<div class="toolbar"><select id="action" aria-label="動畫"><option value="Idle">待機</option><option value="Attack01">普通攻擊</option><option value="Attack02">技能</option><option value="Hurt">受傷</option><option value="Death">倒地</option><option value="Walk">行走</option><option value="Summon">登場</option></select>
<select id="scale" aria-label="比較比例"><option value="native">相同像素倍率 ×4</option><option value="height">相同角色高度</option></select>
<button id="pause">暫停</button><button id="step">下一格</button><label>速度 <input id="speed" type="range" min="0.25" max="1.5" value="1" step="0.25"></label><small id="frame"></small></div>
<h2>Tiny RPG 原素材</h2><div id="refs"></div><h2>重繪前 → 重繪後</h2><div id="cards"></div>
<footer>2026-09-09 · PNG 已嵌入此頁，可離線開啟。未提供的動畫會標示「無此動作」，並顯示待機。動作播完會留一段待機空檔；倒地會停在最後一格。</footer>
<script>
const DATA=__DATA__;
const views=[];let elapsed=0,paused=false,last=performance.now();
const action=document.querySelector('#action'),scale=document.querySelector('#scale');
function view(parent,source,stats,title,width=240){
 const box=document.createElement('div');box.className='sample';
 const label=document.createElement('div');label.textContent=title;box.append(label);
 const canvas=document.createElement('canvas');canvas.width=width;canvas.height=width===144?160:240;box.append(canvas);
 const caption=document.createElement('div');caption.className='caption';box.append(caption);parent.append(box);
 const images={};for(const [name,url] of Object.entries(source)){const img=new Image();img.src=url;images[name]=img;}
 views.push({canvas,images,stats,caption});
}
for(const ref of DATA.references){const box=document.createElement('div');box.className='ref';document.querySelector('#refs').append(box);view(box,ref.sheets,ref.stats,ref.id,144);}
for(const c of DATA.characters){
 const box=document.createElement('article');box.className='card';
 const heading=document.createElement('h2');heading.textContent=c.stem.replaceAll('_',' ');box.append(heading);
 const pair=document.createElement('div');pair.className='pair';box.append(pair);
 view(pair,c.before,c.beforeStats,'重繪前');view(pair,c.after,c.afterStats,'重繪後');document.querySelector('#cards').append(box);
}
action.onchange=()=>{elapsed=0};
document.querySelector('#pause').onclick=()=>{paused=!paused;document.querySelector('#pause').textContent=paused?'播放':'暫停'};
document.querySelector('#step').onclick=()=>{paused=true;document.querySelector('#pause').textContent='播放';elapsed+=action.value==='Idle'?120:100};
function render(now){
 if(!paused)elapsed+=(now-last)*Number(document.querySelector('#speed').value);last=now;
 document.querySelector('#frame').textContent=(elapsed/1000).toFixed(1)+' s';
 for(const v of views){
  const {canvas,images,stats,caption}=v,ctx=canvas.getContext('2d');ctx.clearRect(0,0,canvas.width,canvas.height);ctx.imageSmoothingEnabled=false;
  const missing=!images[action.value];let img=images[action.value]||images.Idle;if(!img.complete||!img.naturalWidth)continue;
  const n=img.naturalWidth/img.naturalHeight,loop=['Idle','Walk'].includes(action.value),duration=action.value==='Idle'?120:100;
  let f=Math.floor(elapsed/duration)%n;
  if(!loop){const t=elapsed%1800;f=Math.min(n-1,Math.floor(t/duration));if(t>=n*duration&&action.value!=='Death'){img=images.Idle;f=0;}}
  if(missing){img=images.Idle;f=0;}
  const [x,y,w,h]=stats.bounds,s=scale.value==='native'?4:100/h;
  const dx=Math.round(canvas.width/2-(x+w/2)*s),dy=Math.round(canvas.height-30-(y+h)*s);
  ctx.drawImage(img,f*100,0,100,100,dx,dy,100*s,100*s);
  caption.textContent=(missing?'無此動作 · ':'')+stats.colors+' 色 · 待機高 '+h+' px · '+(f+1)+' / '+(missing?stats.frames:n)+' 格';
  caption.className='caption'+(missing?' missing':'');
 }
 requestAnimationFrame(render);
}
requestAnimationFrame(render);
</script></html>'''
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(html.replace("__DATA__", payload))
print(f"Saved {OUT.relative_to(ROOT)} ({OUT.stat().st_size:,} bytes)")
