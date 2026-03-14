extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var main_camera: Camera2D = $Camera2D
@onready var dash_cooldown: Timer = $"dash-cooldown"

signal carried_item_changed(is_carrying: bool)
signal active_talisman_changed(new_talisman)
signal active_talisman_activated(talisman)
signal active_talisman_deactivated(talisman)

const BASE_SPEED := 450.0
const IDLE_TIME_MIN := 1.0
const IDLE_TIME_MAX := 5.0
const BULLET_SCENE = preload("res://src/tscn/player_bullets.tscn")
const ITEM_SCENE_PATH := "res://src/tscn/talisman-pickup.tscn"
var ITEM_SCENE: PackedScene = null
const BASE_SHOT_COOLDOWN := 0.6

var speed_bonus := 0.0
var damage_bonus := 0.0
var attack_speed_bonus := 0.0
var attack_range_bonus := 0.0
var shot_speed_bonus := 0.0
var fatness_max_bonus := 0.0
var fatness_from_food_bonus := 0.0

var fatness: float = 0
var fatness_max: float = 100
const FAT_SPEED_PENALTY := 0.4

var items: Array[TalismanData] = []

var active_talisman: TalismanData = null
var active_talisman_is_triggered: bool = false
var active_talisman_time_left: float = 0.0
var active_talisman_cooldown_left: float = 0.0

enum PlayerState { MOVING, IDLE_STANDING, IDLE_PECKING }
var current_state: PlayerState = PlayerState.IDLE_STANDING

var direction := Vector2.ZERO
var last_direction := Vector2.DOWN
var idle_time := 0.0
var idle_rng := 0.0
var rng = RandomNumberGenerator.new()

var last_dir: Vector2 = Vector2.DOWN
var bomb_bullets_unlocked: bool = false
var cooldown: float = 0.0
var cooldown_multiplier: float = 1.0

var carried_item: Node = null

var angle_degrees := 0.0
var snapped_angle := 0

var dash_speed := BASE_SPEED + 1400.0
var dash_distance := 250.0
var is_dashing := false
var dash_direction := Vector2.ZERO
var dash_traveled := 0.0

var dash_stretch := 1.05
var dash_squash := 0.85
var dash_anim_speed := 2.5
var normal_anim_speed := 1.0

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
	if FileAccess.file_exists(ITEM_SCENE_PATH):
		ITEM_SCENE = load(ITEM_SCENE_PATH)
	else:
		ITEM_SCENE = null
		printerr("ITEM_SCENE_PATH not found. Update ITEM_SCENE_PATH to your item pickup scene to enable dropping active talismans.")
	_update_cooldown_multiplier()

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
	if Input.is_action_just_pressed("use_active"):
		_try_activate_active_talisman()
	if active_talisman_is_triggered:
		active_talisman_time_left -= delta
		if active_talisman_time_left <= 0.0:
			_deactivate_active_talisman()
	if active_talisman_cooldown_left > 0.0:
		active_talisman_cooldown_left -= delta
		if active_talisman_cooldown_left < 0.0:
			active_talisman_cooldown_left = 0.0

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
	var fat_ratio: float = fatness / (fatness_max + fatness_max_bonus)
	var speed_multiplier: float = 1.0 - (fat_ratio * FAT_SPEED_PENALTY)
	velocity = direction * (BASE_SPEED + speed_bonus) * speed_multiplier
	sprite.play("walking")
	last_dir = direction
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

func _start_dash():
	if is_dashing or not dash_cooldown.is_stopped():
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
	var dir: Vector2 = dash_direction.normalized()
	var stretch_x: float = lerp(dash_squash, dash_stretch, abs(dir.x))
	var stretch_y: float = lerp(dash_squash, dash_stretch, abs(dir.y))
	sprite.scale = Vector2(stretch_y, stretch_x)

func _handle_dash(delta):
	var move_amount: float = dash_speed * delta
	dash_traveled += move_amount
	velocity = dash_direction * dash_speed
	ghost_timer -= delta
	if ghost_timer <= 0.0:
		_spawn_ghost()
		ghost_timer = ghost_interval
	if dash_traveled >= dash_distance:
		_end_dash()

func _end_dash():
	is_dashing = false
	sprite.scale = Vector2.ONE
	sprite.speed_scale = normal_anim_speed

func _spawn_ghost():
	var ghost: Sprite2D = Sprite2D.new()
	var frame_texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.texture = frame_texture
	ghost.global_position = sprite.global_position
	ghost.rotation = sprite.rotation
	ghost.scale = sprite.scale / 2
	ghost.modulate = ghost_color
	get_tree().current_scene.add_child(ghost)
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, ghost_lifetime)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.9, ghost_lifetime)
	tween.tween_callback(ghost.queue_free)

func collect_talisman(data: TalismanData, from_load := false):
	if data.isActive:
		if active_talisman != null:
			if active_talisman_is_triggered:
				_deactivate_active_talisman()
			_drop_active_talisman_to_world(active_talisman)
			items.erase(active_talisman)
		active_talisman = data
		active_talisman_cooldown_left = 0.0
		emit_signal("active_talisman_changed", active_talisman)
	else:
		speed_bonus += data.speed_bonus
		damage_bonus += data.damage_bonus
		attack_speed_bonus += data.attack_speed_bonus
		attack_range_bonus += data.attack_range_bonus
		shot_speed_bonus += data.shot_speed_bonus
		fatness_max_bonus += data.fatness_max_bonus
		fatness_from_food_bonus += data.fatness_from_food_bonus
	items.append(data)
	_update_cooldown_multiplier()
	if not from_load and GameLoad.current_run:
		GameLoad.current_run.talismans.append(data)
		GameLoad.save_run()
	print("Collected talisman:", data.talisman_name)

func _handle_pickup():
	if not Input.is_action_just_pressed("pick_up"):
		return
	if carried_item:
		carried_item.drop()
		for nest in get_tree().get_nodes_in_group("nest"):
			nest.try_deposit(carried_item)
		carried_item = null
		emit_signal("carried_item_changed", false)
	else:
		for item in get_tree().get_nodes_in_group("item"):
			if item.in_range and not item.carried:
				item.pick_up(self)
				carried_item = item
				emit_signal("carried_item_changed", true)
				break

func _try_activate_active_talisman():
	if active_talisman == null:
		return
	if active_talisman_is_triggered:
		return
	if active_talisman_cooldown_left > 0.0:
		print("Active talisman on cooldown (%.2f s left)" % active_talisman_cooldown_left)
		return
	_activate_active_talisman(active_talisman)

func _activate_active_talisman(talisman: TalismanData):
	if talisman == null:
		return
	_apply_active_bonuses(talisman)
	active_talisman_is_triggered = true
	active_talisman_time_left = talisman.active_duration
	active_talisman_cooldown_left = talisman.active_cooldown
	emit_signal("active_talisman_activated", talisman)
	print("Activated talisman:", talisman.talisman_name, "for", talisman.active_duration, "s (cooldown:", talisman.active_cooldown, "s)")

func _deactivate_active_talisman():
	if active_talisman == null:
		active_talisman_is_triggered = false
		active_talisman_time_left = 0.0
		return
	_remove_active_bonuses(active_talisman)
	emit_signal("active_talisman_deactivated", active_talisman)
	print("Deactivated talisman:", active_talisman.talisman_name)
	active_talisman_is_triggered = false
	active_talisman_time_left = 0.0

func _apply_active_bonuses(talisman: TalismanData):
	speed_bonus += talisman.speed_bonus
	damage_bonus += talisman.damage_bonus
	attack_speed_bonus += talisman.attack_speed_bonus
	attack_range_bonus += talisman.attack_range_bonus
	shot_speed_bonus += talisman.shot_speed_bonus
	fatness_max_bonus += talisman.fatness_max_bonus
	fatness_from_food_bonus += talisman.fatness_from_food_bonus
	_update_cooldown_multiplier()

func _remove_active_bonuses(talisman: TalismanData):
	speed_bonus -= talisman.speed_bonus
	damage_bonus -= talisman.damage_bonus
	attack_speed_bonus -= talisman.attack_speed_bonus
	attack_range_bonus -= talisman.attack_range_bonus
	shot_speed_bonus -= talisman.shot_speed_bonus
	fatness_max_bonus -= talisman.fatness_max_bonus
	fatness_from_food_bonus -= talisman.fatness_from_food_bonus
	_update_cooldown_multiplier()

func _drop_active_talisman_to_world(talisman: TalismanData):
	if ITEM_SCENE == null:
		printerr("Cannot drop active talisman to world: ITEM_SCENE not configured (ITEM_SCENE_PATH).")
		return
	var dropped = ITEM_SCENE.instantiate()
	if dropped.has_variable("talisman_data"):
		dropped.talisman_data = talisman
	elif dropped.has_method("set_talisman_data"):
		dropped.call("set_talisman_data", talisman)
	else:
		dropped.set_meta("talisman_data", talisman)
	if dropped is Node2D:
		dropped.global_position = global_position + Vector2(0, 16)
	get_tree().current_scene.add_child(dropped)
	dropped.add_to_group("item")

func _handle_shooting():
	if Input.is_action_pressed("shoot") and cooldown <= 0:
		cooldown = BASE_SHOT_COOLDOWN * cooldown_multiplier
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

func _update_cooldown_multiplier():
	var old_multiplier: float = cooldown_multiplier
	var denom: float = 1.0 + attack_speed_bonus
	if denom <= 0.01:
		denom = 0.01
	var new_multiplier: float = clamp(1.0 / denom, 0.02, 10.0)
	if old_multiplier > 0.0:
		cooldown = cooldown * (new_multiplier / old_multiplier)
	cooldown_multiplier = new_multiplier
