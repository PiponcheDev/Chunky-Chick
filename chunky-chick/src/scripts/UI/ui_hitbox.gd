extends Area2D

var popup
var upgrade

func _ready():
	popup = get_tree().current_scene.get_node("Nest/CanvasLayer/PopupUI")
	print(popup)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	print("test")
	if body.is_in_group("player"):
		print("player test")

func _on_body_exited(body):
	if body.is_in_group("player"):
		popup.hide_popup()
