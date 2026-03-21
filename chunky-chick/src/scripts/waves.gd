extends Node2D

@export var enemy: PackedScene

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
var c_fast := 0
var c_tank := 0
var c_range:= 0

func _ready() -> void:
	var a: float = randf() * TAU
	_add_point_at_angle(a)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_arc(center, radius, 0.0, TAU, 128, arc_color, 2.0)

	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		for p in points:
			draw_circle(p, 6.0, point_color)
		return

	var world_to_screen: Transform2D = get_viewport().get_canvas_transform()
	var screen_to_world: Transform2D = world_to_screen.affine_inverse()

	var vp_size: Vector2 = get_viewport_rect().size
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, vp_size)
	var screen_center: Vector2 = vp_size * 0.5

	for p_local: Vector2 in points:
		var p_world: Vector2 = to_global(p_local)
		var p_screen: Vector2 = world_to_screen * p_world

		if screen_rect.has_point(p_screen):
			draw_circle(p_local, 6.0, point_color)
		else:
			var dir: Vector2 = p_screen - screen_center
			if dir.length_squared() < 0.000001:
				dir = Vector2.RIGHT
			else:
				dir = dir.normalized()

			# Indicator position locked to an invisible circle 
			var indicator_screen: Vector2 = screen_center + dir * indicator_orbit_radius

			# Flashing
			var alpha: float = 0.2 + 0.8 * abs(sin(_t * flash_speed))
			var c: Color = indicator_color
			c.a = alpha

			var indicator_world: Vector2 = screen_to_world * indicator_screen
			var indicator_local: Vector2 = to_local(indicator_world)

			_draw_triangle_indicator(indicator_local, dir, c)

func _draw_triangle_indicator(pos_local: Vector2, dir_screen: Vector2, c: Color) -> void:
	# Draw a filled triangle arrow pointing to the point
	var forward: Vector2 = dir_screen
	var right: Vector2 = Vector2(-forward.y, forward.x)

	var tip: Vector2 = pos_local + forward * (indicator_size * 1.4)
	var base_center: Vector2 = pos_local - forward * (indicator_size * 0.9)
	var left: Vector2 = base_center - right * indicator_size
	var rgt: Vector2 = base_center + right * indicator_size

	draw_colored_polygon(PackedVector2Array([tip, left, rgt]), c)

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
	if Input.is_action_just_pressed("wave"):
		var count := randi_range(10, 20)

		var base_angle: float = angles[-1]
		var half_arc: float = deg_to_rad(40.0) * 0.5

		for i in count:
			await get_tree().create_timer(randf_range(0.5, 1)).timeout
			var t = 0.0 if count == 1 else float(i) / float(count - 1)
			var a = lerp(base_angle - half_arc, base_angle + half_arc, t)
			var p_local: Vector2 = center + Vector2(cos(a), sin(a)) * radius
			var p_global: Vector2 = to_global(p_local)

			var e := enemy.instantiate() as Node2D
			e.enemy_type = pick_type(randomness, c_fast, c_range, c_tank)
			get_parent().add_child(e)
			e.global_position = p_global
			match e.enemy_type:
				0:
					c_range+=1
				1:
					c_fast+=1
				2:
					c_tank+=1


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
