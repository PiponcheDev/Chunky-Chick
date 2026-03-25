extends Node2D

const ENDING_CAMERA_MOVE_TIME: float = 4.0
const ENDING_HOLD_TIME: float = 2.5
const ENDING_FADE_TIME: float = 1.5
const ENDING_DIALOGUE_TIME_PER_CHAR: float = 0.03
const ENDING_DIALOGUE_MIN_TIME: float = 12.0
const ENDING_DIALOGUE_FADE_TIME: float = 2.0
const ENDING_POST_DIALOGUE_HOLD: float = 1.0
const MAIN_MENU_SCENE_PATH: String = "res://MainMenu.tscn"

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
@onready var interaction_area: Area2D = $Egg/InteractionArea
@onready var egg: Node2D = $Egg/InteractionArea
@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer

var main_camera: Camera2D
var placement_camera: Camera2D

var fade_rect: ColorRect
var fade_layer: CanvasLayer

var ending_layer: CanvasLayer
var ending_label: Label

var stage_music: Dictionary = {
	1: preload("res://Assets/Audio/1 - Fat Bird Beginnings.mp3"),
	2: preload("res://Assets/Audio/2 - Walk of the Fat Bird.mp3"),
	3: preload("res://Assets/Audio/3 - Bird Caprice.mp3"),
	4: preload("res://Assets/Audio/6 - Wandering Bird.mp3"),
	5: preload("res://Assets/Audio/9 - Feathery Skyscraper.mp3")
}

var raid_theme: AudioStream = preload("res://Assets/Audio/enemy/bosses/theme/raids/Attack!!.mp3")
var boss_theme: AudioStream = preload("res://Assets/Audio/enemy/bosses/theme/bosses/Angry Bee Leader.mp3")
var end_music: AudioStream = preload("res://Assets/Audio/Game Over..mp3")

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
var current_boss: Node = null
var raid_active: bool = false
var raid_has_spawned_enemies: bool = false
var ending_sequence_started: bool = false

func _ready() -> void:
	pc.add_to_group("placement_camera")
	add_to_group("nest")

	print("Nest ready")

	if popup_ui:
		popup_ui.continue_pressed.connect(_on_popup_continue)
		popup_ui.sleep_pressed.connect(_on_sleep_pressed)

	if upgrade_ui:
		upgrade_ui.close_pressed.connect(_on_upgrade_closed)

	if turret_buy_button:
		turret_buy_button.pressed.connect(_on_buy_turret_pressed)

	if watchtower_buy_button:
		watchtower_buy_button.pressed.connect(_on_buy_watchtower_pressed)

	var cams: Array[Node] = get_tree().get_nodes_in_group("main_camera")
	if cams.size() > 0:
		main_camera = cams[0] as Camera2D
		main_camera.make_current()

	var p_cams: Array[Node] = get_tree().get_nodes_in_group("placement_camera")
	placement_camera = p_cams[0] as Camera2D if p_cams.size() > 0 else null

	if hitbox_area:
		hitbox_area.body_entered.connect(_on_hitbox_body_entered)

	if ui_hitbox_area:
		ui_hitbox_area.body_entered.connect(_on_ui_hitbox_body_entered)
		ui_hitbox_area.body_exited.connect(_on_ui_hitbox_body_exited)

	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	if egg:
		if egg.has_signal("stage_changed"):
			egg.stage_changed.connect(_on_egg_stage_changed)
		_play_stage_music(egg.egg_stage)
		if egg.egg_stage >= 5:
			_start_ending_sequence()

	_create_fade_layer()
	_start_day_timer()

func _play_stream(stream: AudioStream) -> void:
	if stream == null:
		music_player.stop()
		return
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.play()

func _sync_music() -> void:
	if ending_sequence_started:
		return

	if current_boss != null and is_instance_valid(current_boss):
		_play_stream(boss_theme)
		return

	if current_boss != null and not is_instance_valid(current_boss):
		current_boss = null

	if raid_active:
		_play_stream(raid_theme)
		return

	if stage_music.has(current_music_stage):
		_play_stream(stage_music[current_music_stage])
	else:
		music_player.stop()

func _play_stage_music(stage: int) -> void:
	if ending_sequence_started:
		return

	current_music_stage = stage

	if current_boss != null and is_instance_valid(current_boss):
		return
	if raid_active:
		return
	if stage_music.has(stage):
		_play_stream(stage_music[stage])
	else:
		music_player.stop()

func _on_egg_stage_changed(stage: int) -> void:
	if ending_sequence_started:
		return

	_play_stage_music(stage)
	if stage >= 5:
		_start_ending_sequence()

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
	_sync_music()

func _are_raid_enemies_alive() -> bool:
	for group_name in ["raid_enemy", "raid", "enemy"]:
		for enemy in get_tree().get_nodes_in_group(group_name):
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

func _start_ending_sequence() -> void:
	if ending_sequence_started:
		return

	ending_sequence_started = true
	raid_active = false
	raid_has_spawned_enemies = false
	current_boss = null
	current_music_stage = 5

	if popup_ui:
		popup_ui.hide_popup()
	if upgrade_ui:
		upgrade_ui.visible = false

	_sync_music()

	call_deferred("_run_ending_sequence")

func _run_ending_sequence() -> void:
	await _move_camera_to_placement()
	await get_tree().create_timer(ENDING_HOLD_TIME).timeout

	if fade_rect:
		fade_rect.modulate.a = 0.0

	music_player.stream = end_music
	music_player.play()

	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(fade_rect, "modulate:a", 1.0, ENDING_FADE_TIME)
	await fade_tween.finished

	_ensure_ending_ui()
	ending_label.text = ending_dialogue
	ending_label.visible_ratio = 0.0
	ending_label.modulate.a = 1.0

	# Explicitly typed dialogue_time as a float to prevent Variant inference warning
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
	tween.tween_callback(_spawn_weasel)
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.2)

func _spawn_weasel() -> void:
	if not weasel_scene:
		return

	# Explicitly typed as Node to prevent Variant warning
	var boss: Node = weasel_scene.instantiate()
	get_tree().get_current_scene().add_child(boss)
	boss.global_position = global_position + Vector2(0, -2500)

	_register_boss(boss)

	print("Weasel boss spawned.")

func _on_sleep_pressed() -> void:
	if ending_sequence_started:
		return
	if popup_ui:
		popup_ui.hide_popup()

	_sleep_transition()

	if egg:
		egg.next_day()

	_start_day_timer()

func _on_buy_turret_pressed() -> void:
	if ending_sequence_started:
		return
	if not Resources.spend_cardboard(turret_cost):
		print("Not enough cardboard")
		return
	_upgrade_to_placement(turret_scene)
	placing_turret = true
	placement_stage = 1

func _on_buy_watchtower_pressed() -> void:
	if ending_sequence_started:
		return
	if not Resources.spend_cardboard(watchtower_cost):
		print("Not enough cardboard")
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

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("material") and body.in_range:
		deposit_item(body)

func deposit_item(item: Node) -> void:
	if item.is_in_group("material") and item.material_type == "cardboard":
		Resources.add_cardboard(item.material_amount)

	deposit_count += 1
	print("Items Deposited:", deposit_count)

	item.queue_free()

func _on_ui_hitbox_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		if popup_ui:
			popup_ui.show_buy_only()

func _on_ui_hitbox_body_exited(body: Node) -> void:
	if body and body.is_in_group("player"):
		if popup_ui:
			popup_ui.hide_popup()

func _on_interaction_area_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		if popup_ui:
			popup_ui.show_interaction(body)

func _on_interaction_area_body_exited(body: Node) -> void:
	if body and body.is_in_group("player"):
		if popup_ui:
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

	# Explicitly typed to prevent Variant inference warning
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

	print("Day started: 15 min timer")

func _on_day_timeout() -> void:
	if ending_sequence_started:
		return
	print("Day time over → forcing sleep")
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
