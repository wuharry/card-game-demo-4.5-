# 試玩回饋：卡片操作與召喚物預覽驗收

本次修改解決朋友週末試玩的兩個問題：取消卡片操作太費事，以及召喚物無法從說明直接查看。回饋於 2026-09-29 整理；確切試玩日期未另外確認。

## 回饋與改善方向

驗收以玩家能否順手操作、看懂效果為準；Harvey 指定參考爐石與闇影詩章的操作優點。

| 來源 | 玩家遇到的問題 | 本次要達成的行為 |
|---|---|---|
| 朋友試玩回饋 1 | 點卡後，點別處不會收起左下指令視窗，必須移去按取消 | 點空白取消；點另一張場上卡直接換選；點手牌直接開始拖曳 |
| 朋友試玩回饋 2 | 召喚法術只寫召喚物名字，不能查看它的卡片資料 | 召喚物名稱變色並加底線，hover 後就地顯示卡圖、攻血、關鍵字與技能 |

## 玩家討論參考與適用界線

公開討論補充了「資訊容易查，也不能干擾操作」的取捨；這是設計歸納，不代表兩款遊戲目前每一處都採用相同操作，也不是玩家共識統計。

- 爐石玩家曾指出沒有 hover 說明的按鈕需要額外點入查看，以及操作反悔不便。本次取用的是「降低查資訊與取消的成本」。來源：[Hearthstone UI 討論](https://www.reddit.com/r/hearthstone/comments/14qhdfd/)。
- 闇影詩章玩家也有人希望關閉自動 hover 詳情，說明預覽是否干擾操作需要實測。本次保留游標移入詳情的短暫時間，離開後自動關閉，拖曳時關閉預覽。來源：[Shadowverse hover 討論](https://www.reddit.com/r/Shadowverse/comments/1liduv4/)。
- 爐石社群網站 HearthPwn 展示過關聯卡片 hover、點背景或 Esc 關窗，並指出衍生卡內容過多時需要捲動。本次參考就地查關聯卡與小視窗可捲動的做法；這是網站功能，不能當成爐石遊戲本體的既有行為。來源：[HearthPwn 關聯卡預覽介紹](https://www.reddit.com/r/hearthstone/comments/15750dh/weve_created_a_huge_new_improvement_on_hearthpwn/)。

## 操作規則與手動驗收

一般卡片指令可隨時反悔；反制、已付費選牌與等待連線結果必須維持原本流程。開指令時收起右側主卡預覽，使用左下技能說明查召喚物，避免大字模式的兩塊主卡面板擋住換選目標。

| 案例 | 重現步驟 | 預期結果 |
|---|---|---|
| 點空白收起 | 點場上生物，再點不屬於 UI 的空白牌桌 | 左下指令與預覽收起，選取／瞄準狀態清除，不扣費 |
| 直接換卡 | 點生物 A，再點另一隻生物 B | 直接顯示 B 的指令，不需先按取消 |
| 重複點選 | 點生物 A，再點 A | 收起指令 |
| 接續出牌 | 開著生物指令，按住未被 UI 遮住的手牌 | 關閉指令並立即開始原本的拖曳流程 |
| 接續查戰報 | 開著生物指令，點 HUD 戰鬥紀錄 | 關閉指令並開啟戰報，不必另按取消 |
| 面板內操作 | 點指令按鈕、說明文字、召喚物詳情 | 不穿透到背後卡片；攻擊／技能按鈕照常運作 |
| 既有反悔手勢 | 在指令／拖曳／瞄準中按右鍵或 Esc | 經原本取消入口收尾 |
| 反制保護 | 施法觸發守方瞬咒窗口，點空白、其他卡或右鍵 | 保留反制決策，不能藉此操作牌桌；回答後正常繼續 |
| 選牌保護 | 已支付費用、正在選擇抽濾卡片時點空白 | 必須完成選牌，不能取消而免費偷看 |
| 連線等待 | 等待對方反制結果時點空白或右鍵 | 不能自行解除等待 |

## 召喚物資訊驗收

詳情引用真正的召喚資料；查看資訊不生成生物、不消耗卡牌與魔力，也不改變結算。

| 案例 | 重現步驟 | 預期結果 |
|---|---|---|
| 召喚主動技 | 查看死靈法師，hover 說明中的骷髏兵 | 名稱有底線與顏色，彈出骷髏兵模板資訊 |
| 召喚秘術 | 查看亡者召集、地獄犬等召喚秘術 | 同樣能查看技能 `summon_card` 指向的生物 |
| 特殊衍生物 | 查看亡軍之門、替身秘偶伏印、王墓陷阱 | 分別顯示實際墓衛、替身秘偶、王墓守衛資料 |
| 卡文別稱 | 查看惡魔守衛召喚技能 | 顯示實際召喚的蝙蝠，避免只寫「爪牙」卻查不到 |
| 自我分裂 | 查看史萊姆或熔岩史萊姆的召喚物 | 只展開一層相關卡片，不無限開窗 |
| 指令說明 | 場上點死靈法師，移到技能再移到說明內名字 | 左下說明也能開啟召喚物預覽；不能使用技能時仍可查資料 |
| 移入詳情 | hover 卡片，離開後在保留時間內移入右側面板 | 詳情保持開啟，可以繼續把游標移到召喚物名稱 |
| 離開詳情 | 把游標移到空白處並停留 | 主卡與召喚物詳情自動收起 |
| 來源消失 | 預覽開啟時讓來源卡離場／釋放 | 不殘留無效預覽 |
| 小視窗／大字 | 在 1280×720、100%／150% UI 比例查看長說明 | 面板留在畫面內，內容必要時可捲動，相關卡不蓋來源文字 |
| 英文 | 切換英文查看召喚法術與特殊 token | 連結仍指向相同資料，不能依中文卡名硬猜 |

## 可重跑的檢查

自動檢查使用真實牌桌、座標輸入與 RichTextLabel 的 GUI 命中；視覺驗收另外使用 Forward+ 輸出截圖。

```sh
godot --headless --path . --script res://tests/playtest_ui_test.gd
godot --path . --rendering-method forward_plus --resolution 1280x720 \
  --script res://tests/playtest_ui_test.gd -- --capture=build/playtest-ui/default
godot --path . --rendering-method forward_plus --resolution 1280x720 \
  --script res://tests/playtest_ui_test.gd -- large --capture=build/playtest-ui/large
godot --headless --path . --script res://tests/playtest_ui_test.gd -- en large
```

## 驗收紀錄

開發驗證與朋友重新試玩分開記錄；自動測試通過不能代替玩家確認操作手感。

| 檢查 | 結果 | 證據／限制 |
|---|---|---|
| 新增 UI 行為測試 | PASS | `playtest_ui_test.gd`；中文 100% 與英文 150% headless 各 65 項、0 失敗；中文 100%／150% Forward+ 各 68 項、0 失敗（各包含 3 張截圖） |
| 既有拖放／反制／卡圖回歸 | PASS | 秘術拖放 45 項、伏印拖放 4 項、瞬咒反制 5 項、墓地／戰報、hover 30 輪、卡圖 532 次比對、UI/FX review；各腳本退出碼皆為 0 |
| Forward+ 截圖檢視 | PASS | 已檢視 1280×720、100%／150% 的主卡與召喚物並排、特殊 token、左下技能說明；圖片位於下列本地產物目錄 |
| 朋友重新試玩 | NOT RUN | 需由試玩者確認取消與查召喚物是否順手 |

部分既有回歸腳本結束時仍印出 ObjectDB／resource-in-use 訊息；本次未驗證這些腳本的完整資源釋放，行為通過不代表無資源警告。連線等待驗證使用本機狀態，未另外進行雙機實玩。

本地截圖（`build/` 已由 repo 忽略，可用上方命令重建）：

- `build/playtest-ui/default/`：`summon_preview.png`、`token.png`、`command_reference.png`。
- `build/playtest-ui/large/`：相同三個場景的大字版本。

新增程式使用 Godot [RichTextLabel 的 metadata hover 訊號](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html) 連到效果引用的 `CardData`。一般召喚讀取 `SkillData.summon_card`；現有三種特殊召喚依 `special_id` 對應 token，後續新增同類特殊效果須同步維護 `CardDetailPanel.SPECIAL_SUMMONS`。

實作入口：[CardManager](../src/card_manager/card_manager.gd)、[BattleUI](../src/battle_ui/battle_ui.gd)、[CardDetailPanel](../src/battle_ui/card_detail_panel.gd)。
