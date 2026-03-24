extends Node2D

func _ready():
	_setup_spawnzones()
	var zone = item_spawn_zones.pick_random()
	currentClumpPos = _get_randomSpotInZone(zone.shape.size,false) + zone.position + zone.get_parent().position - Vector2(zone.shape.size.x/2,zone.shape.size.y/2)
	_generate_map()


@export var Mapsize :Vector2 = Vector2(100,100)
@export var OriginOffset : Vector2 = Vector2(0,0)
#Describes how the map shall be generated around the origin of the node.
@export var UseSpawnZones : bool = true

@export_subgroup("Frequencies")
@export var itemFrequency = 10
@export var talismanFrequency = 0
@export var foodFrequency = 10
@export var trashcanFrequency = 10
@export var dumpsterFrequency = 10
#Per 100 pixels on a line, in theory...
var FrequencyRandomness = 3

@export_subgroup("Lists")
@export var items : Array[PackedScene] = [preload("uid://crykqrn4dikhk")]
@export var talismen : Array[SpringBoneCollisionCapsule3D] 
@export var foods : Array[SpringBoneCollisionCapsule3D] 
@export var trashCans : Array[SpringBoneCollisionCapsule3D] 
@export var dumpsters : Array[SpringBoneCollisionCapsule3D] 
#Obviously needs to be changed to the correct data structure

@export_subgroup("Clumps")
var currentClumpPos:Vector2 = Vector2(0,0)
var currentClumpWeight:int = 0
#How many spawns are currently in the clump
@export var clumpCapacity = 5
#How many spawns fits in a clump
@export var clumpDensity = 5
#How close to the center the spawns are
var amountOfClumps = 0


var item_spawn_zones :Array[CollisionShape2D]= []
var talimen_spawn_zones :Array[CollisionShape2D]= []
var food_spawn_zones :Array[CollisionShape2D]= []
var trashcan_spawn_zones :Array[CollisionShape2D]= []
var dumpster_spawn_zones :Array[CollisionShape2D]= []

func _setup_spawnzones():
	for child in self.get_children():
		if child is Area2D:
			print(child)
			if child.items:
				item_spawn_zones.append(child.get_child(0))
				print(child.get_child(0))
			if child.foods:
				food_spawn_zones.append(child.get_child(0))
			if child.talimen:
				talimen_spawn_zones.append(child.get_child(0))
			if child.trashcans:
				trashcan_spawn_zones.append(child.get_child(0))
			if child.dumpsters:
				dumpster_spawn_zones.append(child.get_child(0))
	print(item_spawn_zones)


func _generate_map():
	spawn_object(item_spawn_zones,itemFrequency)
	#spawn_object(talimen_spawn_zones,talismanFrequency)
	#spawn_object(food_spawn_zones,foodFrequency)


func spawn_object(spawn_zones, Frequency):
	var i = 0
	while i < _get_AmountOFSpawns(Frequency):
		#print("Items Spawned: "+str(i))
		var spawnPos = getSpawnposInClump(spawn_zones)
		
		var newitem = items.pick_random().instantiate()
		newitem.global_position = spawnPos
		self.add_child(newitem)
		
		print("spawnpos:" + str(spawnPos))
	#	print(currentClumpPos)
	#	print(currentClumpWeight)
		i += 1

func getSpawnposInClump(Spawn_Zones:Array[CollisionShape2D]):
	if randi_range(0,clumpCapacity-currentClumpWeight) > 0:
		currentClumpWeight += 1
		return currentClumpPos + _get_randomSpotInZone(Vector2(clumpDensity,clumpDensity))
	else:
		#currentClumpPos = _get_randomSpotInZone(Mapsize,false)
		var zone:CollisionShape2D = Spawn_Zones.pick_random()
		currentClumpPos = _get_randomSpotInZone(zone.shape.size,false) + zone.position + zone.get_parent().position - Vector2(zone.shape.size.x/2,zone.shape.size.y/2)
		#The reson for the last part of the previous line is unknown, but it did fix an issue
		currentClumpWeight = 1
		amountOfClumps += 1
		return currentClumpPos + _get_randomSpotInZone(Vector2(clumpDensity,clumpDensity))


func _get_randomSpotInZone(area:Vector2, centered:bool = true):
	if centered:
		#return Vector2(0,0)
		return Vector2(randi_range(-area.x,area.x),randi_range(-area.y,area.y))
	else:
		print(area.x)
		print(area.y)
		var returnvalue = Vector2(randi_range(0,area.x),randi_range(0,area.y))
		print("return: " + str(returnvalue))
		
		return returnvalue

func _get_AmountOFSpawns(Frequency):
	var amountOfSpawns = (Mapsize.x+Mapsize.y)/(Frequency + randi_range(-FrequencyRandomness,FrequencyRandomness))
	return amountOfSpawns

		
	return false
