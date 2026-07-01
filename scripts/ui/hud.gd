extends CanvasLayer
## HUD —— 顶部计分板 + Game Over / Level Clear 遮罩
##
## 显示：分数 / 当前关卡 / 生命数 / 计时器 / 版本号
## 监听：GameManager 信号，自动更新
## 按钮：
##   - Game Over: REVIVE（看视频复活）/ PLAY AGAIN
##   - Level Clear: NEXT LEVEL / SHARE

signal replay_requested
signal next_level_requested
signal revive_requested

const VERSION_LABEL: String = "v0.9.0"

@onready var _score_value: Label = $TopBar/ScorePanel/ScoreValue
@onready var _time_value: Label = $TopBar/TimePanel/TimeValue
@onready var _level_value: Label = $TopBar/LevelPanel/LevelValue
@onready var _lives_value: Label = $TopBar/LivesPanel/LivesValue
@onready var _version_label: Label = $VersionLabel

@onready var _game_over_panel: Control = $GameOverPanel
@onready var _game_over_title: Label = $GameOverPanel/VBox/Title
@onready var _game_over_score: Label = $GameOverPanel/VBox/ScoreText
@onready var _revive_button: Button = $GameOverPanel/VBox/ReviveButton
@onready var _replay_button: Button = $GameOverPanel/VBox/ReplayButton

@onready var _level_clear_panel: Control = $LevelClearPanel
@onready var _next_button: Button = $LevelClearPanel/VBox/NextButton
@onready var _share_button: Button = $LevelClearPanel/VBox/ShareButton


func _ready() -> void:
	# 监听 GameManager 信号
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.level_time_changed.connect(_on_time_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.level_clear.connect(_on_level_clear)
	GameManager.game_won.connect(_on_game_won)

	# 按钮信号
	_replay_button.pressed.connect(_on_replay_pressed)
	_revive_button.pressed.connect(_on_revive_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_share_button.pressed.connect(_on_share_pressed)

	# WX 复活回调
	WXAdapter.revive_completed.connect(_on_revive_completed)
	WXAdapter.share_completed.connect(_on_share_completed)

	# 版本号
	if _version_label:
		_version_label.text = VERSION_LABEL

	# 初始化显示
	_on_score_changed(GameManager.score)
	_on_lives_changed(GameManager.lives)
	_on_level_changed(GameManager.current_level)
	_on_time_changed(GameManager.level_time)


func _on_score_changed(new_score: int) -> void:
	_score_value.text = str(new_score)


func _on_time_changed(new_time: float) -> void:
	# 格式 MM:SS（超过 99 分钟会显示 HH:MM:SS）
	var total_seconds: int = int(new_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	if minutes >= 60:
		var hours: int = minutes / 60
		minutes = minutes % 60
		_time_value.text = "%d:%02d:%02d" % [hours, minutes, seconds]
	else:
		_time_value.text = "%02d:%02d" % [minutes, seconds]


func _on_lives_changed(new_lives: int) -> void:
	_lives_value.text = "× %d" % new_lives


func _on_level_changed(new_level: int) -> void:
	_level_value.text = str(new_level)


func _on_game_over(final_score: int, reached_level: int) -> void:
	_game_over_title.text = "GAME OVER"
	_game_over_score.text = "Final Score: %d  ·  Level: %d" % [final_score, reached_level]
	_game_over_panel.visible = true


func _on_level_clear(level: int, score_at_clear: int) -> void:
	var title_label: Label = $LevelClearPanel/VBox/Title
	title_label.text = "LEVEL %d CLEAR!" % level
	var score_label: Label = $LevelClearPanel/VBox/ScoreText
	score_label.text = "Score: %d" % score_at_clear
	_level_clear_panel.visible = true


func _on_game_won(final_score: int) -> void:
	_game_over_title.text = "🏆 YOU WIN!"
	_game_over_score.text = "All levels cleared! Final Score: %d" % final_score
	_game_over_panel.visible = true
	_level_clear_panel.visible = false


func _on_replay_pressed() -> void:
	SoundManager.play_sfx("click")
	_game_over_panel.visible = false
	replay_requested.emit()


func _on_revive_pressed() -> void:
	SoundManager.play_sfx("click")
	# 禁用按钮防止重复点击
	_revive_button.disabled = true
	_revive_button.text = "Loading..."
	WXAdapter.request_revive()


func _on_revive_completed(success: bool) -> void:
	_revive_button.disabled = false
	_revive_button.text = "REVIVE"
	if success:
		# 复活成功：通知 Main 处理（球重置 + 加命 + 隐藏面板）
		_game_over_panel.visible = false
		revive_requested.emit()
	else:
		SoundManager.play_sfx("lose")
		WXAdapter.show_toast("请看完广告再试")


func _on_next_pressed() -> void:
	SoundManager.play_sfx("click")
	_level_clear_panel.visible = false
	next_level_requested.emit()


func _on_share_pressed() -> void:
	SoundManager.play_sfx("click")
	_share_button.disabled = true
	var title: String = "我在弹球砖块打到 Level %d，%d 分！来挑战我~" % [
		GameManager.current_level, GameManager.score
	]
	WXAdapter.share(title)


func _on_share_completed(_success: bool) -> void:
	_share_button.disabled = false
	WXAdapter.show_toast("已分享")