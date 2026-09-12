# 高清秘術演出（2026-09-12）

三張指定秘術已使用專屬 3D 演出，並在傷害核准時立即命中；維持既有同步扣血與反制規則。

| 卡牌 | 演出 | 動態預覽 |
|---|---|---|
| 火焰爆裂 | 流動雜訊火焰材質、爆發波紋、火星、暖色點光源 | [播放](hd_spell_arcana_fireblast.webp) |
| 雷霆貫穿 | 帶狀雷電分支、亮芯與外光、冷色照明；保存前後排命中位置 | [播放](hd_spell_arcana_thunder_pierce.webp) |
| 凍土脈衝 | 立體冰晶、透明受光面、碎光與擴散波紋 | [播放](hd_spell_arcana_frozen_pulse.webp) |

`BattleManager.cast_arcana()` 通過伏印判定後發出 `arcana_visual_requested`，`CardManager` 訂閱並轉給 `src/fx/spell_effect.gd`。播放器依卡片資源名稱選演出，不新增玩法欄位；宿主死亡後使用已保存的世界位置播完。瞬咒或伏印取消時不播成功命中。專用伺服器不建立視覺節點。

減少動態模式只顯示短暫地面光圈；低畫質減少粒子並關閉短暫點光源，同時演出有上限。這是三張法術的專屬演出，沒有新增飛行物延遲扣血，也沒有取代全部技能效果。

## 驗證與預覽

真實牌桌、反制與生命周期檢查已通過；動態預覽由 Forward+ 遊戲畫面錄製並轉成 WebP，不是概念圖。

| 檢查 | 結果 |
|---|---|
| `spell_visual_integration_test.gd` | PASS，16 個斷言：同步傷害、凍結、致死貫穿快照、伏印／瞬咒取消、AI、連線本地重放、server 防護 |
| `spell_visual_lifecycle_test.gd` | PASS，18 個斷言：清除、世界位置、減少動態、同時演出上限、宿主與場景離場 |
| `spell_visual_capture.gd` | PASS，Forward+ 畫面已檢視 |
| 完整雙機連線、FPS 與多種 GPU 比較 | NOT RUN |

循環預覽（關閉遊戲視窗結束）：

```powershell
& 'E:/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path . --rendering-method forward_plus --script res://tests/spell_visual_capture.gd -- docs/hd_spell preview
```

開發方向參考 [Acquire 的 Unreal Engine 訪談](https://www.unrealengine.com/spotlights/octopath-traveler-s-hd-2d-art-style-and-story-make-for-a-jrpg-dream-come-true)：讓特效搭配點光源影響場景。這裡使用 Godot 自製材質與幾何，並非原作素材或完整重製。

## 本機 Godot 啟動修復

桌面與工作列捷徑指向已不存在的引擎，已將目標修正為 `E:/Godot_v4.7.2/Godot_v4.7.2-stable_win64.exe`。

修正前桌面指向 `E:/godot.exe`，工作列指向 `E:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`；原捷徑已備份至本機 TEMP 的 `godot-shortcut-backup-20260912-135456/`。保留現有編輯器程序並移到前景，未強制關閉或刪除專案快取。專案在現有引擎上成功完成載入檢查。
