extends CPUParticles2D

func _ready() -> void:
	emitting = true
	# Wait until lifetime finishes, then delete itself
	await get_tree().create_timer(lifetime).timeout
	queue_free()
