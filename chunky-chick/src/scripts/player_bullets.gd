extends Area2D

const SPEED := 800
var MAX_RANGE := 400
@onready var anim_player = $AnimatedSprite2D

var direction := Vector2.ZERO
var start_pos: Vector2
var distance_traveled: float
var max_range_multiplier: float = 1.0
var damage: int = 0
var shooter: Node2D

var inherited_velocity: Vector2 = Vector2.ZERO

signal bullet_freed(pos: Vector2)

func _physics_process(delta: float) -> void:
	var final_velocity: Vector2

	if direction != Vector2.ZERO:
		anim_player.rotation = direction.angle() + rad_to_deg(90)

	if inherited_velocity == Vector2.ZERO:
		final_velocity = direction * SPEED
	else:
		final_velocity = direction * SPEED + inherited_velocity

	global_position += final_velocity * delta
	distance_traveled = global_position.distance_to(start_pos)

	if distance_traveled > MAX_RANGE * max_range_multiplier:
		queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		bullet_freed.emit(global_position)

func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	if shooter == null:
		return
	if shooter.is_in_group("enemy") and body.is_in_group("enemy"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("get_current_health"):
			print(body, "\nfatness: ", body.get_current_health())
		queue_free()
