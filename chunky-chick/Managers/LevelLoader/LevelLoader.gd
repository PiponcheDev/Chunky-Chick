extends Control

var loading:bool = false
var finishedLoadingStandby:bool = false

#The possible levels stored under one name

var level0 : Array [String] = ["res://Assets/Levels/Example1/GenericLevel1.tscn"]
var level1 : Array [String] = ["res://Assets/Levels/Example2/GenericLevel2.tscn"]
#Of course you add more here as more get created


#A reference to al the above level packets
var allLevels : Array[Array] = [level0,level1]


var nextlevel :String
func _process(delta: float) -> void:
	if loading:
		var progress:Array = []
		var status = ResourceLoader.load_threaded_get_status(nextlevel, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			print("Levelloading Finished")
			finishedLoadingStandby = true

func _loadNextLevel() -> void:
	self.show()
	nextlevel = allLevels.get(GameData.currentlevel).pick_random() #Picks random of the preset levels
	if nextlevel:
		if (ResourceLoader.has_cached(nextlevel)):
			ResourceLoader.load_threaded_get(nextlevel)
		else:
			ResourceLoader.load_threaded_request(nextlevel,"",true)
			loading = true
	else:
		push_warning("Ran out of levels") 
		#This should not happen during gameplay, but now you know why you get an error
	$Downtime_Timer.start()


func _on_downtime_timer_timeout() -> void:
	print("Mandatory time done")
	await finishedLoadingStandby == true
	print("Change")
	var newLevelScene = ResourceLoader.load_threaded_get(nextlevel)
	get_tree().change_scene_to_packed(newLevelScene)
