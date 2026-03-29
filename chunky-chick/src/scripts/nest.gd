extends Node2D

const ENDING_CAMERA_MOVE_TIME: float = 4.0
const ENDING_HOLD_TIME: float = 2.5
const ENDING_FADE_TIME: float = 1.5
const ENDING_DIALOGUE_TIME_PER_CHAR: float = 0.03
const ENDING_DIALOGUE_MIN_TIME: float = 12.0
const ENDING_DIALOGUE_FADE_TIME: float = 2.0
const ENDING_POST_DIALOGUE_HOLD: float = 1.0
const MAIN_MENU_SCENE_PATH: String = "res://src/tscn/Main Menu/MainMenu.tscn"

@export var deposit_padding: Vector2 = Vector2(128, 128)
@export var deposit_fallback_radius: float = 220.0

var is_night: bool = false

var day_timer: Timer
var DAY_DURATION: float = 900.0

var placing_turret: bool = false
var ghost_turret: Node2D = null
var placement_stage: int = 0
var placing_watchtower: bool = false

var turret_cost: int = 1
var watchtower_cost: int = 1
var turret_scene: PackedScene = preload("res://src/tscn/Structures/turret.tscn")
var watchtower_scene: PackedScene = preload("res://src/tscn/Structures/watch_tower.tscn")

var weasel_scene: PackedScene = preload("res://src/tscn/enemy/Bosses/Weasel/weasel_boss.tscn")

var deposit_count: int = 0

@onready var popup_ui: Control = $CanvasLayer/PopupUI
@onready var upgrade_ui: Control = $"Upgrade-Layer/Upgrade-selec"
@onready var pc: Camera2D = $"Placement-camera"
@onready var turret_buy_button: Button = upgrade_ui.get_node("Turret/Turret-buy")
@onready var watchtower_buy_button: Button = upgrade_ui.get_node("WatchTower/WatchTower-buy")
@onready var turret_container: Node = get_tree().get_current_scene().get_node("TurretContainer")
@onready var hitbox_area: Area2D = $Hitbox
@onready var ui_hitbox_area: Area2D = $"UI-hitbox"
@onready var egg: Area2D = $Egg/InteractionArea
@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer

var main_camera: Camera2D
var placement_camera: Camera2D

var fade_rect: ColorRect
var fade_layer: CanvasLayer

var ending_layer: CanvasLayer
var ending_label: Label

var pending_boss_night: bool = false

var stage_music_begining: Dictionary = {
	1: preload("res://Assets/Audio/Start/Beginning walk of fat bird.mp3"),
	2: preload("res://Assets/Audio/Start/Beginning bird caprice.mp3"),
	3: preload("res://Assets/Audio/Start/Beginning wandering bird3.mp3"),
	4: preload("res://Assets/Audio/Start/Beginning city of birds.mp3"),
	5: preload("res://Assets/Audio/Start/Beginning feathery skyscraper.mp3"),
	6: preload("res://Assets/Audio/Start/Beginning black hole bird.mp3")
}

var stage_music_mid: Dictionary = {
	1: preload("res://Assets/Audio/Mid/Middle walk of fat bird.mp3"),
	2: preload("res://Assets/Audio/Mid/Middle bird caprice.mp3"),
	3: preload("res://Assets/Audio/Mid/Middle wandering bird.mp3"),
	4: preload("res://Assets/Audio/Mid/Middle city of birds.mp3"),
	5: preload("res://Assets/Audio/Mid/Middle feathery skyscraper.mp3"),
	6: preload("res://Assets/Audio/Mid/Middle black hole bird.mp3")
}

var raid_theme: AudioStream = preload("res://Assets/Audio/enemy/bosses/theme/raids/Attack!!.mp3")
var boss_theme: AudioStream = preload("res://Assets/Audio/enemy/bosses/theme/bosses/Angry Bee Leader.mp3")

var ending_dialogue: String = "I kept you warm.\n\n" + \
	"Every scrap I found, every danger I chased away, every night I stayed awake listening for claws in the dark… it was all for you.\n" + \
	"You opened your beak, and I filled it. Again and again. I thought that was love.\n" + \
	"I thought if you were full, you were safe.\n" + \
	"But I never taught you hunger.\n" + \
	"I never taught you fear.\n" + \
	"I never taught you how to leave.\n" + \
	"Now look at you.\n" + \
	"You’ve grown… too much, too fast. Wings that cannot lift you. Legs that cannot carry you. A body that knows only waiting. Only wanting.\n" + \
	"And the box… it doesn’t fit you anymore.\n" + \
	"I can hear them already. Out there. The same things I kept from you all this time. They’re not afraid of you. Why would they be? You’ve never had to fight. Never had to run.\n" + \
	"That’s my fault.\n" + \
	"I gave you everything… except the one thing that mattered.\n" + \
	"I can’t protect you out there. Not anymore.\n" + \
	"Out there, the world doesn’t care how much I love you.\n" + \
	"I thought I was saving you.\n" + \
	"I wanted you to live.\n" + \
	"I didn’t know I was teaching you how to die."

var current_music_stage: int = -1
var current_music_mode: StringName = &"idle"
var current_boss: Node = null
var raid_active: bool = false
var raid_has_spawned_enemies: bool = false
var ending_sequence_started: bool = false
var current_player_in_range: Node = null

func _ready() -> void:
	pc.add_to_group("placement_camera")
	add_to_group("nest")

	if popup_ui:
		popup_ui.continue_pressed.connect(_on_popup_continue)
		popup_ui.sleep_pressed.connect(_on_sleep_pressed)
		popup_ui.feed_pressed.connect(_on_feed_pressed)

	if upgrade_ui:
		upgrade_ui.close_pressed.connect(_on_upgrade_closed)

	if turret_buy_button:
		turret_buy_button.pressed.connect(_on_buy_turret_pressed)

	if watchtower_buy_button:
		watchtower_buy_button.pressed.connect(_on_buy_watchtower_pressed)

	if music_player and not music_player.finished.is_connected(_on_music_finished):
		music_player.finished.connect(_on_music_finished)

	var cams: Array[Node] = get_tree().get_nodes_in_group("main_camera")
	if cams.size() > 0:
		main_camera = cams[0] as Camera2D
		main_camera.make_current()

	var p_cams: Array[Node] = get_tree().get_nodes_in_group("placement_camera")
	placement_camera = p_cams[0] as Camera2D if p_cams.size() > 0 else null

	if hitbox_area:
		hitbox_area.monitoring = true
		hitbox_area.area_entered.connect(_on_hitbox_area_entered)

	if ui_hitbox_area:
		ui_hitbox_area.body_entered.connect(_on_ui_hitbox_body_entered)
		ui_hitbox_area.body_exited.connect(_on_ui_hitbox_body_exited)

	if egg:
		egg.body_entered.connect(_on_egg_body_entered)
		egg.body_exited.connect(_on_egg_body_exited)

	_create_fade_layer()

	if egg:
		if egg.has_signal("stage_changed"):
			egg.stage_changed.connect(_on_egg_stage_changed)
		if egg.has_signal("demand_completed"):
			egg.demand_completed.connect(_on_egg_demand_completed)
		await get_tree().process_frame
		_on_egg_stage_changed(egg.egg_stage)

	if GameLoad != null and GameLoad.current_run != null:
		pending_boss_night = GameLoad.current_run.is_boss_night
		if GameLoad.current_run.is_night:
			call_deferred("_start_night_encounter")

	_start_day_timer()

func _physics_process(delta: float) -> void:
	if ending_sequence_started:
		return

	_try_deposit_items_in_zone()

func _on_feed_pressed() -> void:
	if ending_sequence_started or egg == null:
		return

	if current_player_in_range:
		var fat_to_give = current_player_in_range.fatness
		_refresh_interaction_prompt()
		if fat_to_give > 0:
			if egg.demand < fat_to_give:
				egg.add_food(egg.demand)
				fat_to_give = fat_to_give - egg.demand
			elif egg.demand > fat_to_give:
				egg.add_food(fat_to_give)
				fat_to_give = 0
			_refresh_interaction_prompt()

			print("Egg fed! Amount: ", fat_to_give)
		else:
			print("I am too skinny for this")

func _play_stream(stream: AudioStream) -> void:
	if stream == null:
		music_player.stop()
		return
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.play()

func _get_stage_stream(table: Dictionary, stage: int) -> AudioStream:
	if table.has(stage):
		return table[stage] as AudioStream
	return null

func _is_current_stage_stream(stream: AudioStream) -> bool:
	if stream == null:
		return false

	return (
		stream == _get_stage_stream(stage_music_begining, current_music_stage)
		or stream == _get_stage_stream(stage_music_mid, current_music_stage)
	)

func _play_special_music(stream: AudioStream) -> void:
	current_music_mode = &"special"
	_play_stream(stream)

func _sync_music() -> void:
	if ending_sequence_started:
		return

	if current_boss != null and is_instance_valid(current_boss):
		_play_special_music(boss_theme)
		return

	if current_boss != null and not is_instance_valid(current_boss):
		current_boss = null

	if raid_active:
		_play_special_music(raid_theme)
		return

	if current_music_stage < 0:
		music_player.stop()
		current_music_mode = &"idle"
		return

	if music_player.playing and _is_current_stage_stream(music_player.stream):
		return

	_play_stage_music(current_music_stage)

func _play_stage_music(stage: int) -> void:
	if ending_sequence_started:
		return

	current_music_stage = stage

	if current_boss != null and is_instance_valid(current_boss):
		return
	if raid_active:
		return

	current_music_mode = &"stage_intro"

	var stream: AudioStream = _get_stage_stream(stage_music_begining, stage)
	if stream == null:
		stream = _get_stage_stream(stage_music_mid, stage)
		current_music_mode = &"stage_mid"

	if stream != null:
		_play_stream(stream)
	else:
		music_player.stop()
		current_music_mode = &"idle"

func _on_music_finished() -> void:
	if current_music_mode == &"stage_intro":
		var mid_stream: AudioStream = _get_stage_stream(stage_music_mid, current_music_stage)
		if mid_stream != null:
			current_music_mode = &"stage_mid"
			_play_stream(mid_stream)
		else:
			music_player.stop()
			current_music_mode = &"idle"
		return

	if current_music_mode == &"stage_mid":
		if ending_sequence_started:
			return

		var loop_stream: AudioStream = _get_stage_stream(stage_music_mid, current_music_stage)
		if loop_stream != null:
			_play_stream(loop_stream)
		else:
			music_player.stop()
			current_music_mode = &"idle"
		return

func _on_egg_stage_changed(stage: int) -> void:
	if ending_sequence_started:
		return

	_play_stage_music(stage)
	_refresh_interaction_prompt()

	if stage >= 6:
		_start_ending_sequence()

func _on_egg_demand_completed() -> void:
	_refresh_interaction_prompt()

func _refresh_interaction_prompt() -> void:
	if popup_ui == null or egg == null:
		return

	var bodies = egg.get_overlapping_bodies()
	for body in bodies:
		if body != null and body.is_in_group("player"):
			current_player_in_range = body
			popup_ui.show_interaction(body, egg.demand_met, egg.is_night)
			return

	current_player_in_range = null

func _start_raid_theme() -> void:
	if ending_sequence_started:
		return
	raid_active = true
	raid_has_spawned_enemies = false
	_sync_music()

func _end_raid_theme() -> void:
	if ending_sequence_started:
		return
	raid_active = false
	raid_has_spawned_enemies = false

	if egg:
		egg.is_night = false

	_sync_music()

func _register_boss(boss: Node) -> void:
	if ending_sequence_started:
		return
	current_boss = boss
	if current_boss and not current_boss.tree_exited.is_connected(_on_boss_tree_exited):
		current_boss.tree_exited.connect(_on_boss_tree_exited)
	_sync_music()

func _on_boss_tree_exited() -> void:
	if ending_sequence_started:
		return
	current_boss = null

	if not _are_raid_enemies_alive():
		if egg:
			egg.is_night = false

	_sync_music()

func _are_raid_enemies_alive() -> bool:
	for group_name in ["raid_enemy", "raid", "enemy"]:
		var group_nodes := get_tree().get_nodes_in_group(group_name)
		for enemy in group_nodes:
			if not is_instance_valid(enemy):
				continue
			if enemy.is_queued_for_deletion():
				continue
			if enemy == current_boss:
				continue
			if enemy.is_in_group("boss"):
				continue
			return true
	return false

func _create_fade_layer() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 10
	add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.anchor_left = 0
	fade_rect.anchor_top = 0
	fade_rect.anchor_right = 1
	fade_rect.anchor_bottom = 1
	fade_rect.modulate.a = 0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	fade_layer.add_child(fade_rect)

func _ensure_ending_ui() -> void:
	if ending_layer:
		return

	ending_layer = CanvasLayer.new()
	ending_layer.layer = 20
	add_child(ending_layer)

	ending_label = Label.new()
	ending_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_label.offset_left = 80
	ending_label.offset_top = 80
	ending_label.offset_right = -80
	ending_label.offset_bottom = -80
	ending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ending_label.modulate = Color(1, 1, 1, 1)
	ending_label.visible_ratio = 0.0
	ending_label.text = ""

	ending_layer.add_child(ending_label)

func capture_into_run_data(run: RunData) -> void:
	if run == null or egg == null:
		return

	run.curr_day = egg.day
	run.egg_stage = egg.egg_stage
	run.egg_demand = egg.demand
	run.is_night = egg.is_night
	run.is_day = not egg.is_night
	run.is_boss_night = pending_boss_night

	run.turrets.clear()
	run.watchtowers.clear()

	for turret in get_tree().get_nodes_in_group("turret"):
		if turret.has_method("capture_into_run_data"):
			var turret_state: Dictionary = turret.capture_into_run_data()
			run.turrets.append(turret_state)

	for watchtower in get_tree().get_nodes_in_group("watchtower"):
		if watchtower.has_method("capture_into_run_data"):
			var watchtower_state: Dictionary = watchtower.capture_into_run_data()
			run.watchtowers.append(watchtower_state)

	run.turret_count = run.turrets.size()
	run.watchtower_count = run.watchtowers.size()

func apply_run_data(run: RunData) -> void:
	if run == null:
		return

	pending_boss_night = run.is_boss_night
	raid_active = false

	for turret in get_tree().get_nodes_in_group("turret"):
		if turret.has_method("apply_run_data"):
			turret.apply_run_data(_find_structure_state(run.turrets, turret.persistent_id))

	for watchtower in get_tree().get_nodes_in_group("watchtower"):
		if watchtower.has_method("apply_run_data"):
			watchtower.apply_run_data(_find_structure_state(run.watchtowers, watchtower.persistent_id))

func _find_structure_state(list: Array, id: String) -> Dictionary:
	for entry in list:
		if entry is Dictionary and entry.get("id", "") == id:
			return entry
	return {}

func _start_ending_sequence() -> void:
	if ending_sequence_started:
		return

	ending_sequence_started = true
	raid_active = false
	raid_has_spawned_enemies = false
	current_boss = null
	music_player.stop()

	if popup_ui:
		popup_ui.hide_popup()
	if upgrade_ui:
		upgrade_ui.visible = false

	call_deferred("_run_ending_sequence")

func _run_ending_sequence() -> void:
	await _move_camera_to_placement()
	await get_tree().create_timer(ENDING_HOLD_TIME).timeout

	if fade_rect:
		fade_rect.modulate.a = 0.0

	_ensure_ending_ui()
	ending_label.text = ending_dialogue
	ending_label.visible_ratio = 0.0
	ending_label.modulate.a = 1.0

	var dialogue_time: float = max(ENDING_DIALOGUE_MIN_TIME, float(ending_dialogue.length()) * ENDING_DIALOGUE_TIME_PER_CHAR)
	var dialogue_tween: Tween = create_tween()
	dialogue_tween.tween_property(ending_label, "visible_ratio", 1.0, dialogue_time)
	await dialogue_tween.finished

	await get_tree().create_timer(ENDING_POST_DIALOGUE_HOLD).timeout

	var label_fade: Tween = create_tween()
	label_fade.tween_property(ending_label, "modulate:a", 0.0, ENDING_DIALOGUE_FADE_TIME)
	await label_fade.finished

	if music_player.get_parent() == self:
		remove_child(music_player)
		get_tree().root.add_child(music_player)

	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _move_camera_to_placement() -> void:
	if not main_camera or not placement_camera:
		return

	var tween: Tween = create_tween()
	tween.tween_property(main_camera, "global_position", placement_camera.global_position, ENDING_CAMERA_MOVE_TIME)
	tween.parallel().tween_property(main_camera, "zoom", placement_camera.zoom, ENDING_CAMERA_MOVE_TIME)
	await tween.finished

func _sleep_transition() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.2)
	tween.tween_callback(_start_night_encounter)
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.2)

func _start_night_encounter() -> void:
	if pending_boss_night:
		_start_boss_night()
	else:
		_start_raid_night()

func _start_boss_night() -> void:
	raid_active = false
	raid_has_spawned_enemies = false
	current_boss = null
	_play_special_music(boss_theme)

	if egg == null or not weasel_scene:
		return

	var count: int = max(1, int(egg.day / 5))
	for i in range(count):
		var boss: Node = weasel_scene.instantiate()
		get_tree().current_scene.add_child(boss)
		boss.global_position = global_position + Vector2(0, -2500 - (i * 160))
		if i == 0:
			_register_boss(boss)

func _start_raid_night() -> void:
	raid_active = true
	raid_has_spawned_enemies = false
	current_boss = null
	_sync_music()

func _spawn_weasel() -> void:
	if not weasel_scene:
		return

	var boss: Node = weasel_scene.instantiate()
	get_tree().current_scene.add_child(boss)
	boss.global_position = global_position + Vector2(0, -2500)

	_register_boss(boss)

func _on_sleep_pressed() -> void:
	if ending_sequence_started:
		return
	if popup_ui:
		popup_ui.hide_popup()

	if egg:
		egg.next_day()
		pending_boss_night = (egg.day % 5 == 0)
	else:
		pending_boss_night = false

	if GameLoad != null and GameLoad.current_run != null:
		GameLoad.current_run.is_night = true
		GameLoad.save_current_state(null, egg)

	_sleep_transition()

func _on_buy_turret_pressed() -> void:
	if ending_sequence_started:
		return
	if not Resources.spend_cardboard(turret_cost):
		return
	_upgrade_to_placement(turret_scene)
	placing_turret = true
	placement_stage = 1

func _on_buy_watchtower_pressed() -> void:
	if ending_sequence_started:
		return
	if not Resources.spend_cardboard(watchtower_cost):
		return
	_upgrade_to_placement(watchtower_scene)
	placing_watchtower = true

func _upgrade_to_placement(scene: PackedScene) -> void:
	upgrade_ui.visible = false
	if placement_camera:
		placement_camera.make_current()

	ghost_turret = scene.instantiate() as Node2D
	ghost_turret.modulate = Color(1, 1, 1, 0.5)

	turret_container.add_child(ghost_turret)

	if ghost_turret.has_method("enable_preview"):
		ghost_turret.enable_preview()

func _on_popup_continue() -> void:
	if popup_ui:
		popup_ui.visible = false
	upgrade_ui.visible = true

func _on_upgrade_closed() -> void:
	upgrade_ui.visible = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area:
		return
	if area.is_in_group("material") and not area.carried:
		deposit_item(area)

func _try_deposit_items_in_zone() -> void:
	for node in get_tree().get_nodes_in_group("material"):
		if not is_instance_valid(node):
			continue
		if node.is_queued_for_deletion():
			continue
		if node.carried:
			continue
		if node is Node2D and _is_point_inside_deposit_zone(node.global_position):
			deposit_item(node)

func _is_point_inside_deposit_zone(world_pos: Vector2) -> bool:
	if hitbox_area == null:
		return false

	var local_pos: Vector2 = hitbox_area.to_local(world_pos)

	var shape_node := hitbox_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape:
		if shape_node.shape is RectangleShape2D:
			var rect_shape := shape_node.shape as RectangleShape2D
			var extents: Vector2 = rect_shape.extents + deposit_padding
			return abs(local_pos.x) <= extents.x and abs(local_pos.y) <= extents.y

		elif shape_node.shape is CircleShape2D:
			var circle_shape := shape_node.shape as CircleShape2D
			var radius: float = circle_shape.radius + max(deposit_padding.x, deposit_padding.y)
			return local_pos.length() <= radius

		elif shape_node.shape is CapsuleShape2D:
			var capsule_shape := shape_node.shape as CapsuleShape2D
			var radius_capsule: float = max(capsule_shape.radius, capsule_shape.height * 0.5) + max(deposit_padding.x, deposit_padding.y)
			return local_pos.length() <= radius_capsule

	return local_pos.length() <= deposit_fallback_radius

func deposit_item(item: Node) -> void:
	if not is_instance_valid(item):
		return

	if item.is_queued_for_deletion():
		return

	if item.carried:
		return

	if item.is_in_group("material") and item.material_type == "cardboard":
		Resources.add_cardboard(item.material_amount)

	if GameLoad != null and item.has_meta("persistent_id"):
		var persistent_id = str(item.get_meta("persistent_id"))
		if persistent_id != "":
			GameLoad.save_world_state(persistent_id, {
				"kind": "material",
				"removed": true
			})

	deposit_count += 1
	item.queue_free()

func _on_ui_hitbox_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		if egg and egg.overlaps_body(body):
			return
		if popup_ui:
			popup_ui.show_buy_only()

func _on_ui_hitbox_body_exited(body: Node) -> void:
	if body and body.is_in_group("player"):
		if egg and egg.overlaps_body(body):
			_refresh_interaction_prompt()
		else:
			if popup_ui:
				popup_ui.hide_popup()

func _on_egg_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		current_player_in_range = body
		if popup_ui:
			popup_ui.show_interaction(body, egg.demand_met, egg.is_night)

func _on_egg_body_exited(body: Node) -> void:
	if body and body.is_in_group("player"):
		if current_player_in_range == body:
			current_player_in_range = null

		if popup_ui:
			if ui_hitbox_area and ui_hitbox_area.overlaps_body(body):
				popup_ui.show_buy_only()
			else:
				popup_ui.hide_popup()

func _process(delta: float) -> void:
	if ending_sequence_started:
		return

	if Input.is_action_just_pressed("wave"):
		_start_raid_theme()

	if raid_active:
		if _are_raid_enemies_alive():
			raid_has_spawned_enemies = true
		elif raid_has_spawned_enemies:
			_end_raid_theme()

	if not ghost_turret:
		return

	var mouse_pos: Vector2 = placement_camera.get_global_mouse_position() if placement_camera else Vector2.ZERO

	if placing_turret:
		if placement_stage == 1:
			ghost_turret.global_position = mouse_pos
		elif placement_stage == 2:
			if ghost_turret.has_method("rotate_head_towards"):
				ghost_turret.rotate_head_towards(mouse_pos)
	elif placing_watchtower:
		ghost_turret.global_position = mouse_pos

func _unhandled_input(event: InputEvent) -> void:
	if ending_sequence_started:
		return
	if not ghost_turret:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if placing_turret:
			if placement_stage == 1:
				placement_stage = 2
			elif placement_stage == 2:
				ghost_turret.modulate = Color(1, 1, 1, 1)
				if ghost_turret.has_method("lock_head_rotation"):
					ghost_turret.lock_head_rotation()
				_reset_placement()
		elif placing_watchtower:
			ghost_turret.modulate = Color(1, 1, 1, 1)
			if ghost_turret.has_method("finalize_placement"):
				ghost_turret.finalize_placement()
			_reset_placement()

func _reset_placement() -> void:
	ghost_turret = null
	placing_turret = false
	placing_watchtower = false
	placement_stage = 0

	if main_camera:
		main_camera.make_current()

func try_deposit(item: Node) -> bool:
	if not item:
		return false

	if item.is_in_group("material") and item.material_type == "cardboard":
		deposit_item(item)
		return true

	return false

func _start_day_timer() -> void:
	if ending_sequence_started:
		return

	day_timer = Timer.new()
	day_timer.wait_time = DAY_DURATION
	day_timer.one_shot = true
	day_timer.timeout.connect(_on_day_timeout)
	add_child(day_timer)
	day_timer.start()

func _on_day_timeout() -> void:
	if ending_sequence_started:
		return
	_force_sleep()

func _force_sleep() -> void:
	if ending_sequence_started:
		return

	if popup_ui:
		popup_ui.hide_popup()

	_sleep_transition()

	if egg:
		egg.next_day()

	_start_day_timer()
