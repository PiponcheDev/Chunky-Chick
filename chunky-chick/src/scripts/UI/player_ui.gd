extends Control

# Node references
@onready var fatness_bar: ProgressBar = $"Fatness-bar"
@onready var dash_bar: ProgressBar = $"Dash-cooldown"

var player: Node = null
var dash_display := 0.0  # for smooth dash bar animation

func _ready() -> void:
	# Automatically find the player from the group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		push_error("Player not found for UI!")
		return
	player = players[0]

func _process(delta: float) -> void:
	if not player:
		return
	
	# --- Fatness Bar ---
	fatness_bar.value = player.fatness
	fatness_bar.max_value = player.fatness_max + player.fatness_max_bonus
	# --- Dash Cooldown Bar (smooth) ---
	var target = player.get_dash_cooldown_ratio()
	dash_display = lerp(dash_display, target, 10 * delta)
	dash_bar.value = dash_display * dash_bar.max_value
