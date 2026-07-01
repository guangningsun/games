extends Area2D
class_name PowerUp
## PowerUp —— 道具掉落实体
##
## 砖块销毁时按概率生成，从销毁位置向下飘
## 接到（Paddle 碰撞）：触发效果
## 没接到（掉出底部）：自动销毁
##
## 类型（3 种，M10 按类型分色便于区分）：
##   0 EXTEND_PADDLE:  挡板永久 +30px（上限屏幕 1/2 = 360px）── 青色
##   1 MULTI_BALL:     +2 个新球（从 paddle 出发，散开方向）    ── 橙色
##   2 DOUBLE_BALLS:   当前所有活球各克隆 1 份（×2，上限 MAX_BALLS=50）── 紫色

signal collected(powerup_type: int)

const TYPE_EXTEND_PADDLE := 0
const TYPE_MULTI_BALL := 1
const TYPE_DOUBLE_BALLS := 2

# M10: 3 种 PowerUp 各自颜色（之前 M8 全部统一绿色）
const POWERUP_COLORS := {
	TYPE_EXTEND_PADDLE: Color(0.20, 0.85, 0.95),  ## 青色 —— 强化类
	TYPE_MULTI_BALL: Color(0.98, 0.65, 0.20),     ## 橙色 —— 加成类
	TYPE_DOUBLE_BALLS: Color(0.78, 0.30, 0.90),   ## 紫色 —— 翻倍类
}

const FALL_SPEED: float = 220.0
const OFFSCREEN_Y: float = 1320.0  ## 超过这个 y 自动销毁
const SELF_DESTRUCT_TIME: float = 8.0  ## 兜底：8 秒没接到也消失

var powerup_type: int = TYPE_EXTEND_PADDLE

@onready var _sprite: Sprite2D = $Sprite


func setup(p: int) -> void:
	powerup_type = p


func _ready() -> void:
	# M10: 按类型选颜色 + 符号
	var color: Color = POWERUP_COLORS.get(powerup_type, Color.GREEN)
	match powerup_type:
		TYPE_EXTEND_PADDLE:
			_sprite.texture = PixelArt.create_powerup_texture(color, "<>")
		TYPE_MULTI_BALL:
			_sprite.texture = PixelArt.create_powerup_texture(color, "+2")
		TYPE_DOUBLE_BALLS:
			_sprite.texture = PixelArt.create_powerup_texture(color, "x2")

	# 兜底超时
	var t: SceneTreeTimer = get_tree().create_timer(SELF_DESTRUCT_TIME)
	t.timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)


func _physics_process(delta: float) -> void:
	# 下落
	global_position.y += FALL_SPEED * delta
	# 旋转（视觉）
	_sprite.rotation += delta * 2.0

	# 出界销毁
	if global_position.y > OFFSCREEN_Y:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# Paddle 接到（通过 group "paddle" 识别）
	if body.is_in_group("paddle"):
		collected.emit(powerup_type)
		queue_free()