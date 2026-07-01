extends Area2D
class_name PowerUp
## PowerUp —— 道具掉落实体
##
## 砖块销毁时按概率生成，从销毁位置向下飘
## 接到（Paddle 碰撞）：触发效果
## 没接到（掉出底部）：自动销毁
##
## 类型（4 种）：
##   0 BONUS_SCORE:       直接 +500 分
##   1 EXTEND_PADDLE:     挡板永久 +30px（上限屏幕 1/2 = 360px）
##   2 MULTIPLY_BALLS:    当前所有球各克隆一份（×2）
##   3 ADD_BALLS:         +2 个新球（从 paddle 出发）

signal collected(powerup_type: int)

const TYPE_BONUS_SCORE := 0
const TYPE_EXTEND_PADDLE := 1
const TYPE_MULTIPLY_BALLS := 2
const TYPE_ADD_BALLS := 3

const FALL_SPEED: float = 220.0
const OFFSCREEN_Y: float = 1320.0  ## 超过这个 y 自动销毁
const SELF_DESTRUCT_TIME: float = 8.0  ## 兜底：8 秒没接到也消失

var powerup_type: int = TYPE_BONUS_SCORE

@onready var _sprite: Sprite2D = $Sprite


func setup(p: int) -> void:
	powerup_type = p


func _ready() -> void:
	# 道具颜色 + 符号
	match powerup_type:
		TYPE_BONUS_SCORE:
			_sprite.texture = PixelArt.create_powerup_texture(Color(1.0, 0.85, 0.2), "+500")
		TYPE_EXTEND_PADDLE:
			_sprite.texture = PixelArt.create_powerup_texture(Color(0.4, 0.8, 1.0), "↔")
		TYPE_MULTIPLY_BALLS:
			_sprite.texture = PixelArt.create_powerup_texture(Color(0.95, 0.50, 0.20), "x2")
		TYPE_ADD_BALLS:
			_sprite.texture = PixelArt.create_powerup_texture(Color(0.40, 0.90, 0.40), "+2")

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