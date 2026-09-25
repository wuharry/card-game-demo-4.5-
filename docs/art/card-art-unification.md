# 全卡池卡圖統一 · 2026-09-25

全卡池採用暗色像素場景插畫，保留卡牌題材差異；卡面、圖鑑、hover 預覽、選牌與墓地紀錄共用相同取景。

| 範圍 | 處理方式 |
|---|---|
| 已有主題插畫的 91 張卡 | 沿用構圖；其中 5 張修正半透明像素，全部套用正確卡窗 |
| 冰霜女巫 | 保留既有雪景，作為冰雪背景參考 |
| 其餘 40 張卡，含 12 張 Time Fantasy | 新增主題插畫並更新 CardData.art |
| 新增背景 | 冰雪山原、暗色海岸、星界遺跡 |
| 戰鬥動畫與玩法 | 保留原始動畫、技能和數值 |

## 構圖與顯示

卡窗實際尺寸是 42 × 34 像素，程式原先誤將卡框外緣的透明像素也算入，使用了 64 × 34 的寬度，讓插畫兩側又被框遮掉。

修正 `Card.ART_WINDOW_SIZE` 後，卡面依真實開口置中裁切；`Card.face_art()` 統一供應其他 UI 的 AtlasTexture。四色卡框的透明開口都有量測檢查，`tests/probe_sheet_alpha.gd` 也改為只量與中心相連的透明區域。

插畫維持橫向畫布、主體置中、背景較暗。一般角色目標高度約佔原圖一半至六成，頭、腳及武器保留空間；法術維持原有符號及效果。畫布解析度不必完全相同，取景以正式卡窗的長寬比為準。

## 素材與追溯

新增插畫使用 imagegen 技能的內建編輯模式，原圖完整保留。生成式編輯以保留角色辨識及符號為目標，不保證前景與原圖逐像素相同；Time Fantasy 的戰鬥動畫仍使用原作者像素。

- [全卡池主題與正式圖片路徑](card-background-manifest.json)
- [本次完整提示詞與輸入／輸出路徑](card-art-unification-prompts.json)
- [可搜尋的原圖／新版對照](all-card-backgrounds-review.html)
- 新圖：`assets/ui/card_art/<id>_themed_card_art.png`
- 新背景：`assets/ui/card_art/backgrounds/card_bg_<theme>.png`

對照頁預設使用正式卡窗取景，可切換完整插畫；頁尾連結至正式 Card 場景輸出的全卡池截圖。

## 重建與驗證

以下命令使用專案既有 Godot 與 Python，不需要安裝套件。圖像生成提示詞需由 imagegen 工具執行；下面的命令只更新對照頁、匯入資源與驗證顯示。

```powershell
python tests/build_card_art_review.py
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/card_pool_verify.gd
godot --headless --path . --script res://tests/all_card_backgrounds_capture.gd
godot --headless --path . --script res://tests/card_art_consistency_verify.gd
godot --headless --path . --script res://tests/time_fantasy_verify.gd
godot --path . --rendering-method forward_plus --resolution 1920x1080 --script res://tests/all_card_backgrounds_capture.gd -- capture
```

一致性檢查會實例化 Card、圖鑑、BattleUI 與墓地 UI，比對整個卡池的來源貼圖、裁切區域及像素濾鏡，也涵蓋舊從者缺少專用插畫時的待機圖備援。全卡池綁定檢查另外要求每張專用插畫完全不透明，避免背景透出或 UI 間顏色不同。截圖使用 Forward+；通過資源及取景檢查不代替目視確認。

## 實際驗收 · 2026-09-25

正式卡框的全卡池截圖已逐頁查看，角色及法術主體都留在卡窗內，未發現圖片凸框或缺圖。

| 檢查 | 結果 |
|---|---|
| Godot 4.7.2 資源匯入 | PASS |
| 卡池資料 | PASS：132 張載入、315 項檢查 |
| 圖片綁定與不透明背景 | PASS：132 張 |
| 卡面與圖鑑／預覽／選牌／墓地取景 | PASS：532 次比對、0 失敗 |
| Time Fantasy 素材與實際技能執行 | PASS：880 項檢查、0 失敗 |
| Forward+ 正式卡框截圖與目視 | PASS：11 頁，每頁 1920 × 1080 |
| Chrome 離線對照頁 | PASS：132 筆卡牌、264 個圖片元素 |
| harness 投遞完整性 | PASS；應用驗證另外執行如上 |

本次沒有提供 Time Fantasy 原始 ZIP，因此未執行可選的逐幀 ZIP 像素比對；Git 差異確認動畫檔沒有修改。上述目視涵蓋靜態卡面，未逐張操作完整對戰。截圖的實際尺寸以 PNG 為準，專案視窗設定會覆蓋命令列的初始解析度。
