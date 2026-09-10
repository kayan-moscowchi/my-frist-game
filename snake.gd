extends Area2D

@export var crawl_speed: float = 115.0
@export var enrage_time: float = 10.0
@export var enraged_speed_multiplier: float = 1.6

@export var segment_count: int = 15
@export var segment_spacing: float = 7.5
@export var wave_frequency: float = 8.5
@export var wave_amplitude: float = 12.0

var player_ref: Node2D = null
var segment_positions: Array[Vector2] = []
var wave_phase: float = 0.0
var tongue_timer: float = 0.0

var time_alive: float = 0.0
var is_enraged: bool = false
var base_crawl_speed: float = 0.0
var transition_progress: float = 0.0 

var is_dead: bool = false 

func _ready() -> void:
	add_to_group("snakes")
	area_entered.connect(_on_area_entered)
	player_ref = get_tree().get_first_node_in_group("player")
	rotation = 0.0
	
	base_crawl_speed = crawl_speed

	for i in range(segment_count):
		segment_positions.append(global_position - Vector2(i * segment_spacing, 0))

func _process(delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return

	# --- ENRAGE LOGIC ---
	time_alive += delta
	if time_alive >= enrage_time:
		if not is_enraged:
			is_enraged = true
			crawl_speed = base_crawl_speed * enraged_speed_multiplier
			wave_frequency *= 1.5

		if transition_progress < 1.0:
			transition_progress = min(1.0, transition_progress + delta * 2.0)

	wave_phase += delta * wave_frequency
	tongue_timer += delta

	var to_player = (player_ref.global_position - global_position).normalized()
	var lateral = Vector2(-to_player.y, to_player.x)
	var slither_wave = lateral * sin(wave_phase) * wave_amplitude
	var move_dir = (to_player * crawl_speed + slither_wave).normalized()

	position += move_dir * crawl_speed * delta

	segment_positions[0] = global_position
	for i in range(1, segment_count):
		var prev = segment_positions[i - 1]
		var curr = segment_positions[i]
		var dir = (curr - prev).normalized()

		var spine_phase = wave_phase - (float(i) * 0.45)
		var harmonic_wave = Vector2(-dir.y, dir.x) * sin(spine_phase) * 0.7

		segment_positions[i] = prev + dir * segment_spacing + harmonic_wave

	queue_redraw()

func _draw() -> void:
	if segment_positions.size() < 3:
		return

	# --- DYNAMIC COLORS ---
	var current_skin = Color(0.15, 0.55, 0.2).lerp(Color(0.55, 0.1, 0.15), transition_progress) 
	var current_spot = Color(0.95, 0.9, 0.15).lerp(Color(1.0, 0.6, 0.0), transition_progress)   
	var current_eye = Color(0.9, 0.8, 0.1).lerp(Color(1.0, 0.0, 0.0), transition_progress)      
	var shadow_col = Color(0.0, 0.0, 0.0, 0.4)
	var wet_gloss = Color(0.8, 0.95, 0.7, 0.35)
		
	var size = lerp(1.0, 1.25, transition_progress) 

	# --- 1. SHADOW ---
	var shadow_points = PackedVector2Array()
	for p in segment_positions:
		shadow_points.append(to_local(p) + Vector2(0, 2.5 * size))
	draw_polyline(shadow_points, shadow_col, 8.0 * size, true) 

# --- 2. BODY OUTLINE (Pass 1: Silhouette) ---
	var outline_color = Color(0.04, 0.1, 0.04) # Matches the dark color of the head outline
	var outline_thick = 1.25 * size            # Perfectly matches the head line thickness
	
	for i in range(segment_count - 1, 0, -1):
		var curr = to_local(segment_positions[i])
		var next = to_local(segment_positions[i - 1])
		
		var dir = (next - curr).normalized()
		var perp = Vector2(-dir.y, dir.x)
		
		var t_curr = float(segment_count - i) / float(segment_count)
		var t_next = float(segment_count - (i - 1)) / float(segment_count)
		
		var r_curr = lerp(1.5, 6.0, t_curr) * size
		var r_next = lerp(1.5, 6.0, t_next) * size

		# Draw the larger dark background shapes
		draw_circle(curr, r_curr + outline_thick, outline_color)
		var outline_quad = PackedVector2Array([
			curr + perp * (r_curr + outline_thick), curr - perp * (r_curr + outline_thick),
			next - perp * (r_next + outline_thick), next + perp * (r_next + outline_thick)
		])
		draw_colored_polygon(outline_quad, outline_color)

	# --- 2.5 BODY INTERIOR (Pass 2: Skin, Spots, Gloss) ---
	for i in range(segment_count - 1, 0, -1):
		var curr = to_local(segment_positions[i])
		var next = to_local(segment_positions[i - 1])
		
		var dir = (next - curr).normalized()
		var perp = Vector2(-dir.y, dir.x)
		
		var t_curr = float(segment_count - i) / float(segment_count)
		var t_next = float(segment_count - (i - 1)) / float(segment_count)
		
		var r_curr = lerp(1.5, 6.0, t_curr) * size
		var r_next = lerp(1.5, 6.0, t_next) * size

		# Draw the inner green body on top
		draw_circle(curr, r_curr, current_skin)
		var body_quad = PackedVector2Array([
			curr + perp * r_curr, curr - perp * r_curr,
			next - perp * r_next, next + perp * r_next
		])
		draw_colored_polygon(body_quad, current_skin)

		if i % 2 != 0 and i < segment_count - 1:
			var side_offset = 1.0 if (i % 3 == 0) else -1.0 
			var spot_pos = curr + perp * (r_curr * 0.4) * side_offset
			draw_circle(spot_pos, r_curr * 0.65, current_spot)

		var gloss_quad = PackedVector2Array([
			curr + perp * (r_curr * 0.25) + Vector2(-1.0, -1.0), curr - perp * (r_curr * 0.1) + Vector2(-1.0, -1.0),
			next - perp * (r_next * 0.1) + Vector2(-1.0, -1.0), next + perp * (r_next * 0.25) + Vector2(-1.0, -1.0)
		])
		draw_colored_polygon(gloss_quad, wet_gloss)

	# --- 3. HEAD ---
	var head_pos = to_local(segment_positions[0])
	var neck_pos = to_local(segment_positions[1])
	var head_dir = (head_pos - neck_pos).normalized()
	if head_dir == Vector2.ZERO: head_dir = Vector2.RIGHT
	var head_perp = Vector2(-head_dir.y, head_dir.x)

	var snout = head_pos + head_dir * (15.0 * size)
	var snout_tip_l = head_pos + head_dir * (14.2 * size) + head_perp * (3.0 * size)
	var snout_mid_l = head_pos + head_dir * (10.5 * size) + head_perp * (6.0 * size)
	var cheek_l = head_pos + head_dir * (3.5 * size) + head_perp * (8.8 * size)
	var base_l = head_pos - head_dir * (3.0 * size) + head_perp * (5.5 * size)
	var base_r = head_pos - head_dir * (3.0 * size) - head_perp * (5.5 * size)
	var cheek_r = head_pos + head_dir * (3.5 * size) - head_perp * (8.8 * size)
	var snout_mid_r = head_pos + head_dir * (10.5 * size) - head_perp * (6.0 * size)
	var snout_tip_r = head_pos + head_dir * (14.2 * size) - head_perp * (3.0 * size)

	var head_points = PackedVector2Array([snout, snout_tip_l, snout_mid_l, cheek_l, base_l, base_r, cheek_r, snout_mid_r, snout_tip_r])
	var outline_points = PackedVector2Array([snout, snout_tip_l, snout_mid_l, cheek_l, base_l, base_r, cheek_r, snout_mid_r, snout_tip_r, snout])

	var h_shadow_points = PackedVector2Array()
	for pt in head_points:
		h_shadow_points.append(pt + Vector2(0, 3.5 * size))
	draw_colored_polygon(h_shadow_points, shadow_col)

	draw_polyline(outline_points, Color(0.04, 0.1, 0.04), 2.5 * size)
	draw_colored_polygon(head_points, current_skin)
	
	var crown_highlight = PackedVector2Array([
		head_pos + head_dir * (9.5 * size), 
		head_pos + head_dir * (4.0 * size) + head_perp * (4.5 * size), 
		head_pos - head_dir * (1.5 * size), 
		head_pos + head_dir * (4.0 * size) - head_perp * (4.5 * size)
	])
	draw_colored_polygon(crown_highlight, Color(0.8, 0.95, 0.7, 0.4))

	# --- 4. EYES (FIXED X LOGIC) ---
	var eye_l = head_pos + head_dir * (7.5 * size) + head_perp * (5.0 * size)
	var eye_r = head_pos + head_dir * (7.5 * size) - head_perp * (5.0 * size)
	
	if is_dead:
		# Draw comic-book "X" eyes directly on the skin (no black background circle!)
		var x_size = 2.2 * size
		var x_thick = 2.5 * size
		
		# Left Eye X
		draw_line(eye_l - head_dir * x_size - head_perp * x_size, eye_l + head_dir * x_size + head_perp * x_size, Color.BLACK, x_thick)
		draw_line(eye_l - head_dir * x_size + head_perp * x_size, eye_l + head_dir * x_size - head_perp * x_size, Color.BLACK, x_thick)
		
		# Right Eye X
		draw_line(eye_r - head_dir * x_size - head_perp * x_size, eye_r + head_dir * x_size + head_perp * x_size, Color.BLACK, x_thick)
		draw_line(eye_r - head_dir * x_size + head_perp * x_size, eye_r + head_dir * x_size - head_perp * x_size, Color.BLACK, x_thick)
	else:
		# Draw normal alive eyes
		draw_circle(eye_l, 2.8 * size, Color.BLACK)
		draw_circle(eye_r, 2.8 * size, Color.BLACK)
		draw_circle(eye_l, 1.6 * size, current_eye)
		draw_circle(eye_r, 1.6 * size, current_eye)
		draw_line(eye_l - head_dir * (1.5 * size), eye_l + head_dir * (1.5 * size), Color.BLACK, 1.6 * size)
		draw_line(eye_r - head_dir * (1.5 * size), eye_r + head_dir * (1.5 * size), Color.BLACK, 1.6 * size)
		draw_circle(eye_l + head_dir * (0.7 * size) - head_perp * (0.6 * size), 0.7 * size, Color.WHITE)
		draw_circle(eye_r + head_dir * (0.7 * size) + head_perp * (0.6 * size), 0.7 * size, Color.WHITE)

	# --- 5. TONGUE ---
	if is_dead:
		var droop_tip = snout + head_dir * (4.0 * size) + head_perp * (3.5 * size)
		draw_line(snout, droop_tip, Color(0.8, 0.1, 0.1), 2.0 * size)
	else:
		var tongue_active = (fmod(tongue_timer, 1.6) < 0.2) if not is_enraged else (fmod(tongue_timer, 0.4) < 0.15)
		if tongue_active:
			var t_tip = snout + head_dir * (7.0 * size)
			var t_col = Color(0.8, 0.1, 0.1)
			draw_line(snout, t_tip, t_col, 2.0 * size)
			draw_line(t_tip, t_tip + head_dir * (2.8 * size) + head_perp * (2.2 * size), t_col, 1.5 * size)
			draw_line(t_tip, t_tip + head_dir * (2.8 * size) - head_perp * (2.2 * size), t_col, 1.5 * size)

# --- COMBAT & HIT LOGIC ---
func take_hit() -> void:
	if is_dead: 
		return 
		
	is_dead = true
	
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	set_process(false) 
	queue_redraw()

	if has_node("SnakeDeathSound"):
		$SnakeDeathSound.play()

	var tween = create_tween()
	tween.tween_interval(1.0) 
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 2.0) 
	
	await tween.finished
	queue_free() 

func _on_area_entered(area: Area2D) -> void:
	if is_dead: return 
	
	if area.is_in_group("player"):
		var main_node = get_parent()
		if main_node and main_node.has_node("SnakeBiteSound"):
			main_node.get_node("SnakeBiteSound").play()
		
		if area.has_method("take_damage"):
			area.take_damage()
			
		queue_free()
