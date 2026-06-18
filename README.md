# CardGame Demo (Godot 4.5)

3D 卡牌遊戲原型，走 HD-2D 風格。實作卡片拖曳、懸停放大、爐石式扇形手牌、卡槽放置，
以及程序化生成的森林戰場（地板、樹叢、溪流）與棋盤。

- 引擎：Godot **4.5**，算繪器 **Forward+**（啟用 bloom / SSAO / 景深 / 高品質陰影）
- 主場景：`scenes/main.tscn`

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

1. **卡片資料系統** — 為卡片加上屬性（攻擊力、生命、費用、名稱），並讓卡面動態顯示。目前每張卡只是同一張圖。
2. **從牌堆抽牌** — 把 `Deck` 牌堆接上手牌：點牌堆 → 飛入手牌動畫 → 觸發 `PlayerHand` 重排（目前牌堆只是靜態視覺）。
3. **卡片從卡槽取回** — `card_slot.gd` 的 `remove_card()` 已寫好，但尚未接上互動（例如再次拖出或右鍵取消）。
4. **敵方棋盤邏輯** — `EnemyBoard` 已生成卡槽，但目前無任何 AI / 出牌行為，需要敵方出牌與目標分群運用（`enemy_front` / `enemy_back`）。
5. **回合與戰鬥系統** — 回合切換、出牌時機限制、攻擊/結算判定。
6. **地形收尾** — meshlib 純草磚部分仍有問題（見近期 commit），需修復重建；`arena_forest` 的 `Terrain` / `Cliffs` 節點目前為空，待補地貌。

---

## 開發備註

- `ground_generator.gd` 與 `forest_scatter.gd` 皆為 `@tool` 腳本：在編輯器調整 `@export` 後勾選 `regenerate` 即可即時重新生成，不必執行遊戲。
- 刪除無用資源時，建議在 Godot 編輯器「FileSystem → 右鍵 → Delete」，讓引擎同步清除 `.import` 快取與 UID 記錄，避免 Finder/Terminal 直接刪除留下殘留。
