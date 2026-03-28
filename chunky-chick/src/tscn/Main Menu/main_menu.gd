extends Control

@onready var main_tscn: String = "res://Main.tscn"
var is_transitioning: bool = false

func _ready() -> void:
	print("MENU: _ready()")
	print("MENU: current_run:", GameLoad.current_run)
	print("MENU: load_existing_run:", GameLoad.load_existing_run)
	print("MENU: loaded_from_save:", GameLoad.loaded_from_save)
	print("MENU: file exists:", GameLoad.has_saved_run())

func _start_game(use_saved_run: bool) -> void:
	if is_transitioning:
		print("MENU: transition already in progress")
		return

	is_transitioning = true
	print("MENU: _start_game(use_saved_run=", use_saved_run, ")")

	if use_saved_run:
		GameLoad.request_continue_run()
	else:
		GameLoad.request_new_run()

	print("MENU: after request -> current_run:", GameLoad.current_run)
	print("MENU: after request -> load_existing_run:", GameLoad.load_existing_run)
	print("MENU: after request -> loaded_from_save:", GameLoad.loaded_from_save)

	get_tree().change_scene_to_file(main_tscn)

func _on_start_pressed() -> void:
	print("MENU: start pressed")
	_start_game(false)

func _on_continue_pressed() -> void:
	print("MENU: continue pressed")
	if not GameLoad.has_saved_run():
		print("MENU: no saved run found, starting new game")
		_start_game(false)
		return
	_start_game(true)
