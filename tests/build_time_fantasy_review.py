"""Build a self-contained sprite/card review page; only embeds original PNG files."""
import base64
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CARDS = json.loads((ROOT / 'assets/characters/time_fantasy/cards.json').read_text())
OUT = ROOT / 'build/tf-svbattle-20260910/review.html'


def image_data(path):
    return 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode()


panels = []
for card in CARDS:
    folder = ROOT / 'assets/characters/time_fantasy' / card['id']
    sources = {action: image_data(folder / f'TF_{card["id"]}_{action}.png')
               for action in ['Idle', 'Attack01', 'Attack02', 'Hurt', 'Death', 'Summon', 'Walk', 'Block']}
    skill = card['skill']
    battlecry = card['battlecry']
    panels.append(f'''<article>
    <canvas width="192" height="192" data-sheets='{json.dumps(sources)}'></canvas>
    <h2>{html.escape(card['card_name'])}</h2>
    <p class="stats">◆ {card['cost']}　攻擊 {card['atk']}　生命 {card['hp']}</p>
    <p><b>{html.escape(skill['skill_name'])} · ◆ {skill['cost']}</b><br>{html.escape(skill['description'])}</p>
    <p>{('戰吼：' + html.escape(battlecry['description'])) if battlecry else '&nbsp;'}</p>
    <small>{html.escape(' / '.join(card['keywords'])) or '從者'} · tf_{card['id']}</small>
    </article>''')
page = '''<!doctype html><html lang="zh-Hant"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Time Fantasy · 新卡預覽</title>
<style>
body{margin:0;background:#161c25;color:#e5decf;font:16px/1.65 system-ui,sans-serif;padding:32px}
header,main{max-width:1200px;margin:auto}h1{color:#ebcb83;margin-bottom:4px}header p{color:#aeb7bb}
nav{position:sticky;top:0;background:#161c25ee;padding:14px 0;z-index:1}
button{background:#303c49;border:1px solid #65716f;color:#fff;padding:9px 14px;margin:3px;border-radius:6px;cursor:pointer}
button.active{background:#806635}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:18px}
article{background:#242c36;border:1px solid #566057;border-radius:10px;padding:18px}h2{margin:0;font-size:22px}
canvas{display:block;margin:auto;image-rendering:pixelated;background:#30323c;border-radius:5px}p{margin:8px 0}.stats{color:#ebcb83}small{color:#99a5ab}
</style><header><h1>Time Fantasy · 十二名旅人</h1>
<p>原作者 finalbossblues 的像素與動作，直接用於新卡。選擇動畫可同時比較所有角色；遊戲中一次性動作結束後會回待機，死亡停在最後一格。</p>
<nav id="actions"></nav></header><main>''' + ''.join(panels) + '''</main>
<script>
const actions={Idle:'待機',Attack01:'普攻',Attack02:'技能',Hurt:'受傷',Death:'倒地',Summon:'登場',Walk:'行走',Block:'格擋'};
let selected='Idle',start=performance.now();
for(const [key,title] of Object.entries(actions)){const b=document.createElement('button');b.textContent=title;b.dataset.key=key;b.onclick=()=>{selected=key;start=performance.now();document.querySelectorAll('button[data-key]').forEach(n=>n.classList.toggle('active',n.dataset.key===key))};b.classList.toggle('active',key===selected);document.querySelector('nav').append(b)}
const panels=[...document.querySelectorAll('canvas')].map(c=>{const images={};for(const [key,src] of Object.entries(JSON.parse(c.dataset.sheets))){images[key]=new Image();images[key].src=src}const ctx=c.getContext('2d');ctx.imageSmoothingEnabled=false;return{c,ctx,images}});
function draw(t){let frame=Math.floor((t-start)/(selected==='Idle'?120:100))%(selected==='Idle'?6:10);frame=Math.min(frame,5);for(const p of panels){const img=p.images[selected];if(img.complete){p.ctx.clearRect(0,0,192,192);p.ctx.drawImage(img,frame*48,0,48,48,0,0,192,192)}}requestAnimationFrame(draw)}requestAnimationFrame(draw);
</script></html>'''
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(page)
print(OUT)
