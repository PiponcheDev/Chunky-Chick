extends CharacterBody2D

@export var speed: float = 300.0
@export var acceleration: float = 180.0
@export var max_speed: float = 700.0

@export var homing_duration: float = 7.5
@export var homing_turn_rate: float = 2.0

@export var lifetime: float = 4.0
@export var damage: int = 15

var homing_timer: float = 0.0
var life_timer: float = 0.0

var target: Node2D = null
var evaporated := false


func launch(dir: Vector2) -> void:
	velocity = dir.normalized() * speed
	homing_timer = homing_duration
	life_timer = lifetime
	target = get_tree().get_first_node_in_group("player")


func _angle_diff(a: float, b: float) -> float:
	var diff = b - a
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff


func _physics_process(delta: float) -> void:
	if evaporated:
		return

	life_timer -= delta
	if life_timer <= 0:
		queue_free()
		return

	var current_speed = velocity.length()
	current_speed = min(current_speed + acceleration * delta, max_speed)

	var move_dir = velocity.normalized()

	if homing_timer > 0 and is_instance_valid(target):
		homing_timer -= delta
		var to_target = target.global_position - global_position

		if to_target.length() > 0.01:
			var desired_dir = to_target.normalized()
			var cur_dir = velocity.normalized()

			var a_cur = cur_dir.angle()
			var a_des = desired_dir.angle()
			var a_diff = _angle_diff(a_cur, a_des)

			var max_turn = homing_turn_rate * delta
			var new_angle = a_cur + clamp(a_diff, -max_turn, max_turn)
			move_dir = Vector2(cos(new_angle), sin(new_angle))
	elif not evaporated:
		evaporated = true
		velocity = Vector2.ZERO
		hide()
		await get_tree().create_timer(0.3).timeout
		queue_free()
		return

	velocity = move_dir * current_speed
	rotation = velocity.angle() + deg_to_rad(90)

	move_and_slide()
	_try_damage_player()


func _try_damage_player() -> void:
	if target == null:
		return

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue

		var collider := collision.get_collider()
		if collider == null or collider == self:
			continue

		if collider == target or collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
			elif collider.has_method("apply_damage"):
				collider.apply_damage(damage)

			evaporated = true
			velocity = Vector2.ZERO
			hide()
			await get_tree().create_timer(0.3).timeout
			queue_free()
			return
