class_name PixelArt
extends RefCounted
## PixelArt —— 程序生成像素艺术工具
##
## M5 阶段：所有视觉资源都是程序生成的，避免外部依赖
## 风格：像素风 + 简单高光阴影
## M6+ 可以替换为美术提供的 PNG 贴图

# === 砖块 ===

## 生成砖块像素贴图（带高光/阴影边框）
static func create_brick_texture(brick_type: int, width: int, height: int) -> ImageTexture:
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var color: Color = BrickConfig.get_color(brick_type)
	var light: Color = color.lightened(0.30)
	var dark: Color = color.darkened(0.35)

	# 主体填充
	img.fill(color)

	# 顶部 1 像素高光
	img.fill_rect(Rect2i(0, 0, width, 1), light)
	# 底部 1 像素阴影
	img.fill_rect(Rect2i(0, height - 1, width, 1), dark)
	# 左 1 像素高光
	img.fill_rect(Rect2i(0, 0, 1, height), light)
	# 右 1 像素阴影
	img.fill_rect(Rect2i(width - 1, 0, 1, height), dark)

	# 顶部内层再加一道柔光（让砖块有立体感）
	if height >= 6:
		img.fill_rect(Rect2i(1, 1, width - 2, 1), color.lightened(0.10))

	return ImageTexture.create_from_image(img)


# === 挡板 ===

## 生成挡板贴图（圆角 + 高光）
static func create_paddle_texture(width: int, height: int) -> ImageTexture:
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var main_color: Color = Color(0.30, 0.85, 0.45)
	var light: Color = Color(0.55, 0.95, 0.65)
	var dark: Color = Color(0.18, 0.55, 0.28)

	# 圆角像素掩膜：每个角 2x2 切除
	var radius: int = 3

	# 填充主体（避开圆角）
	for y in range(height):
		for x in range(width):
			var in_corner_tl: bool = (x < radius and y < radius and (radius - x) + (radius - y) > radius)
			var in_corner_tr: bool = (x >= width - radius and y < radius and (x - (width - radius - 1)) + (radius - y) > radius)
			var in_corner_bl: bool = (x < radius and y >= height - radius and (radius - x) + (y - (height - radius - 1)) > radius)
			var in_corner_br: bool = (x >= width - radius and y >= height - radius and (x - (width - radius - 1)) + (y - (height - radius - 1)) > radius)
			if in_corner_tl or in_corner_tr or in_corner_bl or in_corner_br:
				continue
			# 顶 1px 高光
			if y == 0:
				img.set_pixel(x, y, light)
			# 底 1px 阴影
			elif y == height - 1:
				img.set_pixel(x, y, dark)
			# 主体
			else:
				img.set_pixel(x, y, main_color)

	return ImageTexture.create_from_image(img)


# === 球 ===

## 生成球贴图（圆形 + 高光）
static func create_ball_texture(radius: int) -> ImageTexture:
	var size: int = radius * 2 + 2
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var center: Vector2 = Vector2(size / 2.0, size / 2.0)
	var highlight_pos: Vector2 = center + Vector2(-radius * 0.35, -radius * 0.35)

	for y in size:
		for x in size:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var d: float = p.distance_to(center)
			if d > radius:
				continue
			# 主体白色
			var color: Color = Color(0.95, 0.95, 0.97)
			# 阴影（右下侧）
			var shadow_dist: float = p.distance_to(center + Vector2(radius * 0.3, radius * 0.3))
			if shadow_dist < radius * 0.7 and d > radius * 0.5:
				color = Color(0.75, 0.75, 0.80)
			# 高光（左上侧）
			var hi_dist: float = p.distance_to(highlight_pos)
			if hi_dist < radius * 0.3:
				color = Color.WHITE
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)


# === 墙 ===

## 生成墙贴图（带纹理）
static func create_wall_texture_v(width: int, height: int) -> ImageTexture:
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var main_color: Color = Color(0.18, 0.22, 0.40)
	var light: Color = Color(0.25, 0.30, 0.50)
	var dark: Color = Color(0.10, 0.12, 0.25)

	img.fill(main_color)
	# 左 1 像素高光（对左边墙）/ 右 1 像素阴影
	img.fill_rect(Rect2i(0, 0, 1, height), light)
	img.fill_rect(Rect2i(width - 1, 0, 1, height), dark)
	# 加几道横纹做装饰
	for y in range(0, height, 32):
		img.fill_rect(Rect2i(1, y, width - 2, 2), Color(main_color, 0.5))

	return ImageTexture.create_from_image(img)


static func create_wall_texture_h(width: int, height: int) -> ImageTexture:
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var main_color: Color = Color(0.18, 0.22, 0.40)
	var light: Color = Color(0.25, 0.30, 0.50)
	var dark: Color = Color(0.10, 0.12, 0.25)

	img.fill(main_color)
	# 顶 1 像素高光 / 底 1 像素阴影
	img.fill_rect(Rect2i(0, 0, width, 1), light)
	img.fill_rect(Rect2i(0, height - 1, width, 1), dark)
	# 横纹
	for x in range(0, width, 32):
		img.fill_rect(Rect2i(x, 1, 2, height - 2), Color(main_color, 0.5))

	return ImageTexture.create_from_image(img)


# === PowerUp 道具 ===

## 生成 PowerUp 道具贴图（圆形 + 边框 + 中间文字/符号）
## size: 直径（默认 36），center_text: 中间显示的字符（1-2 字符）
static func create_powerup_texture(color: Color, _center_text: String = "") -> ImageTexture:
	var size: int = 36
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var center: Vector2 = Vector2(size / 2.0, size / 2.0)
	var main_color: Color = color
	var light: Color = color.lightened(0.30)
	var dark: Color = color.darkened(0.40)
	var border: Color = Color(0, 0, 0, 0.5)

	# 圆形填充
	var radius_outer: float = size / 2.0 - 1
	var radius_inner: float = size / 2.0 - 4
	for y in size:
		for x in size:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var d: float = p.distance_to(center)
			if d > radius_outer:
				continue
			var c: Color
			if d > radius_inner:
				c = border
			else:
				# 主体填充，按角度区分明暗（模拟 3D）
				var angle: float = atan2(p.y - center.y, p.x - center.x)
				if cos(angle - deg_to_rad(225.0)) > 0.4:
					c = light
				elif cos(angle - deg_to_rad(45.0)) > 0.4:
					c = dark
				else:
					c = main_color
			img.set_pixel(x, y, c)

	# 中间加个简单符号像素（"+" 形状 = BONUS_SCORE）
	# 或者画个箭头表示 EXTEND_PADDLE
	if _center_text == "+500" or _center_text == "+":
		# 画十字
		for i in range(8, 14):
			img.set_pixel(i, 17, Color.WHITE)
			img.set_pixel(17, i, Color.WHITE)
	elif _center_text == "↔" or _center_text == "<>":
		# 画左右箭头
		for y in range(15, 21):
			img.set_pixel(8, y, Color.WHITE)
			img.set_pixel(9, y, Color.WHITE)
			img.set_pixel(26, y, Color.WHITE)
			img.set_pixel(27, y, Color.WHITE)
		# 箭头头
		for i in range(4):
			img.set_pixel(8 + i, 15 + i, Color.WHITE)
			img.set_pixel(8 + i, 20 - i, Color.WHITE)
			img.set_pixel(27 - i, 15 + i, Color.WHITE)
			img.set_pixel(27 - i, 20 - i, Color.WHITE)

	return ImageTexture.create_from_image(img)

# === 背景 ===

## 生成背景贴图（深蓝渐变 + 星星）
static func create_background_texture(width: int, height: int, star_count: int = 60) -> ImageTexture:
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	# 渐变填充（顶深 → 底更深）
	for y in height:
		var t: float = float(y) / height
		var color: Color = Color(0.04, 0.06, 0.14).lerp(Color(0.02, 0.03, 0.10), t)
		img.fill_rect(Rect2i(0, y, width, 1), color)

	# 加一些星星（程序生成确定性位置）
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in star_count:
		var x: int = rng.randi_range(0, width - 1)
		var y: int = rng.randi_range(0, height - 1)
		var brightness: float = rng.randf_range(0.4, 1.0)
		var size: int = rng.randi_range(0, 1)  # 0=单像素, 1=2x2
		if size == 0:
			img.set_pixel(x, y, Color(brightness, brightness, brightness * 1.1))
		else:
			img.fill_rect(Rect2i(x, y, 2, 2), Color(brightness, brightness, brightness * 1.1))

	return ImageTexture.create_from_image(img)