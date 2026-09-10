# Time Fantasy 新卡（2026-09-10）

首批選用素材包中的 12 名角色，已加入 `data/cards/`，會由 `Deck.load_pool()` 自動加入圖鑑與隨機牌堆。這批直接使用原作者 finalbossblues 的像素；Time Fantasy 的身體比例與 Tiny RPG 不同，沒有將它重繪成 Tiny RPG。

| 卡名 | 費用 | 攻擊／生命 | 主動技能（技能費用） | 戰吼／關鍵字 |
|---|---:|---|---|---|
| 翠甲衛士 | 2 | 1／4 | 固守（◆1）：自身獲得 2 點護盾。 | 鐵壁 |
| 赤羽統領 | 5 | 4／6 | 破陣斬（◆2）：本次攻擊額外造成 1 點傷害。 |  登場時，左右相鄰友軍獲得【鍛強】2 回合。 |
| 蒼衣遊俠 | 2 | 3／2 | 踏前斬（◆1）：本次攻擊額外造成 2 點傷害。 | — |
| 緋紅劍士 | 3 | 3／3 | 雙連斬（◆2）：以攻擊力連擊兩次，僅第一次受到反擊。 | — |
| 暮色術士 | 4 | 2／4 | 暮焰（◆2）：造成 3 點傷害，並施加【灼燒】2 回合。 | — |
| 潮汐祭司 | 3 | 1／5 | 潮生祈禱（◆2）：恢復一名友軍 3 點生命。 | — |
| 烈陽武僧 | 3 | 3／4 | 回元擊（◆2）：本次攻擊額外造成 1 點傷害，吸血。 | — |
| 荒原鬥士 | 5 | 5／5 | 橫掃重擊（◆3）：以攻擊力橫掃目標及左右相鄰路線。 | — |
| 幽幕咒師 | 4 | 2／5 | 萎靡咒（◆1）：使對路敵人獲得【衰弱】2 回合。 | — |
| 曙光聖衛 | 5 | 3／7 | 晨光庇護（◆2）：一名友軍獲得 3 點護盾。 | 鐵壁 登場時，恢復己方英雄 3 點生命。 |
| 赤羽吟遊者 | 2 | 1／3 | 奮起之歌（◆1）：使一名友軍獲得【鍛強】2 回合。 | — |
| 青林獵手 | 3 | 3／3 | 淬毒箭（◆2）：造成 2 點傷害，並施加【中毒】2 回合。 | — |

## 素材接法

- 角色來源對照與初版數值：`assets/characters/time_fantasy/cards.json`。實際遊戲資料由 `data/cards/tf_*.tres` 載入。
- 每個動畫格保留來源的 48 × 48 像素與座標；原來的三張動作各停留兩格，輸出 288 × 48 橫排動畫。傷害在 0.35 秒結算時仍看得到出招姿勢。
- `Death` 使用原本的三張 `crouch` 接原本的 `dead`（蒼衣遊俠的原檔名為 `down`），最後定格。`Summon` 用 `cheer`，`Block` 用 `crouch`。
- 卡面使用原始待機角色裁切、nearest 整數倍放大，再放入 320 × 170 深色畫布，避免地形透過卡框的透明卡窗。每張卡都有獨立卡圖，不混用其他角色插畫。
- 原圖陰影屬於作者素材的一部分，保留；上桌大小與腳底由既有 `Card.show_standee()` 自動計算。
- 原作者說明：[SOURCE_README.txt](../assets/characters/time_fantasy/SOURCE_README.txt)。ZIP 不需要隨遊戲執行檔配送；重建動畫時才需要提供原始壓縮檔。

來源 ZIP SHA-256：`599ebd5cd76bc481d8a5c56157cba62689602d04f605b6794046d3deff5d406d`。

## 重建與驗證

```sh
godot --headless --path . -s tests/import_time_fantasy.gd -- /path/to/tf_svbattle.zip
godot --headless --editor --path . --import --quit
godot --headless --path . -s tests/time_fantasy_verify.gd -- /path/to/tf_svbattle.zip
godot --headless --path . -s tests/card_pool_verify.gd
python3 tests/build_time_fantasy_review.py
godot --path . -s tests/screenshot_time_fantasy.gd -- build/tf-svbattle-20260910/game-0 0
godot --path . -s tests/screenshot_time_fantasy.gd -- build/tf-svbattle-20260910/game-1 1
```

`time_fantasy_verify.gd` 不帶 ZIP 參數也能跑資源與實戰驗證；帶 ZIP 時另逐幀比對輸出 PNG 與原圖像素。Godot 匯入會填補全透明像素下的 RGB 以避免邊緣暈染，故原圖逐位元比對使用 PNG 本身。

開主選單的「牌庫圖鑑」可直接看到新卡。指定單張試玩可沿用 F8 測卡：

```sh
godot --path . -- --test-card=tf_dusk_mage
```

進入單人對戰後按 F8，即會加入暮色術士並補足測試魔力。卡牌數值為首版，尚未經長時間對戰平衡測試。

## 驗收範圍

- 新卡測試在正式 `main.tscn` 執行全部主動技能，確認魔力扣除、攻擊次數、護盾、治療、灼燒、中毒、衰弱、鍛強、吸血、連擊與橫掃；另確認統領與聖衛戰吼。
- 兩批正式森林牌桌截圖同時放入 Tiny RPG 騎士／巫師作尺寸對照，檢查新角色待機、普攻、技能、受傷與倒地。圖鑑截圖只篩出新卡，正式圖鑑仍顯示完整卡池。
- 卡圖驗證要求不透明底，防止地形穿透卡窗；立牌仍使用原圖透明通道。
- 長期平衡與兩台裝置的多人連線實玩尚未執行。
