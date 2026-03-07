extends StaticBody2D

@export var possible_talismans: Array[TalismanData]
@export var talisman_scene: PackedScene
@export var push_force: float = 150.0

var opened := false
var player_node: Node = null
var is_dumpster := false
var anim_name := ""

func _ready():
	var area = $InteractionArea
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	area.monitoring = true
	area.monitorable = true

	# 1 in 10 chance to become a dumpster
	if randi() % 10 == 0:
		is_dumpster = true
		anim_name = "dumpster"
	else:
		is_dumpster = false
		anim_name = "trash_can"

	# Show first frame only (static sprite)
	var sprite = $AnimatedSprite2D
	sprite.animation = anim_name
	sprite.frame = 0
	sprite.pause()


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
	if opened or possible_talismans.size() == 0:
		return
	print("opened trash can")
	opened = true
	$AnimatedSprite2D.play(anim_name)
	var drop_count := 2 if is_dumpster else 1
	for i in range(drop_count):
		var talisman_data = possible_talismans.pick_random()
		var talisman = talisman_scene.instantiate()
		talisman.talisman_data = talisman_data
		# Small random spawn offset so items never start perfectly stacked
		var spawn_offset = Vector2(randf_range(-6,6), randf_range(-6,6))
		talisman.global_position = global_position + Vector2(0, -16) + spawn_offset
		get_tree().current_scene.add_child(talisman)
		# RANDOM direction instead of player direction
		var random_angle = randf_range(0, TAU)
		var dir = Vector2.from_angle(random_angle)
		var tween = create_tween()
		tween.tween_property(
			talisman,
			"global_position",
			talisman.global_position + dir * push_force,
			0.3
		)
