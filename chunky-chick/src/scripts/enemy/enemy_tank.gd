extends CharacterBody2D

@export var health: int
@export var damage: int
@export var speed: int

var angle_degrees := 0.0
var snapped_angle := 0

var player_in_range := false

var Goal_Entity: Node2D

@onready var Navigation_Agent = $NavigationAgent2D
@onready var Pathfinding_Timer = $Path
@onready var AttackCooldown: Timer = $AttackCooldown
@onready var sprite = $AnimatedSprite2D
func _ready() -> void:
	Goal_Entity = get_tree().get_first_node_in_group("player")
	if Goal_Entity:
		Navigation_Agent.target_position = Goal_Entity.global_position


func _physics_process(delta: float) -> void:
		var nav_dir = to_local(Navigation_Agent.get_next_path_position()).normalized()
		velocity = nav_dir * speed
		_update_rotation(nav_dir)
		move_and_slide()
		
		if player_in_range:
			_try_melee_hit()
		
			
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
	
func _try_melee_hit() -> void:
	if AttackCooldown.time_left > 0:
		return
	if Goal_Entity:
		sprite.play("attack")
		Goal_Entity.take_damage(damage)
	AttackCooldown.start()
	await sprite.animation_finished
	sprite.play("walking")

func makepath() -> void:
	if !Goal_Entity:
		return
	Navigation_Agent.target_position = Goal_Entity.global_position
	
func _on_timer_timeout() -> void:
	makepath()
	
func take_damage(amount: int) -> void:
	health = max(health - amount, 0)

	if health == 0:
		queue_free()

func _update_rotation(dir: Vector2):
	angle_degrees = rad_to_deg(dir.angle())
	snapped_angle = round(angle_degrees / 45) * 45 + 90
	sprite.rotation_degrees = snapped_angle
