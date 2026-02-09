extends Node2D

@export var xp_amount: int = 5
@export var attraction_speed: float = 400.0
@export var pickup_range: float = 100.0

@onready var collection_area = $CollectionArea

var player = null
var is_being_collected: bool = false

func _ready():
	
	add_to_group("xp_orb")
	
	player = GameManager.player
	
	if collection_area:
		collection_area.body_entered.connect(_on_collection_area_entered)

func _process(delta):
	if not player or not player.is_alive:
		return
	
	# Use player's pickup range stat
	var player_pickup_range = player.get_stat("pickup_radius") if player.has_method("get_stat") else pickup_range
	
	# Check distance to player
	var distance = global_position.distance_to(player.global_position)
	
	# If close enough, move towards player
	if distance < player_pickup_range:
		is_being_collected = true
	
	if is_being_collected:
		var direction = (player.global_position - global_position).normalized()
		global_position += direction * attraction_speed * delta

func _on_collection_area_entered(body):
		collect()

func collect():
	ExperienceManager.add_experience(xp_amount)
	queue_free()
