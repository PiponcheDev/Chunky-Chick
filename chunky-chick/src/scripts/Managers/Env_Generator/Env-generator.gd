extends Node2D

func _ready():
	_generate_map()


@export var Mapsize :Vector2 = Vector2(100,100)
@export var OriginOffset : Vector2 = Vector2(0,0)
#Describes how the map shall be generated around the origin of the node.

@export_subgroup("Frequencies")
@export var itemFrequency = 10
@export var talismanFrequency = 0
@export var foodFrequency = 10
#Per 100 pixels on a line, in theory...
var FrequencyRandomness = 3

@export_subgroup("Lists")
@export var items : Array[SpringBoneCollisionCapsule3D] 
@export var talismen : Array[SpringBoneCollisionCapsule3D] 
@export var foods : Array[SpringBoneCollisionCapsule3D] 
#Obviously needs to be changed to the correct data structure

var currentClumpPos:Vector2 = Vector2(0,0)
var currentClumpWeight:int = 0
#How many spawns are currently in the clump
var clumpCapacity = 5
#How many spawns fits in a clump
var clumpDensity = 5
#How close to the center the spawns are

func _generate_map():
	var i = 0
	while i < _get_AmountOFSpawns(itemFrequency):
		print("Items Spawned: "+str(i))
		print(getSpawnposInClump())
		print(currentClumpPos)
		print(currentClumpWeight)
		i += 1
	
	i = 0
	while i < _get_AmountOFSpawns(talismanFrequency):
		print("Talimen Spawned: "+str(i))
		i += 1
		
	i = 0
	while i < _get_AmountOFSpawns(foodFrequency):
		print("Foods Spawned: "+str(i))
		i += 1

func getSpawnposInClump():
	if randi_range(0,clumpCapacity-currentClumpWeight) > 0:
		currentClumpWeight += 1
		return currentClumpPos + _get_randomSpotInZone(Vector2(clumpDensity,clumpDensity))
	else:
		currentClumpPos = _get_randomSpotInZone(Mapsize,false)
		currentClumpWeight = 1
		return currentClumpPos + _get_randomSpotInZone(Vector2(clumpDensity,clumpDensity))


func _get_randomSpotInZone(area:Vector2, centered:bool = true):
	if centered:
		return Vector2(randi_range(-area.x,area.x),randi_range(-area.y,area.y))
	else:
		return Vector2(randi_range(0,area.x),randi_range(0,area.y))

func _get_AmountOFSpawns(Frequency):
	var amountOfSpawns = (Mapsize.x+Mapsize.y)/(Frequency + randi_range(-FrequencyRandomness,FrequencyRandomness))
	return amountOfSpawns
