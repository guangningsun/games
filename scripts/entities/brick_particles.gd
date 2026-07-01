extends CPUParticles2D
class_name BrickParticles
## BrickParticles —— 砖块销毁粒子特效
##
## 用 CPUParticles2D 实现，比 GPUParticles2D 更稳定可控
## M5 阶段：纯 GDScript 配置，无外部资源
##
## 用法：在砖块销毁处调用 spawn(global_position, color)

const PARTICLE_AMOUNT: int = 16
const LIFETIME: float = 0.5


static func spawn(at_position: Vector2, color: Color, parent: Node) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.global_position = at_position
	particles.amount = PARTICLE_AMOUNT
	particles.lifetime = LIFETIME
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	# 方向：全方向随机
	particles.direction = Vector2(0, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 220.0
	# 重力：让粒子落下来
	particles.gravity = Vector2(0, 400)
	# 缩放：从大到小
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 7.0
	particles.scale_amount_curve = _make_fade_curve()
	# 颜色：砖块颜色 → 透明
	particles.color = color

	parent.add_child(particles)

	# 生命周期结束后释放
	particles.finished.connect(func(): particles.queue_free())


static func _make_fade_curve() -> Curve:
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 0.7))
	curve.add_point(Vector2(1, 0))
	return curve