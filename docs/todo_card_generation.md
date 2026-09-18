# 待生成卡牌與候選圖檔清單 (Card Art & Generation TODO)

> **目的**：列管待生成、待補齊專用卡圖的卡牌項目，並歸檔已生成之高品質 HD-2D 像素候選圖檔，作為未來卡池擴充與視覺升級的評估備案。

---

## 一、卡圖資產規範與規格

本專案卡框、數值標籤（ATK/HP/Cost）與狀態特效均由 Godot 引擎（`src/card/card.gd`）與 Shader 即時疊合，插畫圖檔嚴格遵守以下管線規範：

| 項目 | 規範標準 | 說明 |
| :--- | :--- | :--- |
| **檔案格式** | `.png` (8-bit RGB / RGBA) | 放置於 `assets/ui/card_art/`（候選圖暫存於 `docs/art/candidates/`） |
| **建議尺寸** | 1200 × 896 或 1495 × 1052 | 比例約為 **4:3 橫向**，完全相容於 `card.gd` 的 `ART_WINDOW_SIZE` 視窗裁切 |
| **美術風格** | 16-bit / HD-2D 暗黑奇幻像素 | 主體輪廓清晰，背景為低對比暗色系（夜空、石板地牢、冰峰），凸顯前景角色 |
| **禁用內容** | **嚴禁預烤卡框、UI、數值或文字** | 否則會與遊戲內部的 Shader 裁切視窗與原生 Label3D 產生重疊穿幫 |

---

## 二、已生成候選圖檔（評估備選庫）

### 1. 霜寒古龍 (Ancient Frost Dragon)
- **圖檔位置**：`docs/art/candidates/candidate_frost_dragon.png`
- **適用類型**：高階龍族從者 (Minion)
- **建議定位**：7～8 費高階掌控者，入場凍結（FREEZE）對位前後排敵人，具備 `飛行` 關鍵字。
- **預覽展示**：
  ![霜寒古龍](art/candidates/candidate_frost_dragon.png)

### 2. 天雷貫擊 (Thunder Arcana)
- **圖檔位置**：`docs/art/candidates/candidate_thunder_arcana.png`
- **適用類型**：元素直傷秘術 (Arcana)
- **建議定位**：3～4 費單體貫穿雷擊，對前排造成 3 點傷害並對後排造成 1 點電弧濺射。
- **預覽展示**：
  ![天雷貫擊](art/candidates/candidate_thunder_arcana.png)

### 3. 主題環境背景庫 (4 款新場景已就緒)
- **熔岩焦土**：`docs/art/candidates/candidate_bg_volcano.png`（惡魔/火系）
- **幽暗古林**：`docs/art/candidates/candidate_bg_forest.png`（精靈/野獸/自然）
- **幽冥墓穴**：`docs/art/candidates/candidate_bg_catacombs.png`（骷髏/死靈/暗黑）
- **荒蕪廢墟**：`docs/art/candidates/candidate_bg_desert.png`（沙漠/物理/戰士）
- **展示檢視頁**：[docs/art/card-art-scene-showcase.html](art/card-art-scene-showcase.html)（支援卡框模擬疊加）

---

## 三、待生成與待修訂卡牌清單 (TODO Backlog)

依據 2026-09-17 卡池數值與機制體檢，以下卡牌列為優先處理項目：

| 優先度 | 卡名 / 檔名 | 類型與現況 | 待辦內容說明 | 狀態 |
| :---: | :--- | :--- | :--- | :---: |
| **P0** | **史萊姆衍生物**<br>`slime_token.tres` | 從者衍生物 | 解決 `slime.tres` 自體無限分裂問題，生成一張純 1/1 無技能的「小史萊姆」專用卡圖與卡牌資源。 | 待生成 |
| **P0** | **熔岩史萊姆衍生物**<br>`lava_slime_token.tres` | 從者衍生物 | 解決 `lava_slime.tres` 召喚自身的滾雪球問題，產出 1/1 帶灼燒的熔岩史萊姆衍生物卡圖。 | 待生成 |
| **P1** | **霜寒古龍**<br>`frost_dragon.tres` | 高階從者 | 使用候選圖檔 `candidate_frost_dragon.png` 正式建置 `.tres` 資源，填補 7-8 費高階龍族曲線。 | 候選待定 |
| **P1** | **天雷貫擊**<br>`arcana_thunder_strike.tres` | 秘術 | 評估替換現有 `arcana_twin_thunder.tres` 或開闢為新秘術資源。 | 候選待定 |
| **P1** | **死靈法師**<br>`necromancer.tres` | 從者 (5 費) | 體質由 2/4 調整為 3/5 後，評估是否更新其專用召喚施法插畫。 | 待評估 |
| **P2** | **樹靈守衛**<br>`treant_guardian.tres` | 從者 (4 費) | 數值平抑後（3/7 降為 3/5），視需要補齊古代發光靈木戰鬥插畫。 | 待評估 |
| **P2** | **石像鬼哨兵**<br>`gargoyle_sentinel.tres` | 從者 (4 費) | 體質由 3/6 修正為 3/4 飛行衛士，目前已有佔位圖，列入精緻化後補名單。 | 待評估 |

---

## 四、卡圖轉正落地 SOP

候選圖確認採用時，執行以下四個標準步驟：

1. **圖檔轉移**：
   將 `docs/art/candidates/candidate_*.png` 複製至 `assets/ui/card_art/<slug>_card_art.png`。
2. **資源綁定**：
   在對應的 `data/cards/<slug>.tres` 內設定：
   ```ini
   art = ExtResource("...")
   use_dedicated_art = true
   ```
3. **驗證完整性**：
   執行驗證腳本確認無遺漏與圖檔正常：
   ```bash
   python3 .harness/verify.py --run --only card_pool_verify
   ```
4. **回歸測試**：
   執行單人對局或沙盒確認卡面 hover 放大、裁切與 3D 戰場表現正常。
