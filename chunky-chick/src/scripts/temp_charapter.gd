extends CharacterBody2D

const SPEED = 300.0
var direction = Vector2.ZERO
var last_direction : Vector2 = Vector2.DOWN

var carried_item : Node = null

func get_direction():
	direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		last_direction = direction.normalized()
	direction = direction.normalized()
	return direction

func _physics_process(delta: float) -> void:
	get_direction()
	velocity = direction * SPEED
	move_and_slide()
	handle_pickup()

#Functions on item managment

func handle_pickup():
	if Input.is_action_just_pressed("pick_up"):
		if carried_item:
			# Drop item
			carried_item.drop()
			# Check all nests in the scene
			for nest in get_tree().get_nodes_in_group("nest"):
				nest.try_deposit(carried_item)
			carried_item = null
		else:
			# Pick up nearby item
			for item in get_tree().get_nodes_in_group("item"):
				if item.in_range and not item.carried:
					item.pick_up(self)
					carried_item = item
					break
