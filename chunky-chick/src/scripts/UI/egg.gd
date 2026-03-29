extends Area2D

signal stage_changed(stage: int)
signal demand_completed

@onready var ui = get_tree().get_first_node_in_group("ui")
@onready var stage_1 = $"../Node2D/1-stage"
@onready var stage_2 = $"../Node2D/2-stage"
@onready var stage_3 = $"../Node2D/3-stage"
@onready var stage_4 = $"../Node2D/4-stage"
@onready var stage_5 = $"../Node2D/5-stage"

var day: int = 1
var demand: float = 15
var current_progress: float = 0
var egg_stage: int = 1

func _ready():
	add_to_group("egg")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_demand()
	_update_stage_visibility()
	stage_changed.emit(egg_stage)
	if is_ending(egg_stage):
		print("run is finished")

func _on_body_entered(body):
	if body.is_in_group("player") and ui:
		ui.show_interaction(body, is_demand_met())

func _on_body_exited(body):
	if body.is_in_group("player") and ui:
		ui.hide_popup()

func _update_demand():
	if day <= 5:
		demand = 30 + day * 10
	else:
		demand = 80 * pow(1.12, day - 5)

	current_progress = 0

	print("Day:", day, " Demand:", demand)

func _update_stage_visibility():
	stage_1.visible = egg_stage == 1
	stage_2.visible = egg_stage == 2
	stage_3.visible = egg_stage == 3
	stage_4.visible = egg_stage == 4
	stage_5.visible = egg_stage == 5

func is_ending(current_stage: int) -> bool:
	return current_stage >= 5

func add_food(amount: float):
	current_progress += amount

	print("Progress:", current_progress, "/", demand)

	if current_progress >= demand:
		current_progress = demand
		emit_signal("demand_completed")

func is_demand_met() -> bool:
	return current_progress >= demand

func next_day():
	if is_demand_met() and egg_stage < 5:
		egg_stage += 1
		_update_stage_visibility()
		stage_changed.emit(egg_stage)
	day += 1
	_update_demand()
	if is_ending(egg_stage):
		print("run is finished")
