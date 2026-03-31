extends Area2D

@export var hold_distance: float = -62.0
@export var material_type := "cardboard"
@export var material_amount := 1
@export var wobble_amount: float = 3.0
@export var wobble_speed: float = 22.0

var carried: bool = false
var carrier: Node = null
var in_range: bool = false
var wobble_time: float = 0.0

func _ready():
	add_to_group("item")
	add_to_group("material")
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		in_range = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		in_range = false

func pick_up(player: Node):
	carried = true
	carrier = player
	wobble_time = 0.0
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

func drop():
	carried = false
	carrier = null
	set_deferred("collision_layer", 2)
	set_deferred("collision_mask", 3)

func _process(delta):
	if carried and carrier:
		_update_position(delta)

func _update_position(delta: float):
	if not carrier:
		return

	var angle_rad: float = deg_to_rad(carrier.snapped_angle + 90)
	var dir: Vector2 = Vector2(cos(angle_rad), sin(angle_rad))
	var base_pos: Vector2 = carrier.global_position + dir * hold_distance

	var is_moving: bool = carrier.direction != Vector2.ZERO
	if is_moving:
		wobble_time += delta
		var wobble := (sin(wobble_time * wobble_speed) + 0.35 * sin(wobble_time * wobble_speed * 2.3)) * wobble_amount
		global_position = base_pos + dir * wobble
	else:
		global_position = base_pos
		wobble_time = 0.0

	rotation_degrees = carrier.snapped_angle
