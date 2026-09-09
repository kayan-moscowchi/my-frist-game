extends Node2D

func _ready() -> void:
	visible = false

func _draw() -> void:
	# Same chevron proportions as PortalIndicator
	var tip = Vector2(16, 0)
	var left = Vector2(-10, -10)
	var right = Vector2(-10, 10)
	var indent = Vector2(-4, 0)

	# Dark ink outline
	draw_colored_polygon(PackedVector2Array([tip * 1.25, left * 1.25, indent * 1.25, right * 1.25]), Color(0.1, 0.08, 0.0))
	# Solid golden-yellow fill
	draw_colored_polygon(PackedVector2Array([tip, left, indent, right]), Color(1.0, 0.85, 0.15))
