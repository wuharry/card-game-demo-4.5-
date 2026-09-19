# 主題卡圖背景更新 · 2026-09-18

來源 commit：8a36c21be9003ef896de4729db0c3f281513567a。

該 commit 新增四張環境背景、兩張完整插畫（霜寒古龍、天雷貫擊）；不是五張環境背景。
以既有「暗夜地牢／冰雪魔女雪景」兩種視覺主題，加上此次四種，為 **2 + 4 = 6 種**，並非七種可選卡背。
冰雪魔女雪景是原插畫的一部分，不是獨立可重用背景檔。

| 卡牌 | 新背景 | 選擇原因 |
|---|---|---|
| 火焰魔像 | 熔岩焦土 | 技能「熔岩爆發」與火系石像 |
| 樹靈守衛 | 幽暗古林 | 樹靈與「年輪壁壘」 |
| 死靈法師 | 幽冥墓穴 | 亡靈召喚與墓穴題材 |
| 沙漠遊牧者 | 荒蕪廢墟 | 沙漠身分、彎刀與遺跡 |

首批修改上述四張 CardData 的 art 路徑；後續全卡池處理結果見下節。數值、技能、standee、Attack01／Attack02 等動畫完全未動。
卡面、圖鑑與預覽沿用既有 art 消費端。對手手牌背面不依卡片內容換圖，避免暴露隱藏資訊。
舊圖片完整保留，新圖片位於 assets/ui/card_art/<card_id>_themed_card_art.png。
採用 imagegen 技能的 built-in 編輯模式，不使用 CLI。原角色外觀經目視對照，但生成式編輯不保證逐像素相同。

## 完整提示詞

## 全卡池擴充 · 2026-09-19

已逐張分類 132 張卡牌：91 張採主題背景（首批 4 張加本輪 87 張），41 張保留既有背景。
火焰／鍛造採熔岩，亡靈／血咒採墓穴，自然／遊獵／荊棘採森林，武者／遺跡採荒原。
冰雪與抽象法術沒有適合的獨立替換背景時保留原圖；12 張 Time Fantasy 原生小尺寸卡圖亦保留，避免生成式重畫改變角色比例與像素。
這裡調整的是正面插畫背景，不是蓋牌背面；沒有更換 UI 卡框或洩漏對手隱藏卡資訊。

- [全部 132 張背景分配與理由](card-background-manifest.json)
- [可搜尋的原圖／新版對照頁](all-card-backgrounds-review.html)：以瀏覽器開啟，無須伺服器。
- [91 張完整生成提示詞與輸入／輸出路徑](card-background-generation-prompts.json)：使用內建 imagegen 編輯模式。
- 正式卡框截圖位於 all-card-backgrounds-review/page_01.png 至 page_11.png。

新版資產全部儲存於 assets/ui/card_art/<card_id>_themed_card_art.png；原圖保留，可逐卡還原。
生成式編輯以背景替換和保留前景造型為目標，已檢視正式卡框效果，但不保證與原角色逐像素相同。

驗證：Godot 4.7.2 匯入完成；tests/all_card_backgrounds_capture.gd 通過全部 132 張 CardData 與插畫路徑檢查，並成功輸出 11 頁正式卡面截圖。git diff --check 通過。

### 首批四張提示詞

每次 Input 1 為 assets/ui/card_art/<card_id>_card_art.png；
Input 2 為 docs/art/candidates/candidate_bg_<theme>.png。

### flame_golem

```text
Use case: compositing. Edit target Image 1 is an existing pixel art game card illustration. Image 2 is the exact replacement environment background. Replace ONLY the navy empty sky and stone-floor background of Image 1 with the environment of Image 2. Keep the foreground character from Image 1 unchanged: identical design, pose, silhouette, weapon/effect, palette, coarse pixel size and proportions. Do not redraw or add any character details. Keep its original relative centered placement and scale, full body visible, feet at about 84% of canvas height. Preserve the original wide landscape canvas aspect ratio. Fit the second environment behind it; environment contrast should be subdued so the existing character is legible. No new effects, glow, particles, borders, card frame, letters or numbers. Retain low-saturation crisp pixel-art rendering, no smoothing or photorealism. Output one finished card illustration only. Target card flame_golem, background volcano.
```

### treant_guardian

```text
Use case: compositing. Edit target Image 1 is an existing pixel art game card illustration. Image 2 is the exact replacement environment background. Replace ONLY the navy empty sky and stone-floor background of Image 1 with the environment of Image 2. Keep the foreground character from Image 1 unchanged: identical design, pose, silhouette, weapon/effect, palette, coarse pixel size and proportions. Do not redraw or add any character details. Keep its original relative centered placement and scale, full body visible, feet at about 84% of canvas height. Preserve the original wide landscape canvas aspect ratio. Fit the second environment behind it; environment contrast should be subdued so the existing character is legible. No new effects, glow, particles, borders, card frame, letters or numbers. Retain low-saturation crisp pixel-art rendering, no smoothing or photorealism. Output one finished card illustration only. Target card treant_guardian, background forest.
```

### necromancer

```text
Use case: compositing. Edit target Image 1 is an existing pixel art game card illustration. Image 2 is the exact replacement environment background. Replace ONLY the navy empty sky and stone-floor background of Image 1 with the environment of Image 2. Keep the foreground character from Image 1 unchanged: identical design, pose, silhouette, weapon/effect, palette, coarse pixel size and proportions. Do not redraw or add any character details. Keep its original relative centered placement and scale, full body visible, feet at about 84% of canvas height. Preserve the original wide landscape canvas aspect ratio. Fit the second environment behind it; environment contrast should be subdued so the existing character is legible. No new effects, glow, particles, borders, card frame, letters or numbers. Retain low-saturation crisp pixel-art rendering, no smoothing or photorealism. Output one finished card illustration only. Target card necromancer, background catacombs.
```

### desert_nomad

```text
Use case: compositing. Edit target Image 1 is an existing pixel art game card illustration. Image 2 is the exact replacement environment background. Replace ONLY the navy empty sky and stone-floor background of Image 1 with the environment of Image 2. Keep the foreground character from Image 1 unchanged: identical design, pose, silhouette, weapon/effect, palette, coarse pixel size and proportions. Do not redraw or add any character details. Keep its original relative centered placement and scale, full body visible, feet at about 84% of canvas height. Preserve the original wide landscape canvas aspect ratio. Fit the second environment behind it; environment contrast should be subdued so the existing character is legible. No new effects, glow, particles, borders, card frame, letters or numbers. Retain low-saturation crisp pixel-art rendering, no smoothing or photorealism. Output one finished card illustration only. Target card desert_nomad, background desert.
```

## 驗證

Godot 原生匯入新圖；tests/themed_card_art_capture.gd 使用正式 Card 場景與卡面 shader 截圖，檢查新版資源實際綁定。
