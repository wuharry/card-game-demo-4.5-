# CardGame Demo (Godot 4.7)

3D 卡牌遊戲原型，走 HD-2D 風格。實作卡片拖曳、懸停放大、爐石式扇形手牌、卡槽放置、
CardData 資料層（24 張卡、隨機發牌）、卡圖挖空窗與遊戲王式召喚立牌，
以及主選單（歧路旅人式介面）與多張程序生成戰場（森林 / 洞窟 / 冰原隨機輪替，城鎮作主選單背景）。

- 引擎：Godot **4.7**，算繪器 **Forward+**（bloom / SSAO / SSR / 霧；後製集中在各戰場場景的 WorldEnvironment）
- 進入點：`scenes/main_menu.tscn`（主選單）→「開始遊戲」→ `scenes/main.tscn`（牌桌）

> 📖 **遊戲規則設計規格**請見下方「[遊戲規則設計規格 (Gameplay Spec)](#-遊戲規則設計規格-gameplay-spec)」。
> 該章節由桌遊原型規則整理而來，作為 PC / Mobile 版實作的**單一事實來源 (single source of truth)**。
> 當桌遊與數位版規則衝突時，**以本 README 的規格為準**。

---

## 架構圖

```
main.tscn  ← 牌桌主場景 (MainScene, Node3D)  [src/main_scene/main_scene.gd]
│   (進入點是 main_menu.tscn 主選單；開始遊戲後切到這裡。
│    _ready 依 ArenaPool 抽籤抽換戰場——場景裡烤死的預設是森林)
│
├── CardManger (Node3D)              [src/card_manager/card_manager.gd]
│   └── 全場互動中樞：
│       ├── 3D 射線拖曳 (Plane 投影法)
│       ├── hover 動畫 dispatch (同時只放大一張)
│       ├── 雙層射線：卡片(Layer 1) / 卡槽(Layer 2)
│       └── 出牌判定 → 入槽 or 退回手牌
│
├── CameraRig / Camera3D            (攝影機)
│
├── PlayerHand (Node3D)            [src/play_hand/player_hand.gd]
│   └── 起手抽牌 + 爐石式扇形排列 + 出牌後靠攏；
│       同時是每張卡 hover 信號的「中繼站」轉發給 CardManager
│
├── PlayerBoard / EnemyBoard       [src/player_board/player_board.gd]
│   └── 程序生成 5 欄 × 2 排 = 10 個 CardSlot；
│       依 is_enemy 決定遠/近端，並加入群組
│       (player_front / player_back / enemy_front / enemy_back)
│
├── Deck (Node3D)                  牌堆視覺（8 張卡背 Sprite3D 疊放於玩家右側）
│
└── Arena_Forest (arena_forest.tscn)  森林戰場
    ├── GridMap (ground_generator)  [src/environment/ground_generator.gd]
    │                               噪聲程序鋪地：純草為底、泥土成簇
    ├── Props/ForestScatter         [src/environment/forest_scatter.gd]
    │                               程序散佈 PSX 樹/灌木（成簇、內圈淨空）
    │                               ＋地景小物（草叢/石頭/枯木）＋遠景土丘
    ├── Stream (MeshInstance3D)     風格化溪流中線（stream_water.gdshader）
    ├── WorldEnvironment            ACES tonemap + bloom + SSAO + 暖色氛圍
    └── DirectionalLight3D          柔和陽光
```

> 戰場家族：`arena_caverns` / `arena_frostlands`（隨機輪替）與 `arena_town`（主選單背景）皆為程式生成，
> 共用底盤在 [src/environment/arena_base.gd](src/environment/arena_base.gd)（場景繼承：共用邏輯放基底、各自長相放子類）；
> 抽籤桶 [src/environment/arena_pool.gd](src/environment/arena_pool.gd) 以 static 類別跨場景傳路徑（維持「無 autoload」慣例）。

> 一張卡片 (`src/card/card.tscn`) 內部結構：
> `Card (Node3D)` → `CardFrame (Sprite3D, 卡框)` + `CardArt (Sprite3D, 嵌入卡框挖空窗)`
> + `NameLabel / CostLabel / ATKLabel / HPLabel (Label3D, 數值即時印上)` + `Area3D/CollisionShape3D (滑鼠偵測)`。
> 數值與卡圖由 `setup(CardData)` 餵入——資料變、程式不變。

---

## 檔案說明

### GDScript

| 檔案 | 說明 |
|------|------|
| [src/card/card.gd](src/card/card.gd) | 一張卡片的「大腦」。發射 hover 信號；`setup(CardData)` 把資料套到 Label3D 與卡圖（卡框挖空窗定位、掃描立牌第 0 幀可見範圍裁切放大）；召喚立牌（standee 待機動畫，與卡圖共用同一套可見範圍掃描）；hover 動畫與鎖定 |
| [src/card/card_data.gd](src/card/card_data.gd) | `CardData`（Resource）：卡名 / cost / atk / hp / 立牌動畫表。純資料不進場景樹；一份資料可生多張場上 Card；24 張 `.tres` 在 `data/cards/` |
| [src/card_manager/card_manager.gd](src/card_manager/card_manager.gd) | 全場互動中樞。Plane 投影法拖曳；雙層射線偵測卡片(Layer 1)/卡槽(Layer 2)；出牌判定並協調 Card / CardSlot / PlayerHand 三方 |
| [src/play_hand/player_hand.gd](src/play_hand/player_hand.gd) | 玩家手牌。`@tool` 可在編輯器預覽；`draw_starting_hand()` 起手抽牌、`_arrange_fan()` 排成圓弧扇形、`organize_hand()` 出牌後靠攏；hover 信號中繼站 |
| [src/card_slot/card_slot.gd](src/card_slot/card_slot.gd) | 桌面卡槽 (Area3D)。記錄 `is_empty` / `card_in_slot`；`place_card()` 入槽吸附+鎖定、`remove_card()` 取回、`highlight()` / `unhighlight()` 高亮提示 |
| [src/player_board/player_board.gd](src/player_board/player_board.gd) | 棋盤生成器。5 欄 × 2 排自動置中；依 `is_enemy` 擺位並加入群組 |
| [src/environment/ground_generator.gd](src/environment/ground_generator.gd) | `@tool` GridMap 噪聲鋪地：純草為底、泥土依噪聲成簇、邊緣草泥過渡磚、每格隨機朝向 |
| [src/environment/forest_scatter.gd](src/environment/forest_scatter.gd) | `@tool` 程序散佈 PSX 樹/灌木：成簇分布、內圈與前方淨空、生成時補上 alpha 鏤空雙面材質；另散佈草原地景小物（草叢/石頭/枯木，薄片模型自動十字交叉）與遠景土丘（landmass 埋地只露丘頂） |
| [src/environment/arena_base.gd](src/environment/arena_base.gd) | `@tool` 程式生成戰場的共用底盤（清場、散佈數學、材質快取、淨空區）；Caverns / Frostlands / Town 繼承它並在 `_build()` 實作各自長相 |
| [src/environment/arena_pool.gd](src/environment/arena_pool.gd) | 戰場抽籤桶（static 純工具，不進場景樹）：主選單抽路徑 → `main_scene.gd` 讀取決定換不換環境 |
| [src/main_scene/main_scene.gd](src/main_scene/main_scene.gd) | 牌桌環境切換器：依 ArenaPool 抽籤結果，`_ready` 時把烤死的森林換成抽到的戰場（用 `free()` 避免兩個 WorldEnvironment 並存） |
| [src/main_menu/main_menu.gd](src/main_menu/main_menu.gd) | 主選單：3D 城鎮背景 + 固定鏡頭 + 歧路旅人式純文字選單（UI 全由程式組裝，CanvasLayer 疊在 3D 上） |
| [src/settings/app_settings.gd](src/settings/app_settings.gd) | 全域設定 Autoload：`user://settings.cfg` 持久化、視窗／全螢幕、解析度、三檔畫質、繁中／英文 UI 與無障礙參數 |
| [src/settings/settings_panel.gd](src/settings/settings_panel.gd) | 主選單設定疊層：套用／取消／恢復預設，大字模式可捲動且鍵盤焦點會自動跟隨 |
| [src/battle_ui/battle_ui.gd](src/battle_ui/battle_ui.gd) | 指令選單（歧路旅人式）：點擊上桌單位 → 攻擊/技能/取消 + 效果描述列；指定目標時出提示字；戰況 HUD（回合/魔力/結束回合/提示訊息）。全程式生成，由 CardManager 掛載並訂閱信號 |
| [src/battle_manager/battle_manager.gd](src/battle_manager/battle_manager.gd) | 戰鬥帳房：魔力/回合/行動經濟（§1/§3/§6）與真結算（§4.2 雙向傷害交換、死亡清位、打臉與路線阻擋 §4.1、勝負判定）。訂閱 `CardManager.action_performed`；規則只寫這一份，UI 轉述 |
| [src/hero/hero.gd](src/hero/hero.gd) | 本體（玩家/敵方的「臉」）：像素立牌呈現（同卡牌角色、無卡槽）、HP 20、受擊/死亡動畫；程式生成、站位由卡槽群組實際位置推算 |
| [src/card/skill_data.gd](src/card/skill_data.gd) | `SkillData`（Resource）：主動技能的資料定義（類別/費用/動畫表/效果參數），設計明細見 [docs/skills_design.md](docs/skills_design.md) |
| [src/grave_pile/grave_pile.gd](src/grave_pile/grave_pile.gd) | 墓地/棄牌堆（一側一座，純視覺）：底座＋張數＋最後入土那張卡；投放區掛第 4 層，拖手牌到上面＝丟牌回魔（§1.1）；帳在 BattleManager 的 `SideState.grave` |

### 場景

| 檔案 | 說明 |
|------|------|
| [scenes/main_menu.tscn](scenes/main_menu.tscn) | **遊戲進入點**：主選單（內容由 `main_menu.gd` 程式組裝） |
| [scenes/main.tscn](scenes/main.tscn) | 牌桌主場景：CardManger + 攝影機 + 雙棋盤 + 手牌 + 牌堆 + 戰場 |
| [scenes/arena_forest.tscn](scenes/arena_forest.tscn) | 森林戰場（預設）：程序地板 + 森林散佈 + 溪流 + 燈光環境 |
| [scenes/arena_caverns.tscn](scenes/arena_caverns.tscn) / [scenes/arena_frostlands.tscn](scenes/arena_frostlands.tscn) | 洞窟 / 冰原戰場（繼承 ArenaBase 程式生成，進牌桌時隨機輪替） |
| [scenes/arena_town.tscn](scenes/arena_town.tscn) | 黃昏城鎮廣場（主選單背景） |
| [src/card/card.tscn](src/card/card.tscn) | 可實例化的 3D 卡片預製件（卡面用 `NewCard_fixed.png`）|
| [src/card_slot/card_slot.tscn](src/card_slot/card_slot.tscn) | 可實例化的 3D 卡槽預製件（卡槽外觀由 `slot_tile.gdshader` 程序生成）|
| [src/player_board/player_board.tscn](src/player_board/player_board.tscn) | 棋盤場景，`@export card_slot_scene` 指向 `card_slot.tscn` |

### 美術資源

| 路徑 | 用途 |
|------|------|
| `NewCard_fixed.png` | 目前卡框圖（已清除白色 matte，上半透明窗由 CardArt 遮罩填入）|
| `data/cards/*.tres` | 24 張 CardData 卡片資料（名稱 / 費用 / 攻血 / 立牌動畫表）|
| `assets/packs/tiny_rpg_characters` | 像素角色動畫表（卡圖取第 0 幀、召喚立牌播待機動畫）|
| `assets/packs/pixel3d_{caverns,frostlands,town}` | 洞窟 / 冰原 / 城鎮 像素 3D 環境素材包（第三方素材包統一收 `assets/packs/`，資料夾 snake_case、包內保留原始結構利於對照授權） |
| `assets/ui/card_frames/` | 卡槽外框圖（card_slot.tscn 使用）|
| `assets/mesh_libraries/grasslands/grassland_tiles.meshlib` | GridMap 地板格子（arena_forest 使用）|
| `assets/environment/psx_trees/` | PSX 樹/灌木 FBX 模型與貼圖（forest_scatter 使用）|
| `assets/terrain/pixel_3d_grasslands/` | 草原地景小物（草叢/石頭/枯木）與遠景土丘 landmass（forest_scatter 使用；UV 對到 `tilesheets/Updated_Sheets`）|
| `assets/water/stream_water.gdshader` | 溪流水面 shader（波紋法線 + 反射）|
| `assets/water/psx_ocean_surface/` | 水面貼圖 |
| `assets/fonts/` | 思源宋體 Noto Serif TC（標題/選單）＋ Playpen Sans（英文小字），主選單使用（皆 SIL OFL 授權可商用）|

---

## 碰撞層規則

| Layer | 名稱 | 用途 |
|-------|------|------|
| 1 | `Card` | 卡片 Area3D，供拖曳射線偵測 |
| 2 | `CardSlot` | 卡槽 Area3D，供放置射線偵測 |

---

# 🎮 遊戲規則設計規格 (Gameplay Spec)

> 來源：桌遊原型規則整理。本章節為數位版實作的權威參考。
> 標註 `[桌遊]` 者為實體限制，數位版可放寬；標註 `[數位調整]` 者為 PC/Mobile 專屬設計。

## 1. 勝負與資源

| 項目 | 規則 |
|------|------|
| 勝利條件 | 將對手玩家生命值由 **20** 降至 **0** |
| 玩家初始 HP | 20 |
| 魔力上限 | 起始 0，每回合開始 +1（上限 7），並回滿至上限 |
| 魔力累積 | 未使用魔力**不**保留到下回合 |
| 手牌上限 | **8**：手牌滿時抽到的牌**直接銷毀**（爆牌，雙方可見；同爐石／暗影詩章。棄牌價值另有 §1.1 丟牌回魔） |
| 牌堆 | **60 張**／副，同名卡最多 **3** 份（現階段由 120 種卡隨機組成；抽空後不再抽、無疲勞傷害） |

### 1.1 丟牌回魔（含冷卻）`[數位調整]`

- 抽牌後，可捨棄 1 張手牌，獲得「該牌 Cost ÷ 2（無條件捨去）」的**暫時魔力**。
- **冷卻：使用後下一回合不可再用**（最多隔回合一次）。
- 9–13 費高階卡必須靠這個機制跨越自然魔力上限：9／10／11／12／13 費分別至少要棄掉 4／6／8／10／12 費卡。
- ✅ **已實作（2026-07-16）**：把手牌**拖到墓地**放開＝棄牌（任何卡型皆可）；帳在 `battle_manager.gd` 的 `apply_discard_for_mana()`，UX 與同步在 `card_manager.gd` 的 `_try_discard` / `_net_discard`（連線/單人 AI 走同一條重放路）。
- 實作註記：`SideState.discard_cd` 使用時設 **2**、**自己**回合開始 `max(0, cd - 1)`、`cd == 0` 才允許——設 1 會在下一個自己回合就歸零，變成「每回合都能用」，違反「下一回合不可再用」。（早期草稿的 `=1` 寫法是 off-by-one，勿沿用。）

## 2. 戰場與路線

- 戰場為 **5 條並排路線 (Lane)**，雙方一對一對應（路線 1–5）。
- 每條路線可有：前排從者（可被攻擊/阻擋）+ 其附著的靈裝 / 伏印。
- `[桌遊]` 桌面只有 10 格卡槽；後排（伏印）以皮製卡盒直立卡位呈現，對手看不到內容。
- `[數位調整]` 伏印**不佔卡槽**，住在 `SideState.wards` 側帳（宿主制：埋在我方場上從者底下）。

> ⚠ **後排卡槽站得了從者**（2026-08-10 訂正）：早期這段寫「後排＝伏印區」，但實作上
> `player_back` / `enemy_back` 是真的卡槽，前排滿了就往後放（`enemy_ai.gd` 的落點順序即如此）。
> 規則上的差別只有兩點：**後排不當阻擋**（`_lane_blocked` 只看前排），
> 但**打得到**——【貫穿】的第二目標就是同路線的後排單位。

## 3. 召喚

| 召喚方式 | 規則 |
|----------|------|
| 一般召喚 | 支付卡牌 Cost |
| 獻祭召喚 | `被獻祭單位 Sacrifice + 剩餘魔力 ≥ 目標 Cost`，獻祭場上 1 張從者補差額 |
| 捨棄召喚 | 依卡面捨棄手牌；捨棄牌依 Cost ÷ 2 回流魔力 |

**被獻祭單位需同時滿足**：本回合①未受過攻擊 ②未攻擊 ③未發動主動效果 ④`HP > floor(MaxHP / 2)`。

**召喚暈眩**：從者被召喚當回合不能攻擊（除非具【衝鋒】）。技能是否可發動見 §6。

## 4. 攻擊與戰鬥結算

### 4.1 攻擊範圍 `[數位調整]`

> **架構決策**：預設維持「直線攻擊」，但保留 `attack_range` 作為**少數特殊單位**的屬性。
> 大多數單位 `range = LANE_ONLY`，避免遊戲從「站位」變成「網格戰棋」。

```gdscript
enum AttackRange {
    LANE_ONLY,   # 預設：只能打正前方同路線
    SPREAD_3,    # 廣域：前左 / 前中 / 前右 三格
    BACKLINE,    # 遠程：可越過前排打後排
}
```

- 預設所有從者為 `LANE_ONLY`，維持核心識別。
- 若該路線正前方無敵方阻擋，則直接攻擊對方玩家 (Face)。
- 從者**不可移動**，除非具【換位】（移至相鄰路線）或【突進】（移至任意空路線）。

### 4.2 雙向傷害交換

數值結構只有 ATK / HP，**ATK 同時是攻擊力與反擊力**（與爐石相同模型）。

- 從者 A (ATK 5/HP 4) 攻擊 從者 B (ATK 3/HP 6)：
  1. A 對 B 造成 5 → B 剩 1 HP
  2. B 反擊 A 造成 3 → A 剩 1 HP
  3. 兩者**同時結算**
- **攻擊玩家 (Face) 不受反擊**；雙向交換只發生在從者之間。

## 5. 回合流程

```
開始階段（魔力 +1 回滿、解除凍結等狀態、tick 狀態效果、回合開始效果、冷卻 -1）
  → 抽牌階段（抽 1）
  → 丟牌回魔（可選，需冷卻就緒）
  → 主要階段（召喚、附靈裝、埋伏印、發動非攻擊技能）
  → 攻擊階段（逐次攻擊 / 秘術 / 從者效果，走 §5.1 反制流程）
  → 結束階段（tick 狀態效果、回合結束效果、勝負檢查）
```

### 5.1 攻擊反制流程（每次宣告 6 步）

```
STEP 1 宣告        攻方指定攻擊者與目標（或施放秘術 / 發動效果），支付費用
STEP 2 守方瞬咒    守方可發動 1 張瞬咒回應 → 立即結算（後發先解，通常用於抵銷）
STEP 3 守方伏印    被指定的從者若埋有伏印，守方可翻開 → 立即結算
STEP 4 結算        若未被抵銷，進行雙向傷害交換 (§4.2)
STEP 5 攻方伏印    若守方效果指定了攻方從者且其埋有伏印，攻方可翻開；
                   守方若仍有魔力可再以瞬咒回應 → 結算
STEP 6 清算        移除陣亡從者、處理死亡觸發 → 回到 STEP 1 或結束攻擊階段
```

> `[桌遊]` 簡化原則：同一次宣告中，每位玩家最多回應 1 張瞬咒、每張被指定從者最多翻 1 張伏印。
> `[數位調整]` 數位版可改用完整 Stack (LIFO) 實作無限回應鏈，但 MVP 階段建議先沿用桌遊簡化版。

## 6. 從者技能與行動規則

**行動分離**：每個從者每回合有「1 次攻擊」+「1 次主動技能」，預設**獨立計算、可各用一次**。

攻擊型技能依與攻擊的互動分三類：

| 標籤 | 規則 | 召喚當回合 |
|------|------|-----------|
| 【強化攻擊】 | 改變本次攻擊性質，發動即消耗本回合攻擊 | 可發動技能，但仍不能攻擊 |
| 【獨立攻擊】 | 額外一次攻擊，不佔用普通攻擊 | 不可使用（視同攻擊） |
| 【非攻擊】 | 與攻擊無關（治療/增益/控場），可自由額外用 | 可發動 |

> 設計理由：例「噴火（ATK+10 後攻擊）」屬【強化攻擊】，用了就是這回合的攻擊；「治療」屬【非攻擊】，治療完仍可普攻。

### 6.1 動畫驅動技能（Animation-Driven Skills）`[數位調整]`

> 素材包每隻角色自帶多張攻擊動畫表，技能系統直接以動畫為錨：**看得到的動作 = 用得到的招**。

| 動畫表 | 對應行動 | 費用 |
|---|---|---|
| `Attack01` | **普通攻擊**（§4 雙向傷害交換） | **免費**，每回合 1 次 |
| `Attack02` | **主動技能**（預設；個別單位可指定專屬表，如牧師 `Heal`、死靈法師 `Summon`） | 消耗魔力（卡面標示） |
| `Attack03` | 保留欄位（升級技 / 進化用，暫不啟用） | — |
| `Block` | 被動【鐵壁】/ 守護觸發的受擊動畫 | — |
| `Summon` | 登場動畫；骷髏家族兼【不滅】復活動畫 | — |

- 主動技能歸類沿用 §6 三分類（強化攻擊 / 獨立攻擊 / 非攻擊），行動經濟不變：每回合 1 攻擊 + 1 技能。
- 沒有第二張攻擊表的單位（骷髏弓手）＝ 無主動技，靠被動與數值補（白板堆料）。
- 資料結構在 [src/card/skill_data.gd](src/card/skill_data.gd)（`CardData.active_skill` / `battlecry` / `keywords`）。
  **42 張從者的現行配置以 [docs/card_rebalance_pack01_02.md](docs/card_rebalance_pack01_02.md) 為準**
  （2026-08-10 對齊 Pack01/02 設計稿）；[docs/skills_design.md](docs/skills_design.md) 的 24 卡表已被它取代，
  該檔仍有效的是**動畫盤點與命名地雷**那兩節。
- **戰吼（登場效果）** `[數位調整]`：`CardData.battlecry` 是一份 `SkillData`，召喚落地時自動結算一次。
  不收魔力、不佔「每回合 1 攻擊 + 1 技能」的行動經濟——它不是玩家的選擇，是卡的登場條款。
  觸發點在 `BattleManager.mark_summoned()`（所有召喚的必經之路：手動出牌／召喚技／召喚秘術／連線重放），
  且**先於伏印結算**（否則「登場就有盾」在最需要它的那一刻剛好還沒生效）。

## 7. 卡牌類型

| 類型 | 說明 | 可用時機 |
|------|------|---------|
| 從者卡 | 場上戰鬥單位，有 ATK/HP，可搭載靈裝 | 主要階段召喚 |
| 靈裝卡 | 附著從者的裝備，持續加成；宿主離場通常一併離場 | 主要階段 |
| 秘術卡 | 主動法術，結算後離場 | **僅攻方、自己回合** |
| 瞬咒卡 | 反應法術，抵銷對方秘術 / 伏印 | **僅守方、反制窗口** |
| 伏印卡 | 蓋放的陷阱，條件觸發 | 埋設於主要階段 |
| 領域卡 | 影響全場的環境卡 | ⚠️ **尚未完工，本版不使用** |

從者四數值：`Cost`（召喚魔力）/ `Sacrifice`（獻祭可提供魔力）/ `ATK` / `HP`。

## 8. 關鍵字能力

| 關鍵字 | 效果 |
|--------|------|
| 衝鋒 | 召喚當回合即可攻擊（無視召喚暈眩） |
| **嘲諷** | **見 §8.1（已為路線制重新定義）** |
| 潛行 | 無法被秘術 / 瞬咒指定 |
| 飛行 | 攻擊時無視該路線阻擋，可直擊玩家 |
| 不滅 | 首次陣亡時以指定 HP 復活（每場一次） |
| 換位 | 可移至相鄰路線 |
| 突進 | 可移至任意空路線 |
| 沉默 | 無法觸發任何技能 |
| **鐵壁** `[數位調整]` | 每回合首次受到的從者攻擊傷害 −1（觸發時播 `Block` 動畫；僅配給有格擋動畫的單位） |

### 8.1 嘲諷：守護型重定義 `[數位調整]`

> **為什麼要改**：爐石嘲諷依賴「攻方能自由選目標」，但本作是直線攻擊——同路線本來就會先打到前排，
> 「逼你打我」在同路線已內建。純路線下，嘲諷真正缺的是**跨路線保護**。

**預設規則（守護型）**：嘲諷單位除了守住自己的路線，**額外「守護」左右相鄰路線**。
若相鄰路線無阻擋（攻擊本會打 Face），該攻擊**改為指向此嘲諷單位**。

- 平衡閥門（擇一）：①每回合只守護一次 ②只守護單側 ③守護時嘲諷單位受到的傷害 +1。
- 與 `attack_range` 互動：若攻方為 `SPREAD_3` 等多目標，其攻擊範圍涵蓋嘲諷路線時必須優先指定嘲諷單位。

**替代方案（記錄備查，未採用）**：
- 方案 B｜全面攻擊範圍系統：所有單位都有 range，嘲諷＝範圍涵蓋者必須先打它。深度高但複雜度大。
- 方案 C｜以「掩護」（相鄰友軍不可被指定）或「格擋」（相鄰友軍傷害轉移到我）取代嘲諷。

## 9. 狀態效果

> 實作建議：用統一資料結構承載，集中在回合的 tick 點處理。

```gdscript
class StatusEffect:
    var type: StatusType         # BURN / FREEZE / POISON / ...
    var turns_left: int          # 剩餘回合
    var tick_start: bool         # 回合開始是否扣血
    var tick_end: bool           # 回合結束是否扣血
    var dmg_per_tick: int        # 每次 tick 傷害
```

| 狀態 | 類型 | 效果 | 持續 | tick 時機 | 互斥 |
|------|------|------|------|----------|------|
| **灼燒 Burn** | 減益 | 每次 tick **-1 HP**（開始+結束 = 每回合 2 點） | **預設 1，最多 2 回合**（< 3） | 回合**開始 + 結束** | ⚔ 與凍結互斥 |
| **凍結 Freeze** | 減益 | 無法攻擊 / 發動主動技能 | < 3 回合 | — | ⚔ 與灼燒互斥 |
| **中毒 Poison** | 減益 | 每回合 -1 HP（取代舊「凋零」） | **預設 3 回合，可更高**（必 > 灼燒） | 回合**結束**一次 | — |
| 夜幕 | 增益 | 下回合首次受到的傷害減半 | 1 回合 | — | — |
| 鍛強 | 增益 | ATK +2 | 2 回合 | — | — |
| **衰弱** `[數位調整]` | 減益 | ATK −1(夾在 0 以上) | 依卡面 | — | — |

> **衰弱的由來**:卡池設計稿有「防禦力 −1」「攻擊力 −1」兩種寫法,但 §4.2 的數值結構只有
> ATK/HP。與其為了一個減益開第三個數值(卡面、HUD、AI 評估、連線同步全要動),
> 一律收斂成 ATK −1。鍛強與衰弱**不互斥**(只有灼燒/凍結互斥),同時在身上就是淨 +1。

### 9.3 護盾 `[數位調整]`

**護盾不是狀態,是單位身上的一層「暫時 HP」**——沒有回合數、不會自然消退,吸完為止。
之所以不塞進上面那張狀態表:狀態靠 `turns_left` 遞減,護盾靠被打才減少,tick 的時機完全不同。

**在傷害管線的位置(順序是規則的一部分)**:

```
夜幕減半 → 鐵壁 −1 → 護盾吸收 → 扣 HP
```

減免**先**做、吸收**後**做。反過來排不會報錯,只會讓數值默默不對:
10 點傷害打在「3 盾 + 夜幕 + 鐵壁」的單位上,盾先吸只擋下 7 點(掉 3 血),盾後吸擋下 9 點(掉 1 血)。
通則:**每一層減免都要作用在「還沒被盾墊掉」的完整數字上**,兩層才都拿到最大價值。

- 護盾擋掉的部分**不算「實際傷害」**:吸血回的是真正扣掉的 HP(盾不是血,砍在盾上沒有血可吸)。
- 護盾存在**場上的單位實例**(`Card.shield`),不寫回共享的 `CardData`——寫回去會讓全場同名卡共用一面盾。
- 卡面狀態列以 `盾N` 顯示，排在其他狀態之前（「還能擋幾點」比「減益剩幾回合」更影響當下決策）。
  刻意不用 🛡 符號：專案字型 Noto Serif TC 不含 emoji 區段，貼上去是豆腐框。

### 9.1 灼燒 / 凍結互斥規則（火融冰、冰滅火）`[數位調整]`

兩者不可共存。施加新狀態時，若目標已有互斥狀態，則**移除舊狀態**而非疊加：

```gdscript
func apply_burn(unit, turns := 1) -> void:
    unit.remove_status(StatusType.FREEZE)        # 火融冰：先解凍
    unit.add_status(StatusType.BURN, turns)

func apply_freeze(unit, turns := 1) -> void:
    unit.remove_status(StatusType.BURN)          # 冰滅火：先滅燒
    unit.add_status(StatusType.FREEZE, turns)
```

### 9.2 設計意圖

- **灼燒**：短而猛的爆發（每回合 2 點、短回合）。`回合數刻意壓低`以免 burst 過高。
- **中毒**：長而慢的消耗（每回合 1 點、回合數長）。與灼燒形成清楚的「爆發 vs 消耗」對比軸。

---

## ✅ 已完成

**核心玩法**
- [x] 3D 卡片拖曳（攝影機射線 + Plane 投影，維持水平高度跟手）
- [x] 懸停放大動畫（全場同時只放大一張，含扇形重疊的補償射線）
- [x] 卡槽放置：吸附入槽 + 卡片轉正 + 鎖定（入槽後不可再拖）
- [x] 出牌判定：對準空槽則入槽、否則退回手牌
- [x] 爐石式扇形手牌：起手抽牌、動態張角、出牌後平滑靠攏（`organize_hand` 已實作）
- [x] 棋盤程序生成：5×2 卡槽自動置中，玩家/敵方分別擺位並分群

**資料與卡面**
- [x] CardData 資料層：Resource + 120 張 `.tres`；DirAccess 掃卡池、發牌隨機 `setup()`（資料變、程式不變）
- [x] 卡片數值 Label3D（爐石式四角配置；z=0.02 + render_priority 解決手牌/上桌兩態的深度浮埋）
- [x] 卡圖嵌入卡框挖空窗 + 遊戲王式召喚立牌（像素角色第 0 幀卡圖、入槽立牌待機動畫）
- [x] 動畫驅動技能資料層：120 卡 `active_skill` / `keywords` 全接線（[§6.1](#61-動畫驅動技能animation-driven-skills-數位調整)）；卡面顯示技能名+費用+描述
- [x] 指令選單（純演出版）：點上桌單位 → 歧路旅人式選單 → 指定目標 → 施放/受擊動畫；結算走 `action_performed` 信號留給戰鬥系統
- [x] 魔力與生命值（BattleManager）：魔力回合成長/召喚與技能費用檢查（§1/§3）、行動分離+召喚暈眩+衝鋒（§6）、雙向傷害交換與治療（§4.2）、死亡演出+卡槽清位；HUD 回合/魔力/結束回合
- [x] 戰鬥回饋：飄浮傷害/治療數字、反擊受擊動畫、受擊綁「結算」不綁「宣告」
- [x] 本體與勝負：雙方本體（像素立牌、HP 20）、打臉需路線無阻擋（§4.1）且不吃反擊（§4.2）、本體倒下 → 勝負畫面（再戰/回主選單）；本體站位 2026-07-14 改為鏡像居中（見「場景與美術」的牌桌構圖改版）
- [x] 每回合抽 1 張（§5 抽牌階段；從牌堆位置飛入手牌。隨機卡池，真 Deck 見待辦）＋敵方牌堆視覺（玩家牌堆對角鏡射）
- [x] 狀態效果全套（§9）：灼燒/凍結/中毒/夜幕/鍛強，回合 tick＋卡面狀態列；灼燒凍結互斥、先 tick 再遞減
- [x] 打法修飾（§6）：連擊/吸血（回實際傷害）/橫掃（鄰路副目標）/貫穿（後排副目標）；副目標不反擊
- [x] 關鍵字：鐵壁（首傷 -1 播 Block）、不滅（首死 1 HP 復活播 Summon）、飛行（無視阻擋打臉）、嘲諷（§8.1 守護型：擋相鄰路線打臉）＋既有衝鋒
- [x] 召喚系技能（死靈法師）：己方空槽生新單位，hover 中繼自動接回
- [x] 手牌上限 8：滿手抽牌直接燒掉（§1，爆牌制）；卡牌類型欄位預留（§7：`CardData.card_type`，非從者卡擋在卡槽外）
- [x] 真牌堆（`deck.gd`）：雙方各一副 **60 張**（同名上限 3，§1）、抽完即空、兩疊牌堆掛剩量數字
- [x] 熱座雙人（連線前置，ADR-001 後果清單完成）：雙方獨立魔力/牌堆/手牌帳（`SideState`）、回合歸屬（非行動方單位不能動、只能召喚自己那側）、結束回合＝換邊＋換手牌視圖；狀態效果改在持有者自己的回合階段 tick
- [x] 連線 2a 大廳與骨架（`src/net/`）：主選單「連線對戰」→ 大廳欄（開房顯示本機 IP／輸 IP 加入）；ENet 建線、`_start_match` 握手 RPC（host 抽牌桌廣播 index）、host=player / client=enemy 寫進 `NetMatch`；headless 雙分支 loopback 實連驗證通過
- [x] 五類卡池完成（領域不啟用）：從者 66／靈裝 5／秘術 33／瞬咒 8／伏印 8，共 120 張；非從者卡面＝圖示卡圖＋藏攻血＋卡型印章（`card.gd`）。像素圖示包歸位 `assets/ui/icons/`（Shikashi v1/v2 免署名；Antahonist **CC-BY 4.0 發佈時需掛名 "Icons by Andrey Kalyuzhnyy"**，見 [CREDITS.md](CREDITS.md)）
- [x] **9–13 費高階卡（2026-08-28）**：新增 28 張（9 費 7／10 費 6／11 費 6／12 費 6／13 費 3），包含從者、秘術、瞬咒、伏印與靈裝；自然魔力維持 7，終結卡靠丟牌回魔支付。六名新從者必有普通攻擊 `Attack01`，只有具主動技能者才另有 `Attack02`。
- [x] **法術結算層（§7）**：秘術＝拖到敵方從者即結算（宣告即付費 §5.1 STEP1、潛行不可指定 §8）；**守方瞬咒反制窗口**（施放秘術時熱座面板詢問守方，發動＝抵銷、扣守方剩餘魔力並離手）；靈裝＝拖到我方從者附著（生命上限加成記在單位節點，宿主離場隨亡）；伏印＝蓋放進側帳資料層（§2 後排、不佔格），敵方召喚從者時觸發傷害。headless 驗收 14 斷言全過
- [x] 通用命中爆點 3D 特效（`src/fx/fx_burst.gd`）：GPUParticles3D 純程式美術（emission 過 glow 門檻自動泛光），掛在 Card/Hero `take_damage` ＝所有傷害自動觸發
- [x] 匯出管線（macOS）：export preset ＋ ETC2 ASTC（Universal 必需）＋ 匯出版 headless 啟動驗證；掛名清單 [CREDITS.md](CREDITS.md)（含待查證素材區）

**場景與美術**
- [x] Forward+ 算繪 + ACES tonemap + bloom + SSAO + 暖色氛圍燈光
- [x] 程序化地板（噪聲成簇：純草為底 + 泥土斑塊 + 草泥過渡磚）
- [x] 風格化溪流戰場中線（波紋法線 + 反射）
- [x] 程序化森林散佈（成簇樹叢、內圈淨空、PSX alpha 鏤空材質）+ 地形整修（溪流凹進地形、樹木落地、地景小物散佈、遠景土丘、世界邊界推遠配霧）
- [x] 牌堆視覺（玩家右側卡背堆疊）
- [x] 主選單（歧路旅人式：3D 城鎮背景 + 固定鏡頭 + 純文字選單）
- [x] **完整設定系統（2026-08-31）**：視窗／全螢幕與 720p–1440p 解析度；低／中／高畫質實際調整 3D 渲染比例、MSAA、FXAA 與陰影圖；繁體中文／English 切換主選單、圖鑑分類、戰鬥 UI 與資料化卡牌效果；無障礙含 UI 100/125/150%、高對比、減少動態（主選單／設定面板皆可捲動與鍵盤導覽）。全部保存至 `user://settings.cfg`；`tests/settings_test.gd` 自動驗收加 720p 中英文／150% 實機截圖檢查。
- [x] 戰場家族：洞窟 / 冰原 / 城鎮（ArenaBase 繼承 + ArenaPool 隨機輪替）
- [x] 卡槽高亮著色器（鈴蘭之劍式：圓角雙框 SDF + 內緣漸層 + 拖曳懸停呼吸脈動發光；執行期掛材質、場景檔零改動）
- [x] **牌桌構圖改版（2026-07-14）**：鏡頭沿中線一眼看穿「我方本體→我方卡槽→溪流→敵方卡槽→敵方本體」，歧路旅人式斜視角（俯角 36°、fov 50，截圖 harness 迭代定案後烘進 main.tscn）；手牌壓在畫面下緣只露卡頂、面向鏡頭攤開（hand 傾 -108° 與每張卡自帶 +55° 合成後法線對準視線），hover 抬升整張浮出（爐石式，`HOVER_LIFT`）；敵方卡槽改**鏡像**（前排貼中線——修正舊版「敵方前排反而離玩家更遠」的語意顛倒，全場 mid_z 歸 0）；本體改巫師 vs 死靈法師、鏡像站各自後排正後方 2.2；溪流置中 z=0（Stream 節點/ground_generator/forest_scatter 三處同步）、岸線蜿蜒收斂（bank_jitter 0.9→0.4）保證水帶最寬 ±1.7 不進前排卡槽（槽緣 ±1.74）；forest/caverns/frostlands 與 client 翻轉視角構圖皆截圖驗證
- [x] **hover 卡片放大預覽＋卡面截斷**：hover 任何卡（手牌/桌上單位）→ 右側資訊卡（卡圖第 0 幀/名稱/費用/卡型/攻血含靈裝加成/關鍵字/技能全文，mouse_filter 全 IGNORE 不擋操作，來源卡被釋放自動收起）；卡面描述超過 5 行估算截斷加 …（全形 1/半形 0.5 字寬估算——不再壓到攻血列），全文交給預覽面板
- [x] **伏印宿主制＋裝備替換＋技能三標籤標示（2026-07-17，對齊桌遊 v0.1 試玩回饋）**：伏印改「埋設在我方場上從者底下」（拖到從者＝埋設、一格一張、宿主陣亡未觸發伏印隨葬入墓 §7 FAQ）；埋設後**我方整排卡槽紅色脈動警戒**（前後排都亮＝威懾成立：對手知道有陷阱、不知道在誰底下；訊息也不報宿主名）；靈裝**一次一件新蓋舊**（舊裝加成收回、現血夾回上限、舊卡入墓）；技能三分類（強化攻擊/獨立攻擊/非攻擊——機制與卡池早已就位）補上**卡面/指令選單/hover 預覽**的標示。`tests/ward_equip_test.gd` 13 斷言＋全測回歸
- [x] **墓地＋丟牌回魔（2026-07-16）**：所有離場的牌統一走 `BattleManager.bury()` 入土（死亡從者＋隨葬靈裝、用畢秘術/瞬咒、觸發的伏印、爆牌、棄牌）——埋點全在兩台會重放的函式裡，連線零新增同步；`GravePile` 雙墓視覺（牌堆旁、對角鏡射、躺著最後入土那張＋張數），拖手牌到墓地＝丟牌回魔（§1.1：Cost÷2 捨去、隔回合冷卻）；`tests/grave_test.gd` 14 斷言＋loopback 簽名一致。AI 也會在「棄牌後能立即解鎖更高價值行動」時使用回魔。**殘留**：墓地內容查看面板未做（現只顯示最上張與張數）
- [x] **素材整理（2026-07-16）**：第三方素材包統一收 `assets/packs/`（snake_case、包內保留原結構）；清 ~82M 死重（未用字重 73M、構圖參考圖 8M→docs/、殘留複本與孤兒檔——匯出預設打包全部資源，死重會進 zip）；`docs/` 加 `.gdignore` 不被引擎掃描；驗證＝重掃＋三測試全綠＋洞窟/冰原/主選單截圖
- [x] **景深 DOF（2026-07-15）**：HD-2D 微縮感——Camera3D 掛 `CameraAttributesPractical`（僅 far blur：20/5/0.08，遊戲資訊沿視線 4.8~18.5 全在對焦內；near 刻意不開，否則最先糊的是手牌）；透明物件（本體/召喚立牌、對手卡背）加 `ALPHA_CUT_OPAQUE_PREPASS` 寫深度，免被 DOF 拿背景深度當遠景糊；本體 HP 標籤改墊**深度錨定板**（Label3D 直接掛 alpha_cut 會黑字——字身/外框共面、render_priority 在深度管線失效）；截圖對比＋spell/hover/AI 三回歸驗證；純視覺驗證工具 `tests/screenshot.gd` 落籍

---

## 🚧 待辦（接下來的步驟）

> 🎯 **目標(2026-07-10 定向)**:朋友從網站下載遊戲、彼此連線對戰。
> 對手 = 真人 → 連線取代敵方 AI 成為關鍵路徑;AI 降級為之後的單人練習模式。
> 連線選型與取捨見 [docs/adr-001-network-multiplayer.md](docs/adr-001-network-multiplayer.md)。

依優先順序：

1. ~~**卡牌類型實作（結算層）**~~ ✅ 完成（見已完成清單）。**殘留小尾巴**：①瞬咒窗口目前只接「反制秘術」——攻擊宣告的反制窗與 LIFO 堆疊（桌遊反制鏈）未做；②「沉默」關鍵字尚未實作（現行卡池無沉默來源）；③~~伏印蓋放後無場上視覺~~ ✅ 已解（2026-07-17 宿主制＋整排紅色警戒）；④玩家看不到「自己的伏印埋在誰底下」（現靠記憶；hover 宿主提示待補，注意熱座會洩密）。
2. **連線對戰（host-client，見 ADR-001）** — ✅ **demo 版可對戰**（2026-07-12；雙 headless loopback 實測:開局帳同步、雙方各召喚+換回合,兩台終局簽名一字不差）：
   - ~~**2a. 大廳與連線骨架**~~ ✅（`src/net/net_lobby.gd` + `net_match.gd` + 主選單大廳欄）
   - ~~**2b. 回合與視角**~~ ✅ client 視角翻轉（鏡頭/手牌/牌堆繞棋盤中線轉 180°，從自己那側看桌）；HUD 我方/對方與勝負判定改**本機視角**（比對 `NetMatch.my_side`）；非自己回合鎖出牌；`_is_valid_target` 改相對敵我（寫死 "player"/"enemy" 在 client 上會顛倒）。
   - ~~**2c. 行動同步**~~ ✅（**demo 簡化版**）：host 開局把雙方牌堆/起手打包給 client（帳同步），之後召喚/攻擊/技能/法術/換回合全走 RPC 兩台重放——資料一致＋操作一致＝狀態一致。單位跨機器身分證＝所在卡槽的場景樹路徑。**債**：行動合法性只在出牌端驗（client 可作弊）,正式版要改 host 權威驗證。
   - **2d. 對手手牌同步** — 張數 HUD ✅（右上「對方手牌:N 張」）＋卡背扇形 ✅（2026-07-15 隨單人模式一起做，`OpponentHand` 連線/單人共用）；**債**：對方手牌「內容」仍在本機記憶體（真隱藏＝host 只送張數）。
   - ~~**2e. 斷線與收尾**~~ ✅ 任一方掉線→「對方已離線」→ 收線回主選單；連線時勝負畫面兩顆按鈕都改走收線（單邊 reload 會讓帳分家）。
   - **2f. 異地連線（UPnP 自動打洞）** ✅（2026-07-16）：開房時背景執行緒向路由器申請「UDP 8910 轉發」（`src/net/net_upnp.gd`，static 列管——洞是路由器的狀態，跨場景不消失，回主選單收殘洞），成功後狀態字顯示「同網路朋友連:區網 IP／異地朋友連:對外 IP」；失敗（路由器不支援 UPnP、CGNAT）顯示原因＋備案（手動轉發／Tailscale）。`discover()` 標稱 2 秒實測可拖 ~10 秒 → Thread ＋主執行緒輪詢 `take_result()`（官方 Thread 模式）。**注意**：開發機所在網路不支援 UPnP，fallback 路徑已實測；**成功路徑（真的顯示對外 IP＋異地連入）待有 UPnP 的網路實測**（`tests/upnp_probe.gd` 是換網路先跑的體檢工具）。
   - **實機驗收待做**：本機開兩個遊戲視窗走大廳連 `127.0.0.1` 對打一局（headless 已驗邏輯,UI/視角要人眼）；家用網路跑 `upnp_probe` 驗 UPnP 成功路徑＋真異地連入一局。
3. **打磨與試玩** — 連線實測抓蟲、音效（出牌/攻擊/受擊至少三個）、數值平衡。
4. **發佈** — Windows 匯出 preset（icon/版本號）＋ itch.io 或 GitHub Releases 下載頁。
5. ~~**敵方 AI（單人練習模式）**~~ ✅ 完成（2026-08-31 強化）：主選單「單人練習」→ `MatchMode.VS_AI`（static 旗標，仿 ArenaPool）；`EnemyAI` 走玩家同一條結算路，對手手牌仍以卡背與張數隱藏。AI 現會把手牌、全場技能與可攻擊目標生成合法候選並評分：施放目標/無目標/高階秘術，使用抽濾、靈裝、伏印與主動技能，優先斬殺、有利交換、受傷治療與高價值宿主；瞬咒保留反制，棄牌回魔只在能當回合解鎖更強行動時使用。AI 施法時的玩家瞬咒反制仍由玩家決定；AI 守方才自動反制。`tests/ai_turn_test.gd` 驗收完整回合，`tests/ai_strategy_test.gd` 以固定局面驗收秘術/靈裝/伏印/技能/棄牌回魔與優先級。
6. **卡片從卡槽取回** — `card_slot.gd` 的 `remove_card()` 已寫好，但尚未接上互動（例如再次拖出或右鍵取消）。
7. **CardData 欄位擴充** — 技能資料層與 24 張接線已完成；剩 `attack_range` / `Sacrifice`（[§4.1](#41-攻擊範圍-數位調整)、[§3](#3-召喚)）。
8. **地形收尾** — meshlib 純草磚問題與空的 `Terrain` / `Cliffs` 節點；地形整修 commit（04f8bbf）後需重驗哪些仍存在。

---

## 開發備註

- **回歸測試在 [tests/](tests/)**（headless SceneTree 腳本，曾放系統暫存被清掉兩次，故落籍版控）：
  `Godot --headless --path . -s tests/spell_smoke.gd`（法術結算 14 斷言）、`tests/ai_turn_test.gd`（單人 vs AI 完整回合）、`tests/ai_strategy_test.gd`（AI 秘術/靈裝/伏印/技能/棄牌回魔與優先級）、`tests/hover_spam_test.gd`（手牌 hover 漂移/碰撞箱釘位）、`tests/grave_test.gd`（墓地＋丟牌回魔 14 斷言）、`tests/net_battle_test.gd`（雙進程連線 loopback：先開 host，再帶 `-- client` 開第二個進程，比對兩端簽名）。
  另有幾支**非 CI 的工具腳本**：`tests/screenshot.gd` / `tests/screenshot_summon.gd`（非 headless 跑遊戲存 PNG，驗純視覺改動）、`tests/screenshot_leave.gd`（拍「離開對戰」確認窗，並印出面板實際尺寸；加 `-- <png> online` 拍連線版的長文案）、`tests/upnp_probe.gd`（實測目前網路的 UPnP 打洞，結果依環境而異）、`tests/fix_stale_uids.gd`（掃全專案 `.tres`/`.tscn`，把失效的 `ext_resource` UID 換成引擎當前的正確值；`-- --dry` 只報告不寫入，`-- --drop-dangling` 連「目標根本沒有 UID」的懸空引用一起拆成純路徑）。
- 在編輯器**外**新建帶 `class_name` 的腳本後，headless 跑會報「Identifier not declared」——全域類別註冊表（`.godot/global_script_class_cache.cfg`）由編輯器掃描生成，跑一次 `Godot --headless --editor --quit` 重掃即可。
- `ground_generator.gd` 與 `forest_scatter.gd` 皆為 `@tool` 腳本：在編輯器調整 `@export` 後勾選 `regenerate` 即可即時重新生成，不必執行遊戲。
- 刪除無用資源時，建議在 Godot 編輯器「FileSystem → 右鍵 → Delete」，讓引擎同步清除 `.import` 快取與 UID 記錄，避免 Finder/Terminal 直接刪除留下殘留。
- **UID 失效**（`invalid UID ... using text path instead`）：資產重新匯入會拿到新 UID，但引用它的 `.tres`/`.tscn` 還留著舊的。能載是因為引擎退回字串路徑比對——慢，而且那組舊 ID 一旦被配給別的資源就會**默默載到錯的東西**。跑 `tests/fix_stale_uids.gd` 修（2026-09-01 一次修掉 111 處）。
- **規則同步提醒**：本 README 的 [Gameplay Spec](#-遊戲規則設計規格-gameplay-spec) 已調整灼燒 / 中毒 / 嘲諷 / 丟牌回魔，與既有桌遊說明書（docx）不一致。若要更新桌遊說明書請以本檔為準。
- **學習債清單**：逃生艙（AI 代工）產出的觀念、等級評等與複習考題在 [docs/LEARNING_LEDGER.md](docs/LEARNING_LEDGER.md)——複習時由 agent 從該表出題並更新等級。
