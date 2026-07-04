## card_data.gd — 一張卡的「資料定義」(Route A 資料層,藍圖見 docs/HANDOFF_card_data.md)
##
## CardData 是 Resource(資料),不是 Node(場上物件):
##   ‧ 它不進場景樹、不跑邏輯,只是一包數值。
##   ‧ 一份 CardData 可以生出很多張場上的 Card 節點(同名怪可以同時出好幾隻)。
##   ‧ 存成 .tres 檔(在 data/cards/),編輯器 Inspector 就能視覺化編輯。
##
## 核心原則:會變的(數字/名字)= 資料 + 文字節點;不變的外觀 = 圖。
## 永遠別把數值烤進卡圖裡——那是「每種組合一張圖」的排列組合地獄(交接筆記 §3)。
extends Resource
class_name CardData   # 註冊全域型別:Inspector 的「新增資源」搜尋得到、變數能寫 var d: CardData

@export var card_name: String = "未命名"   # 卡名(顯示在 NameLabel)
@export var cost: int = 1                  # 召喚費用(左上 CostLabel)
@export var atk: int = 1                   # 攻擊力(左下 ATKLabel)
@export var hp: int = 1                    # 生命值(右下 HPLabel)
@export var art: Texture2D                 # 卡圖:卡框中央的繪畫風插圖
                                           # (AI 卡圖生出來前,先拿像素圖佔位)
@export var standee: Texture2D             # 立牌圖:召喚上桌時「站在卡片上」的
                                           # HD-2D 像素角色(billboard 顯示,功能待做;
                                           # 資料先備好 = 之後召喚系統直接讀這欄)
