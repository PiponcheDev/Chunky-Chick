extends Area2D

@export var talisman_data: TalismanData
@onready var icon: Sprite2D = $Icon

# Repulsion settings
@export var repel_radius := 32.0
@export var repel_strength := 80.0

var player_node: Node = null
var player_in_range := false

func _ready() -> void:
	add_to_group("talisman")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_update_icon()


func _process(delta: float) -> void:
	_apply_repulsion(delta)
	if player_in_range and Input.is_action_just_pressed("pick_up"):
		collect()


func _update_icon() -> void:
	if talisman_data == null:
		icon.texture = null
		return

	icon.texture = talisman_data.icon


# -----------------------------
# TALISMAN REPULSION
# -----------------------------
func _apply_repulsion(delta: float) -> void:
	var talismans = get_tree().get_nodes_in_group("talisman")
	for other in talismans:
		if other == self:
			continue
		var dist: float = global_position.distance_to(other.global_position)
		if dist < repel_radius and dist > 0.0:
			var dir: Vector2 = (global_position - other.global_position).normalized()
			var force: float = (repel_radius - dist) / repel_radius
			global_position += dir * force * repel_strength * delta


# -----------------------------
# COLLECT
# -----------------------------
func collect() -> void:
	print("collected item")
	if not player_node:
		return
	player_node.collect_talisman(talisman_data)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_node = body
		player_in_range = true


func _on_body_exited(body: Node) -> void:
	if body == player_node:
		player_in_range = false
		player_node = null
