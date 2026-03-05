extends StaticBody2D

@export var possible_talismans: Array[TalismanData]
@export var talisman_scene: PackedScene
@export var push_force: float = 150.0

var opened := false
var player_node: Node = null

func _ready():
	var area = $InteractionArea
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	area.monitoring = true
	area.monitorable = true

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_node = body

func _on_body_exited(body):
	if body == player_node:
		player_node = null

func _process(delta):
	if player_node and Input.is_action_just_pressed("pick_up") and not opened:
		open()

func open():
	print("opened trash can")
	if opened or possible_talismans.size() == 0:
		return
	opened = true
	var talisman_data = possible_talismans.pick_random()
	var talisman = talisman_scene.instantiate()
	talisman.talisman_data = talisman_data
	talisman.global_position = global_position + Vector2(0, -16)
	get_tree().current_scene.add_child(talisman)
	# Push away from player
	var dir = (talisman.global_position - player_node.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var tween = create_tween()
	tween.tween_property(talisman, "global_position", talisman.global_position + dir * push_force, 0.3)
