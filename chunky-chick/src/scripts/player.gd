extends CharacterBody2D

# --- Nodes ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var main_camera: Camera2D = $Camera2D 

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

func _ready():
	main_camera.add_to_group("main_camera")
	add_to_group("player")
	rng.randomize()
	idle_rng = rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	sprite.play("idle_standing")
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	# Movement input
	direction = Input.get_vector("walk_left","walk_right","walk_up","walk_down").normalized()
	if direction != Vector2.ZERO:
		last_direction = direction
	# Shooting cooldown
	cooldown -= delta
	# State handling
	match current_state:
		PlayerState.MOVING:
			_handle_moving()
		PlayerState.IDLE_STANDING:
			_handle_idle_standing(delta)
		PlayerState.IDLE_PECKING:
			_handle_idle_pecking()
	move_and_slide()
	# Interactions
	_handle_pickup()
	_handle_shooting()
	unlock_ability()

# --------------------------------------------------
# STATE HANDLING
# --------------------------------------------------
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
