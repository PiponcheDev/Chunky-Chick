extends Area2D

@export var speed := 400.0
@export var max_range := 400.0
@export var damage := 10
var direction := Vector2.RIGHT
var shooter: Node2D
var start_pos: Vector2
var distance_traveled := 0.0
var inherited_velocity := Vector2.ZERO
var max_range_multiplier := 1.0

signal bullet_freed(pos: Vector2)

func _ready():
	start_pos = global_position
	rotation = direction.angle()
	connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta):
	var final_velocity = direction * speed
	if inherited_velocity != Vector2.ZERO:
		final_velocity += inherited_velocity

	global_position += final_velocity * delta

	distance_traveled = global_position.distance_to(start_pos)
	if distance_traveled > max_range * max_range_multiplier:
		queue_free()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		bullet_freed.emit(global_position)

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if shooter == null:
		return
	if shooter.is_in_group("enemy") and body.is_in_group("enemy"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("get_current_health"):
			print(body, " current health: ", body.get_current_health())
		queue_free()
