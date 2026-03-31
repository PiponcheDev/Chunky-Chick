extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var main_camera: Camera2D = $Camera2D
@onready var dash_cooldown: Timer = $"dash-cooldown"
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D

signal carried_item_changed(is_carrying: bool)
signal active_talisman_changed(new_talisman)
signal active_talisman_activated(talisman)
signal active_talisman_deactivated(talisman)
signal talisman_collected(talisman)

const AUDIO_SHOOT: AudioStream = preload("res://Assets/Audio/player/fart7.ogg")
const AUDIO_STEP: AudioStream = preload("res://Assets/Audio/player/step.ogg")
const BASE_SPEED := 450.0
const ITEM_SCENE_PATH := "res://src/tscn/talisman-pickup.tscn"
const MAIN_MENU_SCENE_PATH := "res://src/tscn/Main Menu/MainMenu.tscn"
var ITEM_SCENE: PackedScene = null
const BASE_SHOT_COOLDOWN := 0.6
const BULLET_SCENE = preload("res://src/tscn/Player-Bullets.tscn")
const DAMAGE := 25
const STEP_INTERVAL := 1.0 / 3.0

const HIT_INVULN_DURATION := 0.5
const HIT_SPEED_MULT := 1.35
const HIT_ANIM_SPEED_MULT := 1.5
const HIT_FLASH_DURATION := 0.10

const DEATH_FADE_TIME := 1.5
const DEATH_FADE_LAYER := 10

var compass_arrow: Polygon2D
var is_invulnerable: bool = false
var invuln_timer: float = 0.0
var _default_sprite_modulate: Color = Color.WHITE
var _hit_flash_tween: Tween = null

var is_dead: bool = false
var death_sequence_started: bool = false
var fade_layer: CanvasLayer = null
var fade_rect: ColorRect = null

var speed_bonus := 0.0
var damage_bonus := 0.0
var attack_speed_bonus := 0.0
var attack_range_bonus := 0.0
var shot_speed_bonus := 0.0
var fatness_max_bonus := 0.0
var fatness_from_food_bonus := 0.0

var fatness: float = 0.0
var fatness_max: float = 100.0
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
var step_timer: float = 0.0

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

func _ready():
	main_camera.add_to_group("main_camera")
	add_to_group("player")
	rng.randomize()
	sprite.animation_finished.connect(_on_animation_finished)
	_default_sprite_modulate = sprite.modulate
	_setup_compass_arrow()

	_create_fade_layer()

	if FileAccess.file_exists(ITEM_SCENE_PATH):
		ITEM_SCENE = load(ITEM_SCENE_PATH)
	else:
		ITEM_SCENE = null
		printerr("ITEM_SCENE_PATH not found.")

	if GameLoad != null and GameLoad.current_run != null:
		apply_run_data(GameLoad.current_run)

	_update_cooldown_multiplier()
	_update_animation_state()
	_update_sprite_speed_scale()

func _create_fade_layer() -> void:
	if fade_layer != null and is_instance_valid(fade_layer):
		return

	fade_layer = CanvasLayer.new()
	fade_layer.name = "DeathFadeLayer"
	fade_layer.layer = 128

	get_tree().root.add_child.call_deferred(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.name = "DeathFadeRect"
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.size = get_viewport().get_visible_rect().size

	fade_layer.add_child(fade_rect)

func capture_into_run_data(run: RunData) -> void:
	if run == null:
		return

	run.player_items = items.duplicate(true)
	run.player_stats = {
		"speed_bonus": speed_bonus,
		"damage_bonus": damage_bonus,
		"attack_speed_bonus": attack_speed_bonus,
		"attack_range_bonus": attack_range_bonus,
		"shot_speed_bonus": shot_speed_bonus,
		"fatness_max_bonus": fatness_max_bonus,
		"fatness_from_food_bonus": fatness_from_food_bonus,
		"fatness": fatness,
		"fatness_max": fatness_max
	}

func _setup_compass_arrow():
	compass_arrow = Polygon2D.new()
	compass_arrow.polygon = PackedVector2Array([
		Vector2(25, 0),   
		Vector2(-10, -10), 
		Vector2(-10, 10)   
	])
	
	compass_arrow.color = Color.YELLOW
	
	compass_arrow.position = Vector2(0, -110) 
	
	add_child(compass_arrow)

func apply_run_data(run: RunData) -> void:
	if run == null:
		return

	_reset_persisted_stats()
	items.clear()
	active_talisman = null
	active_talisman_is_triggered = false
	active_talisman_time_left = 0.0
	active_talisman_cooldown_left = 0.0

	var stats: Dictionary = run.player_stats
	speed_bonus = float(stats.get("speed_bonus", 0.0))
	damage_bonus = float(stats.get("damage_bonus", 0.0))
	attack_speed_bonus = float(stats.get("attack_speed_bonus", 0.0))
	attack_range_bonus = float(stats.get("attack_range_bonus", 0.0))
	shot_speed_bonus = float(stats.get("shot_speed_bonus", 0.0))
	fatness_max_bonus = float(stats.get("fatness_max_bonus", 0.0))
	fatness_from_food_bonus = float(stats.get("fatness_from_food_bonus", 0.0))
	fatness = float(stats.get("fatness", fatness))
	fatness_max = float(stats.get("fatness_max", fatness_max))

	for talisman in run.player_items:
		collect_talisman(talisman, true)

	_update_cooldown_multiplier()
	_update_animation_state()
	_update_sprite_speed_scale()

func _reset_persisted_stats() -> void:
	speed_bonus = 0.0
	damage_bonus = 0.0
	attack_speed_bonus = 0.0
	attack_range_bonus = 0.0
	shot_speed_bonus = 0.0
	fatness_max_bonus = 0.0
	fatness_from_food_bonus = 0.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_update_compass_logic()
	_update_hit_reaction(delta)

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

	_update_sprite_speed_scale()

func _update_compass_logic():
	if not compass_arrow: return
	
	var nest_node = get_tree().get_first_node_in_group("nest")
	
	if nest_node and is_instance_valid(nest_node):
		compass_arrow.visible = true
		
		var target_pos = nest_node.global_position
		
		compass_arrow.global_rotation = global_position.angle_to_point(target_pos)
	else:
		compass_arrow.visible = false

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
	var speed := (BASE_SPEED + speed_bonus) * _get_fat_speed_multiplier()
	if is_invulnerable:
		speed *= HIT_SPEED_MULT
	return speed

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
	
	if hitbox:
		hitbox.rotation_degrees = snapped_angle

func _start_dash():
	if is_dashing or not dash_cooldown.is_stopped():
		return
	is_dashing = true
	dash_traveled = 0.0
	ghost_timer = 0.0
	dash_cooldown.start()
	dash_direction = (direction if direction != Vector2.ZERO else last_direction).normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2.DOWN
	sprite.play("walking")
	_apply_dash_stretch()
	_update_sprite_speed_scale()

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
	_sync_animation_after_dash()
	_update_sprite_speed_scale()

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

func _update_sprite_speed_scale() -> void:
	var reaction_mult := HIT_ANIM_SPEED_MULT if is_invulnerable else 1.0
	if is_dashing:
		sprite.speed_scale = dash_anim_speed * reaction_mult
	elif sprite.animation == "attack" and sprite.is_playing():
		sprite.speed_scale = normal_anim_speed * reaction_mult
	else:
		sprite.speed_scale = normal_anim_speed * reaction_mult

func _play_attack_animation():
	sprite.play("attack")
	_update_sprite_speed_scale()

func _spawn_ghost():
	var ghost: Sprite2D = Sprite2D.new()
	var frame_texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.texture = frame_texture
	ghost.global_position = sprite.global_position
	ghost.rotation = sprite.rotation
	ghost.scale = sprite.scale
	ghost.modulate = ghost_color
	get_tree().current_scene.add_child(ghost)
	var tween: Tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, ghost_lifetime)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.9, ghost_lifetime)
	tween.tween_callback(ghost.queue_free)

func _start_hit_reaction() -> void:
	is_invulnerable = true
	invuln_timer = HIT_INVULN_DURATION

	if _hit_flash_tween and is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()

	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(sprite, "modulate", _default_sprite_modulate, HIT_FLASH_DURATION)

	_update_sprite_speed_scale()

func _update_hit_reaction(delta: float) -> void:
	if not is_invulnerable:
		return

	invuln_timer -= delta
	if invuln_timer <= 0.0:
		invuln_timer = 0.0
		is_invulnerable = false
		sprite.modulate = _default_sprite_modulate
		_update_sprite_speed_scale()

func collect_talisman(data: TalismanData, from_load := false):
	if data == null:
		return

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

	if not from_load:
		emit_signal("talisman_collected", data)

	print("Collected talisman:", data.talisman_name)

func _handle_pickup():
	if not Input.is_action_just_pressed("pick_up"):
		return

	if carried_item:
		carried_item.drop()
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
	if Input.is_action_pressed("shoot") and cooldown <= 0.0:
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
	if dash_cooldown.wait_time <= 0.0:
		return 1.0
	if dash_cooldown.is_stopped():
		return 1.0
	return 1.0 - (dash_cooldown.time_left / dash_cooldown.wait_time)

<<<<<<< HEAD
func eat_food(amount: float) -> void:
	var bonus := 1.0 * fatness_from_food_bonus
	fatness = min(fatness + (amount * bonus) + amount, fatness_max + fatness_max_bonus)
=======
func eat_food(amount: float) -> bool:
	var max_value := fatness_max + fatness_max_bonus
	if fatness >= max_value:
		return false

	var bonus := 1.0 + fatness_from_food_bonus
	fatness = min(fatness + (amount * bonus), max_value)
	return true
>>>>>>> origin/main

func take_damage(amount: int) -> void:
	if is_dead:
		return
	if is_invulnerable:
		return

	fatness = max(fatness - amount, 0.0)
	_start_hit_reaction()

	if fatness <= 0.0:
		_start_death_sequence()

func _start_death_sequence() -> void:
	if death_sequence_started:
		return

	death_sequence_started = true
	is_dead = true
	is_invulnerable = true
	velocity = Vector2.ZERO
	direction = Vector2.ZERO
	last_direction = Vector2.ZERO
	dash_direction = Vector2.ZERO
	is_dashing = false
	cooldown = 0.0
	ghost_timer = 0.0
	step_timer = 0.0

	if dash_cooldown:
		dash_cooldown.stop()

	if sprite:
		sprite.speed_scale = 0.0

	if fade_rect == null or fade_layer == null:
		_create_fade_layer()

	call_deferred("_run_death_sequence")

func _run_death_sequence() -> void:
	GameLoad.destroy_save_file()

	if fade_rect == null:
		return

	fade_rect.visible = true
	fade_rect.color = Color(0, 0, 0, 0)

	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, DEATH_FADE_TIME)
	await fade_tween.finished

	if fade_layer and is_instance_valid(fade_layer):
		fade_layer.queue_free()
		fade_layer = null
		fade_rect = null

	await get_tree().process_frame

	if ResourceLoader.exists(MAIN_MENU_SCENE_PATH):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	else:
		push_error("Main menu scene not found: " + MAIN_MENU_SCENE_PATH)

func get_current_health() -> float:
	return fatness

func get_health_ratio() -> float:
	var max_value := fatness_max + fatness_max_bonus
	if max_value <= 0.01:
		return 0.0
	return fatness / max_value
