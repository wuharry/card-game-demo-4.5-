# 素材來源推薦(2026-08-06)

> 目標是「朋友從網站下載遊戲」(README 待辦 #4)= **要能商業/公開散布**。
> 所以下面每一條都標了授權型態;**下載後第一件事是把 LICENSE 收進包內**,
> 並依 [CREDITS.md](../CREDITS.md) 的格式登記(CC-BY 類**必須**掛名,漏掉就是違約)。

---

## 網站清單(先收藏這幾個站,其餘都是從這裡長出來的)

### 綜合素材站(什麼都有,優先來這裡找)

| 網站 | 網址 | 授權 | 備註 |
|---|---|---|---|
| **itch.io 素材區** ★ | https://itch.io/game-assets/free | 逐包不同 | 像素風素材的最大集散地;篩 `Free` + `Pixel Art` + `Sprites` |
| **OpenGameArt** | https://opengameart.org | CC0 / CC-BY / GPL 混雜 | 老牌;**進站先看授權欄**,CC-BY-SA 盡量避開 |
| **Kenney** ★ | https://kenney.nl/assets | **全站 CC0** | 免掛名、免煩惱;UI、圖示、音效、3D 都有 |
| **CraftPix 免費區** | https://craftpix.net/freebies/ | 自訂免費授權 | 量大質整齊,但免費版通常**禁止再散布素材本體** |
| **Game-Icons.net** ★ | https://game-icons.net | CC BY 3.0 | 4000+ 向量圖示,可任意上色——法術卡圖首選 |

### 2D 角色 / 怪物(要有攻擊動畫的那種)

| 作者 / 站 | 網址 | 備註 |
|---|---|---|
| **LuizMelo** ★ | https://luizmelo.itch.io | 免費;Idle/Attack1-3/Hurt/Death 動畫最齊,天生對得上 §6.1 |
| **Penusbmic** | https://penusbmic.itch.io | 低價付費;暗黑奇幻怪物與 Boss 最多 |
| **Sanctumpixel** | https://sanctumpixel.itch.io | 怪物 + 魔法特效同一作者,風格一致 |
| **Elthen(Ma9ici4n)** | https://elthen.itch.io | 動物/怪物動畫;授權逐包確認 |
| **Szadi art / Anokolisa** | https://szadiart.itch.io ／ https://anokolisa.itch.io | 偏場景與 tileset,補戰場用 |

### 法術 / 伏印 / 瞬咒的卡圖(**要對得上現有風格**:32×32 像素、黑外框、暗色魔法調)

> 現況:法術卡圖來自兩包風格**不同**的圖示——
> `antahonist_spells`(暗底、高對比、真法術主題,但**整包只有 16 格**)、
> `shikashi/v1+v2`(亮色黑細邊、透明底,**幾乎沒有法術圖示**,強項是武器/防具/藥水/書卷)。
> 所以缺的其實只有一類:**暗色調的魔法/符文圖示**。靈裝卡的圖 Shikashi 那包已經夠用。

| 來源 | 網址 | 授權 | 風格對得上嗎 |
|---|---|---|---|
| **CraftPix — Free Spells Icons Pixel Art** ★ | https://craftpix.net/freebies/free-spells-icons-pixel-art/ | 自訂免費授權 | ★★★ 直接就是法術主題,暗底高對比,和 antahonist 同調 |
| **Dungeon Crawl Stone Soup 32×32 tiles** ★ | https://opengameart.org/content/dungeon-crawl-32x32-tiles | **CC0** | ★★★ 尺寸剛好 32×32,卷軸/符文/法杖/魔法書量大;色調略暗,正合伏印 |
| **Ravenmore — Fantasy Icon Pack** | https://opengameart.org/content/fantasy-icon-pack-by-ravenmore-0 | CC BY 3.0 | ★★☆ 暗色奇幻,含符文與法術;像素密度略粗 |
| **game-icons.net** | https://game-icons.net | CC BY 3.0 | ★★☆ **血緣一致**(Shikashi 本來就部分衍生自這裡);向量,匯出 32px 後自己補外框 |
| **Shikashi's Fantasy Icons Pack**(已購買,回原頁看有無更新) | https://cheekyinkling.itch.io/shikashis-fantasy-icons-pack | 已購買 | ★★★ 同一包當然最合;但法術類要另外找 |
| **Franuka** | https://franuka.itch.io | 免費+付費 | ★★☆ 亮色描邊,和 shikashi 同調,適合靈裝/道具 |
| **Kyrise's Free 16×16 RPG Icon Pack** | https://kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack | 免費(CC-BY) | ★☆☆ 16×16,放大兩倍後像素會比角色粗一倍,慎用 |

**四種卡型的視覺語言**(找圖時直接照這個關鍵字搜):

| 卡型 | 該長什麼樣 | 搜尋關鍵字 |
|---|---|---|
| 秘術 | 主動轟出去的法術 | fireball / lightning / ice shard / poison cloud |
| 瞬咒 | 反制、抵銷 | shield / mirror / hourglass / broken staff / counter |
| 伏印 | 蓋放的陷阱、封印 | rune circle / seal / chains / trap / spider web |
| 靈裝 | 裝備 | **不用找**,`shikashi` 的武器/防具/戒指區現成 |

> **比找素材更有效的一招**:不同來源的圖示只要 ①統一裁成 32×32、②統一放大倍率(nearest 過濾)、
> ③**墊同一個暗色圓底襯**(就是 antahonist 那包自帶、shikashi 沒有的那層),
> 看起來就會是同一套。`card.gd` 已經在畫卡型色帶了,底襯接在那裡最省事。

| 來源 | 網址 | 授權 |
|---|---|---|
| **Bdragon1727** ★ | https://bdragon1727.itch.io | 免費像素特效包(爆炸/斬擊/魔法陣/火冰雷) |
| **Ansimuz** | https://ansimuz.itch.io | 多為 CC0 的特效與場景包 |
| **Dungeon Crawl Stone Soup tiles** | https://opengameart.org/content/dungeon-crawl-32x32-tiles | CC0;大量 32×32 道具/法術圖示 |

### 音效 / 音樂

| 來源 | 網址 | 授權 |
|---|---|---|
| **Freesound** | https://freesound.org | 逐檔不同,**用篩選器只看 CC0** 最省事 |
| **Pixabay(音效/音樂)** | https://pixabay.com/sound-effects/ | 自有授權,免費商用免掛名 |
| **Sonniss GDC Bundle** | https://sonniss.com/gameaudiogdc | 免費商用的專業音效庫(數十 GB) |
| **Incompetech(Kevin MacLeod)** | https://incompetech.com | CC-BY 音樂,掛名即可用 |
| **Tallbeard《Three Red Hearts》** | https://tallbeard.itch.io | 免費配樂包 |

### 3D / 場景 / 字體

| 來源 | 網址 | 授權 |
|---|---|---|
| **Quaternius** ★ | https://quaternius.com | CC0 低多邊形模型庫 |
| **KayKit(Kay Lousberg)** ★ | https://kaylousberg.itch.io | CC0;Dungeon / Medieval / Character 套組 |
| **Poly Haven** | https://polyhaven.com | CC0 HDRI / 材質 / 模型 |
| **ambientCG** | https://ambientcg.com | CC0 PBR 材質 |
| **Google Fonts** | https://fonts.google.com | OFL(現用的思源宋體就是從這來的) |

> ⚠️ **避開 Unity Asset Store / Unreal Marketplace 的免費素材**:它們的 EULA 多半綁定該引擎,
> 拿進 Godot 專案再公開發佈是違約的灰區。同理,AI 生成素材的商用條款各家不同,要發佈前先查清楚。

---

## 0. 挑素材前的硬條件(本專案專屬,不合就別下載)

1. **角色立牌必須有多張動畫表**。§6.1 是「動畫驅動技能」——看得到的動作才是用得到的招。
   最低要求:`Idle` + `Attack01` + `Attack02` + `Hurt`;有 `Death` / `Block` 更好
   (【鐵壁】播 Block、【不滅】播 Summon)。只有 Idle 的角色進來只能當白板堆料。
2. **檔名要能改成 `<角色>_<動畫>.png`**。`card_data.gd` 的 `get_anim_sheet()` 是把最後一個
   底線後面換掉去找兄弟檔——命名不合就抓不到攻擊動畫(現有 `Swordsman_Attack3` 這種
   例外是靠呼叫端硬填後綴兜的,能少一個是一個)。
3. **同一張表的每格等寬等高**(現有素材是 100×100 split)。不等距切幀 = 卡圖抖動。
4. **授權優先序**:CC0 > CC-BY(掛名即可) > 自訂免費商用授權 > CC-BY-SA(會傳染,盡量避開)。
   「免費但禁止商業使用」的一律跳過——那會擋死發佈。
5. **寧可一次拿同一作者的一整包**,不要東拼西湊:HD-2D 最怕的是像素密度不一致
   (32×32 的圖示配 100×100 的角色會很明顯)。

---

## 1. 角色 / 怪物立牌(最缺的一塊)

| 來源 | 內容 | 授權 | 為什麼推 |
|---|---|---|---|
| **LuizMelo**(itch.io) | Hero Knight、Martial Hero、Evil Wizard、Huntress、Fire Worm 等 | 免費(多數可商用,逐包確認) | **動畫最齊**:Idle/Attack1-3/Hurt/Death 一應俱全,天生對得上 §6.1 |
| **Penusbmic**(itch.io) | Dark Fantasy 系列大量怪物與 Boss | 低價付費(約 $3–8) | 怪物種類多、動畫分明;要一次補齊敵方陣容就買這個 |
| **Sanctumpixel**(itch.io) | 怪物角色 + 魔法特效 | 免費/付費混合 | 角色與特效同一作者 → 風格一致 |
| **o_lobster**(itch.io) | 免費動畫角色小包 | 免費 | 補幾隻雜兵很快 |
| **CraftPix free 區** | 2D fantasy character sprites | 自訂免費授權 | ⚠️ 免費版通常**禁止再散布素材本體**(做進遊戲可以),下載前務必讀 |

> 搜尋起點:itch.io → Game Assets → 篩 `Sprites` + `Pixel Art` + 價格 Free,
> 再用「有沒有 attack 動畫」當第一道篩子。

## 2. 法術特效(目前只有純程式粒子 `fx_burst.gd`)

| 來源 | 內容 | 授權 |
|---|---|---|
| **Bdragon1727**(itch.io) | Free Pixel Effects Pack 系列(爆炸/斬擊/魔法陣/火冰雷) | 免費,多數可商用 |
| **Ansimuz**(itch.io) | Explosion / Magic 特效包 | 多為 CC0 |
| **Sanctumpixel** | magic effect sheets | 依包而異 |

> 用途對照:秘術落地(§7)、狀態施加(§9 灼燒/凍結)、【不滅】復活——
> 這三個時機現在都只有粒子,補上 sprite 特效表提升最明顯。

## 3. 卡面圖示(法術卡卡圖;你已有 Shikashi + Antahonist)

| 來源 | 內容 | 授權 |
|---|---|---|
| **game-icons.net** ★ | 4000+ SVG 圖示(法術/武器/狀態/生物) | CC BY 3.0(需掛名) |
| **Dungeon Crawl Stone Soup tiles**(OpenGameArt) ★ | 大量 32×32 道具/法術圖示 | CC0 |
| **Kenney.nl** | UI 圖示、按鈕、標記 | CC0 |

> game-icons.net 是**純向量、可任意上色**——非常適合上面那份卡片構思稿:
> 同一個火焰圖示染紅=灼燒、染藍=凍結,一套圖示撐得起 20 張法術卡。

## 4. 卡框 / UI（目前正式卡框為 `NewCard_fixed.png`）

| 來源 | 內容 | 授權 |
|---|---|---|
| **Kenney Boardgame Pack** ★ | 卡框、卡背、指示物、骰 | CC0 |
| **Kenney UI Pack / Fantasy UI** | 面板、按鈕、邊框 | CC0 |
| **CraftPix free GUI** | 奇幻風 GUI 組 | 自訂免費授權(讀 license) |

> 卡型印章(秘術/瞬咒/伏印)現在是程式畫的色塊;有卡框素材後可以四種卡型各一張框,
> 一眼分得出卡型——這比多加 10 張卡更能改善手感。

## 5. 音效 / 音樂(README 待辦 #3 點名要「出牌/攻擊/受擊至少三個」)

| 來源 | 內容 | 授權 |
|---|---|---|
| **Kenney audio packs** ★ | UI 點擊、打擊、卡牌音 | CC0 |
| **freesound.org** | 幾乎什麼都有 | 逐檔不同,**篩 CC0** 最省事 |
| **Pixabay Audio** | 音樂與音效 | 免費商用(自有授權) |
| **Tallbeard Studios《Three Red Hearts》**(itch.io) | 免費配樂包 | 免費商用 |
| **Sonniss GDC Bundle** | 專業音效庫(數十 GB) | 免費商用 |

## 6. 3D 環境(補現有 PSX 樹 / pixel3d 包)

| 來源 | 內容 | 授權 |
|---|---|---|
| **Quaternius**(quaternius.com) ★ | 大量低多邊形模型(自然/建築/角色) | CC0 |
| **KayKit**(Kay Lousberg, itch.io) ★ | Dungeon / Medieval / Character 包 | CC0 |
| **Kenney 3D packs** | Nature、Castle、Platformer kit | CC0 |

---

## 7. 下載之後的固定流程(別跳)

1. 放進 `assets/packs/<snake_case_包名>/`,**包內保留原始結構**(利於日後對照授權)。
2. 把 `LICENSE` / `README` 一起留著,不要只拿圖。
3. 到 [CREDITS.md](../CREDITS.md) 登記一行;CC-BY 類要寫出作者要求的掛名字串。
4. 刪素材走 **Godot 編輯器 FileSystem → 右鍵 Delete**(讓引擎同步清 `.import` 與 UID)。
5. 匯出前確認沒有死重:匯出預設會把 `res://` 底下全部打包,沒用到的素材照樣進 zip
   (2026-07-16 那次清了 82M)。
