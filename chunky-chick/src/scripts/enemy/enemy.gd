extends CharacterBody2D

enum EnemyType { RANGE, FAST, TANK }
var health: int
var damage: int
var speed: int
var enemy_type: EnemyType
var can_shoot: bool = false
signal death()


var Goal_Entity: Node2D
const BULLET_SCENE = preload("res://src/tscn/Bullets.tscn")
@onready var Navigation_Agent = $NavigationAgent2D
@onready var Pathfinding_Timer = $Path
@onready var Attack_Range = $Area2D/CollisionShape2D
@onready var AttackCooldown: Timer = $AttackCooldown
var player_in_range := false

func _ready() -> void:
	Attack_Range.shape = Attack_Range.shape.duplicate(true)
	Goal_Entity = get_tree().get_first_node_in_group("player")
	if Goal_Entity:
		Navigation_Agent.target_position = Goal_Entity.global_position
	match enemy_type:
		EnemyType.FAST:
			AttackCooldown.wait_time = 0.4
			speed = 300
			health = 100
			damage = 10
		EnemyType.RANGE:
			can_shoot = true
			AttackCooldown.wait_time = 1
			Attack_Range.shape.radius = 35
			speed = 250
			health = 150
			damage = 25
		EnemyType.TANK:
			AttackCooldown.wait_time = 2
			speed = 175
			health = 275
			damage = 75

func _physics_process(delta: float) -> void:
		var nav_dir = to_local(Navigation_Agent.get_next_path_position()).normalized()
		velocity = nav_dir * speed
		move_and_slide()
		
		if player_in_range:
			if can_shoot:
				_try_shoot()
			else:
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
		Goal_Entity.take_damage(damage)
	AttackCooldown.start()

func _try_shoot() -> void:
	if AttackCooldown.time_left > 0:
		return
	if Goal_Entity == null:
		return

	var bullet := BULLET_SCENE.instantiate()
	bullet.shooter = self
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.start_pos = global_position
	var dir := (Goal_Entity.global_position - global_position).normalized()
	bullet.direction = dir
	bullet.max_range_multiplier = 1.5
	bullet.damage = damage
	AttackCooldown.start()

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
