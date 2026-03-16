extends Area2D

@onready var ui = get_tree().get_first_node_in_group("ui")

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player") and ui:
		ui.show_interaction(body)

func _on_body_exited(body):
	if body.is_in_group("player") and ui:
		ui.hide_popup()
