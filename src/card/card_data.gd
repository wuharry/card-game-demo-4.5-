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

## §7 卡牌類型。目前只有從者卡有實作;其餘型別素材未到、行為未寫,
## 但欄位先立好:新型別卡進來只是「加 .tres + 實作該型的結算」,舊卡一張不用回頭改。
## MINION 排第 0 = 預設值,所以現有 24 張 .tres 不需要任何改動。
enum CardType {
	MINION,   ## 從者:場上戰鬥單位(ATK/HP),召喚進卡槽
	EQUIP,    ## 靈裝:附著從者的裝備,宿主離場通常一併離場
	ARCANA,   ## 秘術:主動法術,結算後離場(僅攻方、自己回合)
	QUICK,    ## 瞬咒:反應法術,抵銷秘術/伏印(僅守方、反制窗口)
	WARD,     ## 伏印:蓋放的陷阱,條件觸發(埋設於主要階段)
	DOMAIN,   ## 領域:全場環境卡(§7 標注本版不使用,先佔位)
}

@export var card_type: CardType = CardType.MINION
@export var card_name: String = "未命名"   # 卡名(顯示在 NameLabel)
@export var cost: int = 1                  # 召喚費用(左上 CostLabel)
@export var atk: int = 1                   # 攻擊力(左下 ATKLabel)
@export var hp: int = 1                    # 生命值(右下 HPLabel)
@export var art: Texture2D                 # 卡面靜態圖;舊從者仍可放 standee 第 0 幀的 AtlasTexture
@export var use_dedicated_art: bool = false # true = 卡面/預覽讀 art,召喚立牌仍只讀 standee
@export var standee: Texture2D             # 立牌動畫表(show_standee 切幀播待機動畫)
@export var active_skill: SkillData        # 主動技能(預設 Attack02 動畫;null = 無主動技,
                                           # 見 README §6.1 與 docs/skills_design.md)
## 戰吼:召喚落地時自動結算一次的效果(null = 沒有戰吼)。
## 刻意「復用 SkillData」而不是另開 BattlecryData——它要的欄位(effect / effect_target /
## amount / status / summon_card)一個不多一個不少,新型別只會多一份要同步維護的合約。
## 差別只在「誰觸發」:主動技由玩家點、戰吼由 BattleManager.mark_summoned 自動跑,
## 所以 kind / cost / anim 這幾欄對戰吼沒有意義,填了也不讀。
@export var battlecry: SkillData
@export var keywords: Array[StringName] = []   # 被動關鍵字(README §8):
                                               # &"飛行"、&"不滅"、&"鐵壁"、&"衝鋒"…

## 高階卡的資料驅動欄位。舊卡全部使用預設值，行為完全不變；新卡則不用把
## 卡名硬寫進戰鬥系統。special_id 只標記無法由 SkillData 單一效果表達的複合結算。
@export_group("高階卡效果")
@export var special_id: StringName = &""
@export var equip_atk_bonus: int = 0
@export var equip_hp_bonus: int = 0
@export var equip_keywords: Array[StringName] = []
@export var equip_lifesteal: bool = false
@export var turn_start_heal: int = 0
@export var turn_start_shield: int = 0
@export var revive_hp: int = 1


## 從 standee 的路徑推「同資料夾的兄弟動畫表」,例:get_anim_sheet("Attack02")。
## 素材命名規則是 <角色>_<動畫>.png,把最後一個底線之後換掉即可——
## 這樣連蝙蝠(standee 是 Bat_Flying.png、沒有 Idle)也能正確推出 Bat_Attack02。
## 命名地雷(Swordsman_Attack3、Necromancer_DEATH…)由呼叫端填「完整後綴」處理;
## 檔案不存在回傳 null,呼叫端自行退回待機動畫,不炸。
func get_anim_sheet(suffix: String) -> Texture2D:
	if standee == null:
		return null
	var stem := standee.resource_path.get_basename()   # 去掉 .png
	var cut := stem.rfind("_")                         # 最後一個底線 = 動畫後綴起點
	if cut < 0:
		return null
	var path := stem.substr(0, cut + 1) + suffix + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path)
