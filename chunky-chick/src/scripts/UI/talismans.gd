extends Area2D  # CHANGE from RigidBody2D -> Area2D for simplicity

@export var talisman_data: TalismanData

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
	if player_in_range and Input.is_action_just_pressed("pick_up"):
		collect()

func collect():
	print("collected item")
	if not player_node:
		return
	player_node.collect_talisman(talisman_data)
	queue_free()
