class_name LevelLoader
extends RefCounted
## LevelLoader —— 关卡加载器
##
## 职责：
## - 读取 JSON 关卡配置
## - 按 pattern 矩阵实例化 Brick 节点
## - 挂到指定的 container (Node2D) 下
##
## JSON 格式：
## {
##   "name": "Level 1",                  // 关卡名（M3 用于切换显示）
##   "rows": 8, "cols": 20,              // 网格尺寸
##   "brick_width": 32, "brick_height": 24,
##   "brick_gap": 2,                      // 砖块间距
##   "origin_x": 21, "origin_y": 160,    // 左上角起始位置（可选，未设则自动居中）
##   "pattern": [...],                   // 8 行字符串，每字符 = 一个格子
##   "unbreakable_walls": {              // M9 底部不可消除墙（可选）
##     "y": 510,                         // 墙中心 y 坐标
##     "empty_start": 17,                // 空隙起始列（从 0 计）
##     "empty_count": 6                  // 空隙连续列数
##   }
## }
## pattern 字符：0=空, 1=NORMAL, 2=GOLD, 3=UNBREAKABLE
##
## 返回：生成的 Brick 数量

const BRICK_SCENE: PackedScene = preload("res://scenes/entities/brick.tscn")

## viewport 宽度（关卡居中用的默认值）
const DEFAULT_VIEWPORT_WIDTH: float = 720.0

signal brick_destroyed(brick: StaticBody2D, score: int, position: Vector2, brick_type: int)


func load_level(json_path: String, container: Node2D, viewport_width: float = DEFAULT_VIEWPORT_WIDTH) -> int:
	if not FileAccess.file_exists(json_path):
		push_error("LevelLoader: file not found: %s" % json_path)
		return 0
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("LevelLoader: cannot open: %s" % json_path)
		return 0
	var text: String = file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("LevelLoader: invalid JSON in %s" % json_path)
		return 0
	var dict: Dictionary = data

	var level_name: String = dict.get("name", "Unnamed")
	var rows: int = int(dict.get("rows", 0))
	var cols: int = int(dict.get("cols", 0))
	var bw: float = float(dict.get("brick_width", 32))
	var bh: float = float(dict.get("brick_height", 24))
	var gap: float = float(dict.get("brick_gap", 2))
	var pattern: Array = dict.get("pattern", [])

	if rows <= 0 or cols <= 0 or pattern.size() != rows:
		push_error("LevelLoader: pattern size mismatch in %s" % json_path)
		return 0

	# 计算 origin（如果 JSON 没指定则水平居中）
	var total_w: float = cols * (bw + gap) - gap
	var ox: float = float(dict.get("origin_x", (viewport_width - total_w) * 0.5))
	var oy: float = float(dict.get("origin_y", 160.0))

	print("[LevelLoader] Loading '%s' (%dx%d bricks)" % [level_name, rows, cols])

	var brick_count: int = 0
	# M9: 加载不可消除墙（如果有）
	var walls_data: Variant = dict.get("unbreakable_walls", null)
	if walls_data != null and typeof(walls_data) == TYPE_DICTIONARY:
		var wall_y: float = float(walls_data.get("y", 0.0))
		var empty_start: int = int(walls_data.get("empty_start", -1))
		var empty_count: int = int(walls_data.get("empty_count", 0))
		var wall_count: int = _spawn_unbreakable_walls(
			container, ox, bw, gap, wall_y, cols, empty_start, empty_count
		)
		print("[LevelLoader] Generated %d unbreakable wall segments" % wall_count)
	for r in rows:
		var row_str: String = pattern[r]
		if row_str.length() != cols:
			push_warning("LevelLoader: row %d length mismatch (got %d, expected %d)" % [
				r, row_str.length(), cols
			])
		for c in cols:
			if c >= row_str.length():
				continue
			var ch: String = row_str.substr(c, 1)
			var btype: int = BrickConfig.TYPE_EMPTY
			# pattern 字符可能是数字或 '.' 等空标记
			if ch.is_valid_int():
				btype = int(ch)
			if btype == BrickConfig.TYPE_EMPTY:
				continue
			var brick: StaticBody2D = BRICK_SCENE.instantiate()
			brick.brick_type = btype
			brick.custom_size = Vector2(bw, bh)
			brick.position = Vector2(
				ox + c * (bw + gap) + bw * 0.5,
				oy + r * (bh + gap) + bh * 0.5
			)
			brick.destroyed.connect(_on_brick_destroyed)
			container.add_child(brick)
			brick_count += 1

	print("[LevelLoader] Generated %d bricks" % brick_count)
	return brick_count


func _on_brick_destroyed(brick: StaticBody2D, score: int, position: Vector2, brick_type: int) -> void:
	brick_destroyed.emit(brick, score, position, brick_type)


## M9: 生成底部不可消除墙（中间空几格让球掉出去）
##
## 参数：
##   container: 父节点
##   ox: 砖块 x 起点（左上角）
##   bw: 砖块宽
##   gap: 砖块间距
##   wall_y: 墙中心 y
##   total_cols: 总列数（40）
##   empty_start: 空隙起始列（-1 表示无空隙）
##   empty_count: 空隙连续列数
## 返回：生成的墙段数
func _spawn_unbreakable_walls(
	container: Node2D,
	ox: float,
	bw: float,
	gap: float,
	wall_y: float,
	total_cols: int,
	empty_start: int,
	empty_count: int
) -> int:
	var count: int = 0
	for c in total_cols:
		# 跳过空隙列
		if empty_start >= 0 and c >= empty_start and c < empty_start + empty_count:
			continue
		var wall: StaticBody2D = BRICK_SCENE.instantiate()
		wall.brick_type = BrickConfig.TYPE_UNBREAKABLE
		wall.custom_size = Vector2(bw, bw * 0.75)  # 墙比砖块矮一点（视觉区分）
		# 但与方块"等大小"——按用户原意用方块同高 bh=12
		wall.custom_size = Vector2(bw, 12.0)
		wall.position = Vector2(
			ox + c * (bw + gap) + bw * 0.5,
			wall_y
		)
		# UNBREAKABLE 不连接 destroyed 信号（避免被销毁时调用）
		container.add_child(wall)
		count += 1
	return count