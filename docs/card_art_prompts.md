# 卡圖 AI 生成 Prompt 清單(Gemini 用)

> 目的:為 24 隻 Tiny RPG 角色各生成一張**繪畫風卡圖**(填 CardData 的 `art` 欄位)。
> 像素圖**不是**卡圖——那批已填進 `standee` 欄位,留給「召喚時站在卡片上的 HD-2D 立牌」。
> 本清單的角色描述是**逐一看過素材的 Idle/Flying 圖**寫的(顏色、武器、坐騎都對過)。

## 使用方式(每張卡重複這三步)

1. 開 Gemini,**貼上該角色的像素圖**當參考:
   `assets/小小RPG角色素材包/.../Characters(100x100 split)/<角色>/<角色>/<角色>_Idle.png`
   (用「無陰影」資料夾那張 600×100 六格圖;**只有 Bat 例外,用 `Bat_Flying.png`**)
2. 複製下面該角色**那一整行** prompt 貼上送出。
3. 存檔命名照「`slug 中文.png`」(例:`knight 騎士.png`),放進 `assets/ui/card_art/`
   ——已生成的 10 張就是這格式,剩下的照做,Claude 批次接線時能自動對上。

> **進度:16 / 24 已生成並接進 `.tres`**。
> 還缺 8 張:archer、bat、orc、skeleton、skeleton_archer、slime、soldier、swordsman。

## 重要原則(為什麼 prompt 長這樣)

- **風格前綴每張一模一樣**:24 張要像「同一套牌、同一個畫師」,風格句一個字都別改,只換角色描述。
- **直式 3:4 + 四邊留白**(你實測後定的版型):主體約佔畫面 70%、武器身體不碰邊
  (卡框裁切安全),背景畫滿到邊。CardArt 已改成「依圖寬自動縮放」,任何解析度都能吃。
- **no text / no frame**:數字與卡框是引擎即時疊的(資料與視覺分離),圖裡絕不能烤字。
- 生出來覺得跟像素設計不像,追加一句:
  `Stay faithful to the attached pixel sprite: same colors, same equipment, same silhouette.`

## Prompt 清單(每行完整可直接貼)

```text
Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a small green slime with a darker mossy core, low wobbly gelatinous body. (slime 史萊姆)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a grey-blue cave bat with wide webbed wings, mid-flight, fangs bared. (bat 蝙蝠)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a bone-white skeleton footsoldier holding a short sword level at its side. (skeleton 骷髏兵)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a compact soldier in a dark iron helmet and armor with a dark red tunic, short sword ready. (soldier 士兵)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: an archer in a tan hood and russet-brown outfit drawing a pale wooden bow. (archer 弓箭手)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a skeleton archer with a tattered blue-grey scarf, bow in hand and a red quiver on its back. (skeleton_archer 骷髏弓手)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a red-haired swordsman without a helmet, tan and crimson outfit, holding a pale blue blade low. (swordsman 劍士)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a bare-chested green orc in brown trousers gripping a crude stone club. (orc 獸人)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a knight in blue steel armor riding a dark warhorse with a red saddle, holding an upright lance. (lancer 槍騎兵)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a small priest in a white mitre and white-and-red vestments holding a holy tome. (priest 牧師)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a skeleton knight dragging an enormous grey greatsword nearly as long as itself. (greatsword_skeleton 巨劍骷髏)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a knight in polished silver plate with a red-plumed helmet, sword held level. (knight 騎士)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a bulky warrior in dark blue-grey full plate resting a huge silver battle axe on his shoulder. (armored_axeman 重甲斧手)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a green orc in grey plate armor holding a long halberd diagonally across its body. (armored_orc 重甲獸人)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a slim skeleton clad in dented grey armor with a blade slung behind its back. (armored_skeleton 重甲骷髏)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a wizard in a blue robe and tall pointed blue hat holding a wooden staff with a golden tip. (wizard 巫師)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a necromancer shrouded in a ragged black hooded robe clutching a dark twisted staff. (necromancer 死靈法師)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: an orc warlord in dark spiked armor raising a brutal pink-spiked mace. (elite_orc 菁英獸人)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a mohawked orc raider riding a hulking grey boar. (orc_rider 獸人騎手)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a heavyset templar in grey blessed plate leveling a long poleaxe forward. (knight_templar 聖殿騎士)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a grey-blue furred werewolf hunched forward with oversized curved claws. (werewolf 狼人)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a massive dark-brown werebear with broad shoulders and heavy claws. (werebear 熊人)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a black-bodied demon with crimson horns and wings wielding a broad grey cleaver. (demon_a 惡魔)

Painted fantasy trading-card illustration, vertical portrait 3:4 aspect ratio, half-body portrait centered in frame, subject occupies about 70% of the canvas with clear margin on all sides (no body part or weapon touching the edges, safe for card-frame cropping), background painted edge-to-edge full bleed, dramatic warm rim light, soft dark forest background with god rays, muted earthy palette, high detail, sharp focus, no text, no watermark, no card frame, no border. Match the attached pixel sprite's design, colors and equipment. Character: a hunched abomination of magenta flesh mottled with dark red boils. (blood_monster_a 血肉魔物)
```

## 生完之後

1. 24 張 PNG 建議放 `assets/ui/card_art/`(新資料夾),檔名照上面括號裡的 slug(`slime_art.png`…)。
2. 跟 Claude 說一聲,批次把 24 個 `.tres` 的 `art` 從佔位像素圖換成正式卡圖
   (`standee` 保持像素圖不動,那是立牌);
   或你自己在編輯器點開 `.tres`,把 PNG 拖進 `art` 欄位一張一張換(資料變、程式不變)。
