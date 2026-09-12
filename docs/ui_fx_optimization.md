# 特效與操作介面優化（2026-09-12）

沿用現有暗色金屬風格，這輪讓主要入口、操作狀態與效果結果更容易辨識。

- 主選單：單人遊戲使用主按鈕，圖鑑／設定並排，放大 UI 時縮減裝飾間距；修正開場淡入與進場淡出同時寫黑幕的問題。
- 操作介面：瞄準線增加暗底；長提示換行並依文字長度停留；最近訊息可收合、捲動，最新內容在上方。這是既有 `flash_message()` 的留存，不是完整戰鬥事件紀錄。
- 指令與預覽：顯示含裝備、狀態及生命上限加成的數值；無可用指令時焦點落在取消；開新指令會收起舊提示與瞄準線；預覽避開結束回合鍵。
- 操作防穿透：CardManager 在處理牌桌左鍵按下前檢查 HUD 區域，拖曳放開仍走原本流程。
- 特效：命中保留少量 GPU 火花並加像素命中；實際回血、加盾、施加灼燒／凍結／中毒／夜幕／鍛強／衰弱時播放對應動畫。減少動態模式使用短暫定格。

初版像素播放器保留在 `src/fx/pixel_effect.gd`；後續依要求，戰鬥接點已改用 `src/fx/spatial_effect.gd` 的 3D 演出，詳見下節。未增加依賴；未修改戰鬥費用、傷害公式或網路協定。通用傷害入口仍不區分傷害元素，元素辨識接在施加狀態時。

## 後續：3D 戰鬥特效

實際戰鬥已使用世界座標光環、GPU 粒子與透明護盾球殼，不再在同一接點疊加像素動畫。

| 結算入口 | 演出 |
|---|---|
| `take_damage()` → `FxBurst.spawn_at()` | 暖色擴散衝擊環、向外飛散火花 |
| 實際回血 `heal()` | 綠色上升光環與光粒 |
| `add_shield()` | 藍色透明球殼、邊緣發光與地面環 |
| 灼燒／凍結／中毒 | 橘紅火星／冰藍晶體／黃綠上升粒子 |
| 夜幕、衰弱／鍛強 | 紫色交錯光環／金色上升光環 |

幾何網格共用，演出不繼承卡牌縮放；宿主離場後仍播完，場景卸載則一起回收。最多同時保留 24 組演出，超出只略過視覺，不影響結算。低畫質減少粒子；減少動態模式關閉粒子與尺寸／位移動畫，僅短暫顯示和淡出。

`tests/spatial_fx_review.gd` 已以 Forward+ 跑真實牌桌，驗證結果接點、正常回收、宿主離場、減少動態與大量連擊上限；前中段截圖也已檢視。護盾／戰吼回歸通過；未量測 FPS，不能視為效能提升證明。護盾球殼是「加盾當下」的演出，持續盾值仍由原有狀態文字顯示。

```powershell
godot --path . --rendering-method forward_plus --script res://tests/spatial_fx_review.gd -- docs/spatial_fx
```

實機預覽：[命中／治療／護盾](spatial_fx_start.png)、[演出中段](spatial_fx_middle.png)、[火／冰／毒](spatial_fx_elements.png)。

## 驗證

Godot 4.7.2 的既有回歸與新增 UI／特效檢查已通過；截圖使用 Forward+，並檢視中文一般比例及英文放大比例。

| 檢查 | 結果 |
|---|---|
| `settings_test.gd` | PASS |
| `shield_battlecry_test.gd` | PASS，16 個斷言 |
| `arcana_effects_test.gd` | PASS，12 個斷言 |
| `quick_reaction_input_test.gd` | PASS，5 個斷言 |
| `ward_drag_input_test.gd` | PASS，4 個斷言 |
| `ui_fx_review.gd` | 特效素材與清除、訊息留存、HUD 不重疊、回合按鈕、數值與焦點檢查 |
| `.harness/verify.py`、`git diff --check` | PASS；harness 不代表遊戲驗收 |
| 完整人工對局、雙機連線、效能比較 | NOT RUN |

重現 UI 與特效驗證（將 `godot` 換成本機引擎路徑）：

```powershell
godot --path . --rendering-method forward_plus --script res://tests/ui_fx_review.gd -- docs/ui_battle_optimized.png commands
godot --path . --rendering-method forward_plus --script res://tests/ui_fx_review.gd -- docs/ui_battle_large_en.png en large
godot --headless --path . --script res://tests/ui_fx_review.gd -- review en large
```

截圖：[主選單](ui_menu_optimized.png)、[英文放大主選單](ui_menu_large_en.png)、[戰鬥提示](ui_battle_optimized.png)、[指令與預覽](ui_battle_optimized_commands.png)、[英文放大 HUD](ui_battle_large_en.png)。

本輪為直接實作，沒有進行理解評估；學習帳本狀態不變。
