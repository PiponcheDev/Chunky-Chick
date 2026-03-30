extends Node2D

@export var Mapsize : Vector2 = Vector2(2000, 2000) 

@export_subgroup("Lists")
@export var items : Array[PackedScene] = [preload("res://src/tscn/items.tscn")]
@export var foods : Array[PackedScene] = [preload("res://src/tscn/Food.tscn")] 
@export var trashCans : Array[PackedScene] = [preload("res://src/tscn/Structures/trash_can.tscn")] 
@export var talismen : Array[PackedScene] = [] 
@export var dumpsters : Array[PackedScene] = [] 

@export_subgroup("Clump Settings")
@export var defaultClumpCapacity = 4
@export var clumpDensity = 20 

# Internals for clumping logic
var currentClumpPos : Vector2 = Vector2(0, 0)
var currentClumpWeight : int = 0

var item_spawn_zones : Array[CollisionShape2D] = []
var talimen_spawn_zones : Array[CollisionShape2D] = []
var food_spawn_zones : Array[CollisionShape2D] = []
var trashcan_spawn_zones : Array[CollisionShape2D] = []
var dumpster_spawn_zones : Array[CollisionShape2D] = []

func _ready():
	await get_tree().process_frame 
	_setup_spawnzones()
	_generate_map()

func _setup_spawnzones():
	for child in self.get_children():
		if child is Area2D:
			var shape_node = child.get_child(0)
			if not shape_node is CollisionShape2D: continue

			if child.get("items") == true: item_spawn_zones.append(shape_node)
			if child.get("foods") == true: food_spawn_zones.append(shape_node)
			if child.get("talismen") == true: talimen_spawn_zones.append(shape_node)
			if child.get("trashcans") == true: trashcan_spawn_zones.append(shape_node)
			if child.get("dumpsters") == true: dumpster_spawn_zones.append(shape_node)

func _generate_map():
	# 1. Trash Cans: Exactly 5 total, Clump size of 1
	_spawn_logic(trashCans, trashcan_spawn_zones, 5, 1, "Trash Cans")
	
	# 2. Food: Exactly 60 total, Uses default clump size
	_spawn_logic(foods, food_spawn_zones, 60, defaultClumpCapacity, "Food")
	
	# 3. Items: Random between 10 and 20, Uses default clump size
	var item_count = randi_range(10, 20)
	_spawn_logic(items, item_spawn_zones, item_count, defaultClumpCapacity, "Items")
	
	# 4. Others (Optional)
	_spawn_logic(talismen, talimen_spawn_zones, 2, 1, "Talismans")
	_spawn_logic(dumpsters, dumpster_spawn_zones, 2, 1, "Dumpsters")

func _spawn_logic(objects: Array[PackedScene], zones: Array[CollisionShape2D], count: int, clump_limit: int, debug_name: String):
	if objects.is_empty() or zones.is_empty():
		return
	
	print("Spawning ", count, " ", debug_name)
	
	# Reset clumping for the new category
	currentClumpWeight = 0 
	
	for i in range(count):
		var spawnPos = getSpawnposInClump(zones, clump_limit)
		var new_obj = objects.pick_random().instantiate()
		add_child(new_obj)
		new_obj.global_position = spawnPos

func getSpawnposInClump(Spawn_Zones: Array[CollisionShape2D], clump_limit: int):
	# If we are below the specific clump limit for this item type, stay near center
	if currentClumpWeight < clump_limit and currentClumpWeight > 0:
		currentClumpWeight += 1
		return currentClumpPos + _get_random_offset(clumpDensity)
	else:
		# Start a brand new clump (or a single item)
		var zone = Spawn_Zones.pick_random()
		var size = _get_shape_size(zone)
		
		currentClumpPos = zone.global_position + Vector2(
			randf_range(-size.x/2, size.x/2),
			randf_range(-size.y/2, size.y/2)
		)
		
		currentClumpWeight = 1
		return currentClumpPos

func _get_shape_size(zone: CollisionShape2D) -> Vector2:
	if zone.shape is RectangleShape2D: return zone.shape.size
	if zone.shape is CircleShape2D: return Vector2(zone.shape.radius * 2, zone.shape.radius * 2)
	return Vector2(50, 50)

func _get_random_offset(dist: float) -> Vector2:
	return Vector2(randf_range(-dist, dist), randf_range(-dist, dist))
