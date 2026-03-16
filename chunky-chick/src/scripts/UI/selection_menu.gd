extends Control

signal continue_pressed
signal sleep_pressed
signal feed_pressed

@onready var sleep_button: Button = $Sleep
@onready var buy_button: Button = $Continue
@onready var feed_button: Button = $Feed
@onready var player = get_tree().get_first_node_in_group("player")

func _ready():

	add_to_group("ui")

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


# --- UI Modes ---

func show_buy_only() -> void:
	visible = true
	buy_button.visible = true
	sleep_button.visible = false
	feed_button.visible = false


func show_interaction(player_node: Node = null) -> void:

	visible = true

	buy_button.visible = false
	sleep_button.visible = true

	var p = player_node if player_node != null else player

	if p != null and p.get("fatness") != null:
		feed_button.visible = p.fatness > 0
	else:
		feed_button.visible = false


func hide_popup() -> void:

	visible = false
	sleep_button.visible = false
	buy_button.visible = false
	feed_button.visible = false


# --- Button Handlers ---

func _on_continue_pressed() -> void:

	hide_popup()
	emit_signal("continue_pressed")


func _on_sleep_pressed() -> void:

	hide_popup()
	emit_signal("sleep_pressed")


func _on_feed_pressed() -> void:

	emit_signal("feed_pressed")
