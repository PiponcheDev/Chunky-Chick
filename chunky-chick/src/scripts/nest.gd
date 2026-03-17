extends Node2D

# --- Timer & Day ---

var day_timer: Timer
var DAY_DURATION := 900.0  # 15 minutes

# --- Placement & Turret ---
var placing_turret: bool = false
var ghost_turret: Node2D = null
var placement_stage := 0
var placing_watchtower := false

var turret_cost := 1
var watchtower_cost := 1
var turret_scene := preload("res://src/tscn/Structures/turret.tscn")
var watchtower_scene := preload("res://src/tscn/Structures/watch_tower.tscn")

# --- Boss ---
var weasel_scene := preload("res://src/tscn/enemy/Bosses/Weasel/weasel_boss.tscn")

# --- Deposit ---
var deposit_count := 0

# --- Node references ---
@onready var popup_ui = $CanvasLayer/PopupUI
@onready var upgrade_ui = $"Upgrade-Layer/Upgrade-selec"
@onready var pc = $"Placement-camera"
@onready var turret_buy_button = upgrade_ui.get_node("Turret/Turret-buy")
@onready var watchtower_buy_button = upgrade_ui.get_node("WatchTower/WatchTower-buy")
@onready var turret_container = get_tree().get_current_scene().get_node("TurretContainer") 
@onready var hitbox_area = $Hitbox

@onready var ui_hitbox_area = $"UI-hitbox"
@onready var interaction_area = $Egg/InteractionArea

# --- Cameras ---
var main_camera
var placement_camera

# --- Fade layer ---
var fade_rect : ColorRect
var fade_layer : CanvasLayer

func _ready():
	pc.add_to_group("placement_camera")
	add_to_group("nest")

	print("Nest ready")

	# popup / upgrade UI wiring
	if popup_ui:
		popup_ui.continue_pressed.connect(_on_popup_continue)
		popup_ui.sleep_pressed.connect(_on_sleep_pressed)

	if upgrade_ui:
		upgrade_ui.close_pressed.connect(_on_upgrade_closed)

	if turret_buy_button:
		turret_buy_button.pressed.connect(_on_buy_turret_pressed)

	if watchtower_buy_button:
		watchtower_buy_button.pressed.connect(_on_buy_watchtower_pressed)

	# Cameras
	var cams = get_tree().get_nodes_in_group("main_camera")
	if cams.size() > 0:
		main_camera = cams[0]
		main_camera.make_current()

	placement_camera = get_tree().get_nodes_in_group("placement_camera")[0] if get_tree().get_nodes_in_group("placement_camera").size() > 0 else null

	# Deposit signals
	if hitbox_area:
		hitbox_area.body_entered.connect(_on_hitbox_body_entered)

	if ui_hitbox_area:
		ui_hitbox_area.body_entered.connect(_on_ui_hitbox_body_entered)
		ui_hitbox_area.body_exited.connect(_on_ui_hitbox_body_exited)

	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	_create_fade_layer()
	
	#Timers
	_start_day_timer()


# ---------------------------
# Fade Layer
# ---------------------------

func _create_fade_layer():
	fade_layer = CanvasLayer.new()
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


func _sleep_transition():
	var tween = create_tween()

	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.2)

	tween.tween_callback(_spawn_weasel)

	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.2)


func _spawn_weasel():
	if not weasel_scene:
		return

	var boss = weasel_scene.instantiate()

	get_tree().get_current_scene().add_child(boss)

	boss.global_position = global_position + Vector2(0, -2500)

	print("Weasel boss spawned.")


# ---------------------------
# Sleep
# ---------------------------

func _on_sleep_pressed():
	if popup_ui:
		popup_ui.hide_popup()

	_sleep_transition()

	var egg = get_tree().get_first_node_in_group("egg")
	if egg:
		egg.next_day()

	_start_day_timer()


# --- Turret Placement ---
func _on_buy_turret_pressed():
	if not Resources.spend_cardboard(turret_cost):
		print("Not enough cardboard")
		return
	_upgrade_to_placement(turret_scene)
	placing_turret = true
	placement_stage = 1

func _on_buy_watchtower_pressed():
	if not Resources.spend_cardboard(watchtower_cost):
		print("Not enough cardboard")
		return
	_upgrade_to_placement(watchtower_scene)
	placing_watchtower = true

func _upgrade_to_placement(scene):
	upgrade_ui.visible = false
	if placement_camera:
		placement_camera.make_current()

	ghost_turret = scene.instantiate()
	ghost_turret.modulate = Color(1,1,1,0.5)

	turret_container.add_child(ghost_turret)

	if ghost_turret.has_method("enable_preview"):
		ghost_turret.enable_preview()


# --- UI Callbacks ---
func _on_popup_continue():
	if popup_ui:
		popup_ui.visible = false
	upgrade_ui.visible = true

func _on_upgrade_closed():
	upgrade_ui.visible = false


# --- Deposit Handling ---
func _on_hitbox_body_entered(body):
	if body.is_in_group("material") and body.in_range:
		deposit_item(body)

func deposit_item(item):
	if item.is_in_group("material") and item.material_type == "cardboard":
		Resources.add_cardboard(item.material_amount)

	deposit_count += 1
	print("Items Deposited:", deposit_count)

	item.queue_free()


# --- UI / Interaction ---
func _on_ui_hitbox_body_entered(body):
	if body and body.is_in_group("player"):
		if popup_ui:
			popup_ui.show_buy_only()

func _on_ui_hitbox_body_exited(body):
	if body and body.is_in_group("player"):
		if popup_ui:
			popup_ui.hide_popup()

func _on_interaction_area_body_entered(body):
	if body and body.is_in_group("player"):
		if popup_ui:
			popup_ui.show_interaction(body)

func _on_interaction_area_body_exited(body):
	if body and body.is_in_group("player"):
		if popup_ui:
			popup_ui.hide_popup()


# --- Placement Process ---
func _process(delta):
	if not ghost_turret:
		return

	var mouse_pos = placement_camera.get_global_mouse_position() if placement_camera else Vector2.ZERO

	if placing_turret:
		if placement_stage == 1:
			ghost_turret.global_position = mouse_pos
		elif placement_stage == 2:
			if ghost_turret.has_method("rotate_head_towards"):
				ghost_turret.rotate_head_towards(mouse_pos)

	elif placing_watchtower:
		ghost_turret.global_position = mouse_pos


func _unhandled_input(event):
	if not ghost_turret:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

		if placing_turret:

			if placement_stage == 1:
				placement_stage = 2

			elif placement_stage == 2:

				ghost_turret.modulate = Color(1,1,1,1)

				if ghost_turret.has_method("lock_head_rotation"):
					ghost_turret.lock_head_rotation()

				_reset_placement()

		elif placing_watchtower:

			ghost_turret.modulate = Color(1,1,1,1)

			if ghost_turret.has_method("finalize_placement"):
				ghost_turret.finalize_placement()

			_reset_placement()


func _reset_placement():
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

func _start_day_timer():
	day_timer = Timer.new()
	day_timer.wait_time = DAY_DURATION
	day_timer.one_shot = true
	day_timer.timeout.connect(_on_day_timeout)
	add_child(day_timer)
	day_timer.start()

	print("Day started: 15 min timer")


func _on_day_timeout():
	print("Day time over → forcing sleep")
	_force_sleep()

func _force_sleep():
	if popup_ui:
		popup_ui.hide_popup()

	_sleep_transition()

	# advance day
	var egg = get_tree().get_first_node_in_group("egg")
	if egg:
		egg.next_day()

	_start_day_timer()
