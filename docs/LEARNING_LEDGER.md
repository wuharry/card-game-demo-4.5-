# 學習債清單(Learning Ledger)

> **這是什麼**:逃生艙 / AI 代工做出來、但 Harvey(Godot 新手)未必理解的觀念總帳。
> 建帳日 2026-07-06;主帳範圍 = commit `d49c7fb`…`3f97f17`(Harvey 指定的逃生艙區間)。
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

## 主帳(d49c7fb…3f97f17)

### 1. 溪流水面 shader(`d49c7fb`;[assets/water/stream_water.gdshader](../assets/water/stream_water.gdshader))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| shader 在哪跑:fragment 每幀·每像素·在 GPU;跟 `_process`(CPU、每幀一次)的量級差 | 初階/未驗 | 「水面波紋一秒被算幾次?搬到 `_process` 用 CPU 算會發生什麼?」 |
| 法線貼圖騙光:波紋是「動法線騙光照」,網格根本沒動 | 初階/未驗 | 「把相機貼平水面側看,水面是平的還是起伏的?那為什麼正看有波?」 |
| `TIME` 驅動 UV 捲動(動畫的來源) | 初階/未驗 | 「波紋為什麼會流?TIME 乘 2 畫面變什麼樣?」 |
| SSR 螢幕空間反射:只能反射「當前畫面裡有的東西」 | 初階/未驗 | 「為什麼樹一被鏡頭切出畫面,水裡倒影就消失?」 |

### 2. 程序化地板(`b5b0696`、`acf46c5`;[src/environment/ground_generator.gd](../src/environment/ground_generator.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 噪聲 vs 純隨機:FastNoiseLite「相鄰值相近」所以成簇;`randi` 是雪花點 | 初階/未驗 | 「想要泥巴斑塊更大顆,調 frequency 還是 threshold?兩者各控制什麼?」 |
| 閾值切分:連續噪聲值 → 離散磚種(草 / 泥 / 過渡磚) | 初階/未驗 | 「過渡磚是怎麼被選中的?畫出噪聲值軸上三個區間」 |
| GridMap + MeshLibrary 的分工(棋盤格 vs 磚的字典) | 初階/未驗 | 「新增一種磚要動哪邊?鋪磚邏輯要改嗎?」 |
| `acf46c5` 的 bug 根因:磚隨機朝向 → 部分磚光照/UV 方向錯 → 深色斑塊 | 初階/未驗 | 「為什麼『轉一下磚』會讓它變深色?跟法線的關係?」 |

### 3. 森林散佈([src/environment/forest_scatter.gd](../src/environment/forest_scatter.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 成簇散佈(先選簇心、再繞著撒點)與內圈淨空(排除區判定) | 初階/未驗 | 「為什麼牌桌正中央永遠不會長樹?淨空是在哪一步被保證的?」 |
| alpha scissor(鏤空)vs alpha blend:樹葉用 scissor 是為了躲透明排序問題 | 初階/未驗 | 「樹葉改用 alpha blend 會出什麼視覺 bug?為什麼 scissor 沒這問題?」 |
| 生成的節點不設 owner → 不會存進 .tscn(場景檔保持薄,內容由 code 重建) | 初階/未驗 | 「編輯器裡看得到幾百棵樹,.tscn 檔裡卻沒有它們——為什麼?這樣的好處?」 |

### 4. 卡牌互動 code review 清理(`0a5ca1a`)

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 封裝:`play_card()` 收進 PlayerHand,外部不直接動 `cards` 陣列 | 初階/未驗 | 「如果 CardManager 直接 `cards.erase(card)`,少做了什麼事?會出什麼 bug?」 |
| `@export` 節點注入 vs `$` 字串路徑(`node_paths` 的意義;場景樹搬家誰會壞) | 初階/未驗 | 「把 PlayerHand 在場景樹搬到別層,@export 注入和 `$../PlayerHand` 誰活誰死?」 |
| 靜態型別標註的好處(自動補全、錯誤提早在編輯期爆) | 初階/未驗 | 「`var card: Card` 比 `var card` 多買到哪兩件事?」 |

### 5. Label3D 深度與數值顯示(`9fa9096`、`c860c60`)——已教學

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

## 續帳(3f97f17…HEAD,本機 session;2026-07-06 依 session 全記錄補齊)

> 原「待分類」五條全部展開移入。等級照規則預設「初階/未驗」;
> 有實際問答依據的兩處已標註(§12 河道根因 = 中階、§9 出血 / §11 錨點 = 出過題未答)。

### 8. CardData 資料層實作(`d959cb7`;[src/card/card_data.gd](../src/card/card_data.gd)、[data/cards/](../data/cards/))

> 觀念層(資料/視覺分離)在主帳 §7,這裡是實作層。

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| .tres 檔解剖:ext_resource(引用外部檔)vs sub_resource(內嵌小資源) | 初階/未驗 | 「打開 knight.tres:哪行是引用、哪行是內嵌?刪掉被引用的 png 會發生什麼?」 |
| AtlasTexture:在大圖上「框一格」當獨立貼圖(卡圖佔位 = 動畫表第 0 幀) | 初階/未驗 | 「region = Rect2(0,0,100,100) 在說什麼?想改用第 3 幀改哪個數字?」 |
| DirAccess 掃資料夾 + 懶載入(卡池第一次要用才載);`.remap` 後綴剝除 | 初階/未驗 | 「卡池是開遊戲瞬間載入,還是第一次發牌才載?懶載入買到什麼?」 |

### 9. 卡圖挖空窗與召喚立牌(`09f8b40`、`8ddf5a5`;[src/card/card.gd](../src/card/card.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 透明繪製順序:卡圖擺卡框「後面」(z=-0.01)從挖空窗露出 → 怎麼縮放都壓不到框的美術 | 初階/未驗 | 「為什麼放後面反而安全?改成 +0.01 疊前面會出什麼事?」 |
| 出血(bleed):遮罩決定形狀、內容做大藏在遮罩後——卡圖出血 6% 和水面板加寬是同一條原則 | 初階(2026-07-05 出題未答) | 「bank_jitter 調到 2.0,水面板要多寬才不露餡?公式?」 |
| 可見範圍掃描:alpha 掃出角色實佔行列,大小/腳位用「量出來的」——100×100 格子裡角色只有 ~30px,信帳面就會又小又飄 | 初階/未驗 | 「按整格算,角色為什麼只剩帳面 1/3 還懸空?掃描一次解決哪兩件事?」 |
| Sprite3D 立牌三件套:hframes 切格(幀數=寬÷高)、tween_callback+set_loops 播待機、BILLBOARD_FIXED_Y 直立面向鏡頭 | 初階/未驗 | 「幀數 6 是誰算出來的?為什麼這批素材能用寬除以高?」 |
| 旋轉疊加(§5 牙籤原則的旋轉版):place_card 轉 local (0,0,0) 就是躺平——父節點 PlayerHand 已 -90°X;再補 -90 卡會立起來 | 初階/未驗 | 「卡在槽裡 local rotation=0,世界裡為什麼是躺的?『躺』是誰給的?」 |

### 10. 戰場家族與輪替(`9385150`;[src/environment/arena_base.gd](../src/environment/arena_base.gd)、[arena_pool.gd](../src/environment/arena_pool.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 場景繼承:共同流程在基底(環境/地板/散佈工具),子類只覆寫 `_build()` | 初階/未驗 | 「新增『沙漠』牌桌要寫哪些函式、哪些直接繼承來用?」 |
| static 類別變數跨場景傳值:static 活在類別上,change_scene 清不掉(ArenaPool 不用 autoload 的原因) | 初階/未驗 | 「換場景後 main.tscn 為什麼還讀得到抽籤結果?什麼時候該升級成 autoload?」 |
| free() vs queue_free():queue_free 等幀尾才刪;換 WorldEnvironment 必須立刻 free,兩環境並存一幀會打架 | 初階/未驗 | 「哪種情境不能等幀尾?main_scene.gd 那行為什麼用 free()?」 |

### 11. 主選單(`2fb80f8`;[src/main_menu/main_menu.gd](../src/main_menu/main_menu.gd))

| 觀念 | 等級 | 考題方向 |
|---|---|---|
| 錨點=比例、偏移=像素修正;`set_anchors_preset` 只動錨點且「保留當下矩形」→ UI 鎖死在舊視窗大小(置中 bug 根因);帶 `and_offsets` 的才等於 Layout 選單 | 初階(2026-07-05 教過+出題未答) | 「編輯器裡擺好的 Control 呼叫 set_anchors_preset 會不會歪?跟 code 生成的 0×0 新節點差在哪?」 |
| CanvasLayer:2D 疊層永遠畫在 3D 之上(選單、黑幕都掛它下面) | 初階/未驗 | 「UI 不掛 CanvasLayer、直接掛在 Node3D 下會發生什麼?」 |
| 主題覆寫做文字選單:normal 給 StyleBoxEmpty、hover/focus 共用「只開下邊框」的 StyleBoxFlat → 滑鼠/鍵盤回饋一致 | 初階/未驗 | 「為什麼 focus 也要接樣式?只接 hover 冷落了誰?」 |
| 轉場模式:鎖按鈕 → tween 黑幕 → `await tw.finished` → change_scene_to_file,失敗要還原 | 初階/未驗 | 「await 那行在等什麼信號?不鎖按鈕連點兩下會怎樣?」 |

### 12. 森林地形整修(`4ab417d`;[ground_generator.gd](../src/environment/ground_generator.gd)、[forest_scatter.gd](../src/environment/forest_scatter.gd))

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
