# card-game-demo-4.5--main — 專案契約



此檔是 repo-specific 來源，可直接維護；共用政策改 ai-wrapper/rules 後同步。



## 專案速覽
- **引擎**:Godot **4.7**(2026-09-01 由 4.5 升級),語言 **GDScript**(無 C#)。
- **進入點**:`scenes/main_menu.tscn`(主選單)→「開始遊戲」→ `scenes/main.tscn`(牌桌;`main_scene.gd` 依 ArenaPool 抽籤抽換戰場)。
- **程式碼都在 [src/](src/)**:每個功能一個資料夾(`card/`、`card_manager/`、`card_slot/`、`play_hand/`、`player_board/`、`environment/`、`main_menu/`、`main_scene/`)。
- **只有一個 autoload:`AppSettings`**(`src/settings/app_settings.gd`,全域設定/語言/無障礙)。其餘狀態一律掛在節點上,互動中樞是 `CardManager`;跨場景傳值用 `ArenaPool`(static 類別,見 `src/environment/arena_pool.gd`),別為此再開 autoload。
  `AppSettings.current()` **保證不回傳 null**:編輯器裡沒有 autoload 時會給一個只帶預設值的備援實例——因為 146 個呼叫點沒有半個做 null 檢查。
- 算繪器:**Forward+**。`project.godot` 的 `config/features` 已於 2026-09-01 更新為 `("4.7", "Forward Plus")`(先前殘留 `"4.5", "GL Compatibility"` 的過時標籤)。
  **實測:編輯器不會自己同步這個標籤**(跑 `--import` 兩次 project.godot 零 diff),要改就用引擎 API 寫,別手編檔案:
  `ProjectSettings.set_setting("application/config/features", PackedStringArray([...]))` + `ProjectSettings.save()`。
  真正的設定鍵 `rendering/renderer/rendering_method` 仍不存在 = 吃預設 `forward_plus`,與標籤一致。
- 後製/燈光都在 `scenes/arena_forest.tscn`(被 main.tscn 實例化):WorldEnvironment(ACES/SSAO/SSR/霧/**glow 已啟用**,`glow_hdr_threshold=0.95`)+ 暖色 DirectionalLight3D。**main.tscn 自己沒有環境節點,別在那裡找。**

## 關鍵慣例(改 code 前先記住)
- **signal 中繼鏈**:每張 `Card` 的 hover 信號 → `PlayerHand`(中繼站,以自己名義轉發)→ `CardManager`(只訂閱這一個來源)。新增會發信號的物件時沿用這條鏈,別讓 `CardManager` 直接連每張卡。
- **`@tool` 腳本**:`player_hand.gd`、`environment/ground_generator.gd`、`environment/forest_scatter.gd` 會**在編輯器裡執行**。動它們前先想「這段現在是在編輯器跑還是遊戲裡跑」——編輯器裡 `@export` 指向的節點可能還沒就緒而為 `null`。
- **碰撞層**:Layer 1 = `Card`、Layer 2 = `CardSlot`(見 `project.godot`)。**射線打不到東西時,先懷疑 layer/mask 對不上,而非程式邏輯錯。**
- **群組**:`player_board.gd` 用群組(`player_front` / `player_back` / `enemy_front` / `enemy_back`)而非直接引用節點。改群組名要全場一起改。
- **生命週期**:`_ready()` 進場跑一次(放初始化、快照);`_process()` / `_physics_process()` 每幀跑(放持續性邏輯)。放錯地方是這類專案的高頻 bug。
- **節點路徑**:`$Area3D/CollisionShape3D` 這種字串路徑是相對自己往下找;**改場景樹結構會讓它默默失效**(不會編譯期報錯,執行才炸)。



玩法規格以 README.md Gameplay Spec 為準；Review 分工程慣例與玩法規格兩軸。

學習權威保留 docs/LEARNING_LEDGER.md（包括還債表及退關紀錄）；不要由 AI 產出推定升等。



## 驗證



精確命令維護在 `.harness/project.json`；`python3 .harness/verify.py --list` 列出，`--run --only ID` 執行。

未安裝工具、需要外部服務或人工視覺驗收時標 NOT RUN，不能回報全綠。
