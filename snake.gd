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

@onready var body_line: Line2D = $BodyLine

func _ready() -> void:
	add_to_group("snakes")
	area_entered.connect(_on_area_entered)
	player_ref = get_tree().get_first_node_in_group("player")

	body_line.show_behind_parent = true
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
	body_line.points = local_points

	queue_redraw()

func _draw() -> void:
	if segment_positions.size() < 3:
		return

	# --- 1. DORSAL SCALE BANDS ---
	for i in range(1, segment_count - 1):
		var curr = to_local(segment_positions[i])
		var prev = to_local(segment_positions[i - 1])
		var seg_dir = (curr - prev).normalized()
		var seg_perp = Vector2(-seg_dir.y, seg_dir.x)

		var t = float(i) / float(segment_count)
		var band_width = lerp(4.2, 1.2, t)

		# Dark belly shade
		if i % 2 == 0:
			draw_line(curr - seg_perp * band_width, curr + seg_perp * band_width, Color(0.04, 0.12, 0.06), 2.2)
		else:
			# Specular golden scales
			var diamond = PackedVector2Array([
				curr - seg_dir * 1.8,
				curr + seg_perp * (band_width * 0.7),
				curr + seg_dir * 1.8,
				curr - seg_perp * (band_width * 0.7)
			])
			draw_colored_polygon(diamond, Color(0.98, 0.88, 0.35))

	# --- 2. HEAD CALCULATIONS ---
	var head_pos = to_local(segment_positions[0])
	var neck_pos = to_local(segment_positions[1])
	var head_dir = (head_pos - neck_pos).normalized()
	if head_dir == Vector2.ZERO:
		head_dir = Vector2.RIGHT
	var head_perp = Vector2(-head_dir.y, head_dir.x)

	var snout = head_pos + head_dir * 7.5
	var left_flare = head_pos + head_dir * 1.0 + head_perp * 5.2
	var left_base = head_pos - head_dir * 2.8 + head_perp * 3.5
	var right_base = head_pos - head_dir * 2.8 - head_perp * 3.5
	var right_flare = head_pos + head_dir * 1.0 - head_perp * 5.2

	var head_points = PackedVector2Array([snout, left_flare, left_base, right_base, right_flare])

	# Dark edge rim
	draw_polyline(PackedVector2Array([snout, left_flare, left_base, right_base, right_flare, snout]), Color(0.04, 0.12, 0.05), 1.8)
	
	# Main head base fill
	draw_colored_polygon(head_points, Color(0.16, 0.48, 0.2))

	# 3D Dome Highlight (upper hemisphere of the head)
	var dome_highlight = PackedVector2Array([
		snout - head_dir * 1.0,
		left_flare - head_perp * 1.5,
		head_pos,
		right_flare + head_perp * 1.5
	])
	draw_colored_polygon(dome_highlight, Color(0.35, 0.75, 0.4, 0.55))

	# --- 3. EYES ---
	var eye_pos_left = head_pos + head_dir * 1.2 + head_perp * 3.4
	var eye_pos_right = head_pos + head_dir * 1.2 - head_perp * 3.4

	draw_circle(eye_pos_left, 2.4, Color.BLACK)
	draw_circle(eye_pos_right, 2.4, Color.BLACK)

	draw_circle(eye_pos_left, 1.6, Color(1.0, 0.9, 0.1))
	draw_circle(eye_pos_right, 1.6, Color(1.0, 0.9, 0.1))

	draw_line(eye_pos_left - head_dir * 1.2, eye_pos_left + head_dir * 1.2, Color.BLACK, 1.0)
	draw_line(eye_pos_right - head_dir * 1.2, eye_pos_right + head_dir * 1.2, Color.BLACK, 1.0)

	# --- 4. TONGUE ---
	var tongue_cycle = fmod(tongue_timer, 1.6)
	if tongue_cycle < 0.22:
		var tongue_base = snout
		var tongue_tip = snout + head_dir * 7.0
		var tongue_col = Color(0.95, 0.15, 0.2)
		draw_line(tongue_base, tongue_tip, tongue_col, 1.3)
		draw_line(tongue_tip, tongue_tip + (head_dir * 2.2 + head_perp * 2.0), tongue_col, 1.0)
		draw_line(tongue_tip, tongue_tip + (head_dir * 2.2 - head_perp * 2.0), tongue_col, 1.0)

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
