extends Area2D

const SPEED := 800
var MAX_RANGE := 400


var direction := Vector2.ZERO
var start_pos: Vector2
var distance_traveled: float
var max_range_multiplier: float = 1
var damage: int
var shooter: Node2D
@onready var col: CollisionShape2D = $CollisionShape2D


var inherited_velocity: Vector2 = Vector2.ZERO

signal bullet_freed(pos: Vector2)

func _ready() -> void:
	if shooter.is_in_group("enemy"):
		max_range_multiplier = 10

func _physics_process(delta: float) -> void:
	var final_velocity
	# Bullet velocity + player velocity
	if inherited_velocity == Vector2.ZERO:
		final_velocity = direction * SPEED
	else:
		final_velocity = direction * SPEED + inherited_velocity
	global_position += final_velocity * delta
	distance_traveled = global_position.distance_to(start_pos)
	if distance_traveled > MAX_RANGE * max_range_multiplier:
		print("NOOOO",
			" start_pos=", start_pos,
			" pos=", global_position,
			" dist=", distance_traveled,
			" max=", MAX_RANGE * max_range_multiplier,
			" parent=", get_parent()
		)
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
		print(body, "\nhealth: ", body.health)
		queue_free()
