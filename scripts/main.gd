extends Node2D
## Main —— 游戏主控（M3 阶段）
##
## 职责：
## - 加载/切换关卡（LevelLoader）
## - 信号桥接：Paddle/Ball/Brick ↔ GameManager ↔ HUD
## - HUD 按钮：重玩 / 下一关
##
## M3 新增：
## - GameManager 单例：分数/生命/关卡
## - HUD：顶部计分板 + Game Over / Level Clear 遮罩
## - 关卡完成 → 加载下一关
## - 生命值耗尽 → Game Over
##
## 命令行参数：
## - --screenshot [path]   截图后退出
## - --auto-launch        0.5s 后发射球
## - --screenshot-after N 自定义截图前等待秒数

@onready var paddle: CharacterBody2D = $Paddle
@onready var _ball_template: CharacterBody2D = $Ball  ## 球模板，多球技能时 duplicate() 克隆
@onready var level_container: Node2D = $LevelContainer
@onready var hud: CanvasLayer = $HUD
@onready var background: Sprite2D = $Background
@onready var wall_left: StaticBody2D = $Walls/WallLeft
@onready var wall_right: StaticBody2D = $Walls/WallRight
@onready var wall_top: StaticBody2D = $Walls/WallTop

const POWERUP_SCENE: PackedScene = preload("res://scenes/entities/power_up.tscn")
const BALL_SCENE: PackedScene = preload("res://scenes/ball.tscn")  ## M8：用 instantiate 替代 duplicate()（duplicate 不调度 _physics_process）

var _level_loader: LevelLoader = LevelLoader.new()
var _bricks_remaining: int = 0
var balls: Array[CharacterBody2D] = []  ## 所有活球（MULTI/DOUBLE 技能产生多个）
const MAX_BALLS: int = 50  ## 多球上限（M8 用户要求：DOUBLE_BALLS 翻倍后最多 50 个）


func _ready() -> void:
	# M5: 程序生成背景 + 墙贴图
	_apply_visual_textures()

	# 信号连接
	paddle.launched.connect(_on_paddle_launched)
	_setup_balls()
	_level_loader.brick_destroyed.connect(_on_brick_destroyed)
	hud.replay_requested.connect(_on_replay_requested)
	hud.next_level_requested.connect(_on_next_level_requested)
	hud.revive_requested.connect(_on_revive_requested)

	# M5: 监听关卡事件触发 SFX + BGM 控制
	GameManager.level_clear.connect(_on_level_clear)
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_won.connect(_on_game_won)

	# 加载关卡
	_load_current_level()

	# 球初始位置
	_ball_template.reset_to_paddle(paddle.global_position)

	# M5: 启动 BGM
	SoundManager.play_bgm()

	# 命令行快捷方式
	_handle_cli_shortcuts()


## 初始化球池：模板球加入 balls，监听 lost 信号
func _setup_balls() -> void:
	_ball_template.ball_lost.connect(_on_ball_lost.bind(_ball_template))
	balls.append(_ball_template)


func _on_level_clear(_level: int, _score: int) -> void:
	SoundManager.play_sfx("clear")


func _on_game_over(_score: int, _level: int) -> void:
	SoundManager.stop_bgm()
	SoundManager.play_sfx("lose")


func _on_game_won(_score: int) -> void:
	SoundManager.stop_bgm()
	SoundManager.play_sfx("clear")


func _apply_visual_textures() -> void:
	# 背景：720x1280 渐变 + 星星
	background.texture = PixelArt.create_background_texture(720, 1280, 60)
	background.centered = false
	background.position = Vector2.ZERO

	# 左右墙：40x1280
	wall_left.get_node("Sprite").texture = PixelArt.create_wall_texture_v(40, 1280)
	wall_right.get_node("Sprite").texture = PixelArt.create_wall_texture_v(40, 1280)
	wall_top.get_node("Sprite").texture = PixelArt.create_wall_texture_h(720, 40)


# === 关卡管理 ===

func _load_current_level() -> void:
	var path: String = GameManager.get_level_path()
	if path.is_empty():
		# 全通关（GameManager 已发 game_won 信号）
		return
	_clear_level()
	_bricks_remaining = _level_loader.load_level(path, level_container)
	# 重置所有活球到 paddle
	for b in balls:
		b.reset_to_paddle(paddle.global_position)


func _clear_level() -> void:
	for child in level_container.get_children():
		child.queue_free()
	_bricks_remaining = 0


# === 信号回调 ===

func _on_paddle_launched() -> void:
	if GameManager.is_game_over:
		return
	# 发射所有未发射的球（MULTIPLY 产生的球可能也未发射）
	for b in balls:
		if not b.is_launched:
			b.launch(b.global_position)


## 兜底输入：直接处理鼠标点击 / 触摸屏幕 → 发射球
## Paddle._input 已经在处理，但为防事件被某层截断，main 也兜一份
func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		return
	var has_pending: bool = false
	for b in balls:
		if not b.is_launched:
			has_pending = true
			break
	if not has_pending:
		return
	var should_launch: bool = false
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			should_launch = true
	elif event is InputEventScreenTouch:
		if event.pressed:
			should_launch = true
	if should_launch:
		for b in balls:
			if not b.is_launched:
				b.launch(b.global_position)


func _on_ball_lost(lost_ball: CharacterBody2D) -> void:
	balls.erase(lost_ball)
	# 模板球永远不释放（保留作为 _clone_ball 的源）
	if lost_ball != _ball_template:
		lost_ball.queue_free()
	if balls.is_empty():
		var game_over: bool = GameManager.lose_life()
		if game_over:
			return
		# 全掉光了，spawn 一个新球（会复用 _ball_template）
		var fresh_ball: CharacterBody2D = _clone_ball()
		if fresh_ball:
			fresh_ball.reset_to_paddle(paddle.global_position)


func _on_brick_destroyed(brick: StaticBody2D, score: int, position: Vector2, brick_type: int) -> void:
	GameManager.add_score(score)
	_bricks_remaining -= 1
	# M5: 砖块销毁粒子特效
	var brick_color: Color = BrickConfig.get_color(brick_type)
	BrickParticles.spawn(position, brick_color, self)
	# M6: PowerUp 掉落（按 brick_type 概率）
	_maybe_spawn_powerup(position, brick_type)
	if _bricks_remaining <= 0:
		GameManager.level_cleared()


## 按概率生成 PowerUp（M8 重构：3 种 + 全部绿色）
func _maybe_spawn_powerup(pos: Vector2, brick_type: int) -> void:
	var drop_rate: float = BrickConfig.get_powerup_drop_rate(brick_type)
	if randf() > drop_rate:
		return
	# 3 种 PowerUp 均等概率（约 33% each）
	var roll: float = randf()
	var pu_type: int
	if roll < 0.333:
		pu_type = PowerUp.TYPE_EXTEND_PADDLE
	elif roll < 0.666:
		pu_type = PowerUp.TYPE_MULTI_BALL
	else:
		pu_type = PowerUp.TYPE_DOUBLE_BALLS
	var pu: PowerUp = POWERUP_SCENE.instantiate()
	pu.setup(pu_type)
	pu.global_position = pos
	pu.collected.connect(_on_powerup_collected)
	add_child(pu)


func _on_powerup_collected(pu_type: int) -> void:
	match pu_type:
		PowerUp.TYPE_EXTEND_PADDLE:
			paddle.apply_extend()
			SoundManager.play_sfx("clear")
		PowerUp.TYPE_MULTI_BALL:
			_trigger_multi_ball()
			SoundManager.play_sfx("clear")
		PowerUp.TYPE_DOUBLE_BALLS:
			_trigger_double_balls()
			SoundManager.play_sfx("clear")


# === 多球管理 / 技能触发 ===

## 从 BALL_SCENE 实例化一个新球加入 balls（带 lost 信号连接）
func _clone_ball() -> CharacterBody2D:
	if balls.size() >= MAX_BALLS:
		return null
	# M8: 用 PackedScene.instantiate() 替代 _ball_template.duplicate()
	# duplicate 复制 CharacterBody2D 后 _physics_process 不会被调度（Godot 4 bug/quirk）
	var new_ball: CharacterBody2D = BALL_SCENE.instantiate() as CharacterBody2D
	new_ball.global_position = _ball_template.global_position
	new_ball.velocity = Vector2.ZERO
	new_ball.is_launched = false
	new_ball.ball_lost.connect(_on_ball_lost.bind(new_ball))
	add_child(new_ball)
	balls.append(new_ball)
	return new_ball


## DOUBLE_BALLS：每个活球克隆 1 个（×2），上限 MAX_BALLS
func _trigger_double_balls() -> void:
	if balls.is_empty():
		return
	var snapshot: Array[CharacterBody2D] = balls.duplicate()
	for b in snapshot:
		if not b.is_launched:
			continue
		if balls.size() >= MAX_BALLS:
			return
		var original_velocity: Vector2 = b.velocity
		# 自身稍微偏转
		b.velocity = original_velocity.rotated(deg_to_rad(-10))
		var new_ball: CharacterBody2D = _clone_ball()
		if new_ball == null:
			return
		new_ball.global_position = b.global_position
		new_ball.velocity = original_velocity.rotated(deg_to_rad(10))
		new_ball.is_launched = true


## MULTI_BALL：直接 +2 个新球（从 paddle 出发，散开方向）
func _trigger_multi_ball() -> void:
	for i in 2:
		if balls.size() >= MAX_BALLS:
			return
		var new_ball: CharacterBody2D = _clone_ball()
		if new_ball == null:
			return
		new_ball.reset_to_paddle(paddle.global_position)
		# 散开方向（左右各一个）
		var angle_deg: float = -30.0 if i == 0 else 30.0
		new_ball.launch(new_ball.global_position, Vector2(sin(deg_to_rad(angle_deg)), -cos(deg_to_rad(angle_deg))))


# === 多球管理 / 技能触发 ===

func _on_replay_requested() -> void:
	# 重玩：清状态 + 重新加载第一关
	GameManager.reset_game()
	SoundManager.play_bgm()  # 重启 BGM
	_load_current_level()


func _on_revive_requested() -> void:
	# 复活（看视频成功）：加一条命 + 重置球
	GameManager.add_life()
	if balls.is_empty():
		var fresh_ball: CharacterBody2D = _clone_ball()
		if fresh_ball:
			fresh_ball.reset_to_paddle(paddle.global_position)
	else:
		for b in balls:
			b.reset_to_paddle(paddle.global_position)


func _on_next_level_requested() -> void:
	# GameManager.level_cleared 已经把 current_level+=1
	_load_current_level()


# === 命令行快捷方式（截图 / 自动发射） ===

func _handle_cli_shortcuts() -> void:
	# Godot 4 用 OS.get_cmdline_user_args() 拿 `--` 之后的用户参数（不是 get_cmdline_args）
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--auto-launch" in args:
		await get_tree().create_timer(0.5).timeout
		if not GameManager.is_game_over:
			for b in balls:
				if not b.is_launched:
					b.launch(b.global_position)
	if "--test-multi" in args:
		# M8 测试：发射 + 立刻触发 4 次 DOUBLE_BALLS（验证 16 球正确翻倍）
		await get_tree().create_timer(0.5).timeout
		for b in balls:
			if not b.is_launched:
				b.launch(b.global_position)
		await get_tree().create_timer(1.5).timeout
		for n in 4:
			_trigger_double_balls()
		print("[TEST] total balls: ", balls.size())
		# 等 0.5 秒让球飞起来再截图
		await get_tree().create_timer(0.5).timeout
		var idx: int = args.find("--screenshot")
		var path: String = "/tmp/m8_multi.png"
		if idx >= 0 and idx + 1 < args.size():
			path = args[idx + 1]
		_take_screenshot(path)
		await get_tree().process_frame
		get_tree().quit()
	if "--simulate-clear" in args:
		# 测试用：0.5s 后立即清完所有砖，触发 level_clear 流程
		await get_tree().create_timer(0.5).timeout
		for brick in level_container.get_children():
			brick.queue_free()
		_bricks_remaining = 0
		GameManager.level_cleared()
	if "--simulate-game-over" in args:
		# 测试用：0.5s 后立即触发 Game Over
		await get_tree().create_timer(0.5).timeout
		GameManager.lives = 1  # 只剩 1 条
		GameManager.lives_changed.emit(1)
		GameManager.lose_life()  # 触发 Game Over
	if "--test-powerups" in args:
		# M8 测试：1 秒后强制 spawn 3 种 PowerUp，1.5 秒后截图（不发射球、不掉砖）
		await get_tree().create_timer(1.0).timeout
		for t in [PowerUp.TYPE_EXTEND_PADDLE, PowerUp.TYPE_MULTI_BALL, PowerUp.TYPE_DOUBLE_BALLS]:
			var pu: PowerUp = POWERUP_SCENE.instantiate()
			pu.setup(t)
			pu.global_position = Vector2(120.0 + float(t) * 240.0, 300.0)
			pu.collected.connect(_on_powerup_collected)
			add_child(pu)
		# 截图：--screenshot 参数可选，否则用默认路径
		await get_tree().create_timer(0.5).timeout
		var idx: int = args.find("--screenshot")
		var path: String = "/tmp/m8_powerups.png"
		if idx >= 0 and idx + 1 < args.size():
			path = args[idx + 1]
		_take_screenshot(path)
		await get_tree().process_frame
		get_tree().quit()
	if "--screenshot" in args:
		var wait_sec: float = 0.8
		var wait_idx: int = args.find("--screenshot-after")
		if wait_idx >= 0 and wait_idx + 1 < args.size():
			wait_sec = float(args[wait_idx + 1])
		await get_tree().create_timer(wait_sec).timeout
		var idx: int = args.find("--screenshot")
		var path: String = "user://m3_screenshot.png"
		if idx >= 0 and idx + 1 < args.size():
			path = args[idx + 1]
		_take_screenshot(path)
		await get_tree().process_frame
		get_tree().quit()


func _take_screenshot(path: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_warning("Screenshot failed: viewport texture is null")
		return
	var resolved: String = path
	if resolved.begins_with("user://"):
		resolved = ProjectSettings.globalize_path(resolved)
	elif not resolved.begins_with("res://") and not resolved.begins_with("/"):
		resolved = ProjectSettings.globalize_path("user://" + resolved.get_file())
	var err: int = img.save_png(resolved)
	if err == OK:
		print("Screenshot saved: ", resolved)
	else:
		push_error("save_png failed: %d" % err)