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

# --- Item bonuses ---
var speed_bonus := 0.0
var damage_bonus := 0.0
var attack_speed_bonus := 0.0
var attack_range_bonus := 0.0
var shot_speed_bonus := 0.0
var fatness_max_bonus := 0.0

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

func _physics_process(delta: float):
	direction = Input.get_vector("walk_left","walk_right","walk_up","walk_down").normalized()
	if direction != Vector2.ZERO:
		last_direction = direction
	match current_state:
		PlayerState.MOVING:
			_handle_moving()
		PlayerState.IDLE_STANDING:
			_handle_idle_standing(delta)
		PlayerState.IDLE_PECKING:
			_handle_idle_pecking()
	move_and_slide()
	_handle_pickup()

# --------------------------------------------------
# STATE HANDLING
# --------------------------------------------------

func _handle_moving():
	if direction == Vector2.ZERO:
		_transition_to_idle()
		return
	velocity = direction * (BASE_SPEED + speed_bonus)
	sprite.play("walking")
	_update_rotation(direction)

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
# ITEM COLLECTION SYSTEM
# --------------------------------------------------

func collect_talisman(data: TalismanData):
	items.append(data)
	speed_bonus += data.speed_bonus
	damage_bonus += data.damage_bonus
	attack_speed_bonus += data.attack_speed_bonus
	attack_range_bonus += data.attack_range_bonus
	shot_speed_bonus += data.shot_speed_bonus
	fatness_max_bonus += data.fatness_max_bonus
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
