extends CharacterBody2D

@export var speed: float = 500.0

func launch(dir: Vector2) -> void:
	velocity = dir.normalized() * speed

func _physics_process(delta: float) -> void:
	move_and_slide()
