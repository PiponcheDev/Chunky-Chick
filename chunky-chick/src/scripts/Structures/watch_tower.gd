extends StaticBody2D

@export var aura_radius: float = 400.0
@export var range_boost: float = 1.3
@export var angle_boost: float = 1.5

var preview_mode: bool = false

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
