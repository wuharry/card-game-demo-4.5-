# 學習債清單(Learning Ledger)

> **這是什麼**:逃生艙 / AI 代工做出來、但 Harvey(Godot 新手)未必理解的觀念總帳。
> 建帳日 2026-07-06;主帳範圍 = commit `cbb80f4`…`f11931d`(Harvey 指定的逃生艙區間)。
>
> **給 agent 的使用規則**:
> 1. **出題時機**:只在 Harvey 主動說「我要複習 / 考我 / 學以前的東西」時啟動,平常別轟炸。
> 2. **怎麼挑**:優先挑等級最低、最久沒驗的;一次最多 2–3 題。
> 3. **考完就記帳**:更新等級欄(附日期+判定依據)。答不出 → 照 CLAUDE.md §3 換方式教,教完維持原級、下次再驗,**不要教完就直接升級**。
> 4. **之後每次逃生艙任務收尾**:把新產生的觀念補進本表(預設「初階/未驗」)。

## 等級定義(Harvey 自訂)

| 等級 | 意義 |
|---|---|
| **初階** | 需要 agent 主動指導、主動提醒、或稍微修正才能運用 |
| **中階** | agent 問他能很好地回答,有不錯的熟悉度 |
| **高階** | 能處理延伸題;做大任務完全不需幫忙;以前會卡的地方現在不卡 |

升級判準:初階→中階 = 被問能答出「是什麼 + 為什麼這樣設計」;中階→高階 = 能答延伸題、或在新情境自己把觀念用出來。

---

## 主帳(cbb80f4…f11931d)

### 1. 溪流水面 shader(`cbb80f4`;[assets/water/stream_water.gdshader](../assets/water/stream_water.gdshader))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| shader 在哪跑:fragment 每幀·每像素·在 GPU;跟 `_process`(CPU、每幀一次)的量級差 | 初階/未驗 | 「水面波紋一秒被算幾次?搬到 `_process` 用 CPU 算會發生什麼?」 |
| 法線貼圖騙光:波紋是「動法線騙光照」,網格根本沒動 | 初階/未驗 | 「把相機貼平水面側看,水面是平的還是起伏的?那為什麼正看有波?」 |
| `TIME` 驅動 UV 捲動(動畫的來源) | 初階/未驗 | 「波紋為什麼會流?TIME 乘 2 畫面變什麼樣?」 |
| SSR 螢幕空間反射:只能反射「當前畫面裡有的東西」 | 初階/未驗 | 「為什麼樹一被鏡頭切出畫面,水裡倒影就消失?」 |

### 2. 程序化地板(`785c975`、`598cd03`;[src/environment/ground_generator.gd](../src/environment/ground_generator.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 噪聲 vs 純隨機:FastNoiseLite「相鄰值相近」所以成簇;`randi` 是雪花點 | 初階/未驗 | 「想要泥巴斑塊更大顆,調 frequency 還是 threshold?兩者各控制什麼?」 |
| 閾值切分:連續噪聲值 → 離散磚種(草 / 泥 / 過渡磚) | 初階/未驗 | 「過渡磚是怎麼被選中的?畫出噪聲值軸上三個區間」 |
| GridMap + MeshLibrary 的分工(棋盤格 vs 磚的字典) | 初階/未驗 | 「新增一種磚要動哪邊?鋪磚邏輯要改嗎?」 |
| `598cd03` 的 bug 根因:磚隨機朝向 → 部分磚光照/UV 方向錯 → 深色斑塊 | 初階/未驗 | 「為什麼『轉一下磚』會讓它變深色?跟法線的關係?」 |

### 3. 森林散佈([src/environment/forest_scatter.gd](../src/environment/forest_scatter.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 成簇散佈(先選簇心、再繞著撒點)與內圈淨空(排除區判定) | 初階/未驗 | 「為什麼牌桌正中央永遠不會長樹?淨空是在哪一步被保證的?」 |
| alpha scissor(鏤空)vs alpha blend:樹葉用 scissor 是為了躲透明排序問題 | 初階/未驗 | 「樹葉改用 alpha blend 會出什麼視覺 bug?為什麼 scissor 沒這問題?」 |
| 生成的節點不設 owner → 不會存進 .tscn(場景檔保持薄,內容由 code 重建) | 初階/未驗 | 「編輯器裡看得到幾百棵樹,.tscn 檔裡卻沒有它們——為什麼?這樣的好處?」 |

### 4. 卡牌互動 code review 清理(`80b6ed8`)

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 封裝:`play_card()` 收進 PlayerHand,外部不直接動 `cards` 陣列 | 初階/未驗 | 「如果 CardManager 直接 `cards.erase(card)`,少做了什麼事?會出什麼 bug?」 |
| `@export` 節點注入 vs `$` 字串路徑(`node_paths` 的意義;場景樹搬家誰會壞) | 初階/未驗 | 「把 PlayerHand 在場景樹搬到別層,@export 注入和 `$../PlayerHand` 誰活誰死?」 |
| 靜態型別標註的好處(自動補全、錯誤提早在編輯期爆) | 初階/未驗 | 「`var card: Card` 比 `var card` 多買到哪兩件事?」 |

### 5. Label3D 深度與數值顯示(`493de31`、`57499e0`)——已教學

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| local 偏移跟著節點旋轉走(牙籤模型):z 偏移只有面向相機時才是「深度」 | **中階**(2026-07-06 理解題通過:垂直俯視→貼合,含平躺卡前提推理正確) | 升高階:給新情境(如怪物頭上血條在斜視角穿模)讓他自己開藥方 |
| z-fighting 根因與三種解法的取捨:縮短偏移 / render_priority / no_depth_test | 初階/未驗(修法是 AI 給的) | 「no_depth_test 什麼時候該用?在手牌扇形重疊下的代價是什麼?」 |

### 6. WorldEnvironment 後製棧([scenes/arena_forest.tscn](../scenes/arena_forest.tscn) 內)

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| glow 與 HDR 門檻:亮度超過 `glow_hdr_threshold`(0.95)才泛光;emission 是主要推手 | 初階(2026-07-06 教過,未驗) | 「為什麼 emission 3.0 會泛光、0.5 不會?門檻設定在哪個檔的哪個節點?」 |
| ACES tonemap / SSAO / 霧 各自解決什麼問題 | 初階/未驗 | 「關掉 SSAO 畫面會少什麼?tonemap 是在管什麼的?」 |
| 設定檔「沒寫 = 預設值」:`rendering_method` 缺席 = forward_plus;features 標籤 ≠ 開關 | 初階(2026-07-06 教過,未驗) | 「project.godot 找不到某設定鍵,代表什麼?去哪確認地面真相?」 |

### 7. 本 session(2026-07-06)新教觀念,一併記帳

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 資料/視覺分離:會變的 = 資料 + 文字節點;不變的外觀 = 圖 | 初階(火球術題答半對:知道差在資料層,但誤以為「資料 = 改 code」) | 「新增一張卡要動哪些檔、不動哪些?」→ 親手做過 .tres 後再驗 |
| Resource 預設共享 vs Local to Scene:Node 每實例一份、Resource 全場一份 | 初階(教過,未驗) | 「不開 Local to Scene,10 個卡槽為什麼一起亮?CardData 的共享為什麼反而是優點?」 |
| 扇形間距幾何:`sin(gap)×radius` vs 卡寬 決定重疊 | 初階/未驗 | 「手牌變 7 張會發生什麼?哪個上限先卡住?」 |

---

## 續帳(f11931d…HEAD,本機 session;2026-07-06 依 session 全記錄補齊)

> 原「待分類」五條全部展開移入。等級照規則預設「初階/未驗」;
> 有實際問答依據的兩處已標註(§12 河道根因 = 中階、§9 出血 / §11 錨點 = 出過題未答)。

### 8. CardData 資料層實作(`dda702a`;[src/card/card_data.gd](../src/card/card_data.gd)、[data/cards/](../data/cards/))

> 觀念層(資料/視覺分離)在主帳 §7,這裡是實作層。

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| .tres 檔解剖:ext_resource(引用外部檔)vs sub_resource(內嵌小資源) | 初階/未驗 | 「打開 knight.tres:哪行是引用、哪行是內嵌?刪掉被引用的 png 會發生什麼?」 |
| AtlasTexture:在大圖上「框一格」當獨立貼圖(卡圖佔位 = 動畫表第 0 幀) | 初階/未驗 | 「region = Rect2(0,0,100,100) 在說什麼?想改用第 3 幀改哪個數字?」 |
| DirAccess 掃資料夾 + 懶載入(卡池第一次要用才載);`.remap` 後綴剝除 | 初階/未驗 | 「卡池是開遊戲瞬間載入,還是第一次發牌才載?懶載入買到什麼?」 |

### 9. 卡圖挖空窗與召喚立牌(`016cb9a`、`42e4dfc`;[src/card/card.gd](../src/card/card.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 透明繪製順序:卡圖擺卡框「後面」(z=-0.01)從挖空窗露出 → 怎麼縮放都壓不到框的美術 | 初階/未驗 | 「為什麼放後面反而安全?改成 +0.01 疊前面會出什麼事?」 |
| 出血(bleed):遮罩決定形狀、內容做大藏在遮罩後——卡圖出血 6% 和水面板加寬是同一條原則 | 初階(2026-07-05 出題未答;**2026-07-11 進步**:圖示 cover 題自己推出「畫大會凸出」,但「凸出被框蓋住所以沒事」仍由 agent 補完,補齊這半即可升中階) | 「bank_jitter 調到 2.0,水面板要多寬才不露餡?公式?」 |
| 可見範圍掃描:alpha 掃出角色實佔行列,大小/腳位用「量出來的」——100×100 格子裡角色只有 ~30px,信帳面就會又小又飄 | 初階/未驗 | 「按整格算,角色為什麼只剩帳面 1/3 還懸空?掃描一次解決哪兩件事?」 |
| Sprite3D 立牌三件套:hframes 切格(幀數=寬÷高)、tween_callback+set_loops 播待機、BILLBOARD_FIXED_Y 直立面向鏡頭 | 初階/未驗 | 「幀數 6 是誰算出來的?為什麼這批素材能用寬除以高?」 |
| 旋轉疊加(§5 牙籤原則的旋轉版):place_card 轉 local (0,0,0) 就是躺平——父節點 PlayerHand 已 -90°X;再補 -90 卡會立起來 | 初階/未驗 | 「卡在槽裡 local rotation=0,世界裡為什麼是躺的?『躺』是誰給的?」 |

### 10. 戰場家族與輪替(`3d9d5da`;[src/environment/arena_base.gd](../src/environment/arena_base.gd)、[arena_pool.gd](../src/environment/arena_pool.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 場景繼承:共同流程在基底(環境/地板/散佈工具),子類只覆寫 `_build()` | 初階/未驗 | 「新增『沙漠』牌桌要寫哪些函式、哪些直接繼承來用?」 |
| static 類別變數跨場景傳值:static 活在類別上,change_scene 清不掉(ArenaPool 不用 autoload 的原因) | 初階/未驗 | 「換場景後 main.tscn 為什麼還讀得到抽籤結果?什麼時候該升級成 autoload?」 |
| free() vs queue_free():queue_free 等幀尾才刪;換 WorldEnvironment 必須立刻 free,兩環境並存一幀會打架 | 初階/未驗 | 「哪種情境不能等幀尾?main_scene.gd 那行為什麼用 free()?」 |

### 11. 主選單(`d36e167`;[src/main_menu/main_menu.gd](../src/main_menu/main_menu.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 錨點=比例、偏移=像素修正;`set_anchors_preset` 只動錨點且「保留當下矩形」→ UI 鎖死在舊視窗大小(置中 bug 根因);帶 `and_offsets` 的才等於 Layout 選單 | 初階(2026-07-05 教過+出題未答) | 「編輯器裡擺好的 Control 呼叫 set_anchors_preset 會不會歪?跟 code 生成的 0×0 新節點差在哪?」 |
| CanvasLayer:2D 疊層永遠畫在 3D 之上(選單、黑幕都掛它下面) | 初階/未驗 | 「UI 不掛 CanvasLayer、直接掛在 Node3D 下會發生什麼?」 |
| 主題覆寫做文字選單:normal 給 StyleBoxEmpty、hover/focus 共用「只開下邊框」的 StyleBoxFlat → 滑鼠/鍵盤回饋一致 | 初階/未驗 | 「為什麼 focus 也要接樣式?只接 hover 冷落了誰?」 |
| 轉場模式:鎖按鈕 → tween 黑幕 → `await tw.finished` → change_scene_to_file,失敗要還原 | 初階/未驗 | 「await 那行在等什麼信號?不鎖按鈕連點兩下會怎樣?」 |

### 12. 森林地形整修(`04f8bbf`;[ground_generator.gd](../src/environment/ground_generator.gd)、[forest_scatter.gd](../src/environment/forest_scatter.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 水面必須是「局部最低點」:換材質治標、換高度治本 | **中階**(2026-07-05 自己推出根因與修法方向) | 升高階:新情境開藥方——「岩漿池 / 流沙坑要怎麼做才不浮?」 |
| 磚是紙片、貼 cell 正中央:面高度 = (y_level + 0.5) × cell_size.y = -0.5;「地表在 0」是幻覺,樹和水都因此浮過 | 初階(兩個高度數字自己查到;薄片幾何是 AI 量的) | 「y_level -3、cell_size.y 0.2,地表在哪?想要 0.1 深的河改哪兩個數字?」 |
| cell_size.y 當垂直解析度:GridMap 只能整格跳,格距改細 = 垂直步距變細(1 → 0.2) | 初階/未驗 | 「為什麼不能『把河床磚往下移 0.2』,非得動 cell_size?」 |
| 薄片模型處置:兩片十字交叉才不會側面消失;用 AABB 反推貼地 / 露頂高度(土丘埋地只露丘頂) | 初階/未驗 | 「_make_prop 怎麼判斷要不要交叉?土丘的 Y 是怎麼算出來的?」 |
| 面積均勻取樣:環帶內半徑要用 sqrt(rand) 插值,否則點擠內圈 | 初階/未驗 | 「為什麼要開根號?不開的話點擠哪邊、為什麼?」 |
| headless Godot 當診斷工具:`--headless -s` 跑一次性腳本印 AABB——「用量的代替用猜的」 | 初階/未驗 | 「想知道某個 mesh 的實際尺寸和原點,除了拖進場景目測,還有什麼辦法?」 |

### 13. 工作流的坑(跨任務,反覆咬人)

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 編輯器舊緩衝蓋檔:外部改過 .gd/.tscn 後回 Godot,提示一律選 **Reload**,否則一存檔就把改動蓋回舊版 | 初階(本 session 踩過多次) | 「什麼情況會跳這個提示?選錯會發生什麼、怎麼發現?」 |
| `echo >> .gitignore` 的黏行陷阱:原檔末行沒有換行符時,append 會黏成一行廢規則(assets/_Raw_Imports/build/)——不但新規則沒生效,舊規則也被弄壞;154MB 匯出 zip 因此差點進版控(amend 救回) | 初階(2026-07-12 AI 自踩自修) | 「為什麼 grep 得到 build/ 卻沒忽略成功?怎麼一眼檢查檔案有沒有結尾換行?git 已 commit 的大檔怎麼救?」 |

### 14. 技能資料層設計(2026-07-09;[skill_data.gd](../src/card/skill_data.gd)、[skills_design.md](skills_design.md))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| Resource 巢狀:CardData 裡掛 SkillData 子資源(.tres 會存成 sub_resource),資料樹跟場景樹是兩回事 | 初階/未驗 | 「active_skill 存在 .tres 的哪一段?跟 standee 的 ext_resource 差在哪?」 |
| enum 當「系統合約」:Kind/Modifier/Effect 枚舉刻意壓小 = 戰鬥系統只要實作這幾種;加新招是加枚舉值+資料,不是加 if | 初階/未驗 | 「想加一招『沉默目標』,要動 skill_data.gd 的哪裡?戰鬥系統為什麼不用改架構?」 |
| 兄弟資源路徑推導:由 standee 路徑字串切「最後一個底線」推 Attack02 等動畫表;ResourceLoader.exists 防呆 | 初階/未驗 | 「為什麼用 rfind 而不是 replace(\"_Idle\", ...)?蝙蝠(無 Idle)哪裡會踩雷?」 |
| 動畫=能力的設計錨:先盤點素材(誰有 Attack02/Block/Summon)再配技能,有格擋動畫才有鐵壁被動 | 初階/未驗 | 「為什麼骷髏弓手沒有主動技?骷髏家族的不滅是從哪個素材事實推出來的?」 |

### 15. 雪地/洞窟場景優化(2026-07-09;[arena_frostlands.gd](../src/environment/arena_frostlands.gd)、[arena_caverns.gd](../src/environment/arena_caverns.gd)、[arena_base.gd](../src/environment/arena_base.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| GPUParticles3D 三件套:ProcessMaterial(發射盒/速度/亂流)、draw_pass(QuadMesh+billboard)、`preprocess`(開場即滿不用等) | 初階/未驗 | 「為什麼開場第一秒就有雪?visibility_aabb 設太小會出什麼詭異 bug?」 |
| 粒子貼圖可以程式生:GradientTexture2D 放射漸層 = 幾像素的小白點,不用進美術資源 | 初階/未驗 | 「雪花貼圖是哪來的?想把雪花變成六角形要換哪個環節?」 |
| 剪影策略:倒吊鐘乳石(rotation.x 180°)+ 黑暗與霧 = 大腦自己補完「洞頂」,不用真的蓋天花板 | 初階/未驗 | 「垂刺為什麼不用登記 _placed?吊多低會穿幫?」 |
| 跨包混材質:模型的 UV 對誰的 tilesheet 就接誰的表——冰晶到洞窟還是接 frostland 總表,不是接洞窟的 | 初階/未驗 | 「把冰晶接 Cavern_Tilesheet 會發生什麼?為什麼?」 |
| 配色公式「大面冷色+少量暖點」(雪夜火把)/「大面暖色+少量冷點」(洞窟藍水晶):對比色是畫面的收束點 | 初階/未驗 | 「洞窟裡的藍水晶在配色上的職責是什麼?拿掉會怎樣?」 |

### 16. 指令選單與技能演出(2026-07-09;[battle_ui.gd](../src/battle_ui/battle_ui.gd)、[card_manager.gd](../src/card_manager/card_manager.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 互動狀態機:同一顆左鍵在 IDLE/DRAGGING/MENU_OPEN/TARGETING 代表不同動作,集中在一個 enum 分流,不靠散落的 bool 旗標 | 初階/未驗 | 「為什麼不用 is_dragging + is_menu_open 兩個 bool?狀態機多買到什麼?」 |
| 「碰撞關掉=射線打不到」的反面:上桌卡片要可點擊,鎖定就不能再用停用碰撞實作,改用旗標分流 | 初階/未驗 | 「舊的 lock_interaction 為什麼會讓指令選單永遠開不起來?」 |
| UI 問、Manager 決定:BattleUI 只發信號(attack_chosen…),狀態轉移全在 CardManager——UI 換皮不動邏輯 | 初階/未驗 | 「把選單改成寶可夢 2×2 格,要動哪支檔?CardManager 要不要改?」 |
| 演出與規則分離:發動只播動畫+emit action_performed,結算留給未來戰鬥系統訂閱——同一條信號兩個階段用 | 初階/未驗 | 「戰鬥系統動工時要在哪裡接?_execute_action 需要改嗎?」 |
| .tres 巢狀資源實戰:sub_resource + script = SkillData 實例;headless 批次載入當資料驗證(bad=0 才算接完) | 初階/未驗 | 「Skill_main 這個 sub_resource 是怎麼變成 SkillData 的?驗證腳本驗了哪兩件事?」 |
| git 暫存區與工作區是兩本帳:檔案刪了但 index 還留著 A,照樣會被寫進歷史(字型 zip 事件) | 初階(2026-07-05 教過) | 「status 顯示 `AD` 是什麼狀態?怎麼把它從暫存區退掉?」 |
| 刪資源的順序:先把所有引用(.tres/.gd)退掉 → 再走編輯器 FileSystem 刪,不用 rm | 初階(2026-07-06 教過) | 「先刪圖再改引用會出什麼事?為什麼要走編輯器刪?」 |
| 量尺寸的時機:PRESET_MODE_MINSIZE 是「當下最小尺寸」的快照——面板還空著就定位=量到 0,內容進來後往預設方向(右下)長出螢幕外只剩標題列;修法=內容就位後重新定位+grow_vertical 往上長。與 original_scale 快照同族:基準要在資料就位後才拍 | 初階/未驗 | 「open() 裡的 reset_size+重新 set_anchors_and_offsets_preset 拿掉,選單會變怎樣?為什麼?」 |
| 2D↔3D 座標往返:project_ray_*(螢幕→3D 射線)與 unproject_position(3D→螢幕像素)互為反運算——導引箭頭=每幀把施放者的 3D 位置投回螢幕,用 Line2D 畫二次貝茲弧線;鎖定目標時尖端吸附目標(吸附=把類比輸入折算成明確意圖的回饋) | 初階/未驗 | 「箭頭起點為什麼要每幀重算而不是進 TARGETING 時算一次?哪種情況下只算一次會出錯?」 |

### 17. 卡槽高亮著色器(2026-07-10;[slot_tile.gdshader](../src/card_slot/slot_tile.gdshader)、[card_slot.gd](../src/card_slot/card_slot.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| SDF(有號距離場)畫程序化 UI 形狀:sd_rounded_box 回傳「到邊緣的距離」,一個距離值就能同時做外框線(abs(d)≈0)、第二道內線(d+0.045)、內緣漸層(d<0 的 smoothstep)——形狀是「算」出來的,不是貼圖 | 初階/未驗 | 「要再加第三道更靠內的細線,改哪個數字?為什麼 abs() 能讓一條線出現在邊的兩側?」 |
| 非等比縮放會把圓角拉成橢圓:先把 UV 乘上「寬/深」壓回等比空間再算 SDF(aspect uniform 由 GDScript 從節點實際 scale 算出傳入) | 初階/未驗 | 「拿掉 aspect 校正,卡槽四個角會變成什麼樣?為什麼?」 |
| shader_parameter/* 是 shader 解析後才存在的「動態屬性」:tween_property 綁它在 headless(dummy 渲染器)下會炸;tween_method + set_shader_parameter 不依賴算繪器狀態。搭配「從當下值起跑」避免動畫中途反向時跳變 | 初階/未驗 | 「為什麼 _current_glow() 不直接回傳 0 或 1?什麼操作序列會讓寫死起點的版本跳一下?」 |
| 執行期換材質:_ready 裡 new ShaderMaterial 蓋掉場景材質 → .tscn 零改動、每個實例一份材質(各槽發光獨立);headless 驗證的時序陷阱:SceneTree 腳本 _init 時 _ready 還沒跑,要 await process_frame | 初階/未驗 | 「20 個卡槽共用一份 ShaderMaterial 會出什麼視覺 bug?」 |

### 18. 魔力與生命值(2026-07-10;[battle_manager.gd](../src/battle_manager/battle_manager.gd)、[card.gd](../src/card/card.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 模板 vs 實例:CardData 是 24 張卡共用的 Resource,當前血量絕不能寫回模板(寫了=全場同名卡一起掉血);會變動的執行期狀態(current_hp、行動旗標)放場上的 Card 實例身上 | 初階/未驗 | 「把 current_hp 存進 CardData 會出什麼 bug?兩張「士兵」同場時會發生什麼?」 |
| 「同時結算」的實作:雙向傷害交換要先把反擊值記下來再一起扣——若順序扣血,先歸零的一方就打不出反擊,規則就錯了(交戰前快照,和 original_scale 同族) | 初階/未驗 | 「_resolve_attack 裡的 counter 變數為什麼要在 take_damage 之前取?刪掉先取的動作會怎樣?」 |
| 規則的單一出口:合法性檢查回傳「被擋的理由字串」(""=可做),UI 拿去灰化+轉述、發動前再驗一次——按鈕永遠只是轉述,最後一道門在帳房 | 初階/未驗 | 「為什麼 _on_attack_chosen 還要再查一次 attack_block_reason?UI 已經灰化了不是嗎?」 |
| 死亡的收尾順序:先清卡槽(位子馬上能用)→ 廣播 unit_died(讓別人清參考)→ 再播死亡演出+queue_free;拿著 freed 物件的參考=懸空參考,摸下去就炸 | 初階/未驗 | 「CardManager._on_unit_died 不清 hovered_target 會在什麼操作下炸掉?」 |
| await + create_timer 做「演出對時」:結算延後 0.35 秒讓數字跟拳頭一起落地;await 之後世界可能已變(單位死了),恢復執行前要 is_instance_valid 再驗 | 初階/未驗 | 「on_action_performed 裡 await 後面那句 is_instance_valid(caster) 防的是什麼劇本?」 |
| 看不見的規則=沒有的規則:反擊有算但沒演,玩家就以為對面攻擊力比較高——回饋(飄浮數字/受擊動畫)要綁在「結算事件」上,不是綁在「宣告動作」上(被治療播受傷就是綁錯邊的症狀);飄浮數字用 no_depth_test + billboard 保證讀得到 | 初階/未驗 | 「受擊動畫為什麼從 _execute_action 搬到 _resolve_attack?搬之前治療隊友會發生什麼?」 |

### 19. 本體、打臉與勝負(2026-07-10;[hero.gd](../src/hero/hero.gd)、[battle_manager.gd](../src/battle_manager/battle_manager.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| class_name 的全域類別快取:新腳本的 class_name 要等編輯器掃描(或 `--headless --import`)才進 `.godot/` 快取——沒進快取前,headless 連「引用它的其他腳本」都解析失敗;IDE 的 "Could not find type" 同源 | 初階/未驗 | 「為什麼加了 hero.gd 之後,連 battle_manager.gd 都在 headless 下 parse error?怎麼修?」 |
| 兩種型別一個介面:Card 和 Hero 都有 animate_hover/take_damage,共用變數宣告成共同祖先 Node3D,結算用 `target is Hero` 分流——先想「誰的規則不同」(反擊有無)再決定分流點,不是到處 if | 初階/未驗 | 「為什麼 hovered_target 從 Card 改宣告成 Node3D?打臉為什麼在 on_action_performed 分流而不是 _resolve_attack 裡?」 |
| 位置對位不寫死索引:路線(lane)判定用「x 座標最近的對面前排格」,換戰場/改棋盤排法不用回來改;本體站位同理由卡槽群組實際位置推算(call_deferred 等群組生完) | 初階/未驗 | 「_lane_blocked 為什麼不用『第 i 欄對第 i 欄』?卡槽間距改了會不會壞?」 |
| 終局閘門:game_ended 一票否決(行動合法性第一條就擋)+ UiState.GAME_OVER 鎖 3D 輸入——「遊戲結束」要同時關掉規則層和互動層,只關一層會漏(結算 await 中途分出勝負的殘餘行動) | 初階/未驗 | 「勝負已分後,為什麼 face_block_reason 和 ui_state 兩邊都要擋?只擋 UI 會發生什麼?」 |
| 三元運算式 vs 帶型別陣列:`a if c else b` 產出的是無型別 Array,執行期指派給 Array[String] 直接炸(而且是「執行到才炸」,parse 過得了)——帶型別容器要用直述句逐一指派;headless 跑主場景 N 幀是抓這類「啟動期執行錯誤」的網 | 初階/未驗 | 「為什麼這個 bug 編輯器不會標紅字、F5 才爆?headless --quit-after 驗的是哪一類錯?」 |
| 站位要讓鏡頭與 UI 的地盤:我方棋盤「正後方」在畫面上就是手牌扇形的位置,3D 物件站那裡必被 UI 擋——擺東西前先想「這個世界座標投影到螢幕是哪一塊」;duplicate() 可整棵複製現成節點樹做鏡射視覺(敵方牌堆),不用重刻場景 | 初階/未驗 | 「敵方牌堆的 z 為什麼是 mid_z*2 - deck.z?這條公式在做什麼幾何操作?」 |
| 網格地形的「方齒」成因:1m 方格上跑高頻噪聲,相鄰格推擠量差超過一格就擠出單格凸齒(看起來像掉了一塊素材)——蜿蜒感靠「幅度」出、不靠高頻抖動(頻率 0.13→0.05,彎改跨 4~8 格);磚緣直線再用水線雜物(岸石/露頭石/水草)遮參差,轉場處的髒亂是藏縫的標準手法 | 初階/未驗 | 「同樣的 bank_jitter,為什麼頻率高會出方齒、頻率低就是河灣?水線石頭為什麼要兩成丟進水裡?」 |

### 20. 狀態效果、打法修飾與卡型預留(2026-07-10;[battle_manager.gd](../src/battle_manager/battle_manager.gd)、[card.gd](../src/card/card.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 傷害管線單一入口:所有扣血都走 _deal_damage(夜幕減半→鐵壁-1→扣血+演出),減免規則只寫一份;吸血拿的是管線回傳的「實際傷害」不是帳面值——資料流設計:先想清楚「誰需要這個計算的結果」 | 初階/未驗 | 「吸血遇到鐵壁目標,回多少血?為什麼減免不能寫在 take_damage 裡?」 |
| 邊界順序決定規則正確性:回合切換=結束 tick → 回合+1 → 開始 tick → 狀態遞減——「先 tick 再遞減」1 回合灼燒才咬得到結束+開始共 2 點;順序反了規則就默默少一半 | 初階/未驗 | 「把 decay_statuses 移到開始 tick 之前,灼燒 1 回合會咬幾點?」 |
| enum 第 0 項=預設值的零遷移技巧:CardType.MINION 排第 0,24 張舊 .tres 一張不用改就自動是從者——擴充資料 schema 時,讓「舊資料的隱含值」正好是新欄位的預設值 | 初階/未驗 | 「如果把 ARCANA 排在 enum 第 0 項會發生什麼?」 |
| 爆牌制的設計取捨:爐石/暗影詩章式「滿手抽牌即銷毀」vs MTG 式「回合末棄到上限」vs 不抽——爆牌懲罰明確+規則最簡,且與本作丟牌回魔(§1.1)形成「囤牌有代價、棄牌有價值」的閉環 | 初階/未驗 | 「為什麼『手滿就不抽』會鼓勵拖節奏?爆牌制怎麼反制囤牌?」 |
| 副目標不反擊的簡化:橫掃/貫穿的濺射目標只挨打不還手(反擊只屬於主目標的雙向交換)——多目標規則先訂「誰有資格反擊」,不然結算順序組合爆炸 | 初階/未驗 | 「橫掃打三個目標,如果三個都反擊,攻擊者會吃幾刀?規則書為什麼不這樣設計?」 |

### 21. 真牌堆與熱座化(2026-07-10;[deck.gd](../src/card/deck.gd)、[battle_manager.gd](../src/battle_manager/battle_manager.gd)、[player_hand.gd](../src/play_hand/player_hand.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 帳與視圖分離:手牌的「帳」(Array[CardData])在 BattleManager 的 SideState,PlayerHand 只是投影——換邊=stash 現況→換帳→rebuild 視圖;連線時把「對面的視圖」拿掉就是網路版,規則層一行不用改 | 初階/未驗 | 「熱座換邊的三步驟(stash/end_turn/rebuild)順序能不能對調?為什麼視圖不能當真相?」 |
| 連線前先熱座:把「雙人規則」(雙帳/回合歸屬/側別檢查)在零網路環境做完並驗證,之後 ENet 只負責「把對面的操作送過來」——規則錯誤和網路錯誤拆成兩個獨立的 debug 空間 | 初階/未驗 | 「為什麼不直接上 ENet?熱座版驗過的哪些東西到網路版不用重驗?」 |
| 公平的資源成長:魔力上限在「輪到自己回合開始」才 +1(雙方各自的 _begin_side_turn),不是全域回合數推——否則後手第一回合就有 2 魔;每側的狀態效果也只在持有者自己的回合階段 tick | 初階/未驗 | 「如果魔力成長寫在全域 end_turn 裡,先手/後手的魔力曲線會差多少?」 |
| 內部類 class SideState:同形狀的兩份帳用一個類裝,dict 選 side——比 mana_p/mana_e 平行變數好擴充(加欄位一處改),也正是連線時序列化的單位 | 初階/未驗 | 「SideState 為什麼不做成獨立檔案的 class_name?什麼時候該升級?」 |
| 重構掃描的盲區:「函式改簽名」parse 期就叫、「屬性搬家」(mana 搬進 SideState)點取處要**執行到那一行**才炸——重構後 grep 的不只函式名,還有 `物件.舊屬性`;headless 啟動測試抓不到「條件路徑」上的錯(魔力不足才走到的那行) | 初階/未驗 | 「為什麼 battle_manager.mana 這個 bug 啟動時不炸、出牌被彈回時才炸?重構後該 grep 什麼?」 |
| 除錯器截停的長相:執行期錯誤發生時編輯器把你切出遊戲視窗、畫面像當機——「離開 app 且卡住」≠ 程式崩潰,是 debugger 停在錯誤行等你看;先去讀底部的錯誤訊息,別急著重開 | 初階/未驗 | 「遊戲視窗突然失焦卡住,第一件事該看哪裡?跟真的 crash 差在哪?」 |
| 「整批重建」的懸空參考家族:視圖重建(rebuild)會 free 舊節點,凡是還指著它們的參考(拖曳中的卡、hover 中的卡)都要在重建**前**清空——is_instance_valid 是最後保險,不是第一道門;列「誰會指著這批節點」的清單來掃,別靠碰運氣 | 初階/未驗 | 「拖著卡按結束回合,舊版會發生什麼?為什麼修法是先 organize_hand 而不是只加 is_instance_valid?」 |
| 動畫的「感」=距離×節奏:發牌感消失是因為重建把「單張從牌堆飛入」變成「原地生成」——修復=給距離(從牌堆出發)+給節奏(stagger 依序起飛);重構搬走一段流程時,附在上面的演出語彙要跟著搬 | 初階/未驗 | 「stagger 0.06 是什麼單位?為什麼平時重排用 0、只有發牌用 0.06?」 |

### 22. 連線 2a:大廳與 ENet 握手(2026-07-11;[net_lobby.gd](../src/net/net_lobby.gd)、[net_match.gd](../src/net/net_match.gd)、[main_menu.gd](../src/main_menu/main_menu.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| peer 掛在樹、不掛在場景:`multiplayer.multiplayer_peer` 屬於 SceneTree 的 MultiplayerAPI——換場景(大廳→牌桌)節點全死,**連線不斷**;所以大廳能「用完就丟」,回主選單賦 `null` 就回離線(還原成 OfflineMultiplayerPeer) | 初階/未驗 | 「大廳節點在 change_scene 時被 free 了,為什麼連線還在?誰負責在回主選單時斷線?」 |
| RPC 的路徑合約:RPC=「叫**對面同路徑節點**跑同名函式」,所以 NetLobby 的名字與掛點是合約的一部分;`@rpc("authority","call_local","reliable")` 三參數=誰有資格叫(host 權威,client 偽造被丟)/自己要不要也跑一份/掉包要不要重送 | 初階/未驗 | 「把 NetLobby 改名只改一台,握手會發生什麼?拿掉 call_local 會變成誰單獨開局?」 |
| 亂數只在 host(ADR-001 第一次落地):牌桌抽籤由 host 抽、把「結果」(index)塞進握手 RPC 廣播,client 只寫不抽——否則兩台各抽各的,你在森林他在冰原;之後的洗牌/抽牌全比照這條 | 初階/未驗 | 「為什麼不讓兩邊用同一個亂數種子各自抽?那種同步脆在哪?」 |
| 同進程雙分支測試:`SceneTree.set_multiplayer(api, root_path)` 能在一個進程開兩條 multiplayer 分支,host/client 走真 UDP loopback 互連——RPC 路徑以各自的 root_path 為基準解析,兩邊都叫 "NetLobby" 就對得上;連線功能因此能 headless 自動化驗證 | 初階/未驗 | 「verify 裡 host 的 NetLobby 在 /root/HostSide 下、client 的在 /root/ClientSide 下,RPC 為什麼找得到對方?」 |
| 繞開 class_name 快取(§19 的解法):實例化/引用**同批新增**的類別用 `preload("res://路徑")` 存進 const,不用 class_name——路徑載入不查全域類別快取,沒有「等編輯器重掃」的時間差;net_lobby 引 NetMatch、main_menu 引 NetLobby 都是這樣踩過才改的 | 初階/未驗 | 「main_menu.gd 為什麼用 NET_LOBBY_SCRIPT.new() 而不是 NetLobby.new()?什麼時候兩者等價?」 |

### 23. 法術卡面與素材管線(2026-07-11;[card.gd](../src/card/card.gd)、[data/cards/](../data/cards/)、assets/ui/icons/)

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| HD-2D 的特效真相:歧路旅人=2D 像素角色 × 3D 舞台 × **現代 3D 粒子特效+泛光後製**——特效不是像素圖!所以本作的法術特效有兩條路:GPUParticles3D+glow(歧路旅人感,WorldEnvironment 已開 glow)或 2D 幀動畫看板(復古感);卡面圖示是 UI 平面圖,跟場上特效是兩回事 | 初階/未驗 | 「歧路旅人的火焰魔法如果是像素幀動畫,畫面會少了什麼?我們的 glow_hdr_threshold=0.95 跟特效有什麼關係?」 |
| 後路分支的價值:setup() 的 `elif data.art != null` 當年寫著「理論上不會走到」,今天法術卡直接踩著它上線零改動——fallback 別只寫 push_error,把行為寫完整,未來功能常常就是免費的 | 初階/未驗 | 「如果當初 elif art 只寫 push_error('不該走到'),今天要多做哪些事?」 |
| AtlasTexture 切格子:一張大圖 + N 個 region 引用,不裁幾百個小檔——載入一次、記憶體一份、檔案系統乾淨;region 座標=格位 × 格尺寸;.tres 手寫格式三件套:ext_resource(path 引用)/sub_resource/load_steps=資源總數+1 | 初階/未驗 | 「16 顆圖示裁成 16 個 PNG 和一張大圖+16 個 AtlasTexture,差在哪?load_steps 數錯會怎樣?」 |
| 匯入系統的邊界:res:// 的圖要有 .import 才 load 得到(headless 同樣受限),編輯器取得焦點才會掃描匯入新檔;`Image.load_from_file` 繞過匯入直接讀原始檔(驗證未匯入素材的後門);`.gdignore` 讓資料夾不被掃描(原始 zip 的隔離區) | 初階/未驗 | 「為什麼我 F5 看得到新圖、你 headless 卻 load 失敗?.gdignore 和 .gitignore 各管什麼?」 |
| static 變數的寫入路徑:透過 class_name 寫 OK(`ArenaPool.next_arena_path = x`),透過 **preload 的 const 類別引用**寫會被編譯器當「改常數」擋下(讀常數/呼叫函式都行,唯獨賦值不行)——跨檔寫 static 收進該類別自己的 static 函式(`NetMatch.start_online()`),順便把「哪些欄位一起變」封裝成一個動作 | 初階/未驗 | 「NET_MATCH.PORT 讀得到、NET_MATCH.reset() 叫得動,為什麼 NET_MATCH.is_online = true 編譯不過?修法為什麼是加 start_online() 而不是把 const 改成 var?」 |
| 圖塞窗三策略:contain(`minf`,完整進窗**必留白**)/ cover(`maxf`,填滿**必裁切**,凸出靠遮罩吃 =§9 出血)/ fill-stretch(高度等比+`scale.x` 拉寬,填滿**必變形**)。三者只能挑一種代價,挑哪個是美術判斷不是對錯 | 初階(2026-07-11 教過+實測:留白方向答對、推出「畫大凸出」;cover 裁 30% 後**他自己打槍改要 fill**——能對策略代價做取捨了,快到中階) | 「窗改直向(0.9:1.3),cover 改裁哪邊?fill 的變形率怎麼算?什麼素材該用 contain 死也不變形?」 |
| VSCode 的 GDScript 紅字 ≠ 引擎判決:語言伺服器沒連 Godot 編輯器時認不得 class_name 全域型別(SkillData/CardType 整排假錯);地面真相用 `godot --headless --quit` 或編輯器本身驗 | 初階(2026-07-11 親歷:改 minf→maxf 後 IDE 爆 13 個假錯,headless 零錯誤) | 「IDE 說 SkillData 找不到、遊戲卻跑得動——兩個檢查器差在哪?要信誰、怎麼驗?」 |

### 24. 回合抽牌動畫:動畫跟隨資料變化量(2026-07-11;[player_hand.gd](../src/play_hand/player_hand.gd)、[card_manager.gd](../src/card_manager/card_manager.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 動畫該演「資料變了多少」:開局=整手都是新的→整手飛入(rebuild fly_in);回合抽牌=只多 1 張→只飛那張(deal_last_from_deck);換邊=整手換人但不是「發牌」→直接就位。用錯就是這次的 bug:換邊重演整手發牌,看起來像重新發牌 | 初階/未驗(逃生艙修復,根因他沒自己追) | 「_sync_hand_view 為什麼保留整手飛入、_on_end_turn 卻關掉?之後做『對手偷走你一張牌』,動畫該演什麼、資料變化量是多少?」 |
| 用「預設參數」擴充 API 不炸舊呼叫:_arrange_fan 加 instant、rebuild_from 加 fly_in,都給預設值 → 既有呼叫點一行不用改 | 初階/未驗 | 「如果 fly_in 不給預設值,專案裡哪一行會立刻爆?為什麼預設值要選 true 而不是 false?」 |

### 25. 連線視角鎖定與回合換頁 RPC(2026-07-11;[card_manager.gd](../src/card_manager/card_manager.gd)、[battle_manager.gd](../src/battle_manager/battle_manager.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 視角鎖定:熱座「視圖跟著行動方換頁」/連線「視圖鎖死自己那側」——同一份帳,兩種投影策略;判斷式收成一個函式(_hand_view_shows_active_side),讓「誰該看什麼」只寫一次 | 初階/未驗(逃生艙) | 「連線時輪到對方,我的手牌視圖為什麼一行都不用動?熱座為什麼反而要整手換頁?」 |
| RPC 換頁令:`@rpc("any_peer","call_local","reliable")`——any_peer 因為 client 也要能發令;call_local 讓發令方自己也執行;兩端各自收拾自己的拖曳/選單再翻頁(懸空參考防炸要兩端都做)。**呼叫端分流:連線才 `.rpc()`,離線本地直呼**(原因見下一列) | 初階/未驗 | 「為什麼這裡不能用 authority?對面機器上被拖著的卡誰去收?」 |
| `.rpc()` 需要活著的 peer:`multiplayer_peer = null` 時 rpc **報錯且整個不執行**(call_local 也救不了);**null ≠ OfflineMultiplayerPeer**。F6 直跑(預設 Offline peer)與走主選單(lobby 把 peer 清成 null)是環境不同的兩條進場路,bug 只在後者出現——測試要把所有進場路徑都走過 | 初階(2026-07-12 逃生艙自炸自修:headless 對照兩條路徑抓到;net_lobby 舊註解也錯在同一點,已更正) | 「同一段 code,為什麼 F6 直跑正常、從主選單進來按鈕就死?『離線直呼、連線才 rpc』的分流為什麼比『永遠 rpc』穩?」 |
| my_side 的離線預設值 = "player" 是刻意的:所有「連線 vs 熱座」的分支寫成跟 my_side 比較,離線語意自動退回熱座——預設值選得好,分支就少一半 | 初階/未驗 | 「side_name 那行為什麼離線時不用另寫一條?如果 my_side 離線預設是空字串會炸哪裡?」 |
| **2b 剩餘的債(還沒做,別誤以為完工)**:①兩台的牌堆各自亂洗(帳沒同步,上桌行動也還沒廣播)②發令資格只在 UI 閘把關,沒有伺服端驗證(client 可偽造換頁令)③client 的鏡頭/棋盤仍是 host 視角 | ——(待辦,非觀念) | 動工 2b 時逐項劃掉 |

### 26. 第一顆 3D 特效:通用命中爆點(2026-07-12;[src/fx/fx_burst.gd](../src/fx/fx_burst.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| GPUParticles3D 一次性爆點解剖:`one_shot + explosiveness=1`(爆點 vs 噴泉)、參數給 min/max 讓每顆粒子抽籤(不整齊才像火花)、`scale_curve` 要包成 CurveTexture(粒子系統只吃貼圖不吃函數)、additive blend(重疊更亮=火光感)、emission 3.0 推過 glow 門檻(泛光,和卡槽高亮同一招)、`finished → queue_free` 自毀 | 初階/未驗(逃生艙) | 「explosiveness 0 和 1 差在哪?想改成持續冒煙要動哪幾個參數?淡出為什麼用縮小而不是改 alpha?」 |
| 特效掛在「所有傷害的必經之路」(Card/Hero 的 take_damage):一次接線,普攻/反擊/技能/灼燒中毒全生效——找 choke point,別在每個事件各接一次 | 初階/未驗 | 「之後要加『治療綠光』,掛哪個函式?為什麼不掛在攻擊指令那端?」 |
| `current_scene` 在場景切換空窗期可能是 null;掛短命節點用 `get_tree().root` 更穩(headless 煙霧測試先抓到,沒等到玩家踩) | 初階/未驗 | 「特效掛 root 為什麼不怕跨場景殘留?什麼樣的節點反而不該掛 root?」 |

### 27. 法術結算層:四種卡型上線(2026-07-12;battle_manager / card_manager / battle_ui)

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| `await` 做「等玩家決定」:秘術流程走到反制窗口就 `await battle_ui.reaction_decided`,整條函式停在那行直到面板按鈕 emit——遊戲流程的「暫停點」不用狀態機硬刻,協程天生就會等 | 初階/未驗(逃生艙) | 「await 那行在等什麼?如果玩家永遠不按,函式怎麼了?為什麼進 async 前要先把 DRAGGING 狀態清掉?」 |
| 宣告即付費(§5.1 STEP1):先 spend 再開反制窗,被抵銷不退費——付費點的位置就是規則本身,放錯位置=規則錯 | 初階/未驗 | 「把 spend 移到結算成功之後,遊戲規則變成什麼樣?哪一方變強?」 |
| 靈裝加成記在「節點」(max_hp_bonus)不寫回共享的 CardData:寫回 data.hp 會讓全場同名卡一起變厚(=主帳 §7 Resource 共享的實戰版);宿主離場,節點亡,加成自然消失,不用寫清理 code | 初階/未驗 | 「為什麼 +2 上限不能直接 data.hp += 2?『裝備隨宿主離場』是誰保證的——有寫這段 code 嗎?」 |
| 伏印住在「側帳」不佔卡槽(§2 後排資料層);觸發點挑在 mark_summoned=召喚的必經之路——和爆點掛 take_damage 同一招:找 choke point,一次接線全情境生效 | 初階/未驗 | 「伏印為什麼不做成一張蓋在卡槽上的卡?觸發檢查為什麼放 mark_summoned 而不是放在出牌按鈕那邊?」 |
| 瞬咒候選查「帳」不查「視圖」:守方的手牌在熱座時已 stash 回 sides[defender].hand,視圖上根本沒有他的牌——帳/視圖分離下,規則永遠問帳 | 初階/未驗 | 「反制窗口跳出來時,守方的牌在哪個資料結構裡?為什麼不能去 player_hand.cards 找?」 |

### 28. 連線 2b–2e:帳同步+行動重放(2026-07-12;card_manager / battle_manager / battle_ui)

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 同步架構的最小可行式:「開局資料一致(host 打包牌堆/手牌給 client)+ 每個操作一致(行動 RPC 兩台重放)= 狀態一致」;驗收方式是**簽名比對**——兩台各印雙方手牌+牌堆剩量,必須一字不差 | 初階/未驗(逃生艙) | 「為什麼開局要同步牌堆而不是每次抽牌廣播結果?如果某台在重放時 lag 掉一個 RPC,簽名會發生什麼?」 |
| 跨機器身分證:節點參考不能過網路——單位=「所在卡槽的場景樹路徑」(兩台樹一致才成立)、本體=側別字串、手牌=索引(兩台帳一致才成立)。身分證的有效性建立在「某種東西兩邊一致」上 | 初階/未驗 | 「為什麼卡槽路徑可以當單位的 ID?什麼情況下手牌索引會失效?」 |
| 出牌端 vs 重放端的不對稱:出牌端有「真的被拖過來的卡節點」(_pending_play_card,動畫連續),重放端只有帳+索引(生新節點/扣帳面)——同一個 RPC 函式裡走兩條路,用 _acting_locally() 分流 | 初階/未驗 | 「_net_summon 裡為什麼出牌端不用 remove_from_hand?重放端為什麼不能用 _pending_play_card?」 |
| 反制窗口跨機器:宣告(兩台記 pending)→ 守方**那台**開面板 await 人類 → 把布林結果 RPC 回來兩台各自結算——await 等的是「另一台機器上的人」,流程凍結點在守方機,出牌端只鎖操作等結果 | 初階/未驗 | 「秘術宣告後出牌端在等什麼信號?resolve 為什麼兩台都要跑 consume_quick,不會重複扣嗎?」 |
| 視角翻轉:繞「通過棋盤中線的垂直軸」轉 180°(v → (-x, y, 2·mid−z)),只轉觀察者那一掛(鏡頭/手牌/牌堆)——**世界只有一份,視角有兩個**;寫死 "player"/"enemy" 的判斷(_is_valid_target)在 client 上敵我顛倒,一律改「相對施放者」 | 初階/未驗 | 「為什麼翻鏡頭不翻棋盤?client 的『我方單位』在哪個群組?_is_valid_target 原本會怎麼錯?」 |

### 29. 牌桌構圖改版:鏡像布局+相機角度預算+hover 預覽(2026-07-14;player_board / card_manager / card.gd / battle_ui / main.tscn)

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 相機構圖是「角度預算」不是試手氣:物體可見 ⇔ 它對相機的俯仰角落在 pitch±fov/2 內——敵本體頭頂 22.8° vs 畫面上緣 23.5°(pitch 46−fov半角 22.5)只差 0.7° 就是被裁;fov 45→50 直接買 2.5° 頭部空間;下緣打到地面的 z = camZ − camH/tan(pitch+fov/2) | 初階/未驗(逃生艙) | 「想在畫面上緣多留一個頭的空間,有哪三種參數可以動?各自的副作用是什麼?」 |
| 視覺任務也能自動化迭代:CLI 非 headless 跑遊戲 + 執行期覆寫 transform + 截 PNG 檢視 → 收斂後才把數值「烘」回 .tscn;和「基準值要快照」同族——實驗態(執行期覆寫)與定案態(場景檔)分開 | 初階/未驗 | 「為什麼不直接改 .tscn 反覆開編輯器看?harness 覆寫和烘進場景檔各自的角色是什麼?」 |
| 鏡像對稱的紅利:布局對稱於 z=0 之後,client 翻轉視角(§28)自動變成完美鏡像——同一組相機參數服務兩台;「敵方前排比後排更遠」的語意顛倒也被「row0 永遠貼中線、兩側背向中線生長」自然修掉 | 初階/未驗 | 「舊版敵方 front/back 為什麼顛倒?鏡像後 _board_mid_z 變多少、哪些下游跟著變?」 |
| Label3D 沒有 max_lines:截斷用「全形 1/半形 0.5」估寬(夠用就好,量測 API 依賴字型載入時機);**資訊分層**:小空間(卡面)給摘要+…,大面板(hover 預覽)給全文——不是把字塞下去,是把閱讀場景分開 | 初階/未驗 | 「為什麼不精確量測每行寬度?卡面 5 行的上限是怎麼從座標推出來的(-0.52 中心、名 -0.1、攻血 -0.9)?」 |
| hover 事件序陷阱兩則:扇形重疊時 enter(B) 可能先於 exit(A) → 收面板要驗「離開的正是預覽中那張」;來源卡被 free(換手牌/陣亡)不會發 unhover → _process 裡 is_instance_valid 兜底收面板 | 初階/未驗 | 「無條件在 unhover 收面板會出什麼視覺 bug?為什麼還需要 _process 那道保險?」 |
| 「三處手動對齊」常數是雷:stream_z 同時活在 Stream 節點(.tscn)、ground_generator、forest_scatter——改一處壞三處;這次三處一起動並讓註解互相指路,長期解是單一來源(誰讀誰) | 初階/未驗 | 「如果只把 Stream 節點移到 z=0、兩支腳本不動,畫面會壞成什麼樣?怎麼設計讓這個常數只寫一次?」 |
| 合成旋轉要「全鏈一起算」:手牌卡的最終朝向 = hand 節點旋轉 ∘ 每張卡自帶的 card_tilt_x(+55°)——只調 hand 到 −46° 時合成變 +9°(卡近乎躺平,看起來又立又扁);「面向玩家」的判準是**卡面法線仰角 ≈ 鏡頭視線仰角**(定案 hand −108°+55°=法線 53° vs 視線 51°) | 初階/未驗 | 「為什麼 hand 轉 −46° 卡反而像躺平?怎麼從『相機位置+手牌位置』算出 hand 該轉幾度?」 |
| hover 抬升的漂移 bug(**第一版「快照+旗標」被 Harvey 實測打臉,已更正**):hover/unhover 快速交錯時,歸位補間還在飛、旗標卻已清掉,重新快照抓到「抬到一半」的位置 → 越 hover 越往前。真解兩層:①基準由**資料源頭**寫入(PlayerHand 排扇形時 sync_hand_base),動畫永遠 tween 到「基準+固定偏移」的**絕對目標**,打幾次都收斂同一點;②同一屬性只留一條補間(開新的先 kill 舊的;拖曳跟手也寫 position,開拖同樣要 kill)。回歸測試:30 輪交錯 hover 斷言零漂移 | 初階(bug 由 Harvey 實測發現,修法是 AI 代工) | 「為什麼快照+旗標防不住交錯 hover?『tween 到絕對目標』和『tween 相對位移 -=HOVER_LIFT』在連打下差在哪?兩條 tween 同時寫 position 誰贏?」 |
| 卡片閃爍 = hover 的「演出」推翻了 hover 的「判定」:抬升把碰撞箱一起搬走 → 游標下一幀指不到 → exit→歸位→又 enter……enter/exit 迴圈。通解=**判定與演出分離**:視覺照抬,$Area3D 反向補償釘在扇形原位(歸位途中也要同步收回,否則碰撞箱「掃回」游標又觸發 enter);補償向量要跨座標系換算(手牌空間抬升 → 卡 local:純旋轉反轉 ÷ hover 後縮放)。headless 斷言:抬升 1.8 期間碰撞箱世界漂移 0.000。可遷移:任何「指到就會動」的 UI,判定幾何都不能跟著動 | 初階(現象與問法由 Harvey 提出,原理講解後逃生艙代工) | 「為什麼以前只放大 1.35 不閃、抬升 1.8 就閃?補償為什麼要除以縮放?下拉選單 hover 展開是同一族問題嗎?」 |

### 30. 單人 vs AI 模式:AI=另一個玩家+三模式判斷式(2026-07-15;match_mode / enemy_ai / opponent_hand / card_manager / main_menu)

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| AI 設計成「另一個會按按鈕的玩家」:不開後門、不直改帳,結算走**和連線重放同一條函式**(_net_summon/_net_action 的帳面路徑)——所有行為者(人類/遠端/AI)走同一條結算路,規則與帳自動一致,AI 天生不會作弊也不會漏掉伏印/反擊等結算 | 初階/未驗(逃生艙) | 「AI 召喚為什麼不直接呼叫 spawn_unit 就好?讓 AI 走重放路徑,伏印觸發是誰保證的?」 |
| 一個判斷式吃三種模式:「誰在看(_hand_view_shows_active_side)/誰在動(_acting_locally)」收斂成單一函式後,新增 VS_AI 只要各加一個分支——熱座=恆真、連線=比 my_side、單人=比 "player";分散寫在每個呼叫點的話,新模式要改十幾處 | 初階/未驗 | 「VS_AI 的 enemy 回合,_acting_locally 為什麼要回 false?這個 false 讓哪條路徑被選中?」 |
| 介面與決策者分離:反制窗口的面板是「問人類」的介面——守方是 AI 時開面板等於(a)把 AI 手牌攤給玩家(b)要玩家替 AI 按鈕,所以 VS_AI 直接自動決策不開面板 | 初階/未驗 | 「單人模式玩家丟秘術,反制窗口會出現在誰面前?為什麼一個都不該出現?」 |
| class_name 全域註冊表的雷:`.godot/global_script_class_cache.cfg` 由**編輯器掃描**生成——編輯器外新建帶 class_name 的檔,headless 直接跑會報 "Identifier not declared";`--headless --editor --quit` 跑一次重掃即解 | 初階(AI 自踩自修) | 「為什麼同一份 code 在編輯器裡跑得動、headless 卻說 MatchMode 未宣告?這個 cache 是誰在維護?」 |
| 回歸測試資產要落籍版控:系統暫存目錄會清檔(本專案兩度弄丟測試腳本),tests/ 進 repo 後「重跑驗收」才是零成本動作;測試斷言要挑「不受隨機性影響的不變量」(認召喚暈眩標記,不認卡名/場上總數——起手隨機、反擊會抵銷數量) | 初階/未驗 | 「為什麼『AI 召喚了』不能用場上單位數+1 驗?summoned_this_turn 為什麼在 AI 回合結束後還留著?」 |

### 31. 秘術施放改爐石式箭頭瞄準:重用狀態機分支(2026-07-15;[card_manager.gd](../src/card_manager/card_manager.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| **旗標區分共用狀態 vs 開新狀態**:秘術瞄準沒新增 `UiState.SPELL_TARGETING`,而是複用既有 `TARGETING`,靠 `pending_spell_card` 旗標分流(active_unit=單位攻擊、pending_spell_card=秘術)。因為 `_input`/`_process`/`_cancel_command`/`_on_game_over`/換頁 全都認 `ui_state` 分派——多開一個狀態就得在每個分派點各加一條分支;用旗標則所有共通清理(右鍵取消、換頁、勝負)自動涵蓋,不會漏 | 初階/未驗(逃生艙) | 「如果當初開 SPELL_TARGETING 新狀態,右鍵取消秘術瞄準要多改哪幾個地方才不會卡死?」 |
| **改互動不動結算**:只換了「怎麼選到目標」(拖放放開→點卡+箭頭+點目標),下游 `_resolve_arcana`/連線宣告 `_net_arcana_declare`/守方反制窗口一行沒改——目標一旦選定,結算跟「當初怎麼選的」無關。同一條「演出/輸入 vs 規則/結算」分離線,跟 §27 是同一招 | 初階/未驗 | 「把秘術從拖放改成箭頭,為什麼反制窗口與連線同步的 code 完全不用動?這條分界線畫在哪?」 |
| **箭頭起點是「施放者」的抽象**:`update_arrow` 本來就吃任意 `from_px`;把起點從「攻擊單位 active_unit」一般化成「施放者節點」(單位 or 本體),同一條箭頭渲染兩用。秘術的施放者=行動方本體(`active_side` 對應的 hero),不寫死 player_hero——熱座/連線 client 時行動方會換邊 | 初階/未驗 | 「秘術箭頭起點為什麼用 `active_side` 挑 hero,而不是永遠用 player_hero?哪種模式會露餡?」 |
| **秘術瞄準不能共用 `_is_valid_target`**:後者靠 `side_of(active_unit)` 判敵我,秘術時 active_unit=null 會炸;所以拆出 `_is_valid_spell_target`(敵方+非潛行)並用 `_is_valid_targeting_target` 依模式分派。**基準值(施放者)換了來源,判定函式就得跟著換** | 初階/未驗 | 「秘術瞄準時 active_unit 是什麼?若硬套舊的 _is_valid_target 會在哪一行爆、為什麼?」 |
