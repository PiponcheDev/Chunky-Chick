extends CharacterBody2D

# --- Nodes ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var main_camera: Camera2D = $Camera2D 
@onready var dash_cooldown: Timer = $"dash-cooldown"

# --- Signals ---
signal carried_item_changed(is_carrying: bool)

# --- Base stats ---
const BASE_SPEED := 450.0
const IDLE_TIME_MIN := 1.0
const IDLE_TIME_MAX := 5.0
const BULLET_SCENE = preload("res://src/tscn/player_bullets.tscn")

# --- Item bonuses ---
var speed_bonus := 0.0
var damage_bonus := 0.0
var attack_speed_bonus := 0.0
var attack_range_bonus := 0.0
var shot_speed_bonus := 0.0
var fatness_max_bonus := 0.0

# --- Fatness System ---
var fatness: float = 0
var fatness_max: float = 100
const FAT_SPEED_PENALTY := 0.4

# --- Inventory ---
var items: Array[TalismanData] = []

# --- Player states ---
enum PlayerState { MOVING, IDLE_STANDING, IDLE_PECKING }
var current_state: PlayerState = PlayerState.IDLE_STANDING

# --- Movement ---
var direction := Vector2.ZERO
var last_direction := Vector2.DOWN
var idle_time := 0.0
var idle_rng := 0.0
var rng = RandomNumberGenerator.new()

# --- Shooting ---
var last_dir: Vector2 = Vector2.DOWN
var bomb_bullets_unlocked: bool = false
var cooldown: float = 0.0
var cooldown_multiplier: float = 1.0

# --- Carry system ---
var carried_item: Node = null

# --- Rotation ---
var angle_degrees := 0.0
var snapped_angle := 0

# --- Dash ---
var dash_speed := BASE_SPEED + 1400.0
var dash_distance := 250.0

var is_dashing := false
var dash_direction := Vector2.ZERO
var dash_traveled := 0.0

# --- Dash Visuals ---
var dash_stretch := 1.05
var dash_squash := 0.85
var dash_anim_speed := 2.5

var normal_anim_speed := 1.0

# --- Afterimage Trail ---
var ghost_interval := 0.03
var ghost_timer := 0.0
var ghost_lifetime := 0.35
var ghost_color := Color(0.8, 0.9, 1.0, 0.6)

func _ready():
	
	main_camera.add_to_group("main_camera")
	add_to_group("player")
	rng.randomize()
	idle_rng = rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	sprite.play("idle_standing")
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	
	if Input.is_action_just_pressed("dash"):
		_start_dash()
	direction = Input.get_vector("walk_left","walk_right","walk_up","walk_down").normalized()
	if direction != Vector2.ZERO:
		last_direction = direction
	cooldown -= delta
	if is_dashing:
		_handle_dash(delta)
	else:
		_handle_normal_state(delta)
	move_and_slide()
	_handle_pickup()
	_handle_shooting()
	unlock_ability()

# --------------------------------------------------
# STATE HANDLING
# --------------------------------------------------

func _handle_normal_state(delta):
	match current_state:
		PlayerState.MOVING:
			_handle_moving()
		PlayerState.IDLE_STANDING:
			_handle_idle_standing(delta)
		PlayerState.IDLE_PECKING:
			_handle_idle_pecking()

func _handle_moving():
	if direction == Vector2.ZERO:
		_transition_to_idle()
		return
	var fat_ratio = fatness / (fatness_max + fatness_max_bonus)
	var speed_multiplier = 1.0 - (fat_ratio * FAT_SPEED_PENALTY)
	velocity = direction * (BASE_SPEED + speed_bonus) * speed_multiplier
	sprite.play("walking")
	last_dir = direction
	_update_rotation(direction)

func eat_food(amount := 5):
	fatness += amount
	fatness = clamp(fatness, 0, fatness_max + fatness_max_bonus)
	print("Fatness:", fatness)

func _handle_idle_standing(delta):
	if direction != Vector2.ZERO:
		current_state = PlayerState.MOVING
		return
	idle_time += delta
	if idle_time >= idle_rng:
		current_state = PlayerState.IDLE_PECKING
		sprite.play("idle_peck")
		idle_time = 0

func _handle_idle_pecking():
	if direction != Vector2.ZERO:
		current_state = PlayerState.MOVING

func _transition_to_idle():
	current_state = PlayerState.IDLE_STANDING
	sprite.play("idle_standing")
	idle_time = 0
	idle_rng = rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	velocity = Vector2.ZERO

func _update_rotation(dir: Vector2):
	angle_degrees = rad_to_deg(dir.angle())
	snapped_angle = (round(angle_degrees / 45) * 45) - 90
	sprite.rotation_degrees = snapped_angle

func _on_animation_finished():
	if current_state == PlayerState.IDLE_PECKING:
		_transition_to_idle()

func _start_dash():
	if is_dashing or !dash_cooldown.is_stopped():
		return
	is_dashing = true
	dash_traveled = 0
	ghost_timer = 0
	dash_cooldown.start()
	dash_direction = direction if direction != Vector2.ZERO else last_direction
	sprite.play("walking")
	sprite.speed_scale = dash_anim_speed
	_apply_dash_stretch()

func _apply_dash_stretch():
	var dir = dash_direction.normalized()
	var stretch_x = lerp(dash_squash, dash_stretch, abs(dir.x))
	var stretch_y = lerp(dash_squash, dash_stretch, abs(dir.y))
	sprite.scale = Vector2(stretch_y, stretch_x)

func _handle_dash(delta):
	var move_amount = dash_speed * delta
	dash_traveled += move_amount
	velocity = dash_direction * dash_speed
	ghost_timer -= delta
	if ghost_timer <= 0:
		_spawn_ghost()
		ghost_timer = ghost_interval
	if dash_traveled >= dash_distance:
		_end_dash()

func _end_dash():
	is_dashing = false
	sprite.scale = Vector2.ONE
	sprite.speed_scale = normal_anim_speed

func _spawn_ghost():
	var ghost := Sprite2D.new()
	var frame_texture = sprite.sprite_frames.get_frame_texture(
		sprite.animation,
		sprite.frame
	)
	ghost.texture = frame_texture
	ghost.global_position = sprite.global_position
	ghost.rotation = sprite.rotation
	ghost.scale = sprite.scale / 2
	ghost.modulate = ghost_color
	get_tree().current_scene.add_child(ghost)
	var tween = create_tween()
	tween.tween_property(
		ghost,
		"modulate:a",
		0.0,
		ghost_lifetime
	)
	tween.parallel().tween_property(
		ghost,
		"scale",
		ghost.scale * 0.9,
		ghost_lifetime
	)
	tween.tween_callback(ghost.queue_free)

# --------------------------------------------------
# TALISMAN COLLECTION SYSTEM
# --------------------------------------------------
func collect_talisman(data: TalismanData, from_load := false):
	items.append(data)
	speed_bonus += data.speed_bonus
	damage_bonus += data.damage_bonus
	attack_speed_bonus += data.attack_speed_bonus
	attack_range_bonus += data.attack_range_bonus
	shot_speed_bonus += data.shot_speed_bonus
	fatness_max_bonus += data.fatness_max_bonus

	if not from_load and GameLoad.current_run:
		GameLoad.current_run.talismans.append(data)
		GameLoad.save_run()

	print("Collected talisman:", data.talisman_name)

# --------------------------------------------------
# PICKUP / DROP SYSTEM
# --------------------------------------------------
func _handle_pickup():
	if !Input.is_action_just_pressed("pick_up"):
		return
	if carried_item:
		carried_item.drop()
		for nest in get_tree().get_nodes_in_group("nest"):
			nest.try_deposit(carried_item)
		carried_item = null
		emit_signal("carried_item_changed", false)
	else:
		for item in get_tree().get_nodes_in_group("item"):
			if item.in_range and !item.carried:
				item.pick_up(self)
				carried_item = item
				emit_signal("carried_item_changed", true)
				break

# --------------------------------------------------
# SHOOTING SYSTEM
# --------------------------------------------------
func _handle_shooting():
	if Input.is_action_pressed("shoot") and cooldown <= 0:
		cooldown = 0.6 * cooldown_multiplier
		var bullet = BULLET_SCENE.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position
		bullet.start_pos = global_position
		bullet.direction = -last_dir
		bullet.bullet_freed.connect(_on_bullet_freed)

func _on_bullet_freed(pos: Vector2) -> void:
	if bomb_bullets_unlocked:
		for i in 8:
			var bomb_bullet = BULLET_SCENE.instantiate()
			get_tree().current_scene.add_child(bomb_bullet)
			bomb_bullet.global_position = pos
			bomb_bullet.start_pos = pos
			bomb_bullet.max_range_multiplier = 0.5
			bomb_bullet.scale = Vector2(6.0, 6.0)
			bomb_bullet.direction = Vector2.RIGHT.rotated(deg_to_rad(i * 45))

func unlock_ability() -> void:
	if Input.is_action_just_pressed("unlock_ability_temp"):
		bomb_bullets_unlocked = true
		cooldown_multiplier = 0.6
		print("Ability unlocked")
		
		
# Returns the dash cooldown progress as a ratio (0.0 to 1.0)
func get_dash_cooldown_ratio() -> float:
	if dash_cooldown.wait_time == 0:
		return 0.0
	return clamp(dash_cooldown.time_left / dash_cooldown.wait_time, 0.0, 1.0)
