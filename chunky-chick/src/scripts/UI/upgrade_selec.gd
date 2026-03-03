extends Control

signal close_pressed

@onready var close_button = $Close

func _ready():
	visible = false
	close_button.pressed.connect(_on_close_pressed)

func _on_close_pressed():
	visible = false
	emit_signal("close_pressed")
