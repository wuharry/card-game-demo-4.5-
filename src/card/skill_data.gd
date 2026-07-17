## skill_data.gd — 一個「主動技能」的資料定義(掛在 CardData.active_skill 上)
##
## 設計藍圖見 docs/skills_design.md;規則錨點見 README Gameplay Spec §6.1。
## 跟 CardData 同一哲學:純資料、不進場景樹。戰鬥系統(README 待辦 #5)動工時
## 讀這包數值做結算;立牌則用 anim 欄位切換動畫表(普攻 Attack01 免費、技能收魔力)。
## 現在先把資料層備好 = 之後系統直接吃,不用回頭改 24 張卡。
extends Resource
class_name SkillData

## §6 的三分類:決定技能佔不佔「每回合 1 次攻擊」的行動經濟。
enum Kind {
	ENHANCED_ATTACK,     ## 強化攻擊:改變本次攻擊的性質,發動 = 用掉這回合的攻擊
	INDEPENDENT_ATTACK,  ## 獨立攻擊:額外一次攻擊,不佔普攻(召喚當回合不可用)
	NON_ATTACK,          ## 非攻擊:治療/增益/控場,與攻擊無關、可自由加用
}

## 三分類的顯示名(卡面/指令選單/hover 預覽的標示;桌遊試玩回饋:要標出來)。
const KIND_NAMES := {
	Kind.ENHANCED_ATTACK: "強化攻擊",
	Kind.INDEPENDENT_ATTACK: "獨立攻擊",
	Kind.NON_ATTACK: "非攻擊",
}

## 攻擊型技能的「打法修飾」(強化/獨立攻擊限定)。
enum Modifier {
	NONE,       ## 一般單體
	SPREAD_3,   ## 橫掃:同時命中左/中/右三路(§4.1 的 SPREAD_3)
	PIERCE,     ## 貫穿:同時命中目標路線的前排與後排
	DOUBLE,     ## 連擊:本次攻擊結算兩次
	LIFESTEAL,  ## 吸血:回復等同本次造成傷害的 HP(不超過上限)
}

## 附加效果(非攻擊技的主體;攻擊型技能則是「命中後」附帶觸發)。
enum Effect { NONE, HEAL, APPLY_STATUS, SUMMON }

## 效果作用對象。
enum Target { SELF, ALLY, LANE_ENEMY }

## 狀態種類(對齊 README Gameplay Spec §9 狀態效果表)。
enum Status { NONE, BURN, FREEZE, POISON, NIGHT_VEIL, FORGE }

@export var skill_name: String = "未命名技能"
@export_multiline var description: String = ""   # 卡面 / UI 顯示的效果描述
@export var kind: Kind = Kind.ENHANCED_ATTACK
@export var cost: int = 1                # 魔力費(§6.1:普攻免費,技能才收費)
@export var anim: String = "Attack02"    # 動畫表後綴,交給 CardData.get_anim_sheet 解析
                                         # (預設 Attack02;牧師 "Heal(With magic effects)"
                                         #  這類專屬表就填完整後綴)

@export_group("攻擊型參數")
@export var power: int = 0               # 強化攻擊 = 攻擊加值;獨立攻擊 = 該次攻擊的傷害
@export var modifier: Modifier = Modifier.NONE

@export_group("效果參數")
@export var effect: Effect = Effect.NONE
@export var effect_target: Target = Target.LANE_ENEMY
@export var amount: int = 0              # HEAL 的治療量
@export var status: Status = Status.NONE          # APPLY_STATUS 施加哪種狀態
@export var status_turns: int = 1                 # 狀態持續回合(§9 上限:灼燒 ≤ 2)
@export var summon_card: String = ""     # SUMMON 要生誰(data/cards 檔名,如 "skeleton")
