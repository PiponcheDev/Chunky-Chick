extends Control

signal continue_pressed
signal sleep_pressed
signal feed_pressed

@onready var sleep_button: Button = $Sleep
@onready var buy_button: Button = $Continue
@onready var feed_button: Button = $Feed

var current_player: Node = null

func _ready():
	add_to_group("ui")
	visible = false
	if sleep_button: sleep_button.visible = false
	if buy_button: buy_button.visible = false
	if feed_button: feed_button.visible = false

	if buy_button:
		buy_button.pressed.connect(func(): continue_pressed.emit())
	if sleep_button:
		sleep_button.pressed.connect(func(): sleep_pressed.emit())
	if feed_button:
		feed_button.pressed.connect(func(): feed_pressed.emit())

# Simplified this function to handle the logic properly
func show_interaction(player: Node, demand_met: bool, is_night: bool):
	current_player = player
	visible = true

	# Buy button is hidden when near the egg (separate region logic)
	if buy_button:
		buy_button.visible = false

	# Sleep button ONLY shows if demand is met and it's not night
	if sleep_button:
		sleep_button.visible = demand_met and not is_night

	# Feed button ONLY shows if demand is NOT met and it's not night
	if feed_button:
		feed_button.visible = not demand_met and not is_night

func show_buy_only():
	visible = true
	if buy_button: buy_button.visible = true
	if sleep_button: sleep_button.visible = false
	if feed_button: feed_button.visible = false

func hide_popup():
	visible = false
	current_player = null

func update_visuals(demand_met: bool, is_night: bool):
	# This keeps the buttons updated in real-time if the menu is open
	if feed_button:
		feed_button.visible = not is_night and not demand_met
	if sleep_button:
		sleep_button.visible = not is_night and demand_met
