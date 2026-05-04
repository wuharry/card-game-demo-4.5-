# CardGame Demo (Godot 4.5)

3D 卡牌遊戲原型。實作卡片拖曳、懸停動畫、卡槽放置，以及棋盤自動生成。

---

## 架構圖

```
Main.tscn  ← 遊戲進入點
├── CardManger (Node3D)          [cardManger3D.gd]
│   ├── Card × 5 (card3D.tscn)  [Card.gd]
│   │   ├── Sprite3D             (卡面圖片)
│   │   └── Area3D               (滑鼠碰撞偵測)
│   │
│   └── 管理邏輯：
│       ├── 3D 射線拖曳 (Plane 投影法)
│       ├── 懸停動畫 dispatch (同一時間只放大一張)
│       └── 放入卡槽 / 退回手牌
│
├── Arena_Forest (arena_forest.tscn)
│   ├── GridMap                  (使用 grassland_tiles.meshlib)
│   ├── WorldEnvironment         (環境光 + Glow)
│   └── DirectionalLight3D       (陽光)
│
└── PlayerBoard (player_board.tscn)  [PlayerBoard.gd]
    └── CardSlot × 10 (CardSlot.tscn × 5欄 × 2排)  [CardSlot.gd]
        ├── Sprite3D              (卡槽框圖)
        └── Area3D                (放置碰撞偵測, Layer 2)
```

---

## 檔案說明

### GDScript

| 檔案 | 說明 |
|------|------|
| `Card.gd` | 3D 卡片。發射 `card_hovered` / `card_unhovered` 信號；提供 `lock_interaction()` / `unlock_interaction()` 讓 Manager 控制是否可拖曳 |
| `cardManger3D.gd` | 3D 手牌管理器。透過 Plane 投影法實作拖曳；雙層射線偵測卡片 (Layer 1) 與卡槽 (Layer 2)；含 `organize_hand()` 待實作預留位 |
| `CardSlot.gd` | 3D 卡槽。記錄 `is_empty` 狀態；`place_card()` 執行吸附並躺平動畫；`highlight()` / `unhighlight()` 提供懸停視覺回饋 |
| `PlayerBoard.gd` | 棋盤生成器。5 欄 × 2 排，間距自動置中；自動將卡槽加入 Group（`player_front` / `player_back` / `enemy_front` / `enemy_back`）|

### 場景

| 檔案 | 說明 |
|------|------|
| `Main.tscn` | 主場景（遊戲進入點）。手動放置 5 張卡片 + 攝影機 Rig |
| `card3D.tscn` | 可實例化的 3D 卡片預製件 |
| `CardSlot.tscn` | 可實例化的 3D 卡槽預製件 |
| `player_board.tscn` | 棋盤場景，`@export card_slot_scene` 指向 `CardSlot.tscn` |
| `arena_forest.tscn` | 森林地圖場景，含 GridMap 地板 + 燈光環境 |

### 美術資源

| 路徑 | 用途 |
|------|------|
| `cardBorder.png` | 卡片正面圖（card3D.tscn 使用）|
| `assets/卡匡包/` | 卡槽框圖（CardSlot.tscn 使用）|
| `assets/test_libs/grassland_tiles.meshlib` | GridMap 格子地板（arena_forest.tscn 使用）|
| `assets/testResource/` | meshlib 的材質與來源 `.tscn`（mat_grass / mat_dirt / mat_mountain）|
| `assets/Pixel_3D_地板包_2.0/Modular Tile Models/OBJ/` | 地板格子 OBJ 模型（由 grassland_tiles.meshlib 引用）|
| `assets/Pixel_3D_地板包_2.0/Landscape Material Tiles/` | 地板材質貼圖（由 testResource 材質引用）|

---

## 碰撞層規則

| Layer | 名稱 | 用途 |
|-------|------|------|
| 1 | `Card` | 卡片 Area3D，供拖曳射線偵測 |
| 2 | `CardSlot` | 卡槽 Area3D，供放置射線偵測 |

---

## 🗑️ 可移除的檔案

以下檔案在目前版本中**沒有任何引用**，可以安全刪除：

### 2D 原型殘留（已被 3D 版本取代）

| 檔案 | 原因 |
|------|------|
| `Card2D.tscn` | 2D 原型場景，無任何場景引用 |
| `CardManger2D.gd` + `.uid` | 2D 管理器原型，已由 `cardManger3D.gd` 取代 |
| `card_slot.gd` + `.uid` | 舊版卡槽腳本（無 `highlight` 方法），無任何場景使用它；`CardSlot.gd` 才是現役版 |

### 根目錄無用圖片

| 檔案 | 原因 |
|------|------|
| `cardBorder_pixel.png` + `.import` | 未被任何場景或腳本引用 |
| `grass_spritesheet.png` + `.import` | 未被任何場景或腳本引用 |
| `理想範本.png` + `.import` | 設計參考圖，非遊戲資源 |

### 未使用的資源包

| 路徑 | 原因 |
|------|------|
| `assets/tree_pack_1.1/` | 整個資料夾無任何場景引用 |
| `assets/風格化自然包/` | 整個資料夾（FBX / OBJ / glTF / 貼圖）無任何場景引用 |
| `assets/Pixel_3D_地板包_2.0/Modular Landmass/` | OBJ 與 Blender 源文件，無引用 |
| `assets/Pixel_3D_地板包_2.0/Modular Mountains/` | OBJ 與 Blender 源文件，無引用 |
| `assets/Pixel_3D_地板包_2.0/Objects/` | OBJ 與 Blender 源文件，無引用 |
| `assets/Pixel_3D_地板包_2.0/Structures/` | OBJ 與 Blender 源文件，無引用 |
| `assets/Pixel_3D_地板包_2.0/TileSheet/` | 貼圖 TileSheet，未直接引用（材質已在 Landscape Material Tiles）|
| `assets/Pixel_3D_地板包_2.0/Landscape Material Tiles.7z` | 壓縮包原始檔，已解壓完畢 |

> **注意**：刪除前建議在 Godot 編輯器使用「FileSystem > 右鍵 > Delete」，讓引擎同步清除對應的 `.import` 快取與 UID 記錄。直接在 Finder/Terminal 刪除可能留下殘留的 .godot 快取。

---

## 待實作

- `organize_hand()` — 卡片退回手牌時的排列動畫（扇形 / 弧線）
- 對手棋盤（`is_enemy: true` 的 PlayerBoard）
- 卡片資料系統（攻擊力、費用等屬性）
