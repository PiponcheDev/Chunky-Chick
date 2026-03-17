extends Control

signal continue_pressed
signal sleep_pressed
signal feed_pressed

@onready var sleep_button: Button = $Sleep
@onready var buy_button: Button = $Continue
@onready var feed_button: Button = $Feed

var current_player: Node = null
var egg: Node = null


func _ready():

	add_to_group("ui")

	egg = get_tree().get_first_node_in_group("egg")

	visible = false
	sleep_button.visible = false
	buy_button.visible = false
	feed_button.visible = false

	if buy_button:
		buy_button.pressed.connect(_on_continue_pressed)

	if sleep_button:
		sleep_button.pressed.connect(_on_sleep_pressed)

	if feed_button:
		feed_button.pressed.connect(_on_feed_pressed)


# -------------------
# UI Modes
# -------------------

func show_buy_only() -> void:
	visible = true
	buy_button.visible = true
	sleep_button.visible = false
	feed_button.visible = false


func show_interaction(player_node: Node = null, can_sleep: bool = false) -> void:

	visible = true

	buy_button.visible = false
	sleep_button.visible = can_sleep

	current_player = player_node

	if current_player != null:
		feed_button.visible = current_player.fatness > 0
	else:
		feed_button.visible = false


func hide_popup() -> void:

	visible = false
	sleep_button.visible = false
	buy_button.visible = false
	feed_button.visible = false


# -------------------
# Button Handlers
# -------------------

func _on_continue_pressed() -> void:

	hide_popup()
	emit_signal("continue_pressed")


func _on_sleep_pressed() -> void:

	hide_popup()
	emit_signal("sleep_pressed")


func _on_feed_pressed() -> void:

	if not current_player:
		print("No player reference!")
		return

	if not egg:
		egg = get_tree().get_first_node_in_group("egg")
		if not egg:
			print("No egg found!")
			return

	var feed_amount = min(10.0, current_player.fatness)

	if feed_amount <= 0:
		print("No fatness to feed")
		return

	# ✅ apply feeding
	current_player.fatness -= feed_amount
	egg.add_food(feed_amount)

	print("Fed:", feed_amount)

	# ✅ refresh UI state after feeding
	show_interaction(current_player, egg.is_demand_met())
