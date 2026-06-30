# 交接筆記:CardData 卡片資料系統(Route A)

> **給家裡那台電腦的 Claude agent**:這是一份自帶上下文的交接文件。
> 請先讀完本檔,再讀專案根目錄的 `CLAUDE.md` 與 `README.md`,然後接續教學與開發。

---

## 0. 給接手 agent 的話(先看這段)

- 你在接手一個 **「教學 + 開發」** 的 session。開發者 = **Harvey,Godot 新手**。
- **務必遵守 `CLAUDE.md` 的 Learning Mode 協定**:這是複雜任務(新增功能),
  **不要直接用 Edit/Write 改他的 `.gd`**;把程式碼**貼在對話裡當範本**,讓他自己打、自己填,你在旁邊修。
  唯一可動檔案系統的是「建立空白檔/資料夾」那一步(見 §8)。
- 一律 **繁體中文** 回覆。引擎 **Godot 4.5**,語言 **GDScript**。
- 系統選單/操作說明請給 **English(中文)雙語**,因為繁中 Godot 介面中英混雜,
  他照其中一個找得到就行。
- 收尾時用**一個**理解題驗證他是真懂(見 §7),答錯就換個方式再講,別跳過。

---

## 1. 目前進度(上一個 session 已完成)

- **Code review 清理**:刪掉死檔 `cardManger3D.gd`、`play_card()` 封裝出牌、
  `@export` 注入 `player_hand`、型別補齊。已用 headless Godot 驗證可跑。
- **README 重寫** + 新增完整「遊戲規則設計規格 (Gameplay Spec)」章節(規格的單一事實來源)。
- 環境腳本與水面 shader 補上新手向中文註解。

> ⚠️ **Harvey 回家前請務必**:`git add -A && git commit && git push`。
> 家裡那台 `git pull` 後才看得到上面所有變更與本筆記。
> 特別注意:`scenes/main.tscn` 的 `CardManger` 節點那行有
> `node_paths=PackedStringArray("player_hand")` —— 這是 `@export` 節點注入能解析的關鍵,**別弄丟**。

---

## 2. 這次的決定:先做「最小 CardData」(Route A)

Harvey 本來想先做「發牌動畫」(README 待辦 #2),但我們決定**先做卡片資料系統**(待辦 #1),理由:

- 場上每張卡現在都是同一張 `NewCard.png`,**沒有 Cost / ATK / HP / 名稱** —— 是「空殼」。
- 整份 Gameplay Spec(魔力、召喚、戰鬥)全都建立在「卡有數值」之上,**現在全做不出來**。
- 先鋪資料地基 → 解鎖最多後續工作;發牌動畫接在它後面,還能「翻牌露出真實數值」,更有料。

可遷移原則:**先解鎖「擋住最多後續工作」的東西,再做拋光 (juice)。別在空殼上做動畫。**

---

## 3. ★必須幫他守住的觀念★(別讓他走回頭路)

Harvey 卡住的真正原因是一個**美術誤會**:他以為「每種數值組合都要一張完整卡 PNG」→
排列組合爆炸 → 結論是「要花錢買美術」。**這是錯的,接手後要持續幫他守住正確觀念。**

**真相:數字不是畫進圖裡的。** 一張卡 = 疊起來的三層:

```
① 卡框 (frame)   ← 1 張就好,所有卡共用(border + 中間挖空 + 下方描述留白)
② 卡圖 (art)     ← 每張卡一張,放進挖空處的生物圖
③ 名字/數字       ← 用 Label3D「即時印上去」,資料來自 CardData(不是圖!)
```

這一刀下去,他的三個難點同時消失:

| 他的擔心 | 真相 |
|---|---|
| Cost/ATK/HP 排列組合爆炸 | 不會。數字是文字節點,**1 張卡框**就能套上百張卡的數值 |
| 中間挖空 + 下面留白要專業美術 | 那只是**卡框模板**,只要 1 張;描述欄是 `RichTextLabel`,不是圖 |

- 他**已經有卡框素材**:`assets/ui/card_frames/`(`base 11.png` 就在裡面)。
- **`https://ultimatetcgcm.com/`**:是 One Piece TCG「卡片製作器」,匯出**把數字烤進去的完整 PNG**
  (免費版只能下 1 張,Pro $5/月)。→ 適合**實體桌遊列印**,**不適合數位版**
  (會把該當資料的數字烤死在圖裡,走回排列組合地獄)。**數位版要「框 + 即時文字」。**

> 🧠 原則:**會變的(數字/文字/狀態)= 資料 + 文字節點;不變的外觀 = 圖。永遠別把會變的值烤進圖。**

---

## 4. 美術便宜路線(現在零美術也能做完整功能)

- **卡框(1 張共用)**:程式美術(色塊 + Label3D 拼)/ [Kenney.nl](https://kenney.nl) CC0 / 他已有的 `card_frames/`。
- **卡圖(每卡一張)**:[game-icons.net](https://game-icons.net)(CC 授權)/ AI 只生成生物圖 / 原型先放純色佔位塊。

原型階段建議:**先用程式美術 + Label3D 把功能做完**,之後再換漂亮素材(因為資料與視覺已分離,換圖不動邏輯)。

---

## 5. 架構

```
src/card/
├── card.gd          (既有) 場上卡片:視覺+互動  ← 幫它加 setup(data) 方法
├── card.tscn        (既有)                      ← 加 Label3D 子節點顯示數值
└── card_data.gd     (新增) class_name CardData extends Resource — 一張卡的數值定義

data/cards/          (新增資料夾) 一張卡一個 .tres(在編輯器可視化編輯)
├── goblin.tres
└── knight.tres

src/deck/
└── deck.gd          (之後) 掛到現有 Deck 節點:var cards: Array[CardData] + draw()
```

**核心概念**:`CardData`(資料,`Resource`)vs `Card`(場上節點,`Node`)。
一份 CardData 可生出多個 Card 節點。資料用 Resource、場上物件用 Node。

**本步資料流(尚未做動畫)**:
`PlayerHand.draw_starting_hand()` → 拿一份 `CardData` → 生成 `Card` → `card.setup(data)` → 卡面顯示該卡。

---

## 6. 步驟(4 階段;選單給 English(中文) 雙語)

### 階段 1:建立 `CardData` 資料類別

1. **FileSystem(檔案系統)** 面板 → 對 `src/card/` 右鍵 → **Create New(建立新的)→ Script…(腳本…)**。
2. **Inherits/繼承** 填 `Resource`、檔名 `card_data.gd`。
3. 範本(讓 Harvey 自己打、理解每一行):

```gdscript
## card_data.gd — 一張卡的「資料定義」。純數值,不在場上跑邏輯。
## extends Resource → 它是「資料容器」,可存成 .tres 在 Inspector 編輯。
extends Resource
class_name CardData   ## 註冊全域型別,Inspector 才認得這個資源類型

@export var card_name: String = "未命名"   ## 卡名
@export var cost: int = 1                  ## 召喚魔力(規格 Cost)
@export var atk: int = 1                   ## 攻擊力
@export var hp: int = 1                    ## 生命值
@export var art: Texture2D                 ## 卡圖(放挖空處的生物圖)
```

> 為什麼 `@export`?這樣欄位才會**出現在 Inspector**,做 .tres 時能拖拉填值。

### 階段 2:建立卡資料 `.tres`(一張卡一個檔)

1. 根目錄右鍵 → **Create New → Folder(資料夾)** → 建 `data`,內再建 `cards`(即 `data/cards/`)。
2. 對 `data/cards/` 右鍵 → **Create New(建立新的)→ Resource…(資源…)**。
3. 對話框搜尋 **`CardData`** → 選它 → **Create**。
4. 在 **Inspector(屬性/檢視面板,右側)** 填數值(如 `card_name=哥布林, cost=1, atk=2, hp=1`),把卡圖拖進 `art`。
5. **Ctrl+S** 存成 `goblin.tres`。重複做 2~3 張。

### 階段 3:卡片顯示資料(加 Label3D + `setup()`)

1. 開 `src/card/card.tscn`,在 **Scene(場景)** 選根節點 `Card`,**Ctrl+A**(**Add Child Node / 新增子節點**)
   加 **`Label3D`**,命名 `CostLabel`;同法加 `AtkLabel`、`HpLabel`、`NameLabel`,擺到卡框對應位置。
2. 在 `card.gd` 加 `setup()`(範本,Harvey 自己打):

```gdscript
## 由發牌端呼叫,把一份 CardData 套到這張卡的外觀上。
@export var data: CardData   ## 這張卡「是哪張卡」

func setup(card_data: CardData) -> void:
	data = card_data
	$CardImage.texture = data.art          ## 換卡面圖(Sprite3D 子節點叫 CardImage)
	$NameLabel.text = data.card_name
	$CostLabel.text = str(data.cost)        ## 數字要 str() 轉成字串,Label 才吃
	$AtkLabel.text = str(data.atk)
	$HpLabel.text = str(data.hp)
```

> 重點:`Label3D` 只吃**字串**,所以 `int` 要 `str()` 轉。

### 階段 4:驗證

暫時在 `player_hand.gd` 的 `draw_starting_hand()` 生成卡後呼叫 `card.setup(...)`
(先 `preload("res://data/cards/goblin.tres")` 硬塞測試),按 ▶ 跑 `scenes/main.tscn`,
手牌應出現**不同數值的卡**,而非 5 張一樣的圖。看到了就成功;之後再把 `Deck` 改成
真正的 `Array[CardData]` 並做發牌。

---

## 7. 待辦的理解檢查(接手 agent:進階段 1 前先問他這題)

> **「如果今天要新增一張『火球術:5 費、8 攻、2 血』,在這套架構下你要做什麼、不用做什麼?
> 你會碰到圖嗎?會改 `card.gd` 嗎?」**

**期望答案**:不用碰任何卡框圖、不用改 `card.gd` 的邏輯(`setup()` 已通用),
只要**新增一個 `fireball.tres`、填數值、(可選)指定一張卡圖**即可。
若他答得出「資料變、程式不變」,代表資料/視覺分離的觀念通了 → 才進階段 1。
答錯就回 §3 換個方式再講。

---

## 8. 接手後的第一個動作

在 Harvey 確認理解(§7)後,你**唯一可動檔案系統的動作**:
建立空白檔 `src/card/card_data.gd`(只建空檔,內容讓他照 §6 階段 1 範本自己打)。
之後回到「他打 → 貼回來 → 你修」的節奏,逐階段推進。
