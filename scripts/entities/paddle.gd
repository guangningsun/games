extends CharacterBody2D
## Paddle —— 底部挡板
##
## 控制（按优先级）：
## 1. 触摸/拖动（微信小游戏主用）—— _input 处理 InputEventScreenTouch/Drag
## 2. 鼠标位置（桌面调试）—— get_global_mouse_position()
## 3. 键盘左右键（调试用）
##
## 约束：
## - X 不能超出左右墙（边界硬约束）
## - Y 固定（挡板只水平移动）

signal launched()  ## 玩家请求发射球

@export var move_speed: float = 1400.0
@export var follow_smoothness: float = 0.6  ## 跟随平滑系数（M4: 0.35 → 0.6，更紧贴手指）

var _viewport_size: Vector2 = Vector2.ZERO
var _half_width: float = 0.0
var _target_x: float = 0.0
var _touch_active: bool = false

## EXTEND_PADDLE 道具配置：永久累加，上限屏幕 1/2
const BASE_PADDLE_WIDTH: int = 120
const PADDLE_HEIGHT: int = 20
const PADDLE_GROW_AMOUNT: int = 30   ## 每次接到 EXTEND_PADDLE 加多少
const MAX_PADDLE_WIDTH: int = 360    ## 上限：屏幕宽度 720 的 1/2

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	# 注意：不要 await process_frame，viewport 在 _ready 时已经可用
	_viewport_size = get_viewport().get_visible_rect().size
	_refresh_width()
	_target_x = global_position.x
	add_to_group("paddle")


## 同步 collision shape 和 sprite 贴图到当前宽度（无副作用调用）
func _refresh_width() -> void:
	var current_w: int = BASE_PADDLE_WIDTH
	if $CollisionShape2D.shape is RectangleShape2D:
		current_w = int(($CollisionShape2D.shape as RectangleShape2D).size.x)
	# 防御：避免 _ready 之前被外部调用时 shape 还是 0
	if current_w <= 0:
		current_w = BASE_PADDLE_WIDTH
	# 强制上限（防止 Inspector 配错值）
	current_w = mini(current_w, MAX_PADDLE_WIDTH)
	if $CollisionShape2D.shape is RectangleShape2D:
		($CollisionShape2D.shape as RectangleShape2D).size = Vector2(current_w, PADDLE_HEIGHT)
	_sprite.texture = PixelArt.create_paddle_texture(current_w, PADDLE_HEIGHT)
	_half_width = current_w * 0.5


func _physics_process(delta: float) -> void:
	# 触摸输入：_input 已更新 _target_x，这里不重复
	# 鼠标输入（桌面调试）：仅当鼠标在窗口内
	if not _touch_active:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		if _is_mouse_in_window():
			_target_x = mouse_pos.x
		else:
			# 键盘
			var dir: float = 0.0
			if Input.is_action_pressed("paddle_left"):
				dir -= 1.0
			if Input.is_action_pressed("paddle_right"):
				dir += 1.0
			if absf(dir) > 0.0:
				_target_x += dir * move_speed * delta

	# 平滑插值（防止抖动）
	global_position.x = lerpf(global_position.x, _target_x, 1.0 - follow_smoothness)

	# 硬约束：不能超出左右墙
	var min_x: float = _half_width
	var max_x: float = _viewport_size.x - _half_width
	global_position.x = clampf(global_position.x, min_x, max_x)
	_target_x = clampf(_target_x, min_x, max_x)

	# Y 永远固定（挡板不上下动）


func _input(event: InputEvent) -> void:
	# 触摸事件（移动端）
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_active = true
			_target_x = _screen_to_world_x(event.position.x)
		else:
			_touch_active = false
		return
	elif event is InputEventScreenDrag and _touch_active:
		_target_x = _screen_to_world_x(event.position.x)
		return

	# 鼠标按钮（Web/桌面）—— 显式触发发射 + 移动挡板
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			launched.emit()
		return

	# 鼠标移动（Web）—— 主动移动挡板
	if event is InputEventMouseMotion:
		_target_x = _screen_to_world_x(event.position.x)
		return

	# launch_ball action 兜底（空格键）
	if event.is_action_pressed("launch_ball"):
		launched.emit()


func _screen_to_world_x(screen_x: float) -> float:
	# 屏幕坐标 → 世界坐标
	# Godot 4: Transform2D * Vector2 等价于旧版 .xform()
	return (get_canvas_transform().affine_inverse() * Vector2(screen_x, 0)).x


func _is_mouse_in_window() -> bool:
	# 注意：headless 模式下 get_mouse_position() 会返回 (0, 0)
	# 用严格大于 0 / 小于 max 排除这个边界值
	var m: Vector2 = get_viewport().get_mouse_position()
	return m.x > 0.5 and m.x < _viewport_size.x - 0.5 and m.y > 0.5 and m.y < _viewport_size.y - 0.5


## 触发 EXTEND_PADDLE 道具效果：永久加宽 +30px，上限屏幕 1/2（360px）
func apply_extend() -> void:
	var current_w: int = int(($CollisionShape2D.shape as RectangleShape2D).size.x)
	if current_w >= MAX_PADDLE_WIDTH:
		return  # 已经够长了，浪费道具
	var new_w: int = mini(current_w + PADDLE_GROW_AMOUNT, MAX_PADDLE_WIDTH)
	_sprite.texture = PixelArt.create_paddle_texture(new_w, PADDLE_HEIGHT)
	_half_width = new_w * 0.5
	# collision shape 修改要 defer 到物理查询外（避免 "Can't change this state while flushing queries"）
	($CollisionShape2D.shape as RectangleShape2D).set_deferred("size", Vector2(new_w, PADDLE_HEIGHT))
	# X 位置 clamp 也 defer 一下（_half_width 已经被改了，clamp 用新值）
	call_deferred("_clamp_position_after_extend")


func _clamp_position_after_extend() -> void:
	var min_x: float = _half_width
	var max_x: float = _viewport_size.x - _half_width
	global_position.x = clampf(global_position.x, min_x, max_x)
	_target_x = clampf(_target_x, min_x, max_x)