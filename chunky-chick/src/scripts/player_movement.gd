extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D


const IDLE_TIME_MIN = 1.0
const IDLE_TIME_MAX = 5.0
const SPEED         = 450.0
const JUMP_VELOCITY = -400.0

enum PlayerState { MOVING, IDLE_STANDING, IDLE_PECKING }
var current_state: PlayerState = PlayerState.IDLE_STANDING

# Idle peck timing
var idle_time := 0.0
var rng = RandomNumberGenerator.new()
var idle_rng := 0.0

var angle_degrees = 0.0
var snapped_angle = 0

func _ready():
	#setting up for the idle_peck animation
	rng.randomize()
	idle_rng = rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	sprite.play("idle_standing")
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	
	match current_state:
		PlayerState.MOVING:
			handle_moving_state(direction, delta)
		PlayerState.IDLE_STANDING:
			handle_idle_standing_state(direction, delta)
		PlayerState.IDLE_PECKING:
			handle_idle_pecking_state(direction, delta)
	
	move_and_slide()

func transition_to_idle_standing() -> void:
	idle_time = 0
	current_state = PlayerState.IDLE_STANDING
	sprite.play("idle_standing")
	idle_rng = rng.randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	velocity = Vector2.ZERO

func handle_moving_state(direction: Vector2, delta: float):
	if direction == Vector2.ZERO:
		transition_to_idle_standing()

	else:
		direction = direction.normalized()
		velocity = direction * SPEED
		sprite.play("walking")
		angle_degrees = rad_to_deg(direction.angle())
		snapped_angle = snapped(angle_degrees, 45)
		snapped_angle -= 90
		
		sprite.rotation_degrees = snapped_angle
		print(snapped_angle)

func handle_idle_standing_state(direction: Vector2, delta: float):
	if direction != Vector2.ZERO:
		current_state = PlayerState.MOVING
		
	else:
		idle_time += delta
		
		if idle_time >= idle_rng:
			current_state = PlayerState.IDLE_PECKING
			sprite.play("idle_peck")
			idle_time = 0

func handle_idle_pecking_state(direction: Vector2, delta: float):
	if direction != Vector2.ZERO:
		# Interrupt pecking to move
		current_state = PlayerState.MOVING

func _on_animation_finished():
	if current_state == PlayerState.IDLE_PECKING:
		transition_to_idle_standing()
