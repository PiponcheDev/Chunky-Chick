extends Area2D

signal food_collected

@onready var sprite: Sprite2D = $Sprite2D
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	sprite.frame = rng.randi_range(0, 8)
	body_entered.connect(_on_body_entered)
	add_to_group("food")

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.eat_food(5)
		food_collected.emit()
		queue_free()
