extends StaticBody2D

var placing_turret: bool = false
var ghost_turret: Node2D = null
var turret_scene := preload("res://src/tscn/Structures/turret.tscn")
var placement_stage := 0

var watchtower_scene := preload("res://src/tscn/Structures/watch_tower.tscn")
var placing_watchtower := false

var deposit_count := 0
@onready var hitbox_shape = $Hitbox.shape

@onready var popup_ui = $CanvasLayer/PopupUI
@onready var upgrade_ui = $"Upgrade-Layer/Upgrade-selec"
@onready var turret_buy_button = upgrade_ui.get_node("Turret/Turret-buy")
@onready var watchtower_buy_button = upgrade_ui.get_node("WatchTower/WatchTower-buy")

var main_camera
var placement_camera
@onready var turret_container = get_tree().get_current_scene().get_node("TurretContainer") 

func _ready():
	add_to_group("nest")
	print("Nest ready")
	
	popup_ui.continue_pressed.connect(_on_popup_continue)
	upgrade_ui.close_pressed.connect(_on_upgrade_closed)
	turret_buy_button.pressed.connect(_on_buy_turret_pressed)
	watchtower_buy_button.pressed.connect(_on_buy_watchtower_pressed)
	
	main_camera = get_tree().get_first_node_in_group("main_camera")
	placement_camera = get_tree().get_first_node_in_group("placement_camera")

func _on_buy_watchtower_pressed():
	upgrade_ui.visible = false
	placement_camera.make_current()
	placing_watchtower = true
	ghost_turret = watchtower_scene.instantiate()
	ghost_turret.modulate = Color(1,1,1,0.5)
	turret_container.add_child(ghost_turret)
	ghost_turret.enable_preview()

func _on_popup_continue():
	popup_ui.visible = false
	upgrade_ui.visible = true

func _on_upgrade_closed():
	upgrade_ui.visible = false

func try_deposit(item):
	if hitbox_shape is RectangleShape2D:
		var rect := Rect2(global_position - hitbox_shape.extents, hitbox_shape.extents * 2)
		if rect.has_point(item.global_position):
			deposit_item(item)
	elif hitbox_shape is CircleShape2D:
		if item.global_position.distance_to(global_position) <= hitbox_shape.radius:
			deposit_item(item)

func deposit_item(item):
	deposit_count += 1
	print("Items Deposited: ", deposit_count)
	item.queue_free()

func _process(delta):
	if not ghost_turret:
		return
	var mouse_pos: Vector2 = placement_camera.get_global_mouse_position()
	if placing_turret:
		if placement_stage == 1:
			ghost_turret.global_position = mouse_pos
		elif placement_stage == 2:
			ghost_turret.rotate_head_towards(mouse_pos)
	elif placing_watchtower:
		ghost_turret.global_position = mouse_pos

func _on_buy_turret_pressed():
	upgrade_ui.visible = false
	placement_camera.make_current()
	placing_turret = true
	placement_stage = 1
	ghost_turret = turret_scene.instantiate()
	ghost_turret.modulate = Color(1,1,1,0.5)
	turret_container.add_child(ghost_turret)
	ghost_turret.enable_preview()

func _unhandled_input(event):
	if not ghost_turret:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if placing_turret:
			if placement_stage == 1:
				placement_stage = 2
			elif placement_stage == 2:
				ghost_turret.modulate = Color(1,1,1,1)
				ghost_turret.lock_head_rotation()
				ghost_turret = null
				placing_turret = false
				placement_stage = 0
				main_camera.make_current()
		elif placing_watchtower:
			ghost_turret.modulate = Color(1,1,1,1)
			ghost_turret.finalize_placement()
			ghost_turret = null
			placing_watchtower = false
			main_camera.make_current()
