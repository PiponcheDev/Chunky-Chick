extends Node2D

@export var persistent_id: String = ""

@onready var head: Node2D = $Head
@onready var muzzle: Marker2D = $Head/Muzzle
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var fire_timer: Timer = $FireTimer

@export var base_detection_radius: float = 300.0
@export var base_attack_angle_deg: float = 30.0
@export var fire_rate: float = 1.0

var detection_radius: float
var attack_angle_deg: float
var temp_range_multiplier: float = 1.0
var temp_angle_multiplier: float = 1.0
var range_multiplier: float = 1.0
var angle_multiplier: float = 1.0
var enemies_in_range: Array = []
var target: Node2D = null
var head_locked: bool = false
var show_preview: bool = false

var BulletScene: PackedScene = preload("res://src/tscn/Structures/turret_bullet.tscn")

func _ready():
	add_to_group("turret")
	_recalculate_stats()
	fire_timer.wait_time = fire_rate
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	fire_timer.timeout.connect(_fire)
	fire_timer.start()

func capture_into_run_data() -> Dictionary:
	return {
		"kind": "turret",
		"id": persistent_id,
		"position": global_position,
		"rotation": head.rotation,
		"range_multiplier": range_multiplier,
		"angle_multiplier": angle_multiplier,
		"locked": head_locked
	}

func apply_run_data(state: Dictionary) -> void:
	if state.is_empty():
		return
	if state.has("position"):
		global_position = state["position"]
	if state.has("rotation"):
		head.rotation = state["rotation"]

	range_multiplier = float(state.get("range_multiplier", 1.0))
	angle_multiplier = float(state.get("angle_multiplier", 1.0))
	head_locked = bool(state.get("locked", false))
	_recalculate_stats()

func _recalculate_stats():
	detection_radius = base_detection_radius * range_multiplier
	attack_angle_deg = base_attack_angle_deg * angle_multiplier
	var circle: CircleShape2D = detection_shape.shape as CircleShape2D
	circle.radius = detection_radius
	queue_redraw()

func apply_watchtower_buff(range_mult: float, angle_mult: float):
	temp_range_multiplier = range_mult
	temp_angle_multiplier = angle_mult
	queue_redraw()

func clear_watchtower_buff():
	temp_range_multiplier = 1.0
	temp_angle_multiplier = 1.0
	queue_redraw()

func _process(delta):
	if show_preview:
		queue_redraw()
	if head_locked:
		_process_targeting()

func _process_targeting():
	if enemies_in_range.is_empty():
		target = null
		return
	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance > detection_radius:
			continue
		if _is_enemy_in_attack_cone(enemy):
			target = enemy
			return
	target = null

func _is_enemy_in_attack_cone(enemy: Node2D) -> bool:
	var to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
	var forward: Vector2 = Vector2.RIGHT.rotated(head.global_rotation)
	var angle_diff: float = rad_to_deg(acos(clamp(forward.dot(to_enemy), -1.0, 1.0)))
	return angle_diff <= attack_angle_deg / 2.0

func _fire():
	if target and head_locked:
		shoot()

func shoot():
	var bullet = BulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	var dir: Vector2 = Vector2.RIGHT.rotated(head.global_rotation)
	bullet.direction = dir
	bullet.rotation = dir.angle()

func _on_body_entered(body):
	if body.is_in_group("enemy"):
		enemies_in_range.append(body)

func _on_body_exited(body):
	enemies_in_range.erase(body)

func rotate_head_towards(global_mouse_pos: Vector2):
	if head_locked:
		return
	var dir: Vector2 = global_mouse_pos - global_position
	head.rotation = dir.angle()

func lock_head_rotation():
	head_locked = true
	show_preview = false
	queue_redraw()

func enable_preview():
	show_preview = true
	queue_redraw()

func _draw():
	if not show_preview:
		return
	var display_radius: float = detection_radius * temp_range_multiplier
	var display_angle: float = attack_angle_deg * temp_angle_multiplier
	draw_circle(Vector2.ZERO, display_radius, Color(0, 1, 0, 0.2))
	var half_angle: float = deg_to_rad(display_angle / 2.0)
	var forward_angle: float = head.global_rotation
	var points: Array[Vector2] = [Vector2.ZERO]
	var segments: int = 24
	for i in range(segments + 1):
		var t: float = float(i) / segments
		var angle: float = forward_angle - half_angle + (display_angle * t * PI / 180.0)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		points.append(dir * display_radius)
	draw_colored_polygon(points, Color(1, 0, 0, 0.25))
