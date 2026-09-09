extends Area2D

@export var crawl_speed: float = 125.0
@export var segment_count: int = 22
@export var segment_spacing: float = 5.5
@export var wave_frequency: float = 8.0
@export var wave_amplitude: float = 16.0

var player_ref: Node2D = null
var segment_positions: Array[Vector2] = []
var wave_phase: float = 0.0
var tongue_timer: float = 0.0

func _ready() -> void:
	add_to_group("snakes")
	area_entered.connect(_on_area_entered)
	player_ref = get_tree().get_first_node_in_group("player")

	rotation = 0.0

	for i in range(segment_count):
		segment_positions.append(global_position - Vector2(i * segment_spacing, 0))

func _process(delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return

	wave_phase += delta * wave_frequency
	tongue_timer += delta

	# 1. Base direction toward wizard
	var to_player = (player_ref.global_position - global_position).normalized()

	# 2. Traveling serpentine undulation
	var lateral = Vector2(-to_player.y, to_player.x)
	var slither_wave = lateral * sin(wave_phase) * wave_amplitude
	var move_dir = (to_player * crawl_speed + slither_wave).normalized()

	position += move_dir * crawl_speed * delta

	# 3. Inverse Kinematic Spine Constraint
	segment_positions[0] = global_position
	for i in range(1, segment_count):
		var prev = segment_positions[i - 1]
		var curr = segment_positions[i]
		var dir = (curr - prev).normalized()

		var spine_phase = wave_phase - (float(i) * 0.48)
		var harmonic_wave = Vector2(-dir.y, dir.x) * sin(spine_phase) * 0.9

		segment_positions[i] = prev + dir * segment_spacing + harmonic_wave

	# 4. Feed points to Line2D
	var local_points: PackedVector2Array = []
	for p in segment_positions:
		local_points.append(to_local(p))

	queue_redraw()

func _draw() -> void:
	if segment_positions.size() < 3:
		return

	# --- 1. VOLUMETRIC 3D BODY SEGMENTS ---
	# We loop BACKWARDS (tail to head) so segments overlap each other accurately in 3D space
	for i in range(segment_count - 1, 0, -1):
		var curr = to_local(segment_positions[i])
		
		# Taper the tail (smaller circles at the end, larger near the neck)
		var t = float(segment_count - i) / float(segment_count)
		var radius = lerp(2.0, 9.0, t)

		# A. Ground Shadow (Elevates the body into 3D space)
		draw_circle(curr + Vector2(0, 10), radius * 0.9, Color(0.0, 0.0, 0.0, 0.3))

		# B. Thick Dark Outline (Preserves cartoon style)
		draw_circle(curr, radius + 2.0, Color(0.04, 0.12, 0.05))

		# C. Base Green Body Volume
		draw_circle(curr, radius, Color(0.16, 0.48, 0.2))

		# D. Curved 3D Highlight (Offset to the top-left to simulate a sphere)
		draw_circle(curr + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.4, Color(0.4, 0.8, 0.4, 0.8))

		# E. Golden Dorsal Pattern
		if i % 2 != 0:
			draw_circle(curr + Vector2(radius * 0.1, -radius * 0.1), radius * 0.3, Color(0.92, 0.82, 0.25))

	# --- 2. HEAD CALCULATIONS ---
	var head_pos = to_local(segment_positions[0])
	var neck_pos = to_local(segment_positions[1])
	var head_dir = (head_pos - neck_pos).normalized()
	if head_dir == Vector2.ZERO:
		head_dir = Vector2.RIGHT
	var head_perp = Vector2(-head_dir.y, head_dir.x)

	var snout = head_pos + head_dir * 8.0
	var left_flare = head_pos + head_dir * 1.0 + head_perp * 6.5
	var left_base = head_pos - head_dir * 3.5 + head_perp * 4.0
	var right_base = head_pos - head_dir * 3.5 - head_perp * 4.0
	var right_flare = head_pos + head_dir * 1.0 - head_perp * 6.5

	var head_points = PackedVector2Array([snout, left_flare, left_base, right_base, right_flare])
	
	# Head Ground Shadow
	var shadow_offset = Vector2(0, 10)
	var shadow_points = PackedVector2Array([snout + shadow_offset, left_flare + shadow_offset, left_base + shadow_offset, right_base + shadow_offset, right_flare + shadow_offset])
	draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.3))

	# --- 3. DRAW HEAD ---
	# Outline
	draw_polyline(PackedVector2Array([snout, left_flare, left_base, right_base, right_flare, snout]), Color(0.04, 0.12, 0.05), 2.5)
	# Solid Fill
	draw_colored_polygon(head_points, Color(0.16, 0.48, 0.2))
	
	# 3D Dome Highlight on the head
	var dome_highlight = PackedVector2Array([snout - head_dir * 1.5, left_flare - head_perp * 2.0, head_pos, right_flare + head_perp * 2.0])
	draw_colored_polygon(dome_highlight, Color(0.4, 0.8, 0.4, 0.5))

	# --- 4. EYES ---
	var eye_pos_left = head_pos + head_dir * 1.5 + head_perp * 4.0
	var eye_pos_right = head_pos + head_dir * 1.5 - head_perp * 4.0

	draw_circle(eye_pos_left, 2.5, Color.BLACK)
	draw_circle(eye_pos_right, 2.5, Color.BLACK)
	draw_circle(eye_pos_left, 1.5, Color(1.0, 0.9, 0.1))
	draw_circle(eye_pos_right, 1.5, Color(1.0, 0.9, 0.1))
	draw_line(eye_pos_left - head_dir * 1.2, eye_pos_left + head_dir * 1.2, Color.BLACK, 1.0)
	draw_line(eye_pos_right - head_dir * 1.2, eye_pos_right + head_dir * 1.2, Color.BLACK, 1.0)

	# --- 5. TONGUE ---
	var tongue_cycle = fmod(tongue_timer, 1.6)
	if tongue_cycle < 0.22:
		var tongue_base = snout
		var tongue_tip = snout + head_dir * 7.0
		var tongue_col = Color(0.95, 0.15, 0.2)
		draw_line(tongue_base, tongue_tip, tongue_col, 1.5)
		draw_line(tongue_tip, tongue_tip + (head_dir * 2.5 + head_perp * 2.5), tongue_col, 1.2)
		draw_line(tongue_tip, tongue_tip + (head_dir * 2.5 - head_perp * 2.5), tongue_col, 1.2)

func take_hit() -> void:
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	set_process(false)

	if has_node("SnakeDeathSound"):
		$SnakeDeathSound.play()

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	
	if has_node("SnakeDeathSound") and $SnakeDeathSound.playing:
		await $SnakeDeathSound.finished
	else:
		await tween.finished

	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var main_node = get_parent()
		if main_node and main_node.has_node("SnakeBiteSound"):
			main_node.get_node("SnakeBiteSound").play()
		
		if area.has_method("take_damage"):
			area.take_damage()
			
		queue_free()
