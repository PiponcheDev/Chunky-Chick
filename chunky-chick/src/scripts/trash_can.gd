extends StaticBody2D

@export var persistent_id: String = ""
@export var possible_talismans: Array[TalismanData]
@export var talisman_scene: PackedScene
@export var push_force: float = 150.0

var opened: bool = false
var player_node: Node = null
var is_dumpster: bool = false
var anim_name: String = ""

func _ready():
	var area = $InteractionArea
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	area.monitoring = true
	area.monitorable = true

	if randi() % 10 == 0:
		is_dumpster = true
		anim_name = "dumpster"
	else:
		is_dumpster = false
		anim_name = "trash_can"

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

	opened = true
	$AnimatedSprite2D.play(anim_name)

	var drop_count: int = 2 if is_dumpster else 1
	for i in range(drop_count):
		var talisman_data: TalismanData = possible_talismans.pick_random()
		var talisman = talisman_scene.instantiate() as Node
		talisman.set("talisman_data", talisman_data)

		var spawn_offset: Vector2 = Vector2(randf_range(-6, 6), randf_range(-6, 6))
		talisman.global_position = global_position + Vector2(0, -16) + spawn_offset

		if talisman.get("persistent_id") != null:
			talisman.set("persistent_id", "%s_drop_%d" % [persistent_id, i])

		get_tree().current_scene.add_child(talisman)

		var random_angle: float = randf_range(0.0, TAU)
		var dir: Vector2 = Vector2.from_angle(random_angle)
		var tween: Tween = create_tween()
		tween.tween_property(talisman, "global_position", talisman.global_position + dir * push_force, 0.3)
