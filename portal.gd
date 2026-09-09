extends Area2D

@export var lifetime: float = 10.0 # Remains open for 10 seconds
var alive_time: float = 0.0
var is_closing: bool = false

func _ready() -> void:
	add_to_group("portal")
	area_entered.connect(_on_area_entered)
	
	scale = Vector2.ZERO
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.4)

func _process(delta: float) -> void:
	if is_closing:
		return

	alive_time += delta
	queue_redraw()
	
	if alive_time >= lifetime:
		close_portal()

func close_portal() -> void:
	is_closing = true
	
	# Hide navigation indicator arrow as the portal vanishes
	var main = get_parent()
	if main and main.has_node("HUD/PortalIndicator"):
		main.get_node("HUD/PortalIndicator").visible = false

	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.45)
	await tween.finished
	queue_free()

func _draw() -> void:
	var pulse = sin(alive_time * 6.0) * 2.0
	
	draw_circle(Vector2.ZERO, 22.0 + pulse, Color(0.1, 0.25, 0.8, 0.35))
	draw_circle(Vector2.ZERO, 16.0 - pulse * 0.5, Color(0.35, 0.7, 1.0, 0.65))
	draw_circle(Vector2.ZERO, 8.0, Color(0.9, 0.95, 1.0, 0.95))
	
	for i in range(4):
		var angle = alive_time * 3.0 + (i * PI * 0.5)
		var rune_pos = Vector2(cos(angle), sin(angle)) * (17.0 + pulse)
		draw_circle(rune_pos, 2.5, Color(0.95, 0.85, 0.3))

func _on_area_entered(area: Area2D) -> void:
	if is_closing:
		return

	if area.is_in_group("player"):
		if area.has_method("trigger_game_over"):
			area.trigger_game_over("YOU ESCAPED!\nYou evaded the perils of the canyon.", true)
