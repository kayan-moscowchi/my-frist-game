extends CPUParticles2D

func _ready() -> void:
	# Reset and burst immediately on spawn
	restart()
	emitting = true
	# Wait for lifetime, then cleanly remove
	await get_tree().create_timer(lifetime).timeout
	queue_free()
