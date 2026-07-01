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
##   "pattern": [                        // 8 行字符串，每字符 = 一个格子
##     "11111111111111111111",
##     ...
##   ]
## }
## pattern 字符：0=空, 1=NORMAL, 2=REINFORCED, 3=STEEL, 4=GOLD
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