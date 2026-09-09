# Tiny RPG 角色圖規格（2026-09-09）

角色立牌以 `assets/packs/tiny_rpg_characters` 為美術基準。這次重繪
`assets/characters` 全部 24 個角色；卡面插畫是另一類素材，未在此批重繪。

## 美術與動畫

| 項目 | 現行規格 |
| --- | --- |
| 人形／小型角色待機高度 | 18–23 個原生像素；樹人與大型怪物 25–29 |
| 影格 | 100×100；每張動畫 6 格橫排，PNG 為 600×100 |
| 色彩 | 每張 PNG 最多 28 色，取自 Tiny RPG 參考角色色盤 |
| 透明度 | 只有 0 或 255；無平滑邊緣、半透明底色或棋盤格 |
| 腳底 | 待機固定在 y=59；動作沿用同一角色座標，保留出招與倒地位移 |
| 共通動作 | Idle、Attack01、Hurt、Death；有主動技者另有 Attack02 |
| 無主動技角色 | Sky Leviathan、Steel Forge Titan、Tombsea Colossus 不產生 Attack02 |
| 冰霜女巫 | 額外保留 Walk、Summon、Idle_Static；Walk 和 Attack02 目前未被戰鬥流程呼叫 |

大頭、短四肢、深色外框、少量完整色塊是判斷依據。不要以高解析度的
細節堆疊代替輪廓；例如 Adventurer 的頭、短披風、劍與盾都必須在原生小圖辨識。
放大時使用 nearest-neighbor，避免重新混出大量近似色。

一般動作的首尾沿用 Idle 第 0 格，Death 只共用起手格，最後停在倒地姿勢。
出招高峰放在第 2 格（從 0 起算），沿用 Card 的每格 0.1 秒，約 0.30 秒
出現，配合既有 0.35 秒傷害結算。Idle 沿用每格 0.12 秒。

## 製作來源與重建

美術由內建 `image_gen.imagegen` 重繪；Godot 工具只處理去底、切格、
像素縮放、色盤與動畫首尾對齊，不以程式位移替代姿勢繪製。

- [生成紀錄](style_generation_20260909.json) 保存提示詞、角色描述、
  原稿位置、正式素材位置與 SHA-256。`scope_baseline_commit` 是使用者指定的
  風格檢查起點，不表示所有角色都已存在於該 commit。
- 原稿保存在本機生成快取及 `build/sprite-style-20260909/drafts/`；
  這些大圖不納入遊戲素材。跨機器重切時需要一併移交原稿。
- 重繪前備份在 `build/sprite-style-20260909/before/`；離線比較頁已嵌入前後 PNG，
  不需要依賴該備份才能瀏覽。

```sh
godot --headless --path . -s tests/normalize_character_animation.gd -- \
  build/sprite-style-20260909/drafts/adventurer.png \
  build/sprite-style-20260909/normalized/adventurer Adventurer 20
```

無主動技者最後加 `no_skill`。冰霜女巫先產生主動畫，再以同一輸出目錄
處理 companion 原稿並加 `frost_extras`，其第 2、3 列分別輸出 Walk、Summon。
生成稿必須人工檢查物種、裝備與每個動作；例如只剩炸彈而角色消失的技能格不能採用。

## 驗收紀錄

| 檢查 | 結果 |
| --- | --- |
| `character_style_verify.gd` | PASS：24 角色、120 PNG；尺寸、色數、透明度、非空影格、動作首尾、倒地姿勢 |
| `card_pool_verify.gd` | PASS：291 項 |
| `generated_minions_verify.gd` | PASS：一般新增從者的卡圖與動畫載入 |
| `high_tier_cards_verify.gd` | PASS：高階卡與無技能者的動畫契約 |
| `frost_witch_test.gd` | PASS：29 斷言；結束時仍印出 4 個 resources 未釋放訊息，此項未修正 |
| `.harness/verify.py` | PASS：投遞完整性；不替代應用／美術驗收 |
| 正式森林牌桌 | 已以 Forward+ / Metal 擷取並檢視待機、普攻、技能、受傷、倒地；輸出 1280×720 |
| 離線比較頁 | 已以 Chrome 開啟並擷取動畫畫面 |
| 新舊來源盲測 | NOT RUN；接近同套美術不等於已證明觀眾無法辨別來源 |

[動態前後比較](../../docs/art/character-style-review.html) 可切換全部動作與比較倍率。
[牌桌待機](../../docs/art/character-style-board.png) 與
[牌桌攻擊](../../docs/art/character-style-attack.png) 展示原素材與重繪角色並排。

```sh
godot --headless --path . -s tests/character_style_verify.gd
godot --path . -s tests/screenshot_character_style.gd -- build/sprite-style-20260909/game
python3 tests/build_character_style_review.py
```

比較頁產生器需要本機的 before 備份與 audit JSON；已生成的 HTML 可獨立離線檢視。
