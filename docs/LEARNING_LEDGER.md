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

## 待分類:範圍外的 AI 代工(3f97f17…HEAD)

> 這段 commit 多半也是 AI 做的(含另一台機器的 session)。**Harvey 圈認後移入主帳**,先列觀念佔位:

- **CardData 實作層**(`d959cb7`):DirAccess 掃資料夾載卡池、懶載入(第一次用才載)、`.remap` 後綴剝除、`pick_random()` —— 注意:觀念層(資料/視覺分離)在主帳 §7,這裡是實作層
- **卡圖與立牌**(`09f8b40`、`8ddf5a5`):卡框挖空窗定位(alpha 掃描出視窗常數)、像素圖第 0 幀裁切放大、立牌待機動畫切幀
- **場景繼承與跨場景傳值**(`9385150`):ArenaBase 基底 + 子類 `_build()`(為何用繼承);ArenaPool 用 static 類別傳值(為何不用 autoload)
- **主選單**(`2fb80f8`):CanvasLayer 讓 2D UI 疊在 3D 上、UI 全程式組裝、固定鏡頭構圖參數化
- **`free()` vs `queue_free()`**([src/main_scene/main_scene.gd](../src/main_scene/main_scene.gd)):換 WorldEnvironment 為何必須「立刻」free —— 兩個環境並存一幀的未定義行為
