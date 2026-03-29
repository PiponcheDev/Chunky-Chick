extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var main_camera: Camera2D = $Camera2D
@onready var dash_cooldown: Timer = $"dash-cooldown"
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

signal carried_item_changed(is_carrying: bool)
signal active_talisman_changed(new_talisman)
signal active_talisman_activated(talisman)
signal active_talisman_deactivated(talisman)

const AUDIO_SHOOT: AudioStream = preload("res://Assets/Audio/player/fart7.ogg")
const AUDIO_STEP: AudioStream = preload("res://Assets/Audio/player/step.ogg")

const BASE_SPEED := 450.0
const ITEM_SCENE_PATH := "res://src/tscn/talisman-pickup.tscn"
var ITEM_SCENE: PackedScene = null
const BASE_SHOT_COOLDOWN := 0.6
const BULLET_SCENE = preload("res://src/tscn/Player-Bullets.tscn")
const DAMAGE := 25
const STEP_INTERVAL := 1.0 / 3.0
var health := 150

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

var direction := Vector2.ZERO
var last_direction := Vector2.DOWN
var rng = RandomNumberGenerator.new()

var last_dir: Vector2 = Vector2.DOWN
var bomb_bullets_unlocked: bool = false
var cooldown: float = 0.0
var cooldown_multiplier: float = 1.0

var carried_item: Node = null

var angle_degrees := 0.0
var snapped_angle := 0

var dash_distance := 250.0
var dash_speed_bonus := 1400.0
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

var step_timer := 0.0

func _ready():
	main_camera.add_to_group("main_camera")
	add_to_group("player")
	rng.randomize()
	sprite.animation_finished.connect(_on_animation_finished)
	if FileAccess.file_exists(ITEM_SCENE_PATH):
		ITEM_SCENE = load(ITEM_SCENE_PATH)
	else:
		ITEM_SCENE = null
		printerr("ITEM_SCENE_PATH not found. Update ITEM_SCENE_PATH to your item pickup scene to enable dropping active talismans.")
	_update_cooldown_multiplier()
	_update_animation_state()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("dash"):
		_start_dash()
	direction = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down").normalized()
	if direction != Vector2.ZERO:
		last_direction = direction
	cooldown -= delta
	if is_dashing:
		_handle_dash(delta)
	else:
		_handle_normal_state()
	_update_step_sounds(delta)
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

func _handle_normal_state():
	if direction != Vector2.ZERO:
		_handle_moving()
	else:
		_handle_stationary()

func _get_fat_speed_multiplier() -> float:
	var denom: float = fatness_max + fatness_max_bonus
	if denom <= 0.01:
		denom = 0.01
	var fat_ratio: float = fatness / denom
	return 1.0 - (fat_ratio * FAT_SPEED_PENALTY)

func _get_move_speed() -> float:
	return (BASE_SPEED + speed_bonus) * _get_fat_speed_multiplier()

func _get_dash_speed() -> float:
	return _get_move_speed() + dash_speed_bonus

func _handle_moving():
	velocity = direction * _get_move_speed()
	last_dir = direction
	_update_rotation(direction)
	if sprite.animation == "attack" and sprite.is_playing():
		return
	sprite.play("walking")

func _handle_stationary():
	velocity = Vector2.ZERO
	_update_animation_state()

func _update_rotation(dir: Vector2):
	angle_degrees = rad_to_deg(dir.angle())
	snapped_angle = round(angle_degrees / 45) * 45 + 90
	sprite.rotation_degrees = snapped_angle

func _start_dash():
	if is_dashing or not dash_cooldown.is_stopped():
		return
	is_dashing = true
	dash_traveled = 0
	ghost_timer = 0
	dash_cooldown.start()
	dash_direction = (direction if direction != Vector2.ZERO else last_direction).normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.DOWN
	sprite.play("walking")
	sprite.speed_scale = dash_anim_speed
	_apply_dash_stretch()

func _apply_dash_stretch():
	var dir: Vector2 = dash_direction.normalized()
	var stretch_x: float = lerp(dash_squash, dash_stretch, abs(dir.x))
	var stretch_y: float = lerp(dash_squash, dash_stretch, abs(dir.y))
	sprite.scale = Vector2(stretch_y, stretch_x)

func _handle_dash(delta):
	var current_dash_speed: float = _get_dash_speed()
	dash_traveled += current_dash_speed * delta
	velocity = dash_direction * current_dash_speed
	ghost_timer -= delta
	if ghost_timer <= 0.0:
		_spawn_ghost()
		ghost_timer = ghost_interval
	if dash_traveled >= dash_distance:
		_end_dash()

func _end_dash():
	is_dashing = false
	velocity = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.speed_scale = normal_anim_speed
	_sync_animation_after_dash()

func _sync_animation_after_dash():
	_update_animation_state()

func _update_animation_state():
	if sprite.animation == "attack" and sprite.is_playing():
		return
	if direction != Vector2.ZERO:
		sprite.play("walking")
	else:
		sprite.play("walking")
		sprite.frame = 0
		sprite.stop()

func _play_attack_animation():
	sprite.play("attack")

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
	active_talisman_cooldown_left = 0.0
	emit_signal("active_talisman_activated", talisman)
	print("Activated talisman:", talisman.talisman_name, "for", talisman.active_duration, "s")

func _deactivate_active_talisman():
	if active_talisman == null:
		active_talisman_is_triggered = false
		active_talisman_time_left = 0.0
		active_talisman_cooldown_left = 0.0
		return
	_remove_active_bonuses(active_talisman)
	active_talisman_is_triggered = false
	active_talisman_time_left = 0.0
	active_talisman_cooldown_left = active_talisman.active_cooldown
	emit_signal("active_talisman_deactivated", active_talisman)
	print("Deactivated talisman:", active_talisman.talisman_name, "cooldown started:", active_talisman.active_cooldown, "s")

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
		_play_attack_animation()
		_play_shoot_sound()
		var bullet = BULLET_SCENE.instantiate()
		bullet.shooter = self
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position
		bullet.start_pos = global_position
		bullet.direction = -last_dir
		bullet.damage = DAMAGE
		bullet.bullet_freed.connect(_on_bullet_freed)

func _play_shoot_sound():
	audio_player.stream = AUDIO_SHOOT
	audio_player.play()

func _play_step_sound():
	audio_player.stream = AUDIO_STEP
	audio_player.play()

func _update_step_sounds(delta: float) -> void:
	if is_dashing or direction == Vector2.ZERO:
		step_timer = 0.0
		return
	step_timer += delta
	while step_timer >= STEP_INTERVAL:
		step_timer -= STEP_INTERVAL
		_play_step_sound()

func _on_animation_finished():
	if sprite.animation == "attack":
		_update_animation_state()

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

func get_dash_cooldown_ratio() -> float:
	if dash_cooldown.wait_time <= 0:
		return 1.0
	if dash_cooldown.is_stopped():
		return 1.0
	return 1.0 - (dash_cooldown.time_left / dash_cooldown.wait_time)

func eat_food(amount: float) -> void:
	var bonus := 1.0 + fatness_from_food_bonus
	fatness += amount * bonus
	var max_fat := fatness_max + fatness_max_bonus
	if fatness > max_fat:
		fatness = max_fat

func take_damage(amount: int) -> void:
	health = max(health - amount, 0)
	if health == 0:
		queue_free()
