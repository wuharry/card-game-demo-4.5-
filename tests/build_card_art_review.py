"""Rebuild the offline card-art review from the authoritative background manifest."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/art/card-background-manifest.json"
OUTPUT = ROOT / "docs/art/all-card-backgrounds-review.html"


def main() -> None:
    cards = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for card in cards:
        for key in ("art", "output") if card["status"] == "complete" else ("art",):
            path = ROOT / card[key].removeprefix("res://")
            if not path.is_file():
                raise FileNotFoundError(path)
    page = '''<!doctype html>
<html lang="zh-Hant"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>全卡池插畫對照</title>
<style>
body{background:#151820;color:#eee;font:16px/1.6 system-ui;margin:24px}
header,nav,main,footer{max-width:1500px;margin:auto}h1{color:#ebcb83;margin-bottom:8px}
nav{position:sticky;top:0;background:#151820f5;padding:12px 0;z-index:1;display:flex;gap:12px;flex-wrap:wrap;align-items:center}
input,select{padding:8px;background:#252b35;color:#eee;border:1px solid #596373;border-radius:4px}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:20px}
article{background:#20252d;border:1px solid #37414e;border-radius:6px;padding:14px}
h2{font-size:19px;margin:0 0 12px}section{display:flex;gap:8px}figure{margin:0;width:50%}
img{display:block;width:100%;aspect-ratio:42/34;object-fit:cover;image-rendering:pixelated;background:#11111a}
body.full img{aspect-ratio:3/2;object-fit:contain}p,figcaption{font-size:13px;color:#aeb6c3}
small{font-size:11px;color:#8793a5}a{color:#cbb27a}footer{padding:24px 0}#count{color:#cbb27a}
</style>
<header><h1>全卡池插畫對照</h1><p>暗色像素插畫、主體置中、依卡牌題材搭配場景。左側是原圖，右側是目前卡圖；預設顯示卡窗取景，可切換檢視完整插畫。</p></header>
<nav><input id="q" aria-label="搜尋卡名或 ID" placeholder="搜尋卡名或 ID">
<select id="theme" aria-label="背景主題"><option value="">所有背景</option></select>
<label><input id="full" type="checkbox">完整插畫</label><span id="count"></span></nav>
<main></main><footer>正式卡框截圖： <span id="pages"></span></footer>
<script>
const cards=__CARDS__;
const themes={volcano:'熔岩焦土',forest:'幽暗古林',catacombs:'幽冥墓穴',desert:'荒原遺跡',snow:'冰雪山原',ocean:'暗色海岸',astral:'星界遺跡',neutral:'舊版暗夜'};
for(const value of [...new Set(cards.map(c=>c.theme))].sort()){const o=document.createElement('option');o.value=value;o.textContent=themes[value]||value;document.querySelector('#theme').append(o)}
const src=p=>'../../'+p.replace('res://','');
function render(){const query=document.querySelector('#q').value.trim().toLowerCase(),theme=document.querySelector('#theme').value;const shown=cards.filter(c=>(!theme||c.theme===theme)&&(c.id+' '+c.name).toLowerCase().includes(query));const main=document.querySelector('main');main.replaceChildren();document.querySelector('#count').textContent=shown.length+' / '+cards.length+' 張';for(const c of shown){const a=document.createElement('article'),h=document.createElement('h2'),s=document.createElement('section');h.textContent=c.name+' · '+(themes[c.theme]||c.theme);a.append(h,s);for(const [label,path] of [['原圖',c.art],['目前卡圖',c.status==='complete'?c.output:c.art]]){const f=document.createElement('figure'),i=document.createElement('img'),caption=document.createElement('figcaption');i.src=src(path);i.alt=c.name+'：'+label;i.loading='lazy';caption.textContent=label;f.append(i,caption);s.append(f)}const p=document.createElement('p'),id=document.createElement('small');p.textContent=c.reason;id.textContent=c.id;a.append(p,id);main.append(a)}}
document.querySelector('#q').addEventListener('input',render);document.querySelector('#theme').addEventListener('change',render);document.querySelector('#full').addEventListener('change',e=>document.body.classList.toggle('full',e.target.checked));
for(let n=1;n<=Math.ceil(cards.length/12);n++){const a=document.createElement('a');a.href='all-card-backgrounds-review/page_'+String(n).padStart(2,'0')+'.png';a.textContent='第 '+n+' 頁';document.querySelector('#pages').append(a,document.createTextNode('　'))}render();
</script></html>
'''
    payload = json.dumps(cards, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c")
    OUTPUT.write_text(page.replace("__CARDS__", payload), encoding="utf-8", newline="\n")
    print(f"Saved {len(cards)} cards: {OUTPUT}")


if __name__ == "__main__":
    main()
