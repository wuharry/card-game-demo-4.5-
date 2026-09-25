# 戰鬥演出與 HUD 優化

本輪已把劍士斬擊、雷霆貫穿、命中停頓及資源提示接入真正的戰鬥流程。可直接開啟 [實機動態預覽](combat-feedback-preview.html)，查看斬擊、格擋、雷擊，以及中英文 HUD。

演出按照「接受行動 → 起手 → 命中結算 → 回饋 → 清除」執行，規則仍由 BattleManager 負責。例如伏印取消攻擊技能時，不播放成功刀光；雷電回閃也不會再次扣血。

| 範圍 | 完成內容 |
| --- | --- |
| 近戰角色 | 移動到敵人側前方、出手、命中停頓後退回；只移動立牌，不移動卡槽／碰撞；持刃角色另加弧形刀光 |
| 遠程與非攻擊技能 | 弓箭手、法師等遠程卡原地出手；治療／加盾不突進；每張卡可用 `approach_on_attack` 調整 |
| 共用傷害 | 暖色命中射線、粒子與短暫燈光；較重的命中增加停頓與鏡頭回饋 |
| 護盾 | 藍色格擋火花、護盾消耗數字、較高音調的接觸聲；全額吸收不產生扣血數字 |
| 雷霆貫穿 | 主雷與不同形狀的回閃、白色亮芯／藍色外光、地面分岔、粒子、環境照明 |
| 傷害數字 | 掛在場景上，目標離場也能讀完；反擊爆點與數字使用移動後的角色腳位；連擊與盾／血數字分層顯示 |
| HUD | 魔力總量、正常／暫時魔力、暫時魔力到期提示、當次增減；單位面板顯示護盾、狀態回合與已消耗行動 |
| 放大介面 | 資源面板避開結束回合；左上工具列移成橫排；英文換回合後按鈕恢復固定寬度；預覽向左擴展 |
| 音效 | 輕重／格擋的變調；同幀同音源合併、限制重疊數；使用獨立 RNG，不干擾抽牌亂數 |
| 減少動態 | 關閉新生成的前衝、刀光、Hit-stop、鏡頭震動、粒子與短暫燈光；保留靜態命中提示與飄字閱讀時間 |

時間參數集中在演出腳本，命中規則沿用原有延遲。這樣可以調整手感而不改變攻擊、反擊、護盾或連線結算。

| 參數 | 設定值／用途 |
| --- | --- |
| 從者命中點 | 起手後 0.35 秒；`actor_feedback.gd` 的 `CONTACT_TIME` |
| 抵達時間 | 起手後 0.18 秒抵達，接著播放揮擊；有 Run 動畫時先播放跑步 |
| 接近距離 | 停在目標側前方約 0.95 個世界單位；依世界座標及鏡頭方向計算 |
| 歸位 | 命中後保留出手姿勢，自演出時間 0.46 秒起退回，耗時 0.28 秒；Hit-stop 會延後視覺歸位 |
| 一般 Hit-stop | 0.055 秒；只暫停角色動畫 Tween 與前衝 |
| 重擊 Hit-stop | 傷害量至少 5 時，0.075 秒 |
| 護盾 Hit-stop | 0.045 秒 |
| 鏡頭震動 | 0.2 秒內衰減；同時命中取最大強度，避免全體傷害累加 |
| 音效上限 | 總數 16 聲、同音源 3 聲；同幀同音源只播一次 |
| 飄字 | 正常／減少動態皆保留約 0.9 秒 |
| 動態預覽 | Forward+、1280 × 720、固定錄製時間步長 30 fps；不是效能量測 |

主要入口如下。`CardData.approach_on_attack` 預設開啟；遠程角色在卡片資源中設為 `false`。刀光另外由 `slash_effect.gd` 的 `BLADE_USERS` 決定，所以槍兵、獸人等角色也會接近目標，不必為了移動而套用刀光。

移動中目標離場會退回，施放者死亡則停在交戰位置播放死亡動畫；傷害結算前再次檢查雙方存活，避免已經倒下的角色繼續出手。途中切換「減少動態效果」也會收回位移並結束跑步動畫。

```text
CardManager.action_performed
  → BattleManager 接受行動與反制檢查
  → Card.play_action_animation：跑步接近 → 抵達後揮擊
  → 等待 CONTACT_TIME
  → 傷害／護盾／反擊結算
  → 刀光、飄字、ActorFeedback、CameraImpulse、Sfx

cast_arcana
  → 原有同步傷害結算
  → arcana_visual_requested（保存世界落點）
  → SpellEffect 的主雷／回閃／餘光
```

| 驗證 | 結果 |
| --- | --- |
| `combat_feedback_review.gd`，headless | PASS：34 項，含規則、Hit-stop 換動畫後恢復、回復基準位置、取消行動、低動態、音效 RNG 與清除 |
| `attack_approach_test.gd` | PASS：25 項，含抵達距離、卡槽／碰撞不動、反擊位置、英雄、遠程、反向視角／縮放、連續起手、死亡／離場與低動態 |
| `card_pool_verify.gd` | PASS：315 項；全部卡牌可載入新增的演出設定 |
| 同腳本，Forward+，繁中／英文 150% | PASS：各 38 項，含截圖；已檢視斬擊、雷擊、護盾與 HUD 畫面 |
| `spatial_fx_review.gd` | PASS：正常／低動態、宿主死亡、數量上限與清除 |
| `spell_visual_integration_test.gd` | PASS：16 項，含反制、貫穿、致死目標位置、AI／連線本地重放／專用伺服器 |
| `spell_visual_lifecycle_test.gd` | PASS：18 項，另以 verbose 獨立重跑 |
| `shield_battlecry_test.gd` | PASS：16 項 |
| `arcana_effects_test.gd` | PASS：12 項 |
| `quick_reaction_input_test.gd` | PASS：5 項 |
| `ai_turn_test.gd` | PASS：AI 自動召喚、攻擊與交回回合 |
| `ui_fx_review.gd` | PASS：中英文、放大 HUD、卡片預覽與結束回合分離 |
| 預覽網頁 | PASS：Chrome 實際載圖、切換、拖動時間軸、播放；窄螢幕無橫向溢出 |
| Harness／diff | PASS：`python3 .harness/verify.py` 投遞完整性、`git diff --check` |
| 實際聽感／長時間效能／雙機連線 | NOT RUN；音效目前驗證播放邏輯、變調與重疊限制，未做人工試聽 |

一次平行執行生命週期測試曾出現退出時資源清理警告；獨立 verbose 重跑未重現。節點回收斷言皆通過，未將此視為長時間記憶體或效能驗收。

驗收用的 [capture 腳本](../tests/combat_feedback_capture.gd) 直接輸出 viewport 連續畫面；`docs/combat-feedback-preview/` 使用 `.gdignore`，避免展示檔被匯入成遊戲資源。測試與截圖腳本只修改當次執行中的設定，不呼叫 `save_settings()`。

```powershell
$combatGodot = 'E:\06_Apps\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $combatGodot --headless --path . --script res://tests/combat_feedback_review.gd
& $combatGodot --path . --rendering-method forward_plus --fixed-fps 30 --script res://tests/combat_feedback_capture.gd
```
