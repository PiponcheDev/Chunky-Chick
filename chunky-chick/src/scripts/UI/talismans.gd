extends Area2D

@export var talisman_data: TalismanData

# Repulsion settings
@export var repel_radius := 32.0
@export var repel_strength := 80.0

var player_node: Node = null
var player_in_range := false

func _ready():
	add_to_group("talisman")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_node = body
		player_in_range = true

func _on_body_exited(body):
	if body == player_node:
		player_in_range = false
		player_node = null


func _process(delta):
	_apply_repulsion(delta)
	if player_in_range and Input.is_action_just_pressed("pick_up"):
		collect()


# -----------------------------
# TALISMAN REPULSION
# -----------------------------
func _apply_repulsion(delta):
	var talismans = get_tree().get_nodes_in_group("talisman")
	for other in talismans:
		if other == self:
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < repel_radius and dist > 0:
			var dir = (global_position - other.global_position).normalized()
			var force = (repel_radius - dist) / repel_radius
			global_position += dir * force * repel_strength * delta


# -----------------------------
# COLLECT
# -----------------------------
func collect():
	print("collected item")
	if not player_node:
		return
	player_node.collect_talisman(talisman_data)
	queue_free()
