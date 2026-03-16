extends CharacterBody2D

const SPEED = 200

var Goal_Entity: Node2D
@onready var Navigation_Agent = $NavigationAgent2D
@onready var Pathfinding_Timer = $Timer

func _ready() -> void:
	Goal_Entity = get_tree().get_first_node_in_group("player")
	Navigation_Agent.target_position = Goal_Entity.global_position
	

func _physics_process(delta: float) -> void:
		var nav_dir = to_local(Navigation_Agent.get_next_path_position()).normalized()
		velocity = nav_dir * SPEED
		move_and_slide()
		

func makepath() -> void:
	Navigation_Agent.target_position = Goal_Entity.global_position


func _on_timer_timeout() -> void:
	makepath()
	
