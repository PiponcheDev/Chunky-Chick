extends CharacterBody2D

# ----------------------
# Weasel boss controller
# ----------------------
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

var state : BossState = BossState.ORBIT
@onready var sprite: Node2D = $Icon

# ---- Core stats ----
var hp := 220
@export var move_speed := 220.0
@export var collision_damage := 20

# ---- Orbit params ----
@export var orbit_radius_inner := 350.0
@export var orbit_radius_outer := 600.0
var orbit_radius := orbit_radius_outer
var orbit_angle := 0.0
var orbit_dir := 1
var orbit_arc_remaining := 0.0
var inward_timer := 0.0

# Natural motion tuning
@export var orbit_noise_amplitude := 0.18   # small jitter on orbit angle
@export var orbit_noise_speed := 1.3
var _rng := RandomNumberGenerator.new()
var _orbit_noise_time := 0.0

# ---- Dash ----
@export var dash_speed := 900.0
var dash_vector := Vector2.ZERO
var dash_count := 0
var dash_cooldown := 0.0

# Coil/telegraph durations (spec: 0.15 lock + 0.25 coil = 0.4s telegraph)
const DASH_LOCK_DUR := 0.15
const DASH_COIL_DUR := 0.25
const DASH_MIN_EXEC := 0.4
const DASH_MAX_EXEC := 0.5
const DASH_POST_MICRO := 0.3
const DASH_COOLDOWN := 1.0

# Coil procedural animation bookkeeping
var _coil_total := DASH_COIL_DUR
var _coil_elapsed := 0.0

# ---- Spit / Pebbles fallback ----
@export var spit_projectile_scene : PackedScene = null    # optional; fallback used if null
var spit_cooldown := 0.0
const SPIT_COOLDOWN := 3.0
const SPIT_WINDUP := 0.4
const SPIT_RECOVER := 0.6

# Pebble fallback settings (used when no scene provided)
const PEBBLE_SPEED := 350.0
const PEBBLE_LIFETIME := 3.0
const PEBBLE_RADIUS := 8.0
var _pebbles := []     # array of dictionaries: {node:Node2D, pos:Vector2, vel:Vector2, life:float}

# Slippery patch fallback settings
const SLIP_RADIUS := 50.0
const SLIP_DURATION := 1.2

# ---- Player reference & timers ----
var player: Node2D = null
var state_timer := 0.0
var desired_velocity := Vector2.ZERO

# Movement smoothing
@export var steer_smooth := 6.0


func _ready():
	_rng.randomize()
	player = get_tree().get_first_node_in_group("player")
	# Prevent physics from applying rotation/torque
	lock_rotation = true
	choose_orbit()


func _physics_process(delta: float) -> void:
	if state == BossState.DEAD:
		return

	# timers
	state_timer = max(state_timer - delta, 0.0)
	inward_timer = max(inward_timer - delta, 0.0)
	dash_cooldown = max(dash_cooldown - delta, 0.0)
	spit_cooldown = max(spit_cooldown - delta, 0.0)
	_orbit_noise_time += delta

	# update pebbles (if any)
	_update_pebbles(delta)

	# main state machine
	match state:
		BossState.ORBIT:
			_orbit_logic(delta)
			_attack_decision()
		BossState.DASH_LOCK:
			# pure lock (immobile) — we keep desired_velocity zero
			if state_timer <= 0.0:
				enter_dash_coil()
		BossState.DASH_COIL:
			_process_coil(delta)
			if state_timer <= 0.0:
				enter_dash_exec()
		BossState.DASH_EXEC:
			# dash: rigid, no tracking mid-dash
			desired_velocity = dash_vector * dash_speed
			if state_timer <= 0.0:
				_enter_post_dash()
		BossState.STUNNED:
			desired_velocity = Vector2.ZERO
			if state_timer <= 0.0:
				enter_orbit()
		BossState.SPIT_WINDUP:
			desired_velocity = Vector2.ZERO
			if state_timer <= 0.0:
				_fire_spit()
		BossState.SPIT_RECOVER:
			desired_velocity = Vector2.ZERO
			if state_timer <= 0.0:
				enter_orbit()
		BossState.DEAD:
			desired_velocity = Vector2.ZERO

	# apply smoothing to make motion natural
	linear_velocity = linear_velocity.lerp(desired_velocity, clamp(steer_smooth * delta, 0.0, 1.0))

	# rotate sprite to face player (visual) but keep body rotation locked
	if sprite and player:
		sprite.rotation = (player.global_position - global_position).angle()


# -------------------------
# Orbit & natural motion
# -------------------------
func _orbit_logic(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			desired_velocity = Vector2.ZERO
			return

	# natural orbit progression + noise (gives non-robotic motion)
	# angular speed scaled by move_speed / radius (approx circular motion)
	var base_angular = orbit_dir * move_speed / max(orbit_radius, 1.0)
	# perlin-ish noise (simple sin/cos mixture)
	var noise = sin(_orbit_noise_time * orbit_noise_speed) * orbit_noise_amplitude
	orbit_angle += (base_angular + noise) * delta

	# arc bookkeeping
	orbit_arc_remaining -= abs(move_speed * delta)
	if orbit_arc_remaining <= 0:
		choose_orbit()

	# inward cuts every 3-5s
	if inward_timer <= 0.0:
		inward_timer = _rng.randf_range(3.0, 5.0)
		# make a short inward cut toward inner ring
		orbit_radius = lerp(orbit_radius, orbit_radius_inner, 0.6)

	# target point on orbit (slightly jittered)
	var orbit_target = player.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	# small perpendicular wobble for more natural arcs
	var perp = Vector2(-sin(orbit_angle), cos(orbit_angle))
	orbit_target += perp * _rng.randf_range(-6.0, 6.0)

	# desired velocity is steering toward that orbit target
	desired_velocity = (orbit_target - global_position).normalized() * move_speed


func choose_orbit() -> void:
	# 60% inner ring bias
	if _rng.randf() < 0.6:
		orbit_radius = orbit_radius_inner
	else:
		orbit_radius = orbit_radius_outer

	# arc length between 90° and 160° in radians, scaled by radius
	var arc_deg = _rng.randf_range(90.0, 160.0)
	orbit_arc_remaining = deg_to_rad(arc_deg) * orbit_radius

	# choose CW or CCW
	orbit_dir = (-1 if _rng.randi_range(0,1) == 0 else 1)


# -------------------------
# Attack decision
# -------------------------
func _attack_decision() -> void:
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)

	# dash: only from ORBIT, cooldown ready, between 100 and 450
	if state == BossState.ORBIT and dash_cooldown <= 0.0 and dist < 450.0 and dist > 100.0:
		enter_dash_lock()
		return

	# spit: use only if not dashing and cooldown ready and player is farther than 300
	if state == BossState.ORBIT and spit_cooldown <= 0.0 and dist > 300.0:
		enter_spit()
		return


# -------------------------
# Dash: staged entry functions
# -------------------------
func enter_dash_lock() -> void:
	# ensure deterministic channeling: only enter if in orbit
	if state != BossState.ORBIT:
		return
	state = BossState.DASH_LOCK
	state_timer = DASH_LOCK_DUR
	desired_velocity = Vector2.ZERO
	# lock dash vector now (target lock)
	if player:
		dash_vector = (player.global_position - global_position).normalized()
	else:
		dash_vector = Vector2.RIGHT
	# reset coil bookkeeping
	_coil_elapsed = 0.0
	_coil_total = DASH_COIL_DUR
	# create a small visual offset to show "pull back" before coil (reset here)
	if sprite:
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE


func enter_dash_coil() -> void:
	# coil: procedural squish + offset over time, stays immobile
	state = BossState.DASH_COIL
	state_timer = DASH_COIL_DUR
	_coil_elapsed = 0.0
	# choose coil direction flip occasionally (avoid monotony)
	# (we keep dash_vector constant so coil aligns to final dash)
	# no immediate scale set here — coil is procedural (see _process_coil)
	# ensure we remain immobile
	desired_velocity = Vector2.ZERO


func _process_coil(delta: float) -> void:
	# procedural coil: animate scale and sprite offset over coil duration
	_coil_elapsed += delta
	var t: float = clamp(_coil_elapsed / _coil_total, 0.0, 1.0)
	# smooth step (ease-in/out)
	var smooth: float = t * t * (3.0 - 2.0 * t)
	# coil strength shaped by a sine for nicer visual
	var s: float = sin(smooth * PI)
	var amplitude := 0.42        # how strong the squash/stretch is (tweakable)

	# squash & stretch along local axes (sprite is already rotated to face player)
	# x-axis: stretch in dash direction; y-axis: squash
	if sprite:
		# We want the visual displacement to be opposite the dash vector:
		# move the sprite *backwards* along dash_vector to appear coiled.
		var back_offset := -dash_vector * (12.0 * s)   # tweak offset magnitude as needed
		sprite.position = back_offset

		# scale: stretch in forward axis and squash in perpendicular
		# since sprite.rotation faces player (and dash_vector ~ to player), scaling local x/y aligns correctly
		var xscale: float = lerp(1.0, 1.0 + amplitude, s)
		var yscale: float = lerp(1.0, 1.0 - amplitude, s)
		sprite.scale = Vector2(xscale, yscale)


func enter_dash_exec() -> void:
	# start dash; dash_vector locked (no mid-dash tracking)
	state = BossState.DASH_EXEC
	# random duration between 0.4 and 0.5
	var exec_dur := _rng.randf_range(DASH_MIN_EXEC, DASH_MAX_EXEC)
	state_timer = exec_dur
	# ensure sprite reset (end coil visual)
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.position = Vector2.ZERO
	# perform dash immediately by setting desired velocity (applied next physics step)
	desired_velocity = dash_vector * dash_speed


func _enter_post_dash() -> void:
	# micro recovery + go back to orbit
	dash_count += 1
	dash_cooldown = DASH_COOLDOWN
	state = BossState.ORBIT
	state_timer = DASH_POST_MICRO
	# choose next orbit behavior
	choose_orbit()


# -------------------------
# Spit attack & pebble fallback
# -------------------------
func enter_spit() -> void:
	if state != BossState.ORBIT:
		return
	state = BossState.SPIT_WINDUP
	state_timer = SPIT_WINDUP
	desired_velocity = Vector2.ZERO


func _fire_spit() -> void:
	# if there is an exported scene, use it
	if spit_projectile_scene and player:
		var projectile = spit_projectile_scene.instantiate()
		get_parent().add_child(projectile)
		projectile.global_position = global_position
		# attempt to call 'launch' on the projectile; if not present, attempt to set velocity property
		if projectile.has_method("launch"):
			projectile.launch((player.global_position - global_position).normalized())
		else:
			# fallback attempt to set a velocity property if the scene supports it
			if projectile.has_variable("velocity"):
				projectile.velocity = (player.global_position - global_position).normalized() * PEBBLE_SPEED
	else:
		# fallback: create a simple pebble node and track it here
		_spawn_pebble(player.global_position if player else global_position + Vector2.RIGHT * 200)

	# set cooldown and transition to recover
	spit_cooldown = SPIT_COOLDOWN
	state = BossState.SPIT_RECOVER
	state_timer = SPIT_RECOVER


func _spawn_pebble(target_pos: Vector2) -> void:
	# create a lightweight Node2D as visual; boss will manage its movement and collisions
	var pebble_node := Node2D.new()
	pebble_node.name = "pebble"
	# draw a simple circle by adding a small ColorRect-like visual: use a Sprite if you have a texture,
	# otherwise we'll add a simple Circle using a CanvasItem script on the node.
	# For simplicity, add a small ColorRect via TextureRect if you like; here we skip visuals (user can supply scene)
	# Position and velocity:
	var dir := (target_pos - global_position).normalized()
	# introduce a little vertical component for arc effect
	var angle_jitter := _rng.randf_range(-0.18, 0.18)
	dir = dir.rotated(angle_jitter)
	var speed := PEBBLE_SPEED
	# initial upward (or perpendicular) component to create an arc over time
	var vel := dir * speed + Vector2(0, -60.0)   # small upward bias (tweak as desired)
	var peb := {
		"node": pebble_node,
		"pos": global_position,
		"vel": vel,
		"life": PEBBLE_LIFETIME
	}
	_pebbles.append(peb)
	get_parent().add_child(pebble_node)
	# optional visual: if you have a texture named "pebble.png" in res:// you could add a Sprite here:
	# var sp := Sprite2D.new(); sp.texture = load("res://pebble.png"); pebble_node.add_child(sp)


func _update_pebbles(delta: float) -> void:
	# move pebbles, apply gravity-ish arc, detect collisions with player / projectiles / terrain
	for i in range(_pebbles.size() - 1, -1, -1):
		var peb = _pebbles[i]
		# simple gravity
		var vel: Vector2 = peb["vel"]
		vel.y += 700.0 * delta * 0.6
		peb["vel"] = vel
		peb["pos"] += peb["vel"] * delta
		peb["life"] -= delta
		# update node position so designer can see it
		if is_instance_valid(peb["node"]):
			peb["node"].global_position = peb["pos"]

		var removed := false
		# hit player?
		if player and peb["pos"].distance_to(player.global_position) < (PEBBLE_RADIUS + 12.0):
			# apply damage and debuff to player if player has the methods/groups you expect
			if player.has_method("apply_damage"):
				player.apply_damage(15)
			# attempt to call blur/debuff method
			if player.has_method("apply_debuff"):
				player.apply_debuff("blur", 0.8)
			_spawn_slippery_patch(peb["pos"], "player_hit")
			removed = true

		# hit by player projectile? (player projectiles should be put into group "player_projectile")
		if not removed:
			var projectiles = get_tree().get_nodes_in_group("player_projectile")
			for prj in projectiles:
				if prj.global_position.distance_to(peb["pos"]) < (PEBBLE_RADIUS + 8):
					# destroy pebble and optionally the projectile
					if prj.has_method("destroy"):
						prj.destroy()
					elif prj.queue_free:
						prj.queue_free()
					removed = true
					break

		# hit ground/terrain: try to detect areas named "mud" (you should tag mud areas with the group "mud")
		if not removed:
			# use a quick point query against the physics world to find areas at pebble position
			var space := get_world_2d().direct_space_state
			var q: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
			q.position = peb["pos"]
			q.exclude = []
			var areas := space.intersect_point(q)
			for a in areas:
				# area result returns dict with "collider"
				if a.has("collider") and is_instance_valid(a["collider"]):
					var col = a["collider"]
					if col.is_in_group("mud"):
						_spawn_slippery_patch(peb["pos"], "mud_hit")
						removed = true
						break
		# lifetime expired
		if peb["life"] <= 0.0:
			removed = true
		if removed:
			# cleanup node & array entry
			if is_instance_valid(peb["node"]):
				peb["node"].queue_free()
			_pebbles.remove_at(i)

func _spawn_slippery_patch(pos: Vector2, reason: String="") -> void:
	# creates a short-lived Area2D which you can test from the player to apply traction changes.
	# Designer: you can replace this with a reusable scene for better visuals.
	var a := Area2D.new()
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = SLIP_RADIUS
	col.shape = circle
	a.add_child(col)
	a.global_position = pos
	get_parent().add_child(a)
	# tag so player logic can detect
	a.add_to_group("slippery_patch")
	# schedule removal
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = SLIP_DURATION
	a.add_child(t)
	t.timeout.connect(Callable(a, "queue_free"))
	t.start()


# -------------------------
# Stun & orbit re-entry
# -------------------------
func stun() -> void:
	state = BossState.STUNNED
	state_timer = 0.6
	desired_velocity = Vector2.ZERO
	# visual feedback
	if sprite:
		sprite.scale = Vector2(0.85, 1.15)


func enter_orbit() -> void:
	# return to orbit deterministically
	state = BossState.ORBIT
	choose_orbit()
	state_timer = 0.0
	# reset visuals
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.position = Vector2.ZERO


# -------------------------
# Damage handling
# -------------------------
func apply_damage(dmg: float) -> void:
	# apply stun damage multiplier
	if state == BossState.STUNNED:
		dmg *= 1.2
	hp -= dmg
	# visual hit feedback (tiny flash)
	modulate = Color(1,1,1)
	if hp <= 0:
		state = BossState.DEAD
		queue_free()


# -------------------------
# Utility / debug
# -------------------------
func _draw() -> void:
	# draw orbit circle for editor visualization (optional)
	if Engine.is_editor_hint() and player:
		draw_circle(to_local(player.global_position), orbit_radius, Color(1,0,0,0.12))
