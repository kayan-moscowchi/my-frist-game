extends Area2D

@export var blast_radius: float = 110.0
@export var fuse_time: float = 2.0

var elapsed: float = 0.0
var exploded: bool = false

var explosion_particles_scene = preload("res://explosion_particles.tscn")

func _ready() -> void:
	# Ensure the collision shape radius matches the visual blast radius
	if has_node("CollisionShape2D") and $CollisionShape2D.shape is CircleShape2D:
		blast_radius = $CollisionShape2D.shape.radius
	elif has_node("CollisionShape2D") and $CollisionShape2D.shape == null:
		var circle = CircleShape2D.new()
		circle.radius = blast_radius
		$CollisionShape2D.shape = circle

func _process(delta: float) -> void:
	if exploded:
		return

	elapsed += delta
	queue_redraw()

	if elapsed >= fuse_time:
		explode()

func _draw() -> void:
	if exploded:
		return

	# 1. Outer warning border
	draw_arc(Vector2.ZERO, blast_radius, 0, TAU, 64, Color(1.0, 0.2, 0.2, 0.8), 2.5)

	# 2. Expanding fill
	var progress = clamp(elapsed / fuse_time, 0.0, 1.0)
	var current_fill_radius = blast_radius * progress

	# 3. Red telegraph zone
	draw_circle(Vector2.ZERO, current_fill_radius, Color(1.0, 0.1, 0.1, 0.35))

func explode() -> void:
	exploded = true
	
	# --- FIX: Proximity Screen Shake ---
	var player = get_tree().get_first_node_in_group("player")
	# Only shake if the player exists and is within 500 pixels
	if player and global_position.distance_to(player.global_position) < 500.0:
		get_tree().call_group("camera", "shake", 12.0)
	
	# Instantly hide everything visually (the sprite, redraw circles, etc.)
	hide()

	# 1. Trigger explosion sound (CHANGED TO AudioStreamPlayer2D)
	var sound: AudioStreamPlayer2D = null
	if has_node("ExplodeSound"):
		sound = $ExplodeSound as AudioStreamPlayer2D
		sound.play()

	# 2. Damage Detection with generous sensitivity
	check_player_hit()
	
	var blast = explosion_particles_scene.instantiate()
	blast.position = global_position
	get_parent().add_child(blast)
	
	# 3. Keep node alive only until audio finishes
	if sound and sound.playing:
		await sound.finished
	else:
		await get_tree().create_timer(0.05).timeout

	queue_free()

func check_player_hit() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return

	# 1. Native Area overlap check (works if physics overlap was active)
	if has_node("CollisionShape2D"):
		var overlapping = get_overlapping_areas()
		if player in overlapping:
			if player.has_method("take_damage"):
				player.take_damage()
			return

	# 2. Multi-point sample check (Wizard center, Staff/Left hand, Right side, Head)
	var center = player.global_position
	if player.has_node("Wizard"):
		center = player.get_node("Wizard").global_position

	# Sample key parts of the wizard's silhouette:
	# - Staff / Left reach extends roughly 55px to the left
	# - Right side extends roughly 35px to the right
	# - Hat tip extends roughly 45px up
	var sample_points = [
		center,                                # Body center
		center + Vector2(-55, 0),              # Staff / Left hand
		center + Vector2(-50, -35),             # Staff tip (upper left)
		center + Vector2(-50, 35),              # Staff base (lower left)
		center + Vector2(35, 0),               # Right side
		center + Vector2(0, -45)               # Hat / Head
	]

	for pt in sample_points:
		if global_position.distance_to(pt) <= (blast_radius + 15.0):
			if player.has_method("take_damage"):
				player.take_damage()
			return
