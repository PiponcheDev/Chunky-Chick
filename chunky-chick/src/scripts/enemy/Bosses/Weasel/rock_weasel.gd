extends CharacterBody2D

@onready var sprite: Sprite2D = $Icon

@export var speed: float = 900.0
@export var lifetime: float = 1.2
@export var damage: int = 10

@export var moss_spin_min: float = 6.0
@export var moss_spin_max: float = 10.0
@export var clean_spin_min: float = 1.0
@export var clean_spin_max: float = 3.0

var life_timer: float = 0.0
var spin: float = 0.0

var _rng := RandomNumberGenerator.new()
var target: Node2D = null


func _ready() -> void:
	_rng.randomize()
	target = get_tree().get_first_node_in_group("player")


func launch(dir: Vector2) -> void:
	velocity = dir.normalized() * speed
	life_timer = lifetime
	rotation = dir.angle()

	_pick_random_frame()

	var mossy := _is_mossy_frame()
	if mossy:
		spin = _rng.randf_range(moss_spin_min, moss_spin_max) * _rand_sign()
	else:
		spin = _rng.randf_range(clean_spin_min, clean_spin_max) * _rand_sign()


func _physics_process(delta: float) -> void:
	if life_timer > 0.0:
		life_timer -= delta
		if life_timer <= 0.0:
			queue_free()
			return

	rotation += spin * delta
	move_and_slide()
	_try_damage_player()


func _try_damage_player() -> void:
	if target == null:
		target = get_tree().get_first_node_in_group("player")
	if target == null:
		return

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue

		var collider := collision.get_collider()
		if collider == null or collider == self:
			continue

		if collider == target or collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(damage)
			elif collider.has_method("apply_damage"):
				collider.apply_damage(damage)

			queue_free()
			return


func _pick_random_frame() -> void:
	if sprite.hframes > 1 or sprite.vframes > 1:
		var total_frames = sprite.hframes * sprite.vframes
		sprite.frame = _rng.randi_range(0, total_frames - 1)


func _is_mossy_frame() -> bool:
	var total_frames = sprite.hframes * sprite.vframes
	if total_frames <= 1:
		return false
	return sprite.frame < total_frames / 2


func _rand_sign() -> float:
	return -1.0 if _rng.randf() < 0.5 else 1.0
