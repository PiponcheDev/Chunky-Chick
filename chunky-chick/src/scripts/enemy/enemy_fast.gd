extends CharacterBody2D

enum DashState {
	NONE_DASH,
	DASH_LOCK,
	DASH_COIL,
	DASH_EXEC,
}

var state: DashState = DashState.NONE_DASH
@onready var sprite = $AnimatedSprite2D
@export var health: int
@export var damage: int
@export var speed: int

var player_in_range := false
var Goal_Entity: Node2D

@onready var Navigation_Agent: NavigationAgent2D = $NavigationAgent2D
@onready var Pathfinding_Timer: Timer = $Path
@onready var AttackCooldown: Timer = $AttackCooldown

# --- Dash tuning ---
@export var dash_speed := 900.0
@export var dash_trigger_distance := 350.0
@export var dash_lock_time := 0.25              
@export var dash_coil_time := 0.25            
@export var dash_exec_time := 0.15              
@export var dash_cooldown_time := 1.25          

var dash_vector := Vector2.ZERO
var dash_cooldown := 0.0
var dash_timer := 0.0
var dashing := false

var angle_degrees := 0.0
var snapped_angle := 0

func _ready() -> void:
	Goal_Entity = get_tree().get_first_node_in_group("player")
	if Goal_Entity:
		Navigation_Agent.target_position = Goal_Entity.global_position


func _physics_process(delta: float) -> void:
	dash_cooldown = max(dash_cooldown - delta, 0.0)

	
	if state == DashState.NONE_DASH:
		_try_start_dash()

	match state:
		DashState.NONE_DASH:
			sprite.play("walk")
			var nav_dir = to_local(Navigation_Agent.get_next_path_position()).normalized()
			velocity = nav_dir * speed
			_update_rotation(nav_dir)

			if player_in_range:
				_try_melee_hit()

		DashState.DASH_LOCK:
			velocity = Vector2.ZERO
			dash_timer -= delta
			if dash_timer <= 0.0:
				state = DashState.DASH_COIL
				sprite.play("coil")
				dash_timer = dash_coil_time

		DashState.DASH_COIL:
			
			velocity = Vector2.ZERO
			dash_timer -= delta
			if dash_timer <= 0.0:
				state = DashState.DASH_EXEC
				sprite.play("dash")
				dash_timer = dash_exec_time

		DashState.DASH_EXEC:
			velocity = dash_vector * dash_speed
			dash_timer -= delta
			if dash_timer <= 0.0:
				_end_dash()

	move_and_slide()


func _try_start_dash() -> void:
	if dash_cooldown > 0.0:
		return
	if not Goal_Entity:
		return

	var dist := _distance_to_player()
	if dist <= dash_trigger_distance:
		return

	dash_vector = (Goal_Entity.global_position - global_position).normalized()

	# Start dash state machine
	state = DashState.DASH_LOCK
	dash_timer = dash_lock_time
	dash_cooldown = dash_cooldown_time
	dashing = true


func _end_dash() -> void:
	state = DashState.NONE_DASH
	velocity = Vector2.ZERO
	dashing = false


func _distance_to_player() -> float:
	if not Goal_Entity:
		return INF
	return global_position.distance_to(Goal_Entity.global_position)


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
	if dashing:
		return
	angle_degrees = rad_to_deg(dir.angle())
	snapped_angle = round(angle_degrees / 45) * 45 + 90
	sprite.rotation_degrees = snapped_angle
