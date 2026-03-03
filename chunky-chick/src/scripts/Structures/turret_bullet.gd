extends Area2D

@export var speed := 400.0
var direction := Vector2.RIGHT

func _ready():
	rotation = direction.angle()

func _physics_process(delta):
	position += direction * speed * delta
