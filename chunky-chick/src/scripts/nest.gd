extends StaticBody2D

# --- Turret Placement ---
var placing_turret: bool = false
var ghost_turret: Node2D = null
var turret_scene := preload("res://src/tscn/Structures/turret.tscn")

# --- Deposit ---
var deposit_count := 0
@onready var hitbox_shape = $Hitbox.shape

# --- UI ---
@onready var popup_ui = $CanvasLayer/PopupUI
@onready var upgrade_ui = $"Upgrade-Layer/Upgrade-selec"
@onready var turret_buy_button = upgrade_ui.get_node("Turret/Turret-buy")

# --- Cameras & turret container ---
var main_camera
var placement_camera
@onready var turret_container = get_tree().get_current_scene().get_node("TurretContainer") 

func _ready():
	add_to_group("nest")
	print("Nest ready")
	
	# Connect UI signals
	popup_ui.continue_pressed.connect(_on_popup_continue)
	upgrade_ui.close_pressed.connect(_on_upgrade_closed)
	turret_buy_button.pressed.connect(_on_buy_turret_pressed)
	
	# Find cameras by group
	main_camera = get_tree().get_first_node_in_group("main_camera")
	placement_camera = get_tree().get_first_node_in_group("placement_camera")

# --- Popup UI callbacks ---
func _on_popup_continue():
	popup_ui.visible = false
	upgrade_ui.visible = true

func _on_upgrade_closed():
	upgrade_ui.visible = false

# --- Deposit handling ---
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

# --- Turret placement ---
func _process(delta):
	if placing_turret and ghost_turret:
		var mouse_pos: Vector2 = placement_camera.get_global_mouse_position()
		ghost_turret.global_position = mouse_pos

func _on_buy_turret_pressed():
	upgrade_ui.visible = false
	placement_camera.make_current()
	
	placing_turret = true
	ghost_turret = turret_scene.instantiate()
	ghost_turret.modulate = Color(1,1,1,0.5)
	turret_container.add_child(ghost_turret)

func _unhandled_input(event):
	if placing_turret and ghost_turret:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Place turret permanently
			ghost_turret.modulate = Color(1,1,1,1)
			ghost_turret = null
			placing_turret = false
			main_camera.make_current()
