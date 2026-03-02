extends StaticBody2D

var deposit_count := 0
@onready var hitbox_shape = $Hitbox.shape

func _ready():
	add_to_group("nest")
	print("Nest ready")

func try_deposit(item):
	if hitbox_shape is RectangleShape2D:
		var rect = Rect2(global_position - hitbox_shape.extents, hitbox_shape.extents * 2)
		if rect.has_point(item.global_position):
			deposit_item(item)
	elif hitbox_shape is CircleShape2D:
		if item.global_position.distance_to(global_position) <= hitbox_shape.radius:
			deposit_item(item)

func deposit_item(item):
	deposit_count += 1
	print("Items Deposited: ", deposit_count)
	item.queue_free()  # remove the item from the scene
