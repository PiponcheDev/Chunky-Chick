extends CharacterBody2D

@export var speed: float = 350.0
@export var lifetime: float = 1.2  


var life_timer: float = 0.0

func launch(dir: Vector2) -> void:
	velocity = dir.normalized() * speed
	life_timer = lifetime
	rotation = dir.angle()

func _physics_process(delta: float) -> void:
	
	if life_timer > 0.0:
		life_timer -= delta
		if life_timer <= 0.0:
			queue_free()
	
	move_and_slide()
