extends CharacterBody2D

enum DashState {
	NONE_DASH,
	DASH_LOCK,
	DASH_COIL,
	DASH_EXEC,
}

var _ghost_owner_id: int

var state: DashState = DashState.NONE_DASH
@onready var anim_sprite = $AnimatedSprite2D
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

# --- Ghost / Afterimage tuning ---
@export var ghost_interval: float = 0.04
@export var ghost_lifetime: float = 0.35
@export var ghost_start_alpha: float = 0.65
@export var ghost_scale_mult: float = 0.95
@export var ghost_color_base: Color = Color(0.8, 0.9, 1.0)

var _ghost_timer: float = 0.0
var _ghost_active: bool = false


func _ready() -> void:
	_ghost_owner_id = get_instance_id()
	Goal_Entity = get_tree().get_first_node_in_group("player")
	if Goal_Entity:
		Navigation_Agent.target_position = Goal_Entity.global_position


func _physics_process(delta: float) -> void:
	dash_cooldown = max(dash_cooldown - delta, 0.0)

	if state == DashState.NONE_DASH:
		_try_start_dash()

	match state:
		DashState.NONE_DASH:
			anim_sprite.play("walk")
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
				anim_sprite.play("coil")
				dash_timer = dash_coil_time

		DashState.DASH_COIL:
			velocity = Vector2.ZERO
			dash_timer -= delta
			if dash_timer <= 0.0:
				state = DashState.DASH_EXEC
				anim_sprite.play("dash")
				dash_timer = dash_exec_time

				# Start ghost trail when dash begins
				_ghost_active = true
				_ghost_timer = 0.0

		DashState.DASH_EXEC:
			velocity = dash_vector * dash_speed
			dash_timer -= delta
			if dash_timer <= 0.0:
				_end_dash()

	_update_dash_ghosts(delta)
	move_and_slide()


func _update_dash_ghosts(delta: float) -> void:
	if not _ghost_active:
		return
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_spawn_dash_ghost()
		_ghost_timer = ghost_interval


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

	# Ensure ghosts are OFF until we actually enter DASH_EXEC
	_ghost_active = false


func _end_dash() -> void:
	state = DashState.NONE_DASH
	velocity = Vector2.ZERO
	dashing = false

	# Stop ghost trail when dash ends
	_ghost_active = false


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
	anim_sprite.rotation_degrees = snapped_angle


func _spawn_dash_ghost() -> void:
	# Requires: anim_sprite: AnimatedSprite2D
	if not anim_sprite or not anim_sprite.sprite_frames:
		return

	var tex: Texture2D = anim_sprite.sprite_frames.get_frame_texture(
		anim_sprite.animation,
		anim_sprite.frame
	)
	if not tex:
		return

	var ghost := Sprite2D.new()
	ghost.texture = tex
	ghost.add_to_group("dash_ghost")
	ghost.set_meta("owner_id", _ghost_owner_id)

	ghost.global_position = anim_sprite.global_position
	ghost.global_rotation = anim_sprite.global_rotation
	ghost.scale = anim_sprite.global_scale
	ghost.modulate = Color(
		ghost_color_base.r,
		ghost_color_base.g,
		ghost_color_base.b,
		ghost_start_alpha
	)

	get_tree().current_scene.add_child(ghost)

	var tw = create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, ghost_lifetime)
	tw.parallel().tween_property(ghost, "scale", ghost.scale * ghost_scale_mult, ghost_lifetime)
	tw.tween_callback(Callable(ghost, "queue_free"))
	
	
func _clear_my_ghosts() -> void:
	if not is_inside_tree():
		return
	for g in get_tree().get_nodes_in_group("dash_ghost"):
		if is_instance_valid(g) and g.get_meta("owner_id", -1) == _ghost_owner_id:
			g.queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_clear_my_ghosts()
