extends CharacterBody2D

# Nodes
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var main_camera: Camera2D = $Camera2D 

# Signals
signal carried_item_changed(is_carrying: bool)

# Constants
const SPEED := 450.0
const IDLE_TIME_MIN := 1.0
const IDLE_TIME_MAX := 5.0
const BULLET_SCENE = preload("res://src/tscn/player_bullets.tscn")

# Player states
enum PlayerState { MOVING, IDLE_STANDING, IDLE_PECKING }
var current_state: PlayerState = PlayerState.IDLE_STANDING

# Idle / movement
var direction := Vector2.ZERO
var last_direction: Vector2 = Vector2.DOWN
var idle_time := 0.0
var idle_rng := 0.0
var rng = RandomNumberGenerator.new()

# Shooting
var last_dir: Vector2 = Vector2.DOWN
var bomb_bullets_unlocked: bool = false
var cooldown: float = 0
var cooldown_multiplier: float = 1

# Carried item
var carried_item: Node = null

# Rotation
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
	direction = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down").normalized()
	cooldown -= delta
	
	match current_state:
		PlayerState.MOVING:
			_handle_moving(delta)
		PlayerState.IDLE_STANDING:
			_handle_idle_standing(delta)
		PlayerState.IDLE_PECKING:
			_handle_idle_pecking(delta)
	
	move_and_slide()
	_handle_pickup()
	_handle_shooting()
	unlock_ability()
# --- State handlers ---

func _handle_moving(delta):
	if direction == Vector2.ZERO:
		_transition_to_idle()
	else:
		velocity = direction * SPEED
		sprite.play("walking")
		last_dir = direction
		_update_rotation(direction)

func _handle_idle_standing(delta):
	if direction != Vector2.ZERO:
		current_state = PlayerState.MOVING
	else:
		idle_time += delta
		if idle_time >= idle_rng:
			current_state = PlayerState.IDLE_PECKING
			sprite.play("idle_peck")
			idle_time = 0

func _handle_idle_pecking(delta):
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

# --- Pickup system ---

func _handle_pickup():
	if Input.is_action_just_pressed("pick_up"):
		if carried_item:
			# Drop the item
			carried_item.drop()
			for nest in get_tree().get_nodes_in_group("nest"):
				nest.try_deposit(carried_item)
			carried_item = null
			emit_signal("carried_item_changed", false)
		else:
			# Pick up nearest item
			for item in get_tree().get_nodes_in_group("item"):
				if item.in_range and not item.carried:
					item.pick_up(self)
					carried_item = item
					emit_signal("carried_item_changed", true)
					break

# --- Shooting system ---
func _handle_shooting():
	if Input.is_action_pressed("shoot") and cooldown <= 0:
		cooldown = 0.6 * cooldown_multiplier
		var bullet = BULLET_SCENE.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position
		bullet.start_pos = global_position
		bullet.direction = last_dir
		bullet.bullet_freed.connect(_on_bullet_freed)

func _on_bullet_freed(pos: Vector2) ->void:
	if bomb_bullets_unlocked:
		for i in 8:
			var Bomb_Bullet = BULLET_SCENE.instantiate()
			get_tree().current_scene.add_child(Bomb_Bullet)
			Bomb_Bullet.global_position = pos
			Bomb_Bullet.start_pos = pos
			Bomb_Bullet.max_range_multiplier = 0.5
			Bomb_Bullet.scale = Vector2(6.0, 6.0)
			Bomb_Bullet.direction = Vector2.RIGHT.rotated(deg_to_rad(i * 45))

func unlock_ability() -> void:
	if Input.is_action_just_pressed("unlock_ability_temp"):
		bomb_bullets_unlocked = true
		cooldown_multiplier = 0.6
		print("unlocked")
