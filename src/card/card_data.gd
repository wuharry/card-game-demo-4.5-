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
@export var art: Texture2D                 # 卡圖(備用):AI 繪圖路線已棄用,現行
                                           # 卡圖由 card.gd 從 standee 掃第 0 幀放大;
                                           # 這欄留給未來真的有手繪卡圖時替換
@export var standee: Texture2D             # 立牌動畫表:card.gd 的卡圖與召喚立牌
                                           # 都讀這欄(show_standee 切幀播待機動畫)
@export var active_skill: SkillData        # 主動技能(預設 Attack02 動畫;null = 無主動技,
                                           # 見 README §6.1 與 docs/skills_design.md)
@export var keywords: Array[StringName] = []   # 被動關鍵字(README §8):
                                               # &"飛行"、&"不滅"、&"鐵壁"、&"衝鋒"…


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
