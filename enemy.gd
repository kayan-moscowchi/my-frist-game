extends Area2D

@export var speed: float = 200.0
var direction: Vector2 = Vector2.ZERO
var bounds: Vector2 = Vector2(1152, 648)
var radius: float = 24.0

func _ready() -> void:
	add_to_group("enemies")
	
	# Connect collision detection with other areas
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	
	# Pick a random starting trajectory
	var angle = randf_range(0, TAU)
	direction = Vector2(cos(angle), sin(angle)).normalized()

func set_bounds(new_bounds: Vector2) -> void:
	bounds = new_bounds

func _process(delta: float) -> void:
	position += direction * speed * delta

	# Horizontal arena boundary bounce
	if position.x <= radius:
		position.x = radius
		direction.x = abs(direction.x)
	elif position.x >= bounds.x - radius:
		position.x = bounds.x - radius
		direction.x = -abs(direction.x)

	# Vertical arena boundary bounce
	if position.y <= radius:
		position.y = radius
		direction.y = abs(direction.y)
	elif position.y >= bounds.y - radius:
		position.y = bounds.y - radius
		direction.y = -abs(direction.y)

func _on_area_entered(other: Area2D) -> void:
	# Bomb-on-bomb bounce collision
	if other.is_in_group("enemies") and other != self:
		var normal = (global_position - other.global_position).normalized()
	
		# Fallback if two bombs spawn or overlap at the exact same coordinate
		if normal == Vector2.ZERO:
			normal = Vector2.RIGHT.rotated(randf() * TAU)
		
		# Deflect direction away from the other bomb
		direction = direction.bounce(normal)
		
		# Nudge slightly outwards to prevent clipping or sticking together
		position += normal * 4.0
