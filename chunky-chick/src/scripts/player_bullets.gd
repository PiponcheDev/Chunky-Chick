extends Area2D

const SPEED := 800
const MAX_RANGE := 400

@onready var Sprite = $ColorRect

var direction := Vector2.ZERO
var start_pos: Vector2
var distance_traveled: float
var max_range_multiplier: float = 1

# NEW
var inherited_velocity: Vector2 = Vector2.ZERO

signal bullet_freed(pos: Vector2)

func _physics_process(delta: float) -> void:
	# Bullet velocity + player velocity
	var final_velocity = direction * SPEED + inherited_velocity
	position += final_velocity * delta
	distance_traveled = global_position.distance_to(start_pos)
	if distance_traveled > MAX_RANGE * max_range_multiplier:
		queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		bullet_freed.emit(global_position)
