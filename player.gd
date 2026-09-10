extends Area2D

# --- CONSTANTS ---
const SPEED: float = 300.0
const TARGET_SCORE: int = 10
const MAX_HP: int = 5
const PORTAL_INTERVAL: int = 10
const PORTAL_OPEN_DURATION: int = 15
const PORTAL_COOLDOWN_DURATION: int = 20

# --- PRELOADS ---
var time_bomb_scene: PackedScene = preload("res://time_bomb.tscn")
var enemy_scene: PackedScene = preload("res://enemy.tscn")
var heart_scene: PackedScene = preload("res://heart.tscn")
var coin_particles_scene: PackedScene = preload("res://coin_particles.tscn")
var spell_scene: PackedScene = preload("res://spell.tscn")
var snake_scene: PackedScene = preload("res://snake.tscn")
@export var portal_scene: PackedScene = preload("res://portal.tscn")

# --- GAMEPLAY STATE ---
@export var base_snake_spawn_rate: float = 5.0 # Starts at 5 seconds
@export var min_snake_spawn_rate: float = 0.5  # Cap the max difficulty at 0.5 seconds
@export var spawn_rate_decrease: float = 0.5   # Gets 0.5 seconds faster every portal

@export var max_hearts_on_map: int = 3         # Maximum hearts allowed at once
@export var heart_spawn_interval: float = 10.0 # Spawns a heart every x seconds

var current_snake_spawn_rate: float = 5.0
var score: int = 0
var hp: int = 3
var game_started: bool = false
var game_over: bool = false
var is_invincible: bool = false
var can_shoot: bool = true
var shoot_cooldown: float = 0.25
var portal_is_open: bool = false
var portal_cycle_timer: int = PORTAL_COOLDOWN_DURATION

# --- ARENA & VIEWPORT ---
var base_screen_size: Vector2 = Vector2(1152, 648)
var map_size: Vector2 = Vector2(1152, 648)
var map_multiplier: float = 1.0


# ==========================================
# 1. ENGINE LIFECYCLE CALLBACKS
# ==========================================

func _ready() -> void:
	add_to_group("player")
	
	var viewport_size = get_viewport_rect().size
	if viewport_size != Vector2.ZERO:
		base_screen_size = viewport_size
		map_size = viewport_size

	# Populate Map dropdown with Medium, Large, and XLarge
	if has_node("../HUD/StartMenu/VBoxContainer/MapSettingRow/MapInput"):
		var map_picker = $"../HUD/StartMenu/VBoxContainer/MapSettingRow/MapInput" as OptionButton
		map_picker.clear()
		map_picker.add_item("Medium (1.5x)")
		map_picker.add_item("Large (2.5x)")
		map_picker.add_item("XLarge (3.5x)")

	$"../Coin".hide()
	$"../HUD/HealthLabel".hide()
	hide()

func _process(delta: float) -> void:
	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	if not game_started:
		return
	
	# Smooth mouse look-at
	var mouse_pos = get_global_mouse_position()
	rotation = (mouse_pos - global_position).angle()
	
	update_coin_indicator()

	# --- NEW: ARROW BLINKING LOGIC ---
	if portal_is_open and has_node("../HUD/PortalIndicator"):
		var indicator = $"../HUD/PortalIndicator"
		if portal_cycle_timer > 10: 
			# During the 5-second warmup, flash on and off every 250 milliseconds
			indicator.modulate.a = 1.0 if int(Time.get_ticks_msec() / 250.0) % 2 == 0 else 0.0
		else:
			# Force it back to solid visibility once the portal is fully open
			indicator.modulate.a = 1.0
	# ---------------------------------

	# WASD / Arrow Movement
	var velocity = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		velocity.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		velocity.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		velocity.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		velocity.y -= 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * SPEED

	position += velocity * delta

	# Clamp wizard inside visible playable boundary
	position.x = clamp(position.x, 32, map_size.x - 32)
	position.y = clamp(position.y, 32, map_size.y - 32)

func _unhandled_input(event: InputEvent) -> void:
	# Cast Spell on Left Click
	if game_started and not game_over and can_shoot:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			cast_spell()

	# Pause / Escape Handling
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		toggle_settings()

	# Start Game with Enter
	if not game_started and not game_over:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER)):
			if has_node("../HUD/SettingsMenu") and not $"../HUD/SettingsMenu".visible:
				_on_start_button_pressed()


# ==========================================
# 2. COMBAT & DAMAGE ACTIONS
# ==========================================

func cast_spell() -> void:
	can_shoot = false

	if has_node("../SpellSound"):
		$"../SpellSound".play()

	var mouse_pos = get_global_mouse_position()
	
	# Determine spawn origin from the StaffTip Marker2D
	var spawn_pos = global_position
	if has_node("StaffTip"):
		spawn_pos = $StaffTip.global_position

	# Calculate direction from the staff tip towards the mouse cursor
	var shoot_dir = (mouse_pos - spawn_pos).normalized()

	var spell = spell_scene.instantiate()
	spell.global_position = spawn_pos
	spell.set_direction(shoot_dir)
	get_parent().add_child(spell)

	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true


func take_damage() -> void:
	if is_invincible or game_over or not game_started:
		return
	
	is_invincible = true
	hp -= 1
	update_hp_display()
	
	spawn_floating_text(position, "-1 HP 💔", Color(1.0, 0.25, 0.25))
	get_tree().call_group("camera", "shake", 8.0)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 0.6), 0.1)
	tween.parallel().tween_property(self, "scale", Vector2(0.85, 0.85), 0.1)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
	
	if hp <= 0:
		trigger_game_over("YOU DIED!\nYou ran out of HP.\nPress R to Retry", false)
		return
		
	await tween.finished
	is_invincible = false


# ==========================================
# 3. LEVEL & EXTRACTION LOGIC
# ==========================================

func spawn_extraction_portal() -> void:
	# Clear any previous portal instance
	get_tree().call_group("portal", "queue_free")
	
	# Spawn anywhere inside the map boundaries (leaving a 100px margin so it doesn't clip off-screen)
	var margin = 100.0
	var portal_pos = Vector2(
		randf_range(margin, map_size.x - margin),
		randf_range(margin, map_size.y - margin)
	)

	var portal = portal_scene.instantiate()
	portal.global_position = portal_pos
	get_parent().add_child(portal)

	if get_parent().has_node("HUD/PortalIndicator"):
		get_parent().get_node("HUD/PortalIndicator").track(portal, self)

func trigger_game_over(message: String, is_win: bool = false) -> void:
	game_over = true
	$"../Timer".stop()
	if has_node("../HeartTimer"):
		$"../HeartTimer".stop()
	if has_node("../TimeBombTimer"):
		$"../TimeBombTimer".stop()
	$"../SnakeTimer".stop()
		
	if has_node("../GameMusic"):
		$"../GameMusic".stop()
	if has_node("../HUD/CoinIndicator"):
		$"../HUD/CoinIndicator".hide()
	if has_node("../HUD/PortalIndicator"):
		$"../HUD/PortalIndicator".hide()

	if is_win:
		if has_node("../WinMusic"):
			$"../WinMusic".play()
		elif has_node("../WinSound"):
			$"../WinSound".play()
	else:
		if has_node("../LoseMusic"):
			$"../LoseMusic".play()
		elif has_node("../LoseSound"):
			$"../LoseSound".play()
	
	$"../Coin".hide()
	get_tree().call_group("enemies", "hide")
	get_tree().call_group("snakes", "queue_free")
	get_tree().call_group("portal", "queue_free")
	get_tree().call_group("hearts", "queue_free")
	get_tree().call_group("time_bombs", "queue_free")
	
	if has_node("../HUD/ResultLabel"):
		$"../HUD/ResultLabel".text = message
		$"../HUD/ResultLabel".modulate = Color(0.3, 1.0, 0.4) if is_win else Color(1.0, 0.3, 0.3)
		$"../HUD/ResultLabel".show()


# ==========================================
# 4. COLLISION & AREA SIGNALS
# ==========================================

func _on_area_entered(area: Area2D) -> void:
	if is_invincible or game_over or not game_started:
		return

	# Bouncing bomb hit
	if area.is_in_group("enemies"):
		if has_node("../BombSound"):
			$"../BombSound".play()
		take_damage()

	# Timed ticking bomb hit
	elif area.is_in_group("time_bombs"):
		take_damage()

	# Snake hit 
	elif area.is_in_group("snakes"):
		take_damage()

	# Health pickup
	elif area.is_in_group("hearts"):
		if hp < MAX_HP:
			hp += 1
			update_hp_display()
			spawn_floating_text(area.position, "+1 HP ❤️", Color(0.3, 1.0, 0.4))
		if has_node("../HealSound"):
			$"../HealSound".play()
		area.queue_free()


func _on_coin_area_entered(area: Area2D) -> void:
	if game_over or not game_started or area != self:
		return
		
	var coin = $"../Coin"
	spawn_floating_text(coin.position, "+1")
	
	var burst = coin_particles_scene.instantiate()
	burst.position = coin.position
	get_parent().add_child(burst)

	var tween = create_tween()
	tween.tween_property(coin, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(coin, "scale", Vector2(1.0, 1.0), 0.05)

	coin.position = Vector2(
		randf_range(64, map_size.x - 64),
		randf_range(64, map_size.y - 64)
	)
	
	if has_node("../CoinSound"):
		$"../CoinSound".play()
	
	score += 1
	if has_node("../HUD/Score"):
		$"../HUD/Score".text = "Score: " + str(score)


# ==========================================
# 5. TIMER CALLBACKS
# ==========================================

func _on_timer_timeout() -> void:
	if game_over or not game_started:
		return
		
	portal_cycle_timer -= 1
	
	if has_node("../HUD/TimeLabel"):
		if portal_is_open:
			if portal_cycle_timer > 10:
				# --- WARMUP PHASE (Seconds 13, 12, 11 map to 3, 2, 1) ---
				var warmup_left = portal_cycle_timer - 10
				$"../HUD/TimeLabel".text = "Forming... (" + str(warmup_left) + "s)"
				$"../HUD/TimeLabel".modulate = Color(1.0, 0.7, 0.2) # Warning Orange
			else:
				# --- ESCAPE PHASE (Seconds 10 down to 0) ---
				$"../HUD/TimeLabel".text = "ESCAPE! (" + str(portal_cycle_timer) + "s)"
				$"../HUD/TimeLabel".modulate = Color(0.2, 0.9, 1.0) # Escape Blue
		else:
			# --- COOLDOWN PHASE ---
			$"../HUD/TimeLabel".text = "Portal in: " + str(portal_cycle_timer) + "s"
			$"../HUD/TimeLabel".modulate = Color.WHITE

	# State switch
	if portal_cycle_timer <= 0:
		if portal_is_open:
			# Portal duration ended: close portal and start 15s cooldown
			portal_is_open = false
			portal_cycle_timer = PORTAL_COOLDOWN_DURATION
			get_tree().call_group("portal", "close_portal")
			
			# Increase Difficulty
			current_snake_spawn_rate = max(min_snake_spawn_rate, current_snake_spawn_rate - spawn_rate_decrease)
			
			if has_node("../SnakeTimer"):
				$"../SnakeTimer".wait_time = current_snake_spawn_rate
				
		else:
			# Cooldown finished: spawn new portal for 13s (3s warmup + 10s open)
			portal_is_open = true
			portal_cycle_timer = PORTAL_OPEN_DURATION
			spawn_extraction_portal()

func _on_snake_timer_timeout() -> void:
	if game_over or not game_started:
		return
	
	var snake = snake_scene.instantiate()
	var edge = randi() % 4
	var spawn_pos = Vector2.ZERO
	match edge:
		0: spawn_pos = Vector2(randf_range(30, map_size.x - 30), 20)
		1: spawn_pos = Vector2(randf_range(30, map_size.x - 30), map_size.y - 20)
		2: spawn_pos = Vector2(20, randf_range(30, map_size.y - 30))
		3: spawn_pos = Vector2(map_size.x - 20, randf_range(30, map_size.y - 30))

	snake.position = spawn_pos
	get_parent().add_child(snake)

func _on_heart_timer_timeout() -> void:
	if game_over or not game_started:
		return
		
	# --- NEW: Check the heart limit before spawning ---
	var current_hearts = get_tree().get_nodes_in_group("hearts").size()
	if current_hearts >= max_hearts_on_map:
		return # Cancel the spawn if the map is already full of hearts!
	
	var new_heart = heart_scene.instantiate()
	new_heart.position = Vector2(
		randf_range(64, map_size.x - 64),
		randf_range(64, map_size.y - 64)
	)
	get_parent().add_child(new_heart)

func _on_time_bomb_timer_timeout() -> void:
	if game_over or not game_started:
		return
	
	var bomb = time_bomb_scene.instantiate()
	var margin = 130.0
	bomb.position = Vector2(
		randf_range(margin, map_size.x - margin),
		randf_range(margin, map_size.y - margin)
	)
	get_parent().add_child(bomb)

# ==========================================
# 6. UI & HUD HELPERS
# ==========================================

func _on_start_button_pressed() -> void:
	
	portal_is_open = false
	portal_cycle_timer = PORTAL_COOLDOWN_DURATION
	if has_node("../HUD/TimeLabel"):
		$"../HUD/TimeLabel".text = "Portal in: " + str(portal_cycle_timer) + "s"
		$"../HUD/TimeLabel".modulate = Color.WHITE
		
	$"../HUD/HealthLabel".show()
	
	# Map Size
	map_multiplier = 1.5
	if has_node("../HUD/StartMenu/VBoxContainer/MapSettingRow/MapInput"):
		var selected_idx = $"../HUD/StartMenu/VBoxContainer/MapSettingRow/MapInput".selected
		match selected_idx:
			0: map_multiplier = 1.5  # Medium: 50% larger than default screen
			1: map_multiplier = 2.5  # Large: expanded exploration arena
			2: map_multiplier = 3.5  # XLarge: massive survival zone

	map_size = base_screen_size * map_multiplier
	
	if has_node("Camera2D"):
		$Camera2D.limit_left = 0
		$Camera2D.limit_top = 0
		$Camera2D.limit_right = int(map_size.x)
		$Camera2D.limit_bottom = int(map_size.y)

	if has_node("../Background"):
		$"../Background".scale = Vector2(map_multiplier, map_multiplier)

	var bomb_count = 1
	if has_node("../HUD/StartMenu/VBoxContainer/BombSettingRow/BombInput"):
		bomb_count = int($"../HUD/StartMenu/VBoxContainer/BombSettingRow/BombInput".value)
	
	hp = 3
	update_hp_display()
	
	current_snake_spawn_rate = base_snake_spawn_rate
	if has_node("../SnakeTimer"):
		$"../SnakeTimer".wait_time = current_snake_spawn_rate
	
	portal_cycle_timer = PORTAL_INTERVAL
	if has_node("../HUD/TimeLabel"):
		$"../HUD/TimeLabel".text = "Portal in: " + str(portal_cycle_timer) + "s"
		$"../HUD/TimeLabel".modulate = Color.WHITE
		
	$"../HUD/StartMenu".hide()
	
	if has_node("../MenuMusic"):
		$"../MenuMusic".stop()
	if has_node("../GameMusic"):
		$"../GameMusic".play()

	for i in range(bomb_count):
		var new_enemy = enemy_scene.instantiate()
		new_enemy.position = Vector2(
			randf_range(100, map_size.x - 100),
			randf_range(100, map_size.y - 100)
		)
		if new_enemy.has_method("set_bounds"):
			new_enemy.set_bounds(map_size)
		get_parent().add_child(new_enemy)
	
	$"../Coin".position = Vector2(
		randf_range(64, map_size.x - 64),
		randf_range(64, map_size.y - 64)
	)

	show()
	$"../Coin".show()
	game_started = true
	
	$"../Timer".start()
	if has_node("../HeartTimer"):
		$"../HeartTimer".wait_time = heart_spawn_interval
		$"../HeartTimer".start()
	if has_node("../TimeBombTimer"):
		$"../TimeBombTimer".start()
	$"../SnakeTimer".start()


func update_hp_display() -> void:
	if has_node("../HUD/HealthLabel"):
		var heart_string = ""
		for i in range(hp):
			heart_string += "❤️"
		$"../HUD/HealthLabel".text = heart_string


func update_coin_indicator() -> void:
	if not has_node("../HUD/CoinIndicator") or not has_node("../Coin"):
		return

	var indicator = $"../HUD/CoinIndicator"
	var coin = $"../Coin"

	if not game_started or game_over or not coin.visible:
		indicator.hide()
		return

	var canvas_transform = get_viewport().get_canvas_transform()
	var coin_screen_pos = canvas_transform * coin.global_position
	var vp_size = get_viewport_rect().size
	var viewport_rect = Rect2(Vector2.ZERO, vp_size)

	if viewport_rect.has_point(coin_screen_pos):
		indicator.hide()
		return

	indicator.show()
	var screen_center = vp_size * 0.5
	var dir = (coin_screen_pos - screen_center).normalized()
	indicator.rotation = dir.angle()

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

	indicator.position = screen_center + dir * min(t_x, t_y)
	indicator.queue_redraw()


func spawn_floating_text(pos: Vector2, text_to_show: String, custom_color: Color = Color(1.0, 0.85, 0.2)) -> void:
	var label = Label.new()
	label.text = text_to_show
	label.position = pos + Vector2(-20, -25)
	label.z_index = 50
	
	label.add_theme_color_override("font_color", custom_color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_font_size_override("font_size", 20)
	
	get_parent().add_child(label)
	
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 35, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.finished.connect(label.queue_free)


# ==========================================
# 7. SETTINGS & AUDIO CONTROLS
# ==========================================

func toggle_settings() -> void:
	if not has_node("../HUD/SettingsMenu"):
		return
	var settings = $"../HUD/SettingsMenu"
	if settings.visible:
		settings.hide()
		if game_started and not game_over:
			get_tree().paused = false
	else:
		settings.show()
		if game_started and not game_over:
			get_tree().paused = true


func _on_settings_button_pressed() -> void:
	toggle_settings()


func _on_close_button_pressed() -> void:
	toggle_settings()


func _on_music_slider_value_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	if value <= 0.01:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


func _on_sfx_slider_value_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if value <= 0.01:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
