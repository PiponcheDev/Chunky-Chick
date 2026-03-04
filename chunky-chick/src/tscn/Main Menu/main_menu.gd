extends Control



func _on_start_pressed() -> void:
	self.hide()
	#I know, lazy


func _on_settings_pressed() -> void:
	print(Settings.GAMMA)


func _on_credits_pressed() -> void:
	$Credits_scene.show()


func _on_quit_pressed() -> void:
	get_tree().quit()
