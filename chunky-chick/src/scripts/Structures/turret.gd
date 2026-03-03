extends Node2D

@onready var head = $Head
@onready var muzzle = $Head/Muzzle
@onready var detection = $DetectionArea
@onready var fire_timer = $FireTimer

var enemies_in_range = []
var target = null

var BulletScene = preload("res://src/tscn/Structures/turret_bullet.tscn")

func _ready():
	detection.body_entered.connect(_on_body_entered)
	detection.body_exited.connect(_on_body_exited)
	
	fire_timer.timeout.connect(_fire)
	fire_timer.start()

func _process(delta):
	if enemies_in_range.size() > 0:
		target = enemies_in_range[0]
		var dir = target.global_position - head.global_position
		head.rotation = dir.angle()
	else:
		target = null

func _on_body_entered(body):
	if body.is_in_group("enemy"):
		print("Detected:", body.name)
		enemies_in_range.append(body)

func _on_body_exited(body):
	enemies_in_range.erase(body)

func _fire():
	if target:
		print("Firing at:", target.name)
		shoot()

func shoot():
	var bullet = BulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	var dir = (target.global_position - muzzle.global_position).normalized()
	
	bullet.direction = dir
	bullet.rotation = dir.angle()
