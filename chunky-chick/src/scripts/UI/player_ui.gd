extends Control

# Node references
@onready var fatness_bar: TextureProgressBar = $"Fatness-bar"
@onready var dash_bar: TextureProgressBar = $"Dash-cooldown"
@onready var active_showcase: TextureRect = $TextureRect
@onready var active_cooldown: TextureProgressBar = $"Active-cooldown"
@onready var guide: Label = $Guide

const DASH_UI_START_DELAY := 0.12
const TALISMAN_THOUGHT_DURATION := 5.0

var player: Node = null
var dash_display: float = 0.0
var dash_cooldown_hold: float = 0.0
var dash_cooldown_was_active: bool = false

var talisman_thought_text: String = ""
var talisman_thought_time_left: float = 0.0

func _ready() -> void:
	# Automatically find the player from the group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		push_error("Player not found for UI!")
		guide.visible = false
		return

	player = players[0]

	# --- CONNECT SIGNALS ---
	player.connect("talisman_collected", Callable(self, "_on_talisman_collected"))
	player.connect("active_talisman_changed", Callable(self, "_on_active_talisman_changed"))
	player.connect("active_talisman_activated", Callable(self, "_on_active_talisman_state_changed"))
	player.connect("active_talisman_deactivated", Callable(self, "_on_active_talisman_state_changed"))
	player.connect("carried_item_changed", Callable(self, "_on_carried_item_changed"))

	# Initialize UI state
	_update_active_talisman_display(player.active_talisman)
	_update_active_cooldown_bar()
	_update_guide_label()

func _process(delta: float) -> void:
	if not player:
		return

	if talisman_thought_time_left > 0.0:
		talisman_thought_time_left -= delta
		if talisman_thought_time_left < 0.0:
			talisman_thought_time_left = 0.0

	# --- Fatness Bar ---
	fatness_bar.value = player.fatness
	fatness_bar.max_value = player.fatness_max + player.fatness_max_bonus

	# --- Dash Cooldown Bar (smooth, with small start delay) ---
	var dash_on_cooldown: bool = not player.dash_cooldown.is_stopped()

	if dash_on_cooldown and not dash_cooldown_was_active:
		dash_cooldown_hold = DASH_UI_START_DELAY
		dash_display = 0.0

	dash_cooldown_was_active = dash_on_cooldown

	if dash_on_cooldown:
		if dash_cooldown_hold > 0.0:
			dash_cooldown_hold -= delta
			if dash_cooldown_hold < 0.0:
				dash_cooldown_hold = 0.0
		else:
			var target: float = player.get_dash_cooldown_ratio()
			dash_display = lerp(dash_display, target, 10.0 * delta)
	else:
		dash_display = lerp(dash_display, 1.0, 10.0 * delta)

	dash_bar.value = dash_display * dash_bar.max_value

	# --- ACTIVE TALISMAN COOLDOWN BAR ---
	_update_active_cooldown_bar()

	# --- INTERACTION GUIDE ---
	_update_guide_label()

# --- SIGNAL HANDLERS ---
func _on_active_talisman_changed(new_talisman) -> void:
	_update_active_talisman_display(new_talisman)
	_update_active_cooldown_bar()
	_update_guide_label()

func _on_active_talisman_state_changed(_talisman) -> void:
	_update_active_cooldown_bar()
	_update_guide_label()

func _on_carried_item_changed(_is_carrying: bool) -> void:
	_update_guide_label()

func _on_talisman_collected(talisman) -> void:
	if talisman == null:
		return

	var text: String = str(talisman.description).strip_edges()
	if text == "":
		text = str(talisman.talisman_name)

	if talisman.isActive:
		text += "\n[to use press L]"

	talisman_thought_text = text
	talisman_thought_time_left = TALISMAN_THOUGHT_DURATION
	_update_guide_label()

# --- UI UPDATE LOGIC ---
func _update_active_talisman_display(talisman) -> void:
	if talisman == null:
		active_showcase.texture = null
		active_showcase.visible = false
		return

	active_showcase.texture = talisman.icon
	active_showcase.visible = true

func _update_active_cooldown_bar() -> void:
	if player == null or player.active_talisman == null:
		active_cooldown.value = 0.0
		active_cooldown.visible = false
		return

	active_cooldown.visible = true
	active_cooldown.max_value = 100.0

	if player.active_talisman_is_triggered:
		active_cooldown.value = 0.0
		return

	var max_cd: float = float(player.active_talisman.active_cooldown)
	if max_cd <= 0.0:
		active_cooldown.value = 0.0
		return

	var ratio: float = player.active_talisman_cooldown_left / max_cd
	ratio = clamp(ratio, 0.0, 1.0)
	ratio = int(ratio * 100)

	active_cooldown.value = ratio

func _update_guide_label() -> void:
	var prompt := ""

	if player != null and player.carried_item != null:
		prompt = "I should take this back to the nest's depot"
	elif talisman_thought_time_left > 0.0 and talisman_thought_text != "":
		prompt = talisman_thought_text
	elif _has_nearby_talisman_pickup():
		prompt = "Pick up talisman [E]"
	elif _has_nearby_trash_can():
		prompt = "Open trash can [E]"
	elif _has_nearby_material():
		prompt = "Pick up material [E]"

	guide.text = prompt
	guide.visible = prompt != ""

func _has_nearby_material() -> bool:
	return _scan_scene_for_interactable("material")

func _has_nearby_trash_can() -> bool:
	return _scan_scene_for_interactable("trash_can")

func _has_nearby_talisman_pickup() -> bool:
	return _scan_scene_for_interactable("talisman_pickup")

func _scan_scene_for_interactable(kind: String) -> bool:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return false
	return _scan_node_recursive(scene_root, kind)

func _scan_node_recursive(node: Node, kind: String) -> bool:
	for child in node.get_children():
		if _node_matches_kind(child, kind):
			return true
		if _scan_node_recursive(child, kind):
			return true
	return false

func _node_matches_kind(node: Node, kind: String) -> bool:
	if node == null:
		return false

	match kind:
		"material":
			return node.get("in_range") == true and node.get("carried") != true

		"trash_can":
			return node.get("player_node") != null and node.get("opened") == false and node.has_method("open")

		"talisman_pickup":
			return node.get("player_in_range") == true and node.has_method("collect")

		_:
			return false
