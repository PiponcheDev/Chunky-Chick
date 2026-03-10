extends CharacterBody2D

enum BossState {
	ORBIT,
	DASH_LOCK,
	DASH_COIL,
	DASH_EXEC,
	STUNNED,
	SPIT_WINDUP,
	SPIT_RECOVER,
	DEAD
}

var state: BossState = BossState.ORBIT
@onready var sprite: Node2D = $Icon
@onready var nav: NavigationAgent2D = $NavigationAgent2D

var hp: int = 220
@export var move_speed: float = 220.0
@export var orbit_radius_inner: float = 350.0
@export var orbit_radius_outer: float = 600.0
var orbit_radius: float = orbit_radius_outer
var orbit_angle: float = 0.0
var orbit_dir: int = 1
var orbit_arc_remaining: float = 0.0
var inward_timer: float = 0.0
@export var orbit_noise_amplitude: float = 0.18
@export var orbit_noise_speed: float = 1.3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _orbit_noise_time: float = 0.0

@export var dash_speed: float = 900.0
var dash_vector: Vector2 = Vector2.ZERO
var dash_count: int = 0
var dash_cooldown: float = 0.0
var dash_stage: int = 0
var _did_hit_player: bool = false

const DASH_LOCK_DUR: float = 0.15
const DASH_COIL_DUR: float = 0.25
const DASH_MIN_EXEC: float = 0.4
const DASH_MAX_EXEC: float = 0.5
const DASH_POST_MICRO: float = 0.3
const DASH_COOLDOWN: float = 1.0

const DASH_TRIGGER_RANGE: float = 200.0
const DASH_CHAIN_DISTANCE: float = 100.0
const DASH_HIT_RADIUS: float = 28.0
const DASH_PLAYER_DAMAGE: int = 80

var _coil_total: float = DASH_COIL_DUR
var _coil_elapsed: float = 0.0

@export var spit_scene_path: String = "res://src/tscn/enemy/Bosses/Weasel/spit_weasel.tscn"
@export var rock_scene_path: String = "res://src/tscn/enemy/Bosses/Weasel/rock_weasel.tscn"
var _spit_scene: PackedScene = null
var _rock_scene: PackedScene = null

var spit_cooldown: float = 0.0
const SPIT_COOLDOWN: float = 6.0
const SPIT_WINDUP: float = 0.4
const SPIT_RECOVER: float = 0.6

const PEBBLE_SPEED: float = 350.0
const PEBBLE_LIFETIME: float = 3.0
const PEBBLE_RADIUS: float = 8.0
var _pebbles: Array = []

const SLIP_RADIUS: float = 50.0
const SLIP_DURATION: float = 1.2

var player: Node2D = null
var state_timer: float = 0.0
var desired_velocity: Vector2 = Vector2.ZERO

var _player_last_pos: Vector2 = Vector2.ZERO
var _player_velocity: Vector2 = Vector2.ZERO
var _player_speed: float = 0.0
const PLAYER_STATIONARY_THRESHOLD: float = 20.0

var _allow_orbit_change: bool = true

@export var steer_smooth: float = 6.0

var _prev_global_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_rng.randomize()
	player = get_tree().get_first_node_in_group("player")
	_player_last_pos = player.global_position if player else global_position
	_load_projectile_scenes()
	choose_orbit()
	_allow_orbit_change = false
	_prev_global_pos = global_position

func _load_projectile_scenes() -> void:
	if spit_scene_path != "":
		var r = load(spit_scene_path)
		if r and r is PackedScene:
			_spit_scene = r
	if rock_scene_path != "":
		var r = load(rock_scene_path)
		if r and r is PackedScene:
			_rock_scene = r

func _physics_process(delta: float) -> void:
	if state == BossState.DEAD:
		return
	state_timer = max(state_timer - delta, 0.0)
	inward_timer = max(inward_timer - delta, 0.0)
	dash_cooldown = max(dash_cooldown - delta, 0.0)
	spit_cooldown = max(spit_cooldown - delta, 0.0)
	_orbit_noise_time += delta
	_update_pebbles(delta)
	_update_player_speed(delta)
	var current_pos: Vector2 = global_position
	match state:
		BossState.ORBIT:
			_orbit_logic(delta)
			_attack_decision()
		BossState.DASH_LOCK:
			if state_timer <= 0.0:
				enter_dash_coil()
		BossState.DASH_COIL:
			_process_coil(delta)
			if state_timer <= 0.0:
				enter_dash_exec()
		BossState.DASH_EXEC:
			_check_dash_hit_segment(delta, current_pos)
			if state_timer <= 0.0:
				_enter_post_dash()
		BossState.STUNNED:
			desired_velocity = Vector2.ZERO
			if state_timer <= 0.0:
				enter_orbit()
		BossState.SPIT_WINDUP:
			desired_velocity = Vector2.ZERO
			if state_timer <= 0.0:
				_fire_ranged()
		BossState.SPIT_RECOVER:
			desired_velocity = Vector2.ZERO
			if state_timer <= 0.0:
				enter_orbit()
		BossState.DEAD:
			desired_velocity = Vector2.ZERO
	if state == BossState.DASH_EXEC:
		velocity = dash_vector * dash_speed
	else:
		velocity = velocity.lerp(desired_velocity, clamp(steer_smooth * delta, 0.0, 1.0))
	move_and_slide()
	_prev_global_pos = current_pos
	if sprite and player:
		sprite.rotation = (player.global_position - global_position).angle()

func _update_player_speed(delta: float) -> void:
	if player == null:
		_player_velocity = Vector2.ZERO
		_player_speed = 0.0
		return
	var vel: Vector2 = (player.global_position - _player_last_pos) / max(delta, 0.0001)
	_player_velocity = vel
	_player_speed = vel.length()
	_player_last_pos = player.global_position

func _orbit_logic(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			desired_velocity = Vector2.ZERO
			return
	var base_angular: float = orbit_dir * move_speed / max(orbit_radius, 1.0)
	var noise: float = sin(_orbit_noise_time * orbit_noise_speed) * orbit_noise_amplitude
	orbit_angle += (base_angular + noise) * delta
	orbit_arc_remaining -= abs(move_speed * delta)
	if orbit_arc_remaining <= 0.0:
		if _allow_orbit_change:
			choose_orbit()
			_allow_orbit_change = false
		else:
			orbit_arc_remaining = 5.0
	if inward_timer <= 0.0:
		inward_timer = _rng.randf_range(3.0, 5.0)
		orbit_radius = lerp(orbit_radius, orbit_radius_inner, 0.6)
	var orbit_target: Vector2 = player.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	var perp: Vector2 = Vector2(-sin(orbit_angle), cos(orbit_angle))
	orbit_target += perp * _rng.randf_range(-6.0, 6.0)
	desired_velocity = (orbit_target - global_position).normalized() * move_speed

func choose_orbit() -> void:
	if _rng.randf() < 0.6:
		orbit_radius = orbit_radius_inner
	else:
		orbit_radius = orbit_radius_outer
	var arc_deg: float = _rng.randf_range(90.0, 160.0)
	orbit_arc_remaining = deg_to_rad(arc_deg) * orbit_radius
	orbit_dir = (-1 if _rng.randi_range(0, 1) == 0 else 1)

func _attack_decision() -> void:
	if player == null:
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist < DASH_TRIGGER_RANGE and dash_cooldown <= 0.0:
		start_double_dash()
		return
	if _player_speed <= PLAYER_STATIONARY_THRESHOLD and dist < 420.0 and dash_cooldown <= 0.0:
		start_double_dash()
		return
	if state == BossState.ORBIT and dist > 420.0 and spit_cooldown <= 0.0:
		if _rng.randf() < 0.18:
			enter_spit()

func enter_dash_lock(force: bool = false) -> void:
	if not force and state != BossState.ORBIT:
		return
	state = BossState.DASH_LOCK
	state_timer = DASH_LOCK_DUR
	desired_velocity = Vector2.ZERO
	if player:
		var dist: float = global_position.distance_to(player.global_position)
		var lead_time: float = clamp(dist / max(dash_speed, 1.0), 0.08, 0.6)
		var predicted: Vector2 = player.global_position + _player_velocity * lead_time
		var raw: Vector2 = predicted - global_position
		if raw.length() < 0.0001:
			raw = player.global_position - global_position
		if raw.length() < 0.0001:
			raw = Vector2.RIGHT
		dash_vector = raw.normalized()
	else:
		dash_vector = Vector2.RIGHT
	_coil_elapsed = 0.0
	_coil_total = DASH_COIL_DUR
	_did_hit_player = false
	if sprite:
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE

func enter_dash_coil() -> void:
	state = BossState.DASH_COIL
	state_timer = DASH_COIL_DUR
	_coil_elapsed = 0.0
	desired_velocity = Vector2.ZERO

func _process_coil(delta: float) -> void:
	_coil_elapsed += delta
	var t: float = clamp(_coil_elapsed / _coil_total, 0.0, 1.0)
	var smooth: float = t * t * (3.0 - 2.0 * t)
	var s: float = sin(smooth * PI)
	var amplitude: float = 0.42
	if sprite:
		var back_offset: Vector2 = -dash_vector * (12.0 * s)
		sprite.position = back_offset
		var xscale: float = lerp(1.0, 1.0 + amplitude, s)
		var yscale: float = lerp(1.0, 1.0 - amplitude, s)
		sprite.scale = Vector2(xscale, yscale)

func enter_dash_exec() -> void:
	state = BossState.DASH_EXEC
	if dash_stage == 0:
		state_timer = 0.35
	else:
		state_timer = 0.45
	if sprite:
		sprite.scale = Vector2.ONE

func start_double_dash() -> void:
	dash_stage = 0
	enter_dash_lock(false)

func _segment_point_distance(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = 0.0
	var denom: float = ab.length_squared()
	if denom > 0.0:
		t = clamp(((p - a).dot(ab)) / denom, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)

func _check_dash_hit_segment(delta: float, current_pos: Vector2) -> void:
	if player == null:
		return
	if _did_hit_player:
		return
	var next_pos: Vector2 = current_pos + dash_vector * dash_speed * delta
	var dist_to_segment: float = _segment_point_distance(current_pos, next_pos, player.global_position)
	if dist_to_segment <= DASH_HIT_RADIUS:
		_did_hit_player = true
		if player.has_method("apply_damage"):
			player.apply_damage(DASH_PLAYER_DAMAGE)
		state_timer = 0.0

func _enter_post_dash() -> void:
	if dash_stage == 0 and (_did_hit_player or (player and global_position.distance_to(player.global_position) <= DASH_CHAIN_DISTANCE)):
		dash_stage = 1
		enter_dash_lock(true)
		return
	dash_count += 1
	dash_cooldown = DASH_COOLDOWN
	dash_stage = 0
	_did_hit_player = false
	_allow_orbit_change = true
	choose_orbit()
	_allow_orbit_change = false
	enter_orbit()

func enter_orbit() -> void:
	state = BossState.ORBIT
	state_timer = 0.0
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.position = Vector2.ZERO

func enter_spit() -> void:
	if state != BossState.ORBIT:
		return
	state = BossState.SPIT_WINDUP
	state_timer = SPIT_WINDUP
	desired_velocity = Vector2.ZERO

func _fire_ranged() -> void:
	if _spit_scene != null:
		_fire_spit_scene()
	elif _rock_scene != null:
		_fire_rock_scene()
	else:
		_spawn_pebble("spit")
	spit_cooldown = SPIT_COOLDOWN
	state = BossState.SPIT_RECOVER
	state_timer = SPIT_RECOVER

func _predict_player_pos_for_projectile(proj_speed: float) -> Vector2:
	if player == null:
		return global_position + Vector2.RIGHT
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var lead: float = clamp(dist / max(proj_speed, 1.0), 0.05, 1.0)
	return player.global_position + _player_velocity * lead

func _fire_spit_scene() -> void:
	var inst = _spit_scene.instantiate()
	get_tree().get_current_scene().add_child(inst)
	inst.global_position = global_position
	var forward: Vector2 = _predict_player_pos_for_projectile(PEBBLE_SPEED) - global_position
	forward = forward.normalized().rotated(_rng.randf_range(-0.18, 0.18))
	if inst.has_method("launch"):
		inst.launch(forward)
	elif inst.has_variable("velocity"):
		inst.velocity = forward * PEBBLE_SPEED

func _fire_rock_scene() -> void:
	var inst = _rock_scene.instantiate()
	get_tree().get_current_scene().add_child(inst)
	inst.global_position = global_position
	var forward: Vector2 = _predict_player_pos_for_projectile(PEBBLE_SPEED) - global_position
	forward = forward.normalized().rotated(_rng.randf_range(-0.22, 0.22))
	if inst.has_method("launch"):
		inst.launch(forward)
	elif inst.has_variable("velocity"):
		inst.velocity = forward * PEBBLE_SPEED

func _spawn_pebble(kind: String = "spit") -> void:
	var pebble_node: Node2D = Node2D.new()
	pebble_node.name = "pebble"
	var poly: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	var radius: float = 8.0
	var segments: int = 12
	for i in range(segments):
		var ang: float = (2.0 * PI * i) / segments
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	poly.polygon = pts
	poly.modulate = (Color(0.9, 0.8, 0.6) if kind == "rock" else Color(0.5, 0.9, 1.0))
	pebble_node.add_child(poly)
	var forward: Vector2 = _predict_player_pos_for_projectile(PEBBLE_SPEED) - global_position
	forward = forward.normalized().rotated(_rng.randf_range(-0.18, 0.18))
	var vel: Vector2 = forward * PEBBLE_SPEED + Vector2(0, -60.0)
	var peb: Dictionary = {
		"node": pebble_node,
		"pos": global_position,
		"vel": vel,
		"life": PEBBLE_LIFETIME,
		"kind": kind
	}
	_pebbles.append(peb)
	get_tree().get_current_scene().add_child(pebble_node)

func _update_pebbles(delta: float) -> void:
	for i in range(_pebbles.size() - 1, -1, -1):
		var peb: Dictionary = _pebbles[i]
		var vel: Vector2 = peb["vel"]
		var pos: Vector2 = peb["pos"]
		vel.y += 700.0 * delta * 0.6
		pos += vel * delta
		peb["vel"] = vel
		peb["pos"] = pos
		peb["life"] = peb["life"] - delta
		if is_instance_valid(peb["node"]):
			peb["node"].global_position = pos
		var removed: bool = false
		if player and pos.distance_to(player.global_position) < (PEBBLE_RADIUS + 12.0):
			if player.has_method("apply_damage"):
				player.apply_damage(15)
			if player.has_method("apply_debuff"):
				player.apply_debuff("blur", 0.8)
			_spawn_slippery_patch(pos, "player_hit")
			removed = true
		if not removed:
			var projectiles := get_tree().get_nodes_in_group("player_projectile")
			for prj in projectiles:
				if prj.global_position.distance_to(pos) < (PEBBLE_RADIUS + 8):
					if prj.has_method("destroy"):
						prj.destroy()
					elif prj.queue_free:
						prj.queue_free()
					removed = true
					break
		if not removed:
			var space := get_world_2d().direct_space_state
			var q: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
			q.position = pos
			var areas := space.intersect_point(q)
			for a in areas:
				if a.has("collider") and is_instance_valid(a["collider"]):
					var col = a["collider"]
					if col.is_in_group("mud"):
						_spawn_slippery_patch(pos, "mud_hit")
						removed = true
						break
		if peb["life"] <= 0.0:
			removed = true
		if removed:
			if is_instance_valid(peb["node"]):
				peb["node"].queue_free()
			_pebbles.remove_at(i)

func _spawn_slippery_patch(pos: Vector2, reason: String = "") -> void:
	var a: Area2D = Area2D.new()
	var col: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = SLIP_RADIUS
	col.shape = circle
	a.add_child(col)
	a.global_position = pos
	get_tree().get_current_scene().add_child(a)
	a.add_to_group("slippery_patch")
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = SLIP_DURATION
	a.add_child(t)
	t.timeout.connect(Callable(a, "queue_free"))
	t.start()

func stun() -> void:
	state = BossState.STUNNED
	state_timer = 0.6
	desired_velocity = Vector2.ZERO
	if sprite:
		sprite.scale = Vector2(0.85, 1.15)

func apply_damage(dmg: float) -> void:
	if state == BossState.STUNNED:
		dmg *= 1.2
	hp -= dmg
	modulate = Color(1, 1, 1)
	if hp <= 0:
		state = BossState.DEAD
		queue_free()

func _draw() -> void:
	if Engine.is_editor_hint() and player:
		draw_circle(to_local(player.global_position), orbit_radius, Color(1, 0, 0, 0.12))
