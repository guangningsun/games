class_name BrickConfig
extends RefCounted
## BrickConfig —— 砖块类型与属性定义
##
## M8 重构：PowerUp 掉率降低（原 NORMAL 30%/GOLD 100% 太频繁）
##
## pattern 字符映射：
##   0 = 空
##   1 = NORMAL（绿色，普通分）
##   2 = GOLD（金色，高分+高掉率）
##
## PowerUp 掉率（M8 调整）：
##   NORMAL: 8%（每打掉一个普通砖 8% 概率掉道具）
##   GOLD:   35%（金色砖 35% 概率掉道具）

const TYPE_EMPTY := 0
const TYPE_NORMAL := 1       ## 1 HP，绿色，普通方块
const TYPE_GOLD := 2         ## 1 HP，金色，高分+高掉率

const STATS := {
	TYPE_NORMAL: {
		"hp": 1,
		"score": 10,
		"color": Color(0.30, 0.85, 0.40),
		"powerup_drop_rate": 0.08,
	},
	TYPE_GOLD: {
		"hp": 1,
		"score": 100,
		"color": Color(0.95, 0.85, 0.30),
		"powerup_drop_rate": 0.35,
	},
}


## 根据 type 拿属性
static func get_stats(type: int) -> Dictionary:
	if STATS.has(type):
		return STATS[type]
	return STATS[TYPE_NORMAL]


## 根据 type 拿颜色
static func get_color(type: int) -> Color:
	return get_stats(type)["color"]


## 根据 type 拿分数
static func get_score(type: int) -> int:
	return get_stats(type)["score"]


## 根据 type 拿最大血量
static func get_max_hp(type: int) -> int:
	return get_stats(type)["hp"]


## 根据 type 拿 PowerUp 掉率
static func get_powerup_drop_rate(type: int) -> float:
	return get_stats(type)["powerup_drop_rate"]