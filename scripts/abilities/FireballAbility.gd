extends BaseAbility

# Fireball stats per level
var base_damage: float = 15.0
var base_cooldown: float = 1.0
var projectiles_per_shot: int = 1  # Increases with levels
var projectile_scene = preload("res://scenes/abilities/Projectile.tscn")

func initialize():
	ability_name = "Fireball"
	max_level = 5
	
	# Start shooting
	cooldown_timer.wait_time = base_cooldown
	cooldown_timer.start()
	
	print("Fireball ability initialized!")

func activate():
	if not player or not player.is_alive:
		return
	
	# Find nearest enemy (within detection radius)
	var nearest_enemy = find_nearest_enemy()
	
	if not nearest_enemy:
		return  # No enemies in range, don't shoot
	
	# Shoot projectiles based on level
	for i in range(projectiles_per_shot):
		shoot_fireball(nearest_enemy, i)

func shoot_fireball(target: Node2D, index: int = 0):
	# Create projectile
	var projectile = projectile_scene.instantiate()
	
	# Calculate damage based on level
	var damage = base_damage + (current_level - 1) * 5  # +5 damage per level
	
	# Spread projectiles in a fan pattern if multiple
	var spread_angle = 0.0
	if projectiles_per_shot > 1:
		var max_spread = 0.3  # radians (about 17 degrees each side)
		spread_angle = lerp(-max_spread, max_spread, float(index) / (projectiles_per_shot - 1))
	
	# Setup projectile
	projectile.setup(player.global_position, target, damage)
	
	# Apply spread
	if spread_angle != 0.0:
		var base_direction = (target.global_position - player.global_position).normalized()
		var rotated_direction = base_direction.rotated(spread_angle)
		projectile.direction = rotated_direction
		projectile.target = null  # Don't home if spread
	
	# Add to scene
	get_tree().root.add_child(projectile)

func on_level_up():
	# Each level does something different
	match current_level:
		2:
			base_damage += 5
			print("Fireball: +5 damage (now ", base_damage, ")")
		
		3:
			cooldown_timer.wait_time = base_cooldown * 0.8  # 20% faster
			print("Fireball: 20% faster cooldown (now ", cooldown_timer.wait_time, "s)")
		
		4:
			projectiles_per_shot = 2  # Shoot 2 fireballs!
			print("Fireball: Now shoots 2 projectiles!")
		
		5:
			projectiles_per_shot = 3  # Shoot 3 fireballs!
			cooldown_timer.wait_time = base_cooldown * 0.6  # Even faster
			print("Fireball: MAX LEVEL - 3 projectiles, super fast!")
