extends Area2D

signal food_collected

func _ready():
	body_entered.connect(_on_body_entered)
	add_to_group("food")

func _on_body_entered(body):
	if body.is_in_group("player"): 
		food_collected.emit()
		queue_free()
