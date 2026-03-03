extends Control

signal continue_pressed

@onready var label = $Label
@onready var continue_button = $Continue
@onready var guide = $Guide
@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	if player:
		guide.visible = player.carried_item != null
		player.carried_item_changed.connect(_on_carried_item_changed)
	else:
		guide.visible = false

func show_message(text: String):
	label.text = text
	visible = true

func hide_popup():
	visible = false

func _on_continue_pressed():
	hide_popup()
	emit_signal("continue_pressed")

func _on_carried_item_changed(is_carrying: bool):
	guide.visible = is_carrying
