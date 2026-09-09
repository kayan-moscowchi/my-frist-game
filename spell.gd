extends Area2D

@export var speed: float = 420.0
var direction: Vector2 = Vector2.RIGHT
var alive_time: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("spells")
	area_entered.connect(_on_area_entered)
	
	# Despawn if it travels for 3 seconds without hitting anything
	get_tree().create_timer(3.0).timeout.connect(func():
		queue_free()
	)

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

func _process(delta: float) -> void:
	alive_time += delta
	position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	# Sharp, aerodynamic magic bolt pointing along velocity
	var tip = Vector2.RIGHT * 8.0
	var tail = -Vector2.RIGHT * 9.0
	var wing_up = Vector2(-2.0, -3.5)
	var wing_down = Vector2(-2.0, 3.5)

	# 1. Dark outline shape (matching character line art)
	var outline_poly = PackedVector2Array([
		tip + Vector2.RIGHT * 1.5,
		wing_up + Vector2(-0.5, -1.0),
		tail - Vector2.RIGHT * 1.5,
		wing_down + Vector2(-0.5, 1.0)
	])
	draw_colored_polygon(outline_poly, Color(0.05, 0.1, 0.2))

	# 2. Main cyan magic energy fill
	var body_poly = PackedVector2Array([tip, wing_up, tail, wing_down])
	draw_colored_polygon(body_poly, Color(0.2, 0.75, 1.0))

	# 3. Slender bright inner energy streak (no round circles)
	draw_line(-Vector2.RIGHT * 5.0, tip * 0.7, Color(0.85, 0.95, 1.0), 1.6)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("snakes"):
		if area.has_method("take_hit"):
			area.take_hit()

		# Quick pop-and-fade on impact
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.06)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.06)
		await tween.finished
		queue_free()
