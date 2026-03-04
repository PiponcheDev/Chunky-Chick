extends Node2D


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("DebugButton"): #Simple debug button to check functionalities, change from E if you want
		print("Debug")
		print(GameData.currentlevel)
		$LoadingScreen._loadNextLevel()
