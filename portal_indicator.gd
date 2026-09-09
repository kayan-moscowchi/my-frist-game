extends Node2D

var target_portal: Node2D = null

func _ready() -> void:
	visible = false

func track(portal: Node2D, _player: Node2D = null) -> void:
	target_portal = portal
	visible = true

func _process(_delta: float) -> void:
	if target_portal == null or not is_instance_valid(target_portal):
		visible = false
		return

	# Convert portal world coordinate to viewport screen coordinate
	var canvas_transform = get_viewport().get_canvas_transform()
	var portal_screen_pos = canvas_transform * target_portal.global_position
	var vp_size = get_viewport_rect().size
	var vp_rect = Rect2(Vector2.ZERO, vp_size)

	# Hide indicator if the portal is already visible on screen
	if vp_rect.has_point(portal_screen_pos):
		visible = false
		return

	visible = true
	var screen_center = vp_size * 0.5
	var dir = (portal_screen_pos - screen_center).normalized()
	rotation = dir.angle()

	var padding = 45.0
	var min_bound = Vector2(padding, padding)
	var max_bound = vp_size - Vector2(padding, padding)

	var t_x = INF
	var t_y = INF

	if dir.x > 0:
		t_x = (max_bound.x - screen_center.x) / dir.x
	elif dir.x < 0:
		t_x = (min_bound.x - screen_center.x) / dir.x

	if dir.y > 0:
		t_y = (max_bound.y - screen_center.y) / dir.y
	elif dir.y < 0:
		t_y = (min_bound.y - screen_center.y) / dir.y

	position = screen_center + dir * min(t_x, t_y)
	queue_redraw()

func _draw() -> void:
	var tip = Vector2(16, 0)
	var left = Vector2(-10, -10)
	var right = Vector2(-10, 10)
	var indent = Vector2(-4, 0)

	# Outer outline matching cartoon art style
	draw_colored_polygon(PackedVector2Array([tip * 1.25, left * 1.25, indent * 1.25, right * 1.25]), Color(0.05, 0.1, 0.15))
	# Cyan portal arrow
	draw_colored_polygon(PackedVector2Array([tip, left, indent, right]), Color(0.2, 0.85, 1.0))
