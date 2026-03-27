extends StaticBody2D

@export var persistent_id: String = ""
@export var aura_radius: float = 400.0
@export var range_boost: float = 1.3
@export var angle_boost: float = 1.5

var preview_mode: bool = false

func _ready():
	add_to_group("watchtower")

func capture_into_run_data() -> Dictionary:
	return {
		"kind": "watchtower",
		"id": persistent_id,
		"position": global_position,
		"radius": aura_radius,
		"range_boost": range_boost,
		"angle_boost": angle_boost,
		"preview": preview_mode
	}

func apply_run_data(state: Dictionary) -> void:
	if state.is_empty():
		return
	if state.has("position"):
		global_position = state["position"]

func _process(delta):
	if preview_mode:
		_apply_preview()
		queue_redraw()

func enable_preview():
	preview_mode = true

func finalize_placement():
	preview_mode = false
	_apply_buffs()
	queue_redraw()

func _apply_preview():
	for turret in get_tree().get_nodes_in_group("turret"):
		if _is_in_range(turret):
			turret.apply_watchtower_buff(range_boost, angle_boost)
			turret.enable_preview()
		else:
			turret.clear_watchtower_buff()

func _apply_buffs():
	for turret in get_tree().get_nodes_in_group("turret"):
		if _is_in_range(turret):
			turret.apply_watchtower_buff(range_boost, angle_boost)

func _is_in_range(turret: Node2D) -> bool:
	return global_position.distance_to(turret.global_position) <= aura_radius

func _draw():
	if not preview_mode:
		return
	draw_circle(Vector2.ZERO, aura_radius, Color(0, 0.6, 1, 0.25))
