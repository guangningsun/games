extends Node
## GameManager —— 全局游戏状态（autoload 单例）
##
## 全局可访问：GameManager.score / lives / current_level
## 状态变更通过信号广播给 HUD 和其他系统
##
## 关卡管理：
## - LEVEL_PATHS 数组定义关卡 JSON 路径
## - get_level_path() 根据 current_level 返回对应路径
## - 全部通关返回 ""（游戏胜利）
##
## M4 扩展：WX Adapter 接入高分上报
## M7 扩展：每关独立计时器，切关清零

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal level_changed(new_level: int)
signal level_time_changed(level_time: float)
signal game_over(final_score: int, reached_level: int)
signal level_clear(level: int, score_at_clear: int)
signal game_won(final_score: int)

const STARTING_LIVES: int = 3
const TOTAL_LEVELS: int = 2

const LEVEL_PATHS: Array[String] = [
	"res://resources/levels/level_001.json",
	"res://resources/levels/level_002.json",
]

var score: int = 0
var lives: int = STARTING_LIVES
var current_level: int = 1
var is_game_over: bool = false
var level_time: float = 0.0
var _last_emitted_second: int = -1


func _ready() -> void:
	reset_game()


func _process(delta: float) -> void:
	# 每关独立计时：游戏进行中累加，game over / 切关时停
	if is_game_over:
		return
	level_time += delta
	var current_second: int = int(level_time)
	if current_second != _last_emitted_second:
		_last_emitted_second = current_second
		level_time_changed.emit(level_time)


## 加分
func add_score(amount: int) -> void:
	if is_game_over:
		return
	score += amount
	score_changed.emit(score)


## 丢一条命
func lose_life() -> bool:
	if is_game_over:
		return true
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		is_game_over = true
		game_over.emit(score, current_level)
		return true
	return false


## 加一条命（复活）
func add_life() -> void:
	lives += 1
	is_game_over = false
	lives_changed.emit(lives)


## 当前关卡通关
func level_cleared() -> void:
	if is_game_over:
		return
	level_clear.emit(current_level, score)
	if current_level >= TOTAL_LEVELS:
		is_game_over = true
		game_won.emit(score)
	else:
		current_level += 1
		level_changed.emit(current_level)
		_reset_level_time()  ## M7: 切关时计时器归零


## 重置游戏
func reset_game() -> void:
	score = 0
	lives = STARTING_LIVES
	current_level = 1
	is_game_over = false
	_reset_level_time()
	score_changed.emit(score)
	lives_changed.emit(lives)
	level_changed.emit(current_level)
	level_time_changed.emit(level_time)


## M7: 关卡计时器归零（切关时调用）
func _reset_level_time() -> void:
	level_time = 0.0
	_last_emitted_second = -1
	level_time_changed.emit(level_time)


## 当前关卡的 JSON 路径（"" 表示全通关）
func get_level_path() -> String:
	var idx: int = current_level - 1
	if idx < 0 or idx >= LEVEL_PATHS.size():
		return ""
	return LEVEL_PATHS[idx]