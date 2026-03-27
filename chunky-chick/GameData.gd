extends Resource
class_name RunData

@export var player_items: Array[TalismanData] = []
@export var player_stats: Dictionary = {
	"speed_bonus": 0.0,
	"damage_bonus": 0.0,
	"attack_speed_bonus": 0.0,
	"attack_range_bonus": 0.0,
	"shot_speed_bonus": 0.0,
	"fatness_max_bonus": 0.0,
	"fatness_from_food_bonus": 0.0
}

@export var egg_stage: int = 1
@export var egg_demand: float = 30.0
@export var curr_day: int = 1
@export var egg_progress: float = 0.0

@export var is_day: bool = true
@export var is_night: bool = false
@export var is_boss_night: bool = false

@export var turrets: Array[Dictionary] = []
@export var turret_count: int = 0
@export var watchtowers: Array[Dictionary] = []
@export var watchtower_count: int = 0
