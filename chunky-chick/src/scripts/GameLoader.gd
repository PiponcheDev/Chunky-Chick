extends Node
class_name GameLoader

const RUN_SAVE_PATH = "res://runs/prev_run.tres"

var current_run : RunData

func _ready():
	load_run()

func start_new_run():
	current_run = RunData.new()
	save_run()

func load_run():
	if ResourceLoader.exists(RUN_SAVE_PATH):
		current_run = load(RUN_SAVE_PATH)
	else:
		start_new_run()

func save_run():
	ResourceSaver.save(current_run, RUN_SAVE_PATH)

func apply_run_to_player(player):
	if current_run == null:
		return
	player.fatness = current_run.fatness
	for talisman in current_run.talismans:
		player.collect_talisman(talisman, true)
