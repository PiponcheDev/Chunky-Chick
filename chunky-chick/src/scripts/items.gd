extends Area2D

# Exported properties
@export var hold_distance: float = 160.0

# State
var carried: bool = false
var carrier: Node = null
var in_range: bool = false

func _ready():
	add_to_group("item")
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
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

func drop():
	carried = false
	carrier = null
	set_deferred("collision_layer", 1)
	set_deferred("collision_mask", 1)

func _process(delta):
	if carried and carrier:
		_update_position()

func _update_position():
	if not carrier:
		return
	var angle_rad = deg_to_rad(carrier.snapped_angle + 90)
	var dir = Vector2(cos(angle_rad), sin(angle_rad))
	global_position = carrier.global_position + dir * hold_distance
