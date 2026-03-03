extends Area2D

@export var hold_distance : float = 160.0
@export var weight : float = 100.0

var carried := false
var carrier : Node = null
var in_range := false  

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

func pick_up(player):
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
		update_position()

func update_position():
	var dir = carrier.last_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	dir = dir.normalized()
	global_position = carrier.global_position + dir * hold_distance
