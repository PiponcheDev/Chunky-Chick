extends Area2D

signal stage_changed(stage: int)
signal demand_completed

@onready var ui = get_tree().get_first_node_in_group("ui")
@onready var stages: Array[Node2D] = [
	$"../Node2D/1-stage",
	$"../Node2D/2-stage",
	$"../Node2D/3-stage",
	$"../Node2D/4-stage",
	$"../Node2D/5-stage"
]

var day: int = 1
var demand: float = 1.0
var current_progress: float = 0.0
var egg_stage: int = 1
var demand_met: bool = false
var is_night: bool = false

func _ready():
	call_deferred("_initialize_from_save")

func capture_into_run_data(run: RunData) -> void:
	if run == null:
		return
	run.curr_day = day
	run.egg_stage = egg_stage
	run.egg_demand = demand
	run.egg_progress = current_progress 
	run.is_night = is_night 
	run.is_day = not is_night

func apply_loaded_state(run: RunData) -> void:
	if run == null:
		return

	day = run.curr_day
	egg_stage = run.egg_stage
	demand = run.egg_demand
	current_progress = run.egg_progress 
	is_night = run.is_night 
	demand_met = (current_progress >= demand)

	_update_stage_visibility()

func _initialize_from_save():
	if GameLoad != null and GameLoad.current_run != null and GameLoad.loaded_from_save:
		await get_tree().process_frame
		apply_loaded_state(GameLoad.current_run)
	else:
		_update_demand()
		_update_stage_visibility()

func _update_demand():
	if day <= 5:
		demand = 1.0
	else:
		demand = 80 * pow(1.12, day - 5)

func _update_stage_visibility():
	for i in range(stages.size()):
		if stages[i]:
			stages[i].visible = (egg_stage == i + 1)
	stage_changed.emit(egg_stage)

func add_food(amount: float):
	if is_night or demand_met:
		return

	current_progress += amount
	if current_progress >= demand:
		current_progress = demand
		demand_met = true
		demand_completed.emit()
	
	if ui and ui.visible:
		ui.update_visuals(demand_met, is_night)

func next_day():
	day += 1
	is_night = true 
	
	if demand_met and egg_stage < 5:
		egg_stage += 1

	current_progress = 0.0
	demand_met = false
	_update_demand()
	_update_stage_visibility()

func is_demand_met() -> bool:
	return demand_met
