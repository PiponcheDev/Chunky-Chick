extends Node2D

@export var enemy_range: PackedScene
@export var enemy_fast: PackedScene
@export var enemy_tank: PackedScene

#circle for raids
@export var radius: float = 2000.0
@export var min_angle: float = PI / 4.0
var max_tries: int = 100

#indicator of point of wave
@export var indicator_orbit_radius: float = 140.0 
@export var indicator_size: float = 12.0
@export var flash_speed: float = 6.0

# Colors
@export var indicator_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var point_color: Color = Color.RED
@export var arc_color: Color = Color.WHITE

#arrays about the circle for raids
var center: Vector2 = Vector2.ZERO
var points: Array[Vector2] = []
var angles: Array[float] = []


var _t: float = 0.0
var randomness := RandomNumberGenerator.new()
var enemy_type : int
var c_fast := 0
var c_tank := 0
var c_range:= 0

@onready var nest = $"../Nest"

func _ready() -> void:
	var a: float = randf() * TAU
	_add_point_at_angle(a)
	nest.start_raid.connect(start_raid)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func spawn_point() -> bool:
	for _i in max_tries:
		var a: float = randf() * TAU
		if _is_angle_valid(a):
			_add_point_at_angle(a)
			return true
	return false

func _is_angle_valid(a: float) -> bool:
	for existing: float in angles:
		if abs(angle_difference(a, existing)) < min_angle:
			return false
	return true

func _add_point_at_angle(a: float) -> void:
	var p: Vector2 = center + Vector2(cos(a), sin(a)) * radius
	angles.append(a)
	points.append(p)

func _angle_difference(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("spawn_one_enemy"):
		var base_angle: float = angles[-1]
		var half_arc: float = deg_to_rad(40.0) * 0.5
		await get_tree().create_timer(randf_range(0.5, 1)).timeout
		var t = 0.0
		var a = lerp(base_angle - half_arc, base_angle + half_arc, t)
		var p_local: Vector2 = center + Vector2(cos(a), sin(a)) * radius
		var p_global: Vector2 = to_global(p_local)
		var e
		e = enemy_tank.instantiate() as Node2D
		get_parent().add_child(e)
		e.global_position = p_global
		
func start_raid() -> void:
	var count := randi_range(10, 20)

	var base_angle: float = angles[-1]
	var half_arc: float = deg_to_rad(40.0) * 0.5

	for i in count:
		await get_tree().create_timer(randf_range(0.5, 1)).timeout
		var t = 0.0 if count == 1 else float(i) / float(count - 1)
		var a = lerp(base_angle - half_arc, base_angle + half_arc, t)
		var p_local: Vector2 = center + Vector2(cos(a), sin(a)) * radius
		var p_global: Vector2 = to_global(p_local)
		var e
		
		enemy_type = pick_type(randomness, c_fast, c_range, c_tank)
		match enemy_type:
			0:
				c_range+=1
				e = enemy_range.instantiate() as Node2D
			1:
				c_fast+=1
				e = enemy_fast.instantiate() as Node2D
			2:
				e= enemy_tank.instantiate() as Node2D
				c_tank+=1
		
		get_parent().add_child(e)
		e.global_position = p_global

func pick_type(rng: RandomNumberGenerator, fast:int, range:int, tank:int, jitter:float=0.2) -> int:
	var total := fast + range + tank
	var desired := Vector3(0.5, 1.0/3.0, 1.0/6.0) * float(total + 1)
	var deficit := desired - Vector3(c_fast, c_range, c_tank)

	var score := Vector3(
		max(0.01, deficit.x + rng.randf_range(-jitter, jitter)),
		max(0.01, deficit.y + rng.randf_range(-jitter, jitter)),
		max(0.01, deficit.z + rng.randf_range(-jitter, jitter))
	)

	var sum := score.x + score.y + score.z
	var r := rng.randf() * sum
	return 1 if r < score.x else (0 if r < score.x + score.y else 2)
