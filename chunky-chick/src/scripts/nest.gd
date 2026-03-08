extends Node2D

# --- Placement & Turret ---
var placing_turret: bool = false
var ghost_turret: Node2D = null
var placement_stage := 0
var placing_watchtower := false

var turret_cost := 1
var watchtower_cost := 1
var turret_scene := preload("res://src/tscn/Structures/turret.tscn")
var watchtower_scene := preload("res://src/tscn/Structures/watch_tower.tscn")

# --- Deposit ---
var deposit_count := 0

# --- Node references ---
@onready var popup_ui = $CanvasLayer/PopupUI
@onready var upgrade_ui = $"Upgrade-Layer/Upgrade-selec"
@onready var pc = $"Placement-camera"
@onready var turret_buy_button = upgrade_ui.get_node("Turret/Turret-buy")
@onready var watchtower_buy_button = upgrade_ui.get_node("WatchTower/WatchTower-buy")
@onready var turret_container = get_tree().get_current_scene().get_node("TurretContainer") 
@onready var hitbox_area = $Hitbox  # Area2D for deposits

# --- Cameras ---
var main_camera
var placement_camera

func _ready():
	pc.add_to_group("placement_camera")
	add_to_group("nest")
	print("Nest ready")
	
	popup_ui.continue_pressed.connect(_on_popup_continue)
	upgrade_ui.close_pressed.connect(_on_upgrade_closed)
	turret_buy_button.pressed.connect(_on_buy_turret_pressed)
	watchtower_buy_button.pressed.connect(_on_buy_watchtower_pressed)
	
	# Cameras
	main_camera = get_tree().get_nodes_in_group("main_camera")[0]
	placement_camera = get_tree().get_nodes_in_group("placement_camera")[0]
	if main_camera:
		main_camera.make_current()
	
	# Connect Area2D signals for deposits
	hitbox_area.body_entered.connect(_on_hitbox_body_entered)

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
	placement_camera.make_current()
	ghost_turret = scene.instantiate()
	ghost_turret.modulate = Color(1,1,1,0.5)
	turret_container.add_child(ghost_turret)
	if ghost_turret.has_method("enable_preview"):
		ghost_turret.enable_preview()

# --- UI Callbacks ---
func _on_popup_continue():
	popup_ui.visible = false
	upgrade_ui.visible = true

func _on_upgrade_closed():
	upgrade_ui.visible = false

# --- Deposit Handling via Area2D ---
func _on_hitbox_body_entered(body):
	if body.is_in_group("material") and body.in_range:
		deposit_item(body)

func deposit_item(item):
	if item.is_in_group("material") and item.material_type == "cardboard":
		Resources.add_cardboard(item.material_amount)
	deposit_count += 1
	print("Items Deposited:", deposit_count)
	item.queue_free()

# --- Process Turret Placement ---
func _process(delta):
	if not ghost_turret:
		return
	var mouse_pos = placement_camera.get_global_mouse_position()
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
