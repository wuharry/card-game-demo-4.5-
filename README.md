# CardGame Demo (Godot 4.5)

3D 卡牌遊戲原型，走 HD-2D 風格。實作卡片拖曳、懸停放大、爐石式扇形手牌、卡槽放置，
以及程序化生成的森林戰場（地板、樹叢、溪流）與棋盤。

- 引擎：Godot **4.5**，算繪器 **Forward+**（啟用 bloom / SSAO / 景深 / 高品質陰影）
- 主場景：`scenes/main.tscn`

> 📖 **遊戲規則設計規格**請見下方「[遊戲規則設計規格 (Gameplay Spec)](#-遊戲規則設計規格-gameplay-spec)」。
> 該章節由桌遊原型規則整理而來，作為 PC / Mobile 版實作的**單一事實來源 (single source of truth)**。
> 當桌遊與數位版規則衝突時，**以本 README 的規格為準**。

---

## 架構圖

```
main.tscn  ← 遊戲進入點 (MainScene, Node3D)
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
    ├── Stream (MeshInstance3D)     風格化溪流中線（stream_water.gdshader）
    ├── WorldEnvironment            ACES tonemap + bloom + SSAO + 暖色氛圍
    └── DirectionalLight3D          柔和陽光
```

> 一張卡片 (`src/card/card.tscn`) 內部結構：
> `Card (Node3D)` → `CardImage (Sprite3D, 卡面)` + `Area3D/CollisionShape3D (滑鼠偵測)`

---

## 檔案說明

### GDScript

| 檔案 | 說明 |
|------|------|
| [src/card/card.gd](src/card/card.gd) | 一張卡片的「大腦」。發射 `card_hovered` / `card_unhovered` 信號；提供 `animate_hover/unhover` 放大縮小動畫與 `lock_interaction()` / `unlock_interaction()` |
| [src/card_manager/card_manager.gd](src/card_manager/card_manager.gd) | 全場互動中樞。Plane 投影法拖曳；雙層射線偵測卡片(Layer 1)/卡槽(Layer 2)；出牌判定並協調 Card / CardSlot / PlayerHand 三方 |
| [src/play_hand/player_hand.gd](src/play_hand/player_hand.gd) | 玩家手牌。`@tool` 可在編輯器預覽；`draw_starting_hand()` 起手抽牌、`_arrange_fan()` 排成圓弧扇形、`organize_hand()` 出牌後靠攏；hover 信號中繼站 |
| [src/card_slot/card_slot.gd](src/card_slot/card_slot.gd) | 桌面卡槽 (Area3D)。記錄 `is_empty` / `card_in_slot`；`place_card()` 入槽吸附+鎖定、`remove_card()` 取回、`highlight()` / `unhighlight()` 高亮提示 |
| [src/player_board/player_board.gd](src/player_board/player_board.gd) | 棋盤生成器。5 欄 × 2 排自動置中；依 `is_enemy` 擺位並加入群組 |
| [src/environment/ground_generator.gd](src/environment/ground_generator.gd) | `@tool` GridMap 噪聲鋪地：純草為底、泥土依噪聲成簇、邊緣草泥過渡磚、每格隨機朝向 |
| [src/environment/forest_scatter.gd](src/environment/forest_scatter.gd) | `@tool` 程序散佈 PSX 樹/灌木：成簇分布、內圈與前方淨空、生成時補上 alpha 鏤空雙面材質 |

> ⚠️ 根目錄的 `cardManger3D.gd` 為早期管理器原型，已被 `src/card_manager/card_manager.gd` 取代，**目前無任何引用，可移除**。

### 場景

| 檔案 | 說明 |
|------|------|
| [scenes/main.tscn](scenes/main.tscn) | 主場景（遊戲進入點）：CardManger + 攝影機 + 雙棋盤 + 手牌 + 牌堆 + 戰場 |
| [scenes/arena_forest.tscn](scenes/arena_forest.tscn) | 森林戰場：程序地板 + 森林散佈 + 溪流 + 燈光環境 |
| [src/card/card.tscn](src/card/card.tscn) | 可實例化的 3D 卡片預製件（卡面用 `NewCard.png`）|
| [src/card_slot/card_slot.tscn](src/card_slot/card_slot.tscn) | 可實例化的 3D 卡槽預製件（卡框用 `assets/ui/card_frames/base 11.png`）|
| [src/player_board/player_board.tscn](src/player_board/player_board.tscn) | 棋盤場景，`@export card_slot_scene` 指向 `card_slot.tscn` |

### 美術資源

| 路徑 | 用途 |
|------|------|
| `NewCard.png` | 卡片正面圖（card.tscn 使用）|
| `assets/ui/card_frames/` | 卡槽外框圖（card_slot.tscn 使用）|
| `assets/mesh_libraries/grasslands/grassland_tiles.meshlib` | GridMap 地板格子（arena_forest 使用）|
| `assets/environment/psx_trees/` | PSX 樹/灌木 FBX 模型與貼圖（forest_scatter 使用）|
| `assets/water/stream_water.gdshader` | 溪流水面 shader（波紋法線 + 反射）|
| `assets/water/psx_ocean_surface/` | 水面貼圖 |

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
| 魔力上限 | 起始 0，每回合開始 +1（上限 10），並回滿至上限 |
| 魔力累積 | 未使用魔力**不**保留到下回合 |

### 1.1 丟牌回魔（含冷卻）`[數位調整]`

- 抽牌後，可捨棄 1 張手牌，獲得「該牌 Cost ÷ 2（無條件捨去）」的**暫時魔力**。
- **冷卻：使用後下一回合不可再用**（最多隔回合一次）。
- 實作建議：在玩家狀態上維護 `discard_mana_cooldown: int`。使用時設為 `1`；每回合開始 `max(0, cooldown - 1)`；`cooldown == 0` 才允許使用。

```gdscript
# PlayerState 內
var discard_mana_cooldown: int = 0

func can_discard_for_mana() -> bool:
    return discard_mana_cooldown == 0

func discard_for_mana(card: CardData) -> int:
    var gained := card.cost / 2          # int 除法自動捨去
    temp_mana += gained
    discard_mana_cooldown = 1            # 進入冷卻
    return gained

func on_turn_start() -> void:
    discard_mana_cooldown = max(0, discard_mana_cooldown - 1)
```

## 2. 戰場與路線

- 戰場為 **5 條並排路線 (Lane)**，雙方一對一對應（路線 1–5）。
- 每條路線可有：前排從者（可被攻擊/阻擋）+ 其附著的靈裝 / 伏印。
- `[桌遊]` 桌面只有 10 格卡槽；後排（伏印）以皮製卡盒直立卡位呈現，對手看不到內容。
- `[數位調整]` 數位版可直接用獨立的 `back_row` 資料層表示伏印區，無需卡盒。

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

**場景與美術**
- [x] Forward+ 算繪 + ACES tonemap + bloom + SSAO + 暖色氛圍燈光
- [x] 程序化地板（噪聲成簇：純草為底 + 泥土斑塊 + 草泥過渡磚）
- [x] 風格化溪流戰場中線（波紋法線 + 反射）
- [x] 程序化森林散佈（成簇樹叢、內圈淨空、PSX alpha 鏤空材質）
- [x] 牌堆視覺（玩家右側卡背堆疊）

---

## 🚧 待辦（接下來的步驟）

依優先順序：

1. **卡片資料系統** — 為卡片加上屬性（攻擊力、生命、費用、名稱、`attack_range`），並讓卡面動態顯示。目前每張卡只是同一張圖。→ 參考 [§7 卡牌類型](#7-卡牌類型)。
2. **從牌堆抽牌** — 把 `Deck` 牌堆接上手牌：點牌堆 → 飛入手牌動畫 → 觸發 `PlayerHand` 重排（目前牌堆只是靜態視覺）。
3. **卡片從卡槽取回** — `card_slot.gd` 的 `remove_card()` 已寫好，但尚未接上互動（例如再次拖出或右鍵取消）。
4. **敵方棋盤邏輯** — `EnemyBoard` 已生成卡槽，但目前無任何 AI / 出牌行為，需要敵方出牌與目標分群運用（`enemy_front` / `enemy_back`）。
5. **回合與戰鬥系統** — 回合切換、出牌時機限制、攻擊/結算判定、狀態效果 tick。→ 完整規格見 [§5 回合流程](#5-回合流程)、[§4 攻擊與戰鬥結算](#4-攻擊與戰鬥結算)、[§9 狀態效果](#9-狀態效果)。
6. **地形收尾** — meshlib 純草磚部分仍有問題（見近期 commit），需修復重建；`arena_forest` 的 `Terrain` / `Cliffs` 節點目前為空，待補地貌。

---

## 開發備註

- `ground_generator.gd` 與 `forest_scatter.gd` 皆為 `@tool` 腳本：在編輯器調整 `@export` 後勾選 `regenerate` 即可即時重新生成，不必執行遊戲。
- 刪除無用資源時，建議在 Godot 編輯器「FileSystem → 右鍵 → Delete」，讓引擎同步清除 `.import` 快取與 UID 記錄，避免 Finder/Terminal 直接刪除留下殘留。
- **規則同步提醒**：本 README 的 [Gameplay Spec](#-遊戲規則設計規格-gameplay-spec) 已調整灼燒 / 中毒 / 嘲諷 / 丟牌回魔，與既有桌遊說明書（docx）不一致。若要更新桌遊說明書請以本檔為準。