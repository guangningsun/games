extends StaticBody2D
## Brick —— 砖块实体（M5 版本：像素风 Sprite2D）
##
## 生命周期：
## - 实例化时拿 type → 从 BrickConfig 读取 hp/color/score
## - _ready 时根据 brick_type + custom_size 程序生成像素贴图
## - 球碰撞时 take_damage() → 受击或销毁
## - 销毁时发 destroyed 信号（LevelLoader 监听后移除）
##
## 注意：砖块大小（size）由 LevelLoader 在生成时设置

signal damaged(brick: StaticBody2D, hp_left: int)
signal destroyed(brick: StaticBody2D, score: int, position: Vector2, brick_type: int)

@export var brick_type: int = BrickConfig.TYPE_NORMAL
@export var custom_size: Vector2 = Vector2(16, 12)  ## M7: 缩小一半（32x24 → 16x12）

var current_hp: int = 1
var score_value: int = 0

@onready var _sprite: Sprite2D = $Sprite
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _hp_label: Label = $HPLabel
@onready var _base_color: Color = Color.WHITE


func _ready() -> void:
	# 应用尺寸
	var rect_shape: RectangleShape2D = _collision.shape as RectangleShape2D
	rect_shape.size = custom_size

	# 程序生成砖块像素贴图（M5）
	_sprite.texture = PixelArt.create_brick_texture(brick_type, int(custom_size.x), int(custom_size.y))

	# 应用 BrickConfig 属性
	var stats: Dictionary = BrickConfig.get_stats(brick_type)
	current_hp = stats["hp"]
	score_value = stats["score"]
	_base_color = stats["color"]

	# HP > 1 时显示数字
	_update_label()


func take_damage(damage: int = 1) -> void:
	current_hp -= damage
	if current_hp <= 0:
		# 销毁时传出位置 + 类型，让 Main 生成对应颜色的粒子
		destroyed.emit(self, score_value, global_position, brick_type)
		queue_free()
	else:
		_flash_white()
		damaged.emit(self, current_hp)
		_update_label()


func _flash_white() -> void:
	# 用 modulate 而不是直接改 sprite.texture
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate", Color(2.0, 2.0, 2.0), 0.05)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)


func _update_label() -> void:
	# M6 重构：所有砖块 HP=1，不再显示数字
	_hp_label.visible = false