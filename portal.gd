extends Area2D

@export var lifetime: float = 15.0 
@export var warmup_duration: float = 5.0
@export var max_volume_db: float = 18.0 # Boosts the base sound by 12 decibels!

var alive_time: float = 0.0
var is_closing: bool = false
var is_active: bool = false 

func _ready() -> void:
	add_to_group("portal")
	area_entered.connect(_on_area_entered)
	
	scale = Vector2.ZERO
	modulate = Color(1.0, 1.0, 1.0, 0.1)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, warmup_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.6), warmup_duration - 0.4)
	tween.chain().tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4).set_trans(Tween.TRANS_BOUNCE)

func _process(delta: float) -> void:
	if is_closing:
		return

	alive_time += delta
	
	if alive_time >= warmup_duration and not is_active:
		is_active = true
		
# --- Dynamic Sound Fade-in & Pitch Ramp ---
	if has_node("PortalSound"):
		var p_sound = $PortalSound
		
		# Safety net to keep the loop playing
		if not p_sound.playing:
			p_sound.play()
			
		# 1. VOLUME FADE-IN (0 to 5 seconds)
		var spawn_progress = clamp(alive_time / warmup_duration, 0.0, 1.0)
		p_sound.volume_db = lerp(-40.0, max_volume_db, spawn_progress)
			
		# 2. PITCH RAMP-UP (Continuous smooth curve)
		if is_active:
			# Calculate how long the portal has been fully open (from 0.0 to 1.0)
			var active_duration = lifetime - warmup_duration
			var time_open = alive_time - warmup_duration
			var progress = clamp(time_open / active_duration, 0.0, 1.0)
			
			# pow(progress, 5.0) means progress * progress * progress * progress * progress
			# This keeps it low for a long time, then creates a massive vertical spike at the end!
			var hyper_curve = pow(progress, 5.0) 
			
			# Lerp from normal speed (1.0) up to an extreme frantic speed (4.0)
			p_sound.pitch_scale = lerp(1.0, 4.0, hyper_curve)
		else:
			# During the 5-second warmup, keep the pitch normal
			p_sound.pitch_scale = 1.0
			
	queue_redraw()
	
	if alive_time >= lifetime:
		close_portal()

func close_portal() -> void:
	is_closing = true
	
	var main = get_parent()
	if main and main.has_node("HUD/PortalIndicator"):
		main.get_node("HUD/PortalIndicator").visible = false

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.45)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.45)
	
	await tween.finished
	queue_free()

func _draw() -> void:
	# --- NEW: Smooth Visual Tension Curve ---
	var tension = 0.0
	if is_active:
		var active_duration = lifetime - warmup_duration
		var time_open = alive_time - warmup_duration
		var progress = clamp(time_open / active_duration, 0.0, 1.0)
		# Use the exact same hyper-curve as the audio so they perfectly match!
		tension = pow(progress, 5.0) 
	
	# Base slow pulse
	var pulse = sin(alive_time * 5.0) * 4.0
	
	# Smoothly add the frantic fast pulse, scaled by the tension curve
	pulse += sin(alive_time * 30.0) * (8.0 * tension)
	
	# The core color starts shifting smoothly to red/orange
	var core_color = Color(0.9, 0.95, 1.0, 0.95)
	var flash_speed = lerp(5.0, 20.0, tension) # Flash speeds up naturally
	var flash = (sin(alive_time * flash_speed) + 1.0) * 0.5 * tension
	core_color = core_color.lerp(Color(1.0, 0.3, 0.1, 1.0), flash)
	
	# Rings and Core
	draw_circle(Vector2.ZERO, 55.0 + pulse, Color(0.1, 0.25, 0.8, 0.25))   
	draw_circle(Vector2.ZERO, 38.0 - pulse * 0.5, Color(0.35, 0.7, 1.0, 0.5)) 
	draw_circle(Vector2.ZERO, 20.0 + pulse * 0.8, core_color)                
	
	# Magical Arcs
	for i in range(3):
		var ring_angle = alive_time * 2.0 + (i * PI * 0.66)
		# Add a bit of tension to make the rings spin faster at the end!
		ring_angle += alive_time * (10.0 * tension)
		draw_arc(Vector2.ZERO, 46.0 + pulse, ring_angle, ring_angle + PI * 0.8, 24, Color(0.4, 0.8, 1.0, 0.6), 4.0, true)
		draw_arc(Vector2.ZERO, 28.0 - pulse, -ring_angle, -ring_angle + PI * 0.8, 24, Color(0.9, 0.9, 1.0, 0.8), 2.0, true)
	
	# Orbiting Runes
	for i in range(8):
		var angle = -alive_time * 1.5 + (i * PI * 0.25)
		# Make the runes orbit faster at the end too!
		angle -= alive_time * (5.0 * tension)
		var rune_pos = Vector2(cos(angle), sin(angle)) * (65.0 + pulse * 0.5)
		var rune_alpha = 0.4 + sin(alive_time * 10.0 + i) * 0.6
		draw_circle(rune_pos, 4.0, Color(0.95, 0.85, 0.3, rune_alpha))

	# --- THE COUNTDOWN ---
	if not is_active:
		var count = int(ceil(warmup_duration - alive_time))
		if count > 0:
			var font = ThemeDB.fallback_font
			var text = str(count)
			var font_size = 48
			
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos = Vector2(-text_size.x / 2.0, text_size.y * 0.25) 
			
			draw_string(font, text_pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.5))
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func _on_area_entered(area: Area2D) -> void:
	if is_closing or not is_active:
		return

	if area.is_in_group("player"):
		var main_level = get_parent()
		if main_level.has_method("trigger_game_over"):
			main_level.trigger_game_over("YOU ESCAPED!\nYou evaded the perils of the canyon.", true)
