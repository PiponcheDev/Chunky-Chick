extends Control

@onready var main_tscn: String = "res://Main.tscn"
@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer

var music: Dictionary = {
	1: preload("res://Assets/Audio/Start/Beginning fat biird beginnings.mp3"),
	2: preload("res://Assets/Audio/Mid/Middle fat biird beginnings.mp3")
}

var current_music_mode: StringName = &"intro"
var is_transitioning: bool = false

func _ready() -> void:
	check_save()
	_play_music()

	print("MENU: _ready()")
	print("MENU: current_run:", GameLoad.current_run)
	print("MENU: load_existing_run:", GameLoad.load_existing_run)
	print("MENU: loaded_from_save:", GameLoad.loaded_from_save)
	print("MENU: file exists:", GameLoad.has_saved_run())

func _play_music() -> void:
	var intro: AudioStream = music.get(1, null)
	if intro:
		current_music_mode = &"intro"
		music_player.stream = intro
		music_player.play()
		music_player.finished.connect(_on_music_finished)

func _on_music_finished() -> void:
	if current_music_mode == &"intro":
		var mid: AudioStream = music.get(2, null)
		if mid:
			current_music_mode = &"mid"
			music_player.stream = mid
			music_player.play()
	elif current_music_mode == &"mid":
		# loop mid forever
		var mid: AudioStream = music.get(2, null)
		if mid:
			music_player.stream = mid
			music_player.play()

func check_save() -> void:
	if GameLoad.has_saved_run() == false:
		$Continue.visible = false
		$Start.set_position($Continue.position, false)
	else:
		$Continue.visible = true

func _start_game(use_saved_run: bool) -> void:
	if is_transitioning:
		print("MENU: transition already in progress")
		return

	is_transitioning = true
	print("MENU: _start_game(use_saved_run=", use_saved_run, ")")

	# 🔴 Abrupt stop (your requirement)
	music_player.stop()

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
	if GameLoad.has_saved_run():
		GameLoad.destroy_save_file()
	_start_game(false)

func _on_continue_pressed() -> void:
	print("MENU: continue pressed")
	if not GameLoad.has_saved_run():
		print("MENU: no saved run found, starting new game")
		_start_game(false)
		return
	_start_game(true)

func _on_quit_pressed():
	get_tree().quit()
