# 死靈流派構想草案

本文件保存 Harvey 於 2026-09-18 提出的死靈流派構想；尚未定案，也不表示已實作。正式玩法規格仍以 README.md Gameplay Spec 為準。

## 流派方向

死靈流派以復活、死靈化、召喚與墓地消耗形成攻防循環。

- 墓地生物可復活，也可作為召喚或防禦的消耗資源。
- 死靈化可用於己方轉生，也可用於敵方感染與控制。
- 「次元」指不可再被召喚的放逐區，與墓地分開。
- token 指效果產生的衍生生物；具體數值與種族對照尚未決定。

```text
生物死亡 → 墓地 → 復活／消耗墓地召喚／骨盾
                     ↓
              次元（無法再召喚）
```

## 主動技能替換構想

預計以死者轉生與骷髏召喚作為主動技能選項；替換的是玩家／英雄技能或生物技能，尚待確認。

| 技能 | 原始構想 | 未定選項 |
|---|---|---|
| 死者轉生 | 每兩回合一次，召喚墓地中的生物並轉為死靈系；生命值與攻擊力剩一半；不能發動被動與進場技能，但可以發動主動技能；再次死亡後進入次元，無法再召喚 | 是否每回合流失 1 生命、流失時點、技能魔力費用、半值取整、生命減半依最大或當前生命計算 |
| 骷髏召喚 | 每回合可消耗 1 魔力，召喚低攻擊力的骷髏雜魚 | 前兩回合是否免費、每回合使用次數、骷髏數值與召喚位置 |

## 生物轉死靈法術

轉化法術分為立即轉化與死亡後產生死靈兩類；種族對應的衍生生物尚未建立。

| 編號 | 原始構想 |
|---|---|
| 死靈化法術 1 | 將對應種族生物轉為對應的死靈生物／token |
| 死靈化法術 2 | 賦予生物死亡時觸發的效果，轉成該種族對應的死靈生物／token |
| 死靈化法術 3 | 賦予生物死亡時觸發的效果，轉成固定的死靈生物／token |

## 召喚死靈法術

召喚來源包含直接產生死靈與復活墓地生物，部分法術另外消耗墓地牌。

| 編號 | 原始構想 |
|---|---|
| 召喚死靈法術 1 | 消耗魔力，召喚指定種族的死靈生物 |
| 召喚死靈法術 2 | 消耗魔力與墓地任意牌，換取較低魔力消耗，或召喚高階死靈生物；墓地牌消耗後去向待定 |
| 召喚死靈法術 3 | 復活墓地生物，一回合後才轉為死靈系 |
| 召喚死靈法術 4 | 在空位置召喚骷髏雜魚 |

## 攻擊死靈法術

攻擊法術涵蓋死靈化、控制、卡槽干擾與利用敵方墓地造成傷害。

| 編號／名稱 | 原始構想 |
|---|---|
| 攻擊死靈法術 1 | 將對手生物死靈化，轉成死靈系生物 |
| 攻擊死靈法術 2 | 將對手的死靈系生物轉為我方控制 |
| 攻擊死靈法術 3 | 被擊破的死靈傳播死靈化，使擊破它的敵方生物轉成死靈系 |
| 攻擊死靈法術 4 | 將對手場地塞滿骷髏雜魚；這些骷髏死亡後回到我方墓地 |
| 攻擊死靈法術 5：墓地爆破 | 將對手墓地所有生物放逐到次元，無法再被召喚 |
| 攻擊死靈法術 6：死者之怒 | 以敵方墓地生物數量的一半作為總傷害，平均分配給場上；對象範圍與取整待定 |
| 攻擊死靈法術 7：亡者將生者拉入地獄 | 高耗魔；對敵方指定一隻生物造成等同敵方墓地生物數量的傷害 |

## 防禦死靈法術

防禦法術利用墓地形成骨盾，或以場上死靈分擔對自己的傷害。

| 編號／名稱 | 原始構想 | 待釐清 |
|---|---|---|
| 防禦死靈法術 1：骨盾 | 消耗墓地生物並放逐到次元，每隻提供 1 骨盾；每次抵擋當前骨盾一半的傷害；剩 1 骨盾時抵擋 1 傷害後消失 | 抵擋上限的精確公式、取整、每次抵擋後扣除多少骨盾 |
| 防禦死靈法術 2：傷害轉移 | 將傷害轉移給場上指定死靈；超過其生命的傷害溢出回自己，並增加 2 額外傷害 | 額外傷害數值可調；是否只在溢出時追加、減傷結算順序 |
| 防禦死靈法術 3：傷害平分 | 高耗魔；將對自己的傷害平均分給場上所有死靈與自己 | 是否包含敵方死靈、餘數分配、分攤後死亡與溢出規則 |

## 死靈共通規則構想

一般生物被復活或受死靈法術影響後會死靈化；原生死靈不承受轉化帶來的減攻與生命流失。

| 項目 | 原始構想／未定選項 |
|---|---|
| 一般生物死靈化 | 轉成死靈系，生命逐漸流失；光環或被動可能阻止此效果 |
| 攻擊力變化 | 依死靈化程度，剩原本的 80% 或一半；程度如何區分待定 |
| 原生死靈 | 不受上述死靈化 debuff 影響 |
| 治療互動 | 死靈化生物與原生死靈不能被治癒；考慮治療轉成傷害，造成兩倍治療量的傷害 |
| 復活例外 | 「召喚死靈法術 3」一回合後才死靈化，與通常復活立即轉化的關係待定 |
| 技能限制範圍 | 禁止被動／進場、保留主動目前明確寫在死者轉生；是否擴及所有復活或死靈化待定 |
| 光環與被動豁免 | 死者轉生會停用被動；如何與阻止生命流失的被動共存待定 |

## 討論建議（尚未採納）

以下是助手提出的收斂與測試建議，不取代上述原始構想，也不構成實作決議。

| 建議 | 原因／例子 |
|---|---|
| 分開記錄死靈身分、生命流失與復活後放逐 | 敵方只被轉成死靈時，不必自動同時減攻、減血、封被動 |
| 考慮保留原種族並增加死靈身分 | 種族對應法術仍能辨識轉化前的種族 |
| 明定生命流失時點與是否算傷害 | 例如控制者回合結束失去生命，不被骨盾抵擋；僅為候選方案 |
| 限制塞敵方卡槽、全面清墓地與永久奪取 | 本作前後排卡槽有限；塞滿可能阻止對手出兵，清墓地可能一次耗盡流派資源 |
| 先測無法治療，再評估雙倍反傷 | 避免低費治療配合死靈化成為過強的解牌 |
| 骨盾可考慮扣除實際抵擋量 | 假設骨盾 5、來襲傷害 4，向上取整擋 3，自己受 1、剩 2 骨盾；此公式未定案 |
| 先驗證小套牌的墓地循環 | 候選包含兩種主動技能、死亡產生骷髏、墓地消耗召喚、骨盾、承傷、死靈化與有限制控制 |

## 定案前需要確認

下一步先確認主動技能的承載者，再統一死靈化、死亡與墓地消耗的規則。

- 主動技能替換玩家／英雄技能，還是某張生物技能？
- 原種族是否保留？死靈化是改身分、變成另一張 token，還是依卡牌區分？
- 生命流失、半值取整、治療反傷及技能封鎖的適用範圍為何？
- 復活生物回手、變形或轉移控制後，是否保留死亡放逐標記？
- token 能否進墓地、復活、支付墓地消耗？控制者與擁有者不同時進哪方墓地？
- 召喚遇到滿場、控制轉移遇到滿場、沒有合法目標時如何處理？
- 各法術費用、目標、次數、持續時間與傷害分配如何定義？

相關規劃見 [Demo 完成度與戰鬥手感計畫](demo_readiness.md)。本次僅保存設計草案，未進行程式實作或平衡驗證。

---

## 導師架構分析與引擎落地建議

本節由導師代理人於 2026-09-18 補充，銜接上方原始構想與另一位代理人之收斂建議，提供對齊現有程式碼架構（Godot 4.7）的系統依賴分析、體驗風險評估與四階段落地藍圖。

### 一、底層架構現況與四大擴充缺口

- **結論**：現有引擎已有墓地陣列與基本召喚能力，但要支撐死靈體系的完整循環，仍缺放逐區、種族標籤、反向治療與英雄技能面板四個底層零件。
- **怎麼解**：在資料層補齊放逐容器與卡牌種族屬性，並在戰鬥結算處加入死靈屬性的反轉判定。
- **為什麼這樣解**：若不補放逐區，轉生怪物死亡會無限回墓地形成死循環；若缺少種族標籤，程式無法判斷哪些從者能吃死靈聯動。
- **舉例**：現有系統與預計擴充之對應清單如下：

| 擴充零件 | 現行程式現狀 | 預計擴充規格 | 對應受影響檔案 |
| :--- | :--- | :--- | :--- |
| **放逐區 (Exile / 次元)** | 僅有 `SideState.grave: Array[CardData]` | 新增 `SideState.exile: Array[CardData]` 與 `exile(side, cd)` | [`src/battle_manager/battle_manager.gd`](../src/battle_manager/battle_manager.gd) |
| **種族標籤 (Tribe)** | 僅有 `CardType`（從者/秘術…） | 新增 `@export var tribe: StringName`（如 `&"不死"`、`&"野獸"`） | [`src/card/card_data.gd`](../src/card/card_data.gd) |
| **反向治療 (Reverse Heal)** | `heal()` 直接無條件回血 | `if is_undead: take_damage(amount * 2)` 反轉造成傷害 | [`src/card/card.gd`](../src/card/card.gd), [`src/hero/hero.gd`](../src/hero/hero.gd) |
| **英雄主動技能** | 英雄僅為 20 血立牌，無技能按鈕 | 在英雄立牌旁增加可點擊的技能徽章與冷卻計數（如 `hero_skill_cd`） | [`src/hero/hero.gd`](../src/hero/hero.gd), [`src/battle_ui/battle_ui.gd`](../src/battle_ui/battle_ui.gd) |

### 二、數值心算與對局體驗的三大陷阱

- **結論**：這套設計中最需要調整的是塞滿對手卡槽導致的死鎖、骨盾除以二的浮點數除法，以及反傷轉移公式過於複雜。
- **怎麼解**：
  1. **塞怪數量設限**：塞骷髏雜魚限制在 1～2 隻，或賦予防守方主動獻祭被卡格子的權利。
  2. **骨盾採固定整數**：將骨盾改成固定點數吸收（例如「獲得 4 點骨盾，每次受傷吸收 2 點並扣除 1 點骨盾」），避免除法餘數問題。
  3. **簡化傷害轉移**：移除「溢出傷害額外 +2」的次級計算，改為純粹的「指定死靈替本體吸收所有傷害」。
- **為什麼這樣解**：卡牌對局需確保玩家在 3 秒內完成心算；若前排被垃圾怪塞滿且無法清理，對手連王牌怪都出不來，會造成極差的挫折體驗。
- **舉例**：在 5 條路線前後排共 10 格的規則下，若「攻擊死靈 4」把敵方 10 格全塞滿 0/1 骷髏，敵方全場無法出怪也無法攻擊，對局將立刻失去互動價值。

### 三、推薦的四階段落地順序

- **結論**：落地時建議先補放逐區與種族標籤，再實作反向治療與死靈秘術，最後才接英雄主動技能。
- **怎麼解**：遵循「資料層契約 → 結算規則 → 卡牌資源檔 → 介面按鈕」由下而上的實作次序。
- **為什麼這樣解**：先建立好放逐區和標籤，所有法術和技能才有地方存取資料；若先做 UI 按鈕，底層沒有放逐陣列和反向治療，按鈕按下去會無效或報錯。
- **舉例**：
  - **階段 1（資料層擴充）**：在 `SideState` 加入 `exile` 陣列，在 `CardData` 加入 `tribe` 欄位。
  - **階段 2（結算層規則）**：在 `card.gd` 的 `heal()` 實裝不死族反轉扣血，並於回合開始加入生命流失 1 點的衰退結算。
  - **階段 3（卡牌資源實裝）**：建立 `skeleton_token.tres`（1/1 衍生怪），並製作「墓地爆破（放逐敵方墓地）」與「死者之怒（墓地傷害）」等秘術卡。
  - **階段 4（英雄介面整合）**：在 `hero.gd` 建立「死者轉生」主動技能按鈕與 2 回合冷卻計時器。

---

## 死靈流派定案規格（Sidegrade 統整版 2026-09-30）

本節為 2026-09-30 雙方代理人與 Harvey 共同收斂之最終定案規格。以「從者換怪、非從者換魔」的強制 Sidegrade 機制為核心，兼顧對局場面強度與高費跳費代價。

### 一、英雄主動技能：死者轉生（Sidegrade 契約）

將魔力回收區升級為「死者轉生」機制（同框、冷卻 2 回合）：

| 投入卡牌類型 | 結算效果 | 代價與限制 |
| :--- | :--- | :--- |
| **從者（MINION）** | **不給予魔力**，直接召喚至己方空位（攻 -1、腐朽 1、死亡放逐） | 費用必須 $\le \text{mana\_max}$（上限 7 費）；若超過則無法召喚（退回給予魔力） |
| **非從者（秘術/瞬咒/伏印/靈裝）** | 給予 $\lfloor \text{Cost} / 2 \rfloor$ 暫時魔力 | 與一般牌組規則完全一致 |

- **流派稅核心**：一般牌組能隨意丟高費大怪換取暫時魔力跳費；死靈牌組丟從者只能換取衰退場面，打 9–13 費卡必須刻意保留高費非從者作為魔力燃料。

### 二、雙標記與四項防雷規則

1. **【死靈】（身分標記）**：不能被治療（治療反轉為扣血）；吃死靈卡牌加成。原生骷髏與轉生怪物皆擁有。
2. **【腐朽 N】（狀態標記）**：控制者回合開始失去 N 點生命（非傷害，不扣骨盾）；攻擊力 -1。原生骷髏沒有此狀態，天生免除衰退。
3. **腐朽致死跳過不滅**：腐朽扣至 0 血時標記 `skip_revive = true`，直接入墓/放逐，避免不滅骷髏連續播放兩次死亡動畫。
4. **Card 實例節點隔離**：狀態掛在 `Card.statuses`，嚴禁修改 `CardData` 資源檔避免同名卡跨區域污染。
5. **Token 不刷墓地**：`bury()` 判定衍生怪（Token）直接消滅，不計入墓地總數。
6. **再死放逐**：轉生怪物死亡後進入 `SideState.exile`，徹底杜絕無限循環復活。

### 三、死靈流派 10 張卡池清單

| # | 推薦主名 | 備選名稱 A | 備選名稱 B | 類型／費 | 數值與效果 | 成本 |
| :---: | :--- | :--- | :--- | :--- | :--- | :---: |
| **1** | **斂骨儀** | 掘墓祭 | 殮葬儀式 | 秘術 2 | 將己方牌堆頂 2 張送入墓地；若其中包含從者，抽 1 張牌 | `🔧` |
| **2** | **守墓人** | 掘墓者 | 殮骨僧 | 從者 3 | 2/5；己方回合開始時，將牌堆頂 1 張送入墓地 | `🔧` |
| **3** | **亡者歸陣** | 朽骨甦醒 | 骸骨復甦 | 秘術 4 | 復活墓地中 1 隻費用 $\le 5$ 的從者，賦予【死靈】與【腐朽 1】 | `🧱` |
| **4** | **借屍還魂** | 一日之生 | 短暫回魂 | 秘術 2 | 復活墓地中 1 隻從者；該從者在己方回合結束時直接放逐 | `🧱` |
| **5** | **腐屍詛咒** | 死靈感染 | 活屍化 | 秘術 3 | 指定敵方 1 隻從者獲得【死靈】與【腐朽 1】（攻 -1、無法被治療） | `🧱` |
| **6** | **屍變伏印** | 墓土伏陣 | 亡骸徵召 | 伏印 2 | 埋設於敵方從者；該從者陣亡時，在該格召喚 1/1 骷髏（歸我方） | `🔧` |
| **7** | **死者之怒** | 亡魂潮 | 墓火湧動 | 秘術 5 | 放逐我方墓地 3 張從者卡：對敵方本體造成 4 點直擊傷害 | `🧱` |
| **8** | **食屍巨魔** | 噬骸魔 | 墓噬者 | 從者 6 | 4/6；戰吼：放逐我方墓地最多 3 張從者，每張獲得 +1/+1（最高 7/9） | `🧱` |
| **9** | **白骨君王** | 屍山之主 | 墓原霸主 | 從者 11 | 6/10；戰吼：檢定我方墓地，每有 3 張卡牌便獲得 +1/+1（進場結算一次） | `🧱` |
| **10** | **白骨障壁** | 骨骸壁壘 | 骨盾結界 | 秘術 3 | 放逐我方墓地 2 張從者卡：本體獲得 4 點骨盾，每次受傷吸收 2 點後扣除 | `🧱` |

---

## 2026-09-30 決議更新：主動技能改走堆怪路線，並附美術 prompt

> ⚠ **與上一節的關係（未由 Harvey 裁決）**：上方〈死靈流派定案規格（Sidegrade 統整版）〉
> §一 的死者轉生是「丟從者 → 召喚那一隻」；本節是 Harvey 其後提出的堆怪方向，
> 改為「丟從者 → 召喚 3 隻骨盾兵」。兩者**互斥，只能擇一**。
> 該節的 §二（雙標記與防雷規則）與 §三（10 張卡池）與本節不衝突，繼續有效。

本節取代上方「主動技能替換構想」中的死者轉生規格，原文保留不動以便對照。
本節的前提全部查證自現行程式，非假設；引用處附檔名與行號。

### 一、查證過的四個前提

**結論：死靈流派缺的不是送墓地手段，而是一個不會把自己燃料拆掉的主動技能。**

| 前提 | 查證結果 | 出處 |
| :--- | :--- | :--- |
| 送墓地手段 | **已存在**。棄牌回魔最後一行就是 `bury(side, cd)`，回魔的牌直接入墓 | `battle_manager.gd:291-298` |
| 棄牌回魔的身分 | 它就是玩家層級的主動技能：冷卻 2 回合、自己回合開始 -1 | `battle_manager.gd:127`、`:296` |
| 使用時機 | 只能在自己回合用（`active_side` 判斷），換來的魔力留得到對手回合 → 支撐瞬咒反制 | `card_manager.gd:1137` |
| 場地格數 | **維持 10 格**（5 路 × 前後排）。後排不拿掉 | 見下方§五 |

推論：死靈與快攻**同框、同冷卻**，二選一。換上死靈技能就永久失去「在對手回合突然變出魔力」的能力，
所以死靈打不了瞬咒戰，它的防線只能是身體。這也決定了死靈主動技能不能太弱——
它是抗快攻的唯一按鈕，弱了不是 4:6，是 2:8。

### 二、主動技能規格：屍潮召集

命名候選：**白骨徵召**（推薦主名，契合盾兵築防） ／ **屍潮召集**（備選，偏進攻感） ／ **亡者列陣**

| 項目 | 規格 | 為什麼 |
| :--- | :--- | :--- |
| 佔用 | 取代棄牌回魔，同一個框 | 玩家已經熟悉那個投放區，不新增 UI |
| 冷卻 | 2 回合 | 與棄牌回魔相同，不新增規則 |
| 成本 | 丟 1 張**手牌從者**（不獻祭場上單位） | 獻祭型在前期場上無怪時是死技能，而前期正是死靈最需要它的時候 |
| 產出（前期） | 在我方**前排空位**召喚 3 隻骨盾兵，不足空位就少召 | 現行 `_resolve_summon` 沒空位會靜默落空，卡面要寫清楚 |
| 產出（後期） | **我方墓地 ≥ 12 張**時，改為召喚 1 隻死亡騎士 | 見下方觸發條件說明 |
| 死靈系 | 不受死靈化與腐朽影響 | 沿用原草案規則 |

**為什麼成本是「丟手牌」而不是「獻祭場上」**：一般牌組丟任何牌換 Cost÷2 魔力；
死靈丟從者換的是身體，**不給魔力**。這是強制轉換不是二選一，否則它就是棄牌回魔的純上位，
任何牌組都會想換上它。代價很具體：死靈再也不能把大怪換成魔力，
付 13 費赤曜古龍的燃料只剩非從者（亡軍之門 12、輪迴伏印 12、終焉儀式 13、不滅王冠 11）。

### 三、連帶調整的三條規則

- **骨盾兵不帶【不滅】**。【不滅】讓單位死兩次才入墓（`battle_manager.gd:1259-1264`），
  把墓地累積速度砍半，與堆墓地的核心互相打架。現有 `skeleton.tres`（2/2 帶不滅）不可直接沿用。
- **腐朽只用於攻擊法術，不用於自己的召喚物**。復活出來的怪若每回合掉血，
  死靈的防線會在最需要擋刀時自己垮；改用「死亡時放逐」當一次性成本，
  順便解掉腐朽致死觸發【不滅】導致復活動畫連播的迴圈。
- **升級條件用墓地張數，不用回合數**。回合數是外生的：若多數對局在第 8 回合前結束，
  死亡騎士等於不存在的卡。墓地張數是內生的，對上快攻時被逼著丟牌反而提早觸發。

### 四、尚未決定

- 丟進去的那張從者，能否被我方復活卡撈回？會的話這個技能從「成本」變成「循環」，強度級距完全不同。
- ~~骨盾兵 token 是否計入墓地張數~~ → 已由上一節 §二 規則 5 決議：token 不刷墓地。
  實作時注意 `bury()` 目前無 token 過濾（`battle_manager.gd:1277`），需新增判定。
- 對位勝率（目標 6:4 為紅線）無法紙上推導：此對位是「死靈能否活過第 6 回合」的開關，
  不是連續刻度。需 `src/ai/enemy_ai.gd` 雙邊自動對戰量測，該工作包尚未評估。

### 五、後排卡槽：暫不移除

三場試玩（2 位玩家 + 作者）皆未使用後排。程式面解釋了原因：後排**不當阻擋**
（`_lane_blocked` 只看前排），但【貫穿】照樣打得到——只有壞處沒有好處，理性玩家必然先填前排。

暫不移除，理由是移除與本流派直接衝突：3 隻骨盾兵在 10 格場地佔 30%，在 5 格場地佔 60%。
後續若要處理，建議先加一條「同路線前排有我方單位時，後排不能被普通攻擊指定」再試玩一次；
`approach_on_attack` 欄位已存在但目前只影響演出、不影響規則，遠程站位的資料層已有一半。

移除的破壞面（備查）：雷霆貫穿與蜥蜴人戰士的【貫穿】失去第二目標、`_unit_behind()`
與卡槽群組約 8 處、場景 10 格改 5 格並重調鏡頭構圖。

### 六、美術素材規格

**結論：這兩隻新單位各需要 1 套像素立牌動畫表 + 1 張卡圖，卡圖走現行的「素材圖 → 套主題背景」兩段式。**

| 用途 | 欄位 | 規格 | 命名與位置 |
| :--- | :--- | :--- | :--- |
| 立牌動畫 | `CardData.standee` | **600×100 PNG，6 幀 × 100×100，透明背景、無陰影**；角色約佔單格中央 40×55，腳底對齊固定基線 | `assets/packs/.../<Name>/<Name>_Idle.png`，兄弟表同資料夾換後綴 |
| 卡圖素材 | — | 橫式約 3:2 像素畫，深色空背景 | `assets/ui/card_art/<slug>_card_art.png` |
| 卡圖成品 | `CardData.art` | 同上，已套主題背景；`use_dedicated_art = true` | `assets/ui/card_art/<slug>_themed_card_art.png` |

動畫後綴由 `CardData.get_anim_sheet()` 從 standee 路徑推出（取代最後一個底線之後的字串），
所以兄弟表必須同資料夾、同前綴。需要的後綴：

| 後綴 | 誰需要 | 用途 |
| :--- | :--- | :--- |
| `_Idle` | 兩隻都要 | 待機（也是卡面第 0 幀來源） |
| `_Attack01` | 兩隻都要 | 普通攻擊 |
| `_Attack02` | 只有死亡騎士 | 主動技能；骨盾兵無主動技可略 |
| `_Summon(With magic effects)` | 兩隻都要 | 登場演出 |
| `_DEATH` | 兩隻都要 | 陣亡演出 |

> ⚠ 實務提醒：影像模型產出「精確 6 幀 × 100×100 等距網格」的成功率很低。
> 建議**單幀生成再自行排表**，或先只生 `_Idle` 單幀驗證造型，通過後再補動畫幀。

### 七、生成 Prompt（可直接複製）

風格基準取自 `assets/ui/card_art/necromancer_themed_card_art.png`：
深色地窖拱廊、紫色靈焰、石板地、低彩度暗藍紫調、粗顆粒清晰像素。
主題背景用 `docs/art/candidates/candidate_bg_catacombs.png`（現有 catacombs 主題，
幽幕咒師、替身秘偶、虛空反噬三張已在用）。

#### 7.1 骨盾兵（命名候選：**白骨盾衛**［推薦］／ 骨盾兵 ／ 殘骸盾衛，slug `bone_shield_token`）

設計要點：1/3、嘲諷、**不帶不滅**。造型要一眼看出是「消耗品雜魚」——
比現有骷髏兵更破爛、盾比劍顯眼，不能看起來像精銳。

立牌單幀 prompt：

```text
Crisp dark-fantasy pixel art game sprite, single frame, transparent background, no shadow,
no ground, no text. A small ragged skeleton shield-bearer: bone-white skull and ribcage,
tattered grey cloth wrap, holding a battered oversized wooden-and-iron kite shield in front
of its body with a short rusted dagger in the other hand. Defensive braced stance, facing
right in three-quarter view, full body visible, feet flat on an implied baseline.
Deliberately cheap and expendable looking: cracked bones, dented shield, missing chunks.
Muted desaturated palette of bone white, cold grey and dull iron, thin dark outline,
coarse readable pixel clusters, character about 55 pixels tall centered in a 100x100 canvas
with transparent margin on all sides. No weapon or limb touching the canvas edge.
```

卡圖素材 prompt（橫式 3:2，之後再套背景）：

```text
Crisp dark-fantasy pixel art trading-card illustration, landscape 3:2 aspect ratio.
A ragged skeleton shield-bearer standing on cracked stone floor, bone-white skull and
ribcage, tattered grey cloth, battered oversized kite shield braced forward, short rusted
dagger low in the other hand. Full body visible, centered, standing within the central 35%
of the width, feet at about 83% of canvas height, head no higher than 23%.
Muted desaturated palette: bone white, cold grey, dull iron, dark navy shadow.
Plain dark navy backdrop behind the subject, minimal detail, subdued contrast.
Coarse crisp pixel clusters with thin dark outlines. No text, no watermark, no card frame,
no border, no UI, no numbers.
```

#### 7.2 死亡騎士（命名候選：死亡騎士／枯骨騎將／無明騎士，slug `death_knight`）

設計要點：建議 5/7、嘲諷 + 衝鋒（對照費 7 的惡魔將軍 6/7 衝鋒、深淵騎士 5/8 嘲諷）。
造型必須明顯壓過骨盾兵——它是「3 隻雜魚換 1 隻品質」的後期型態，一眼看得出升級。

立牌單幀 prompt：

```text
Crisp dark-fantasy pixel art game sprite, single frame, transparent background, no shadow,
no ground, no text. An imposing undead death knight: full blackened plate armor with a
horned helm, hollow eye sockets glowing pale violet, torn dark cloak, gripping a large
two-handed greatsword point-down in front of it. Heavy commanding stance, facing right in
three-quarter view, full body visible, feet flat on an implied baseline.
Clearly elite and menacing, in deliberate contrast to cheap skeleton minions.
Palette of blackened steel, deep violet and bone white accents, pale violet soul-glow only
at the eyes and along the blade edge, thin dark outline, coarse readable pixel clusters.
Character about 70 pixels tall centered in a 100x100 canvas with transparent margin on all
sides. No weapon or limb touching the canvas edge.
```

卡圖素材 prompt：

```text
Crisp dark-fantasy pixel art trading-card illustration, landscape 3:2 aspect ratio.
An imposing undead death knight standing on cracked stone floor: full blackened plate armor
with horned helm, hollow eye sockets glowing pale violet, torn dark cloak, large two-handed
greatsword held point-down before it. Full body visible, centered, standing within the
central 35% of the width, feet at about 83% of canvas height, head no higher than 23%.
Palette of blackened steel, deep violet and bone white, pale violet soul-glow confined to
the eyes and blade edge. Plain dark navy backdrop behind the subject, minimal detail,
subdued contrast. Coarse crisp pixel clusters with thin dark outlines.
No text, no watermark, no card frame, no border, no UI, no numbers.
```

#### 7.3 套主題背景（第二段，沿用 `card-art-unification-prompts.json` 的合成寫法）

把 7.1／7.2 產出的素材圖當 Image 1、`candidate_bg_catacombs.png` 當 Image 2：

```text
Use case: compositing. Image 1 is the EDIT TARGET: an existing pixel-art card illustration.
Image 2 supplies ONLY the replacement catacombs background. Replace the plain navy backdrop
and old stone floor in Image 1 with the subdued scene from Image 2. Preserve the foreground
character from Image 1 exactly: identical design, pose, shape, all symbols, colors, weapons,
pixel texture and proportions. Keep the subject centered, its original relative size and
placement, all parts visible; keep the full subject within the central 65% width and between
23% and 83% of canvas height so it fits the game card crop. Landscape approximately 3:2.
Subdue background detail and contrast behind the subject. Same dark fantasy crisp pixel art
as the reference. No text, no watermark, no card frame, no border.
```

#### 7.4 其他新卡的 prompt 模板

上方兩段式流程可直接套用到後續死靈卡。替換角色描述那一句即可，風格句一個字都別改——
24 張要看起來像同一個畫師畫的（沿用 `docs/card_art_prompts.md` 的原則）。
法術卡把「standing on cracked stone floor」的角色描述換成懸浮符號描述，
其餘欄位不動；現有秘術卡即是此作法。
