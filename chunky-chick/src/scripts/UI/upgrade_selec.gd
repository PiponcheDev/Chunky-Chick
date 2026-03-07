extends Control

signal close_pressed

@onready var close_button = $Close

func _ready():
	visible = false
	close_button.pressed.connect(_on_close_pressed)

func _on_close_pressed():
	visible = false
	emit_signal("close_pressed")

func hide_popup():
	visible = false


func _on_u_ihitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		hide_popup()
