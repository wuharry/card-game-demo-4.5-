# 交接筆記:CardData 卡片資料系統(Route A)

> **給家裡那台電腦的 Claude agent**:這是一份自帶上下文的交接文件。
> 請先讀完本檔,再讀專案根目錄的 `CLAUDE.md` 與 `README.md`,然後接續教學與開發。
>
> **本檔最後更新:2026-07-01(這個 session)。** 前半 §A/§B 是「今天做到哪、卡在哪」(最新);
> 後半 §0–§8 是 CardData 系統的完整施工藍圖(資料層 階段 1/2 尚未做,務必保留)。

---

## §A. 今天(2026-07-01)做了什麼

1. **CLAUDE.md 瘦身/立紀律**:加入「知識庫結構」段(長內容搬 `docs/`、CLAUDE.md 留一行指標;三段式 vs ADR 分界;業務語意留 README),並清掉已刪檔 `cardManger3D.gd` 的過時參照。
2. **README 修**:移除同一個 `cardManger3D.gd` 死參照(全專案已無此檔)。驗證過 README 其餘 19 個路徑/連結都有效。
3. **卡片數值 Label(= 本 CardData 系統 §6 階段 3 的開頭)**:在 `src/card/card.tscn` 的 `Card` 根節點下,
   四個 `Label3D` 子節點都已就位並各填了佔位 text:
   - `NameLabel`(text「怪物名稱」)、`CostLabel`(左上)、`ATKLabel`(左下)、`HPLabel`(右下),皆 `0`。
   - 爐石式版面:Cost 左上、ATK 左下、HP 右下、Name 中間。x/y 由 Harvey 自己在 Inspector 調到滿意。

> ⚠️ **注意**:資料層(§6 階段 1 的 `CardData` class、階段 2 的 `.tres`、`card.gd` 的 `setup()`)**都還沒做**。
> 今天只是把「顯示數值的節點」先擺上去,結果撞到下面 §B 的深度問題。**資料/發牌邏輯仍是主線待辦。**

---

## §B. ★當前卡住的問題:Label3D 的深度(浮起來 / 埋進去)★

### 症狀(Harvey 觀察到的)
- 卡片**在手牌**時,數值 label 看起來貼合卡面,正常。
- 卡片**放到桌上卡槽**後,label 看起來**浮在卡片上方**(HD-2D 斜下視角下特別明顯)。
- 若把 label 的 **z 調小**,桌上不浮了,但**手牌時字會埋進卡面**裡。

### 根因(已定位,這段是留存重點)
label 的 **z 偏移是沿著「卡片自己的 local +Z(卡面法線)」**推出去的,而**卡片在兩種狀態的旋轉不同**:

- **手牌**:旋轉 `Vector3(card_tilt_x, 0, -angle)`,`card_tilt_x = 55`(見 `src/play_hand/player_hand.gd` `_arrange_fan()`)。
  卡面法線≈朝相機 → z 偏移是「往相機方向」的深度,間隙在視線正前後 → **看不到**,只是把字疊到卡面前。
- **上桌**:`src/card_slot/card_slot.gd` 的 `place_card()` 把卡片 `rotation_degrees` 轉成 **`(0,0,0)`**(第 55 行,「轉正」)。
  法線被轉去指別的世界方向、跟「斜下看」的相機視線夾一個大角度 → 同一段 z 偏移變成「往側邊」的位移 → **看得到 = 浮起來**。

> 🧠 **可遷移原則**:local 座標的偏移會跟著節點一起旋轉。z 偏移只有在「節點正對相機」時才等於「往螢幕內的深度」;
> 節點一轉(手牌 55° → 桌上 0°),它就指到世界別處去了。**同一個數字,兩種視覺意義。**

而「z 調小手牌會埋」的真正原因是 **z-fighting(深度快取精度打架)**,不是距離不夠 —— 這才是要對付的東西。

### 今天已套上的修正(起始值,回家要驗證)
在 `card.tscn` 對 `CostLabel / ATKLabel / HPLabel` 三個 label:
- **z 統一改成 `0.02`**(與 `NameLabel` 對齊 → 貼合卡面,桌上不再浮)。
- **加上 `render_priority = 1`**:用「畫在前面」取代「推到前面」——讓字穩定畫在卡框之上,不必靠實體 z 距離去贏深度測試 → 手牌時也不該被埋。
- **`NameLabel` 刻意沒動**(維持 z=0.02、無 render_priority),當**對照組**:跑起來比對它和三個角落 label 在手牌裡的表現,就能看出 render_priority 到底有沒有生效。

### 回家後請這樣驗證與研究
1. 按 ▶ 跑 `scenes/main.tscn`。**手牌**:四個數字都不該被卡面埋掉。**上桌**:數字應貼合、不浮。
2. 對照 `NameLabel`(無 render_priority)vs 角落三個(有):
   - 若三個角落清楚、NameLabel 反而在手牌被埋 → 證明 render_priority 有效,把 NameLabel 也加上。
   - 若四個都好 → 可能單純 z=0.02 就夠,render_priority 是保險(可留)。
3. **若仍被埋**:研究 Label3D 的 `no_depth_test`(強制畫最上層)。**代價**:它會穿透擋在前面的其他卡(手牌扇形重疊、桌上前排),要斟酌。
4. **若仍浮**(理論上 z=0.02 不該):考慮改走「狀態驅動 z」——在 `place_card()` 轉正時順手把 label z 設更小,回手牌時設回。控制最準但多耦合,是備案不是首選。

### 收尾理解題(Harvey 還沒回答,回家先想這題)
> **如果把手牌的 `card_tilt_x` 從 55° 改成 0°(讓手牌也跟上桌一樣不傾斜),你預期手牌那些 label 會變得比較貼合、還是也開始浮?為什麼?**
>
> (提示:想「卡面法線這時指哪、跟相機視線夾幾度」。答得出就代表 §B 的根因真的通了。)

---
---

# CardData 系統完整藍圖(資料層待辦 — 以下保留自原交接筆記)

## §0. 給接手 agent 的話(先看這段)

- 你在接手一個 **「教學 + 開發」** 的 session。開發者 = **Harvey,Godot 新手**。
- **務必遵守 `CLAUDE.md` 的 Learning Mode 協定**:這是複雜任務(新增功能),
  **不要直接用 Edit/Write 改他的 `.gd`**;把程式碼**貼在對話裡當範本**,讓他自己打、自己填,你在旁邊修。
  唯一可動檔案系統的是「建立空白檔/資料夾」那一步(見 §8)。
  (例外:`.tscn` 的數值微調,Harvey 這次有明確授權我直接改 label 的 transform/render_priority;沒授權時仍照協定給值讓他自己填。)
- 一律 **繁體中文** 回覆。引擎 **Godot 4.5**,語言 **GDScript**。
- 系統選單/操作說明請給 **English(中文)雙語**,因為繁中 Godot 介面中英混雜,他照其中一個找得到就行。
- 收尾時用**一個**理解題驗證他是真懂(見 §7),答錯就換個方式再講,別跳過。

---

## §1. 進度總覽

- **上上個 session**:code review 清理(刪 `cardManger3D.gd`、`play_card()` 封裝、`@export` 注入 `player_hand`、型別補齊)、README 重寫 + Gameplay Spec、環境腳本/水面 shader 中文註解。
- **今天(2026-07-01)**:見 §A / §B。重點 = 顯示層 label 節點就位 + 撞到深度問題並已套起始修正。
- **下一步主線**:資料層還沒動 —— `CardData` class(階段 1)、`.tres`(階段 2)、`card.gd` 的 `setup()`(階段 3 收尾)、發牌驗證(階段 4)。**深度問題(§B)驗證完就接這條主線。**

> ⚠️ **git 提醒**:`scenes/main.tscn` 的 `CardManger` 節點那行有 `node_paths=PackedStringArray("player_hand")`
> —— 這是 `@export` 節點注入能解析的關鍵,**別弄丟**。

---

## §2. 為何先做「最小 CardData」(Route A)而非發牌動畫

- 場上每張卡現在都是同一張 `NewCard.png`,**沒有 Cost / ATK / HP / 名稱** —— 是「空殼」。
- 整份 Gameplay Spec(魔力、召喚、戰鬥)全建立在「卡有數值」之上,**現在全做不出來**。
- 先鋪資料地基 → 解鎖最多後續工作;發牌動畫接在它後面,還能「翻牌露出真實數值」,更有料。

可遷移原則:**先解鎖「擋住最多後續工作」的東西,再做拋光 (juice)。別在空殼上做動畫。**

---

## §3. ★必須幫他守住的觀念★(別讓他走回頭路)

Harvey 卡住的真正原因是一個**美術誤會**:他以為「每種數值組合都要一張完整卡 PNG」→
排列組合爆炸 → 結論是「要花錢買美術」。**這是錯的,接手後要持續幫他守住正確觀念。**

**真相:數字不是畫進圖裡的。** 一張卡 = 疊起來的三層:

```
① 卡框 (frame)   ← 1 張就好,所有卡共用(border + 中間挖空 + 下方描述留白)
② 卡圖 (art)     ← 每張卡一張,放進挖空處的生物圖
③ 名字/數字       ← 用 Label3D「即時印上去」,資料來自 CardData(不是圖!)
```

| 他的擔心 | 真相 |
|---|---|
| Cost/ATK/HP 排列組合爆炸 | 不會。數字是文字節點,**1 張卡框**就能套上百張卡的數值 |
| 中間挖空 + 下面留白要專業美術 | 那只是**卡框模板**,只要 1 張;描述欄是 `RichTextLabel`,不是圖 |

- 他**已經有卡框素材**:`assets/ui/card_frames/`(`base 11.png` 就在裡面)。
- **`https://ultimatetcgcm.com/`**:One Piece TCG「卡片製作器」,匯出**把數字烤進去的完整 PNG**
  → 適合**實體桌遊列印**,**不適合數位版**(會把該當資料的數字烤死在圖裡,走回排列組合地獄)。**數位版要「框 + 即時文字」。**

> 🧠 原則:**會變的(數字/文字/狀態)= 資料 + 文字節點;不變的外觀 = 圖。永遠別把會變的值烤進圖。**
> (§B 的 label 就是「③ 即時印上去」這一層 —— 今天在解決它的深度顯示,資料來源之後才由 `setup()` 餵進來。)

---

## §4. 美術便宜路線(現在零美術也能做完整功能)

- **卡框(1 張共用)**:程式美術(色塊 + Label3D 拼)/ [Kenney.nl](https://kenney.nl) CC0 / 他已有的 `card_frames/`。
- **卡圖(每卡一張)**:[game-icons.net](https://game-icons.net)(CC 授權)/ AI 只生成生物圖 / 原型先放純色佔位塊。

原型階段建議:**先用程式美術 + Label3D 把功能做完**,之後再換漂亮素材(資料與視覺已分離,換圖不動邏輯)。

---

## §5. 架構

```
src/card/
├── card.gd          (既有) 場上卡片:視覺+互動  ← 幫它加 setup(data) 方法
├── card.tscn        (既有) ← 已加 NameLabel/CostLabel/ATKLabel/HPLabel(見 §A)
└── card_data.gd     (新增) class_name CardData extends Resource — 一張卡的數值定義

data/cards/          (新增資料夾) 一張卡一個 .tres(在編輯器可視化編輯)
├── goblin.tres
└── knight.tres

src/deck/
└── deck.gd          (之後) 掛到現有 Deck 節點:var cards: Array[CardData] + draw()
```

**核心概念**:`CardData`(資料,`Resource`)vs `Card`(場上節點,`Node`)。一份 CardData 可生出多個 Card 節點。

**本步資料流(尚未做動畫)**:
`PlayerHand.draw_starting_hand()` → 拿一份 `CardData` → 生成 `Card` → `card.setup(data)` → 卡面顯示該卡。

---

## §6. 步驟(4 階段;選單給 English(中文) 雙語)

### 階段 1:建立 `CardData` 資料類別
1. **FileSystem(檔案系統)** → 對 `src/card/` 右鍵 → **Create New(建立新的)→ Script…(腳本…)**。
2. **Inherits/繼承** 填 `Resource`、檔名 `card_data.gd`。
3. 範本(讓 Harvey 自己打、理解每一行):

```gdscript
## card_data.gd — 一張卡的「資料定義」。純數值,不在場上跑邏輯。
extends Resource
class_name CardData   ## 註冊全域型別,Inspector 才認得這個資源類型

@export var card_name: String = "未命名"
@export var cost: int = 1
@export var atk: int = 1
@export var hp: int = 1
@export var art: Texture2D
```

> 為什麼 `@export`?這樣欄位才會**出現在 Inspector**,做 .tres 時能拖拉填值。

### 階段 2:建立卡資料 `.tres`(一張卡一個檔)
1. 根目錄右鍵 → **Create New → Folder(資料夾)** → 建 `data`,內再建 `cards/`。
2. 對 `data/cards/` 右鍵 → **Create New → Resource…(資源…)** → 搜尋 **`CardData`** → 選它 → **Create**。
3. 在 **Inspector** 填數值(如 `card_name=哥布林, cost=1, atk=2, hp=1`),把卡圖拖進 `art`。
4. **Ctrl+S** 存成 `goblin.tres`。重複 2~3 張。

### 階段 3:卡片顯示資料(Label3D 已加好 → 補 `setup()`)
> Label3D 子節點今天已建(§A)。這階段剩「用 `setup()` 把資料餵進那些 label」。
> ⚠️ 注意 **節點名對齊**:今天 tscn 用的是 `NameLabel / CostLabel / ATKLabel / HPLabel`,
> `setup()` 的節點路徑要跟這些名字**完全一致**(大小寫也算),否則 `$AtkLabel` 這種會抓不到而報 null。

```gdscript
## 由發牌端呼叫,把一份 CardData 套到這張卡的外觀上。
@export var data: CardData

func setup(card_data: CardData) -> void:
	data = card_data
	$CardArt.texture = data.art          ## 卡圖 Sprite3D(tscn 裡叫 CardArt,目前空的)
	$NameLabel.text = data.card_name
	$CostLabel.text = str(data.cost)      ## int 要 str() 轉,Label3D 只吃字串
	$ATKLabel.text = str(data.atk)
	$HPLabel.text = str(data.hp)
```

> ⚠️ 上面的 `$CardArt` / `$CostLabel`… 節點名要對到今天的 tscn(不是舊筆記寫的 `CardImage`/`AtkLabel`/`HpLabel`)。

### 階段 4:驗證
暫時在 `player_hand.gd` 的 `draw_starting_hand()` 生成卡後呼叫 `card.setup(...)`
(先 `preload("res://data/cards/goblin.tres")` 硬塞測試),按 ▶ 跑 `scenes/main.tscn`,
手牌應出現**不同數值的卡**。之後再把 `Deck` 改成真正的 `Array[CardData]` 並做發牌。

---

## §7. 待辦的理解檢查(接手 agent:進階段 1 前先問他這題)

> **「如果今天要新增一張『火球術:5 費、8 攻、2 血』,在這套架構下你要做什麼、不用做什麼?
> 你會碰到圖嗎?會改 `card.gd` 嗎?」**

**期望答案**:不用碰任何卡框圖、不用改 `card.gd` 邏輯(`setup()` 已通用),
只要**新增一個 `fireball.tres`、填數值、(可選)指定卡圖**即可。
若他答得出「資料變、程式不變」,代表資料/視覺分離的觀念通了 → 才進階段 1。答錯回 §3 換方式再講。

---

## §8. 接手後的第一個動作

Harvey 確認理解(§7)後,**唯一可動檔案系統的動作**:建立空白檔 `src/card/card_data.gd`
(只建空檔,內容讓他照 §6 階段 1 範本自己打)。之後回到「他打 → 貼回來 → 你修」的節奏,逐階段推進。

**但更前面**:先陪他把 §B 的深度問題在編輯器裡驗證/收尾(那是他離開前最後卡住的地方)。
