extends Area2D

const SPEED := 800
const MAX_RANGE := 400

@onready var Sprite = $ColorRect
@onready var col: CollisionShape2D = $CollisionShape2D

var direction := Vector2.ZERO
var start_pos: Vector2
var distance_traveled: float
var max_range_multiplier: float = 1.0
var damage: int = 0
var shooter: Node2D

var inherited_velocity: Vector2 = Vector2.ZERO

signal bullet_freed(pos: Vector2)

func _ready() -> void:
	if shooter and shooter.is_in_group("player"):
		col.shape = col.shape.duplicate(true)
		col.shape.size = Vector2(4.5, 4.5)

func _physics_process(delta: float) -> void:
	var final_velocity: Vector2

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

	if shooter and shooter.is_in_group("enemy") and body.is_in_group("enemy"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("get_current_health"):
			print(body, "\nfatness: ", body.get_current_health())
		queue_free()
