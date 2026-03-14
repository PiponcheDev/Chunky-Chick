extends Resource
class_name TalismanData

@export var talisman_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var isActive: bool

# gameplay effects
@export var speed_bonus: float = 0
@export var damage_bonus: float = 0
@export var attack_speed_bonus: float = 0 
@export var attack_range_bonus: float = 0
@export var shot_speed_bonus: float = 0
@export var fatness_max_bonus: float = 0
@export var fatness_from_food_bonus: float = 0
@export var active_duration: float = 0
@export var active_cooldown: float = 0
