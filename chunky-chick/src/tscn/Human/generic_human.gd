extends PathFollow2D

var state: int = ROAMING

const ROAMING = 1
const FEEDING = 2
const CHASING = 3 #Used when traveling to player during feeding

const SPEED = 100

var previous_pos: Vector2 = Vector2(0,0)
var derivative: Vector2 = self.position - previous_pos

var movementdir: int = DOWN

const UP = 1
const DOWN = 2
const LEFT = 4
const RIGHT = 3


var feedProbability = 5 # Higher is less likely. 1 in n where n is this
var feedRadius = 100 #How far away it can feed you, unrelated to the area2D

@onready var player = $"../../"
@onready var abandon_feeding_timer: Timer = $AbandonFeeding

func _ready() -> void:
	self.rotation = 0

func _process(delta: float) -> void:
	derivative = self.position - previous_pos
	if state == ROAMING:
		progress += SPEED * delta
	elif state == CHASING:
		var distance = abs(player.position-self.position)
		distance = distance.x + distance.y
		if distance > feedRadius:
			self.position = player.position-self.position * 0.2 * delta #Really scuffed but temporary
		else:
			state = FEEDING
			abandon_feeding_timer.start()
	elif state == FEEDING:
		pass #Give player seeds or smt
	print(state)
		
	
	#Manage the animation
	if abs(derivative.x) > abs(derivative.y):
		if derivative.x > 0:
			movementdir = RIGHT
		else:
			movementdir = LEFT
	else:
		if derivative.y > 0:
			movementdir = DOWN
		else:
			movementdir = UP
	#Once the animation is gathered from the artists this can be used to decide which one to use at any given moment
	#If the Human is moonwalking too much decrease the time of the direction updater
	
	if Input.is_action_just_pressed("DebugButton"):
		if randi_range(0,feedProbability) == 0:
			state = CHASING
			print("CHASE")

			abandon_feeding_timer.start()


func _on_direction_updater_timeout() -> void:
	if state == ROAMING:
		previous_pos = self.position


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body: #Check if body is player
		if randi_range(0,feedProbability) == 0:
			state = CHASING
			print("CHASE")
			abandon_feeding_timer.start()
			


func _on_abandon_feeding_timeout() -> void:
	state = ROAMING
