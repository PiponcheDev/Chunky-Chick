extends Node

var fatness := 0.0
var MAX_FATNESS := 100.0

func _ready() -> void:
	call_deferred("connect_to_food")

func connect_to_food():
	for food in get_tree().get_nodes_in_group("food"):
		print("Found food: ", food.name)
		food.food_collected.connect(_on_food_collected)

func _on_food_collected():
	fatness = min(MAX_FATNESS, fatness + 10)
	print("Ate food! Fatness: ", fatness)
