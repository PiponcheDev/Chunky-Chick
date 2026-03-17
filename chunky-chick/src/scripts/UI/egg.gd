extends Area2D

@onready var ui = get_tree().get_first_node_in_group("ui")

var day: int = 1
var demand: float = 15
var current_progress: float = 0

signal demand_completed

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_update_demand()


# -------------------
# Interaction
# -------------------

func _on_body_entered(body):
	if body.is_in_group("player") and ui:
		ui.show_interaction(body, is_demand_met())


func _on_body_exited(body):
	if body.is_in_group("player") and ui:
		ui.hide_popup()


# -------------------
# Demand System
# -------------------

func _update_demand():
	if day <= 5:
		demand = 30 + day * 10
	else:
		demand = 80 * pow(1.12, day - 5)

	current_progress = 0

	print("Day:", day, " Demand:", demand)


func add_food(amount: float):
	current_progress += amount
	
	print("Progress:", current_progress, "/", demand)

	if current_progress >= demand:
		current_progress = demand
		emit_signal("demand_completed")


func is_demand_met() -> bool:
	return current_progress >= demand


func next_day():
	day += 1
	_update_demand()
