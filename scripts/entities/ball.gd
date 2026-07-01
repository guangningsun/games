extends CharacterBody2D
## Ball —— 弹球实体（M5 版本：像素风 Sprite2D）
##
## 2D 弹球物理：
## - 用 CharacterBody2D + move_and_collide，完全可控
## - 撞到任何碰撞体，按法线反射速度
## - 防卡死：水平速度过小时注入偏置
## - 漏球：掉出底部边界时通知
##
## M5：Sprite2D 像素贴图 + 碰撞音效区分（wall/brick/paddle）
## M7：砖块缩小，球跟着缩（9 → 8）
## M8：边界 clamp 防止球卡在墙内 + 最小垂直分量防卡死

signal ball_lost  ## 球掉出底部

@export var base_speed: float = 520.0
@export var min_horizontal_speed_ratio: float = 0.25
@export var launch_delay: float = 0.5
@export var ball_radius: int = 8

var is_launched: bool = false
var _viewport_size: Vector2 = Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_viewport_size = get_viewport().get_visible_rect().size
	velocity = Vector2.ZERO
	# M5: 程序生成球像素贴图
	_sprite.texture = PixelArt.create_ball_texture(ball_radius)


func _physics_process(_delta: float) -> void:
	if not is_launched:
		return

	# === 边界 clamp：防球卡在墙里出不来 ===
	# 边缘 bug 修：move_and_collide 反弹有时因浮点累积导致球陷入墙内
	# 每帧先钳位坐标 + 强制反向（不依赖碰撞检测）
	var r: float = float(ball_radius)
	if global_position.x < r:
		global_position.x = r
		if velocity.x < 0.0:
			velocity.x = -velocity.x
	elif global_position.x > _viewport_size.x - r:
		global_position.x = _viewport_size.x - r
		if velocity.x > 0.0:
			velocity.x = -velocity.x
	if global_position.y < r:
		global_position.y = r
		if velocity.y < 0.0:
			velocity.y = -velocity.y
	# 防水平球：垂直分量太小时注入偏移，避免球在墙边水平来回弹不出
	if absf(velocity.y) < 80.0:
		velocity.y = 80.0 * (1.0 if velocity.y >= 0.0 else -1.0)

	var collision: KinematicCollision2D = move_and_collide(velocity * _delta)
	if collision:
		# 按碰撞法线反射
		velocity = velocity.bounce(collision.get_normal())
		# 通知被撞物体（如果有 take_damage 方法，比如 Brick）
		var collider: Object = collision.get_collider()
		if collider and collider.has_method("take_damage"):
			collider.take_damage(1)
			SoundManager.play_sfx("hit_brick")
		elif collider and collider.is_in_group("paddle"):
			SoundManager.play_sfx("hit_paddle")
		else:
			SoundManager.play_sfx("hit_wall")
		# 防水平卡死
		_enforce_min_horizontal_speed()
	else:
		# 没碰撞：检查漏球
		if global_position.y > _viewport_size.y + 64:
			is_launched = false
			SoundManager.play_sfx("lose")
			ball_lost.emit()


func launch(from_position: Vector2, direction: Vector2 = Vector2.ZERO) -> void:
	global_position = from_position
	if direction == Vector2.ZERO:
		var angle: float = deg_to_rad(randf_range(-80.0, 80.0))
		direction = Vector2(sin(angle), -cos(angle))
	direction = direction.normalized()
	velocity = direction * base_speed
	is_launched = true


func reset_to_paddle(paddle_position: Vector2) -> void:
	is_launched = false
	velocity = Vector2.ZERO
	global_position = paddle_position + Vector2(0, -30)


func _enforce_min_horizontal_speed() -> void:
	var min_h: float = base_speed * min_horizontal_speed_ratio
	if absf(velocity.x) < min_h:
		var sign_x: float = 1.0 if velocity.x >= 0 else -1.0
		var new_h: float = min_h * sign_x
		var new_v: float = velocity.y
		var new_vel: Vector2 = Vector2(new_h, new_v).normalized() * base_speed
		velocity = new_vel