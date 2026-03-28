extends Node
class_name GameLoader

signal continue_requested
signal new_run_requested

const RUN_SAVE_PATH: String = "user://runs/prev_run.tres"

var current_run: RunData = null
var load_existing_run: bool = false
var loaded_from_save: bool = false
var data_initialized: bool = false


func _ready() -> void:
	print("LOADER: _ready()")
	print("LOADER: save path:", RUN_SAVE_PATH)
	print("LOADER: global path:", ProjectSettings.globalize_path(RUN_SAVE_PATH))
	print("LOADER: file exists on boot:", has_saved_run())


func has_save_file() -> bool:
	return FileAccess.file_exists(RUN_SAVE_PATH) and ResourceLoader.exists(RUN_SAVE_PATH)


func has_saved_run() -> bool:
	return has_save_file()


func destroy_save_file() -> bool:
	if not has_save_file():
		return false

	var abs_path := ProjectSettings.globalize_path(RUN_SAVE_PATH)
	var err: int = DirAccess.remove_absolute(abs_path)
	if err != OK:
		push_error("Failed to delete save file: %s (error %d)" % [abs_path, err])
		return false

	return true


func request_new_run() -> void:
	load_existing_run = false
	loaded_from_save = false
	current_run = RunData.new()
	data_initialized = true
	new_run_requested.emit()


func request_continue_run() -> void:
	if not has_save_file():
		request_new_run()
		return

	var loaded: Resource = ResourceLoader.load(RUN_SAVE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	if loaded is RunData:
		current_run = (loaded as RunData).duplicate(true) as RunData
		load_existing_run = true
		loaded_from_save = true
		data_initialized = true
		continue_requested.emit()
		return

	request_new_run()


func save_current_state(player: Node = null, egg: Node = null) -> void:
	if current_run == null or not data_initialized:
		return

	var p: Node = player if player != null else get_tree().get_first_node_in_group("player")
	var e: Node = egg if egg != null else get_tree().get_first_node_in_group("egg")
	var n: Node = get_tree().get_first_node_in_group("nest")

	if p != null and p.has_method("capture_into_run_data"):
		p.capture_into_run_data(current_run)
	if e != null and e.has_method("capture_into_run_data"):
		e.capture_into_run_data(current_run)
	if n != null and n.has_method("capture_into_run_data"):
		n.capture_into_run_data(current_run)

	save_run()


func save_run() -> void:
	if current_run == null:
		return

	DirAccess.make_dir_recursive_absolute("user://runs")
	ResourceSaver.save(current_run, RUN_SAVE_PATH)


func apply_run_to_player(player: Node) -> void:
	if current_run == null or player == null:
		return
	if player.has_method("apply_run_data"):
		player.apply_run_data(current_run)


func apply_run_to_egg(egg: Node) -> void:
	if current_run == null or egg == null:
		return
	if egg.has_method("apply_loaded_state"):
		egg.apply_loaded_state(current_run)


func apply_run_to_nest(nest: Node) -> void:
	if current_run == null or nest == null:
		return
	if nest.has_method("apply_run_data"):
		nest.apply_run_data(current_run)
