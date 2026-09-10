extends Node2D

# ==========================================
# CONSTANTS
# ==========================================
const TARGET_SCORE: int = 10
const PORTAL_INTERVAL: int = 10
const PORTAL_OPEN_DURATION: int = 15
const PORTAL_COOLDOWN_DURATION: int = 20

# ==========================================
# PRELOADS (PackedScenes)
# ==========================================
var time_bomb_scene: PackedScene = preload("res://time_bomb.tscn")
var enemy_scene: PackedScene = preload("res://enemy.tscn")
var heart_scene: PackedScene = preload("res://heart.tscn")
var coin_particles_scene: PackedScene = preload("res://coin_particles.tscn")
var snake_scene: PackedScene = preload("res://snake.tscn")
@export var portal_scene: PackedScene = preload("res://portal.tscn")

# ==========================================
# GAMEPLAY STATE & DIFFICULTY
# ==========================================
@export var base_snake_spawn_rate: float = 5.0
@export var min_snake_spawn_rate: float = 0.5 
@export var spawn_rate_decrease: float = 0.5   
@export var max_hearts_on_map: int = 3         
@export var heart_spawn_interval: float = 10.0 

var current_snake_spawn_rate: float = 5.0
var score: int = 0
var game_started: bool = false
var game_over: bool = false
var portal_is_open: bool = false
var portal_cycle_timer: int = PORTAL_COOLDOWN_DURATION

# ==========================================
# ARENA SETTINGS
# ==========================================
var base_screen_size: Vector2 = Vector2(1152, 648)
var map_size: Vector2 = Vector2(1152, 648)
var map_multiplier: float = 1.0

# ==========================================
# NODE REFERENCES (Cached for Performance)
# ==========================================
@onready var player = $Player
@onready var coin = $Coin
@onready var main_timer = $Timer
@onready var snake_timer = $SnakeTimer

# ==========================================
# 1. ENGINE LIFECYCLE
# ==========================================
func _ready() -> void:
	var viewport_size = get_viewport_rect().size
	if viewport_size != Vector2.ZERO:
		base_screen_size = viewport_size
		map_size = viewport_size

	if has_node("HUD/StartMenu/VBoxContainer/MapSettingRow/MapInput"):
		var map_picker = $HUD/StartMenu/VBoxContainer/MapSettingRow/MapInput as OptionButton
		map_picker.clear()
		map_picker.add_item("Medium (1.5x)")
		map_picker.add_item("Large (2.5x)")
		map_picker.add_item("XLarge (3.5x)")

	coin.hide()
	if has_node("HUD/HealthLabel"):
		$HUD/HealthLabel.hide()
	player.hide()
	
	# Connect Player Signals
	player.health_changed.connect(update_hp_display)
	player.player_died.connect(func(): trigger_game_over("YOU DIED!\nYou ran out of HP.\nPress R to Retry", false))
	coin.area_entered.connect(_on_coin_area_entered)


func _process(delta: float) -> void:
	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	if not game_started:
		return
	
	update_coin_indicator()

	# Arrow Blinking Logic
	if portal_is_open and has_node("HUD/PortalIndicator"):
		var indicator = $HUD/PortalIndicator
		if portal_cycle_timer > 10: 
			indicator.modulate.a = 1.0 if int(Time.get_ticks_msec() / 250.0) % 2 == 0 else 0.0
		else:
			indicator.modulate.a = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		toggle_settings()

	if not game_started and not game_over:
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER)):
			if has_node("HUD/SettingsMenu") and not $HUD/SettingsMenu.visible:
				_on_start_button_pressed()

# ==========================================
# 2. LEVEL & EXTRACTION LOGIC
# ==========================================
func spawn_extraction_portal() -> void:
	get_tree().call_group("portal", "queue_free")
	var margin = 100.0
	var portal_pos = Vector2(randf_range(margin, map_size.x - margin), randf_range(margin, map_size.y - margin))

	var portal = portal_scene.instantiate()
	portal.global_position = portal_pos
	add_child(portal)

	if has_node("HUD/PortalIndicator"):
		$HUD/PortalIndicator.track(portal, player)

func trigger_game_over(message: String, is_win: bool = false) -> void:
	game_over = true
	player.game_over = true 
	
	main_timer.stop()
	snake_timer.stop()
	if has_node("HeartTimer"): $HeartTimer.stop()
	if has_node("TimeBombTimer"): $TimeBombTimer.stop()
		
	if has_node("GameMusic"): $GameMusic.stop()
	if has_node("HUD/CoinIndicator"): $HUD/CoinIndicator.hide()
	if has_node("HUD/PortalIndicator"): $HUD/PortalIndicator.hide()

	if is_win:
		if has_node("WinMusic"): $WinMusic.play()
		elif has_node("WinSound"): $WinSound.play()
	else:
		if has_node("LoseMusic"): $LoseMusic.play()
		elif has_node("LoseSound"): $LoseSound.play()
	
	coin.hide()
	get_tree().call_group("enemies", "hide")
	get_tree().call_group("snakes", "queue_free")
	get_tree().call_group("portal", "queue_free")
	get_tree().call_group("hearts", "queue_free")
	get_tree().call_group("time_bombs", "queue_free")
	
	if has_node("HUD/ResultLabel"):
		$HUD/ResultLabel.text = message
		$HUD/ResultLabel.modulate = Color(0.3, 1.0, 0.4) if is_win else Color(1.0, 0.3, 0.3)
		$HUD/ResultLabel.show()

# ==========================================
# 3. ITEM COLLISIONS
# ==========================================
func _on_coin_area_entered(area: Area2D) -> void:
	if game_over or not game_started or not area.is_in_group("player"):
		return
		
	spawn_floating_text(coin.position, "+1")
	
	var burst = coin_particles_scene.instantiate()
	burst.position = coin.position
	add_child(burst)

	var tween = create_tween()
	tween.tween_property(coin, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(coin, "scale", Vector2.ONE, 0.05)

	coin.position = Vector2(randf_range(64, map_size.x - 64), randf_range(64, map_size.y - 64))
	
	if has_node("CoinSound"):
		$CoinSound.play()
	
	score += 1
	if has_node("HUD/Score"):
		$HUD/Score.text = "Score: " + str(score)

# ==========================================
# 4. TIMERS
# ==========================================
func _on_timer_timeout() -> void:
	if game_over or not game_started: return
	portal_cycle_timer -= 1
	
	if has_node("HUD/TimeLabel"):
		if portal_is_open:
			if portal_cycle_timer > 10:
				var warmup_left = portal_cycle_timer - 10
				$HUD/TimeLabel.text = "Forming... (" + str(warmup_left) + "s)"
				$HUD/TimeLabel.modulate = Color(1.0, 0.7, 0.2) 
			else:
				$HUD/TimeLabel.text = "ESCAPE! (" + str(portal_cycle_timer) + "s)"
				$HUD/TimeLabel.modulate = Color(0.2, 0.9, 1.0) 
		else:
			$HUD/TimeLabel.text = "Portal in: " + str(portal_cycle_timer) + "s"
			$HUD/TimeLabel.modulate = Color.WHITE

	if portal_cycle_timer <= 0:
		if portal_is_open:
			portal_is_open = false
			portal_cycle_timer = PORTAL_COOLDOWN_DURATION
			get_tree().call_group("portal", "close_portal")
			
			current_snake_spawn_rate = max(min_snake_spawn_rate, current_snake_spawn_rate - spawn_rate_decrease)
			snake_timer.wait_time = current_snake_spawn_rate
		else:
			portal_is_open = true
			portal_cycle_timer = PORTAL_OPEN_DURATION
			spawn_extraction_portal()

func _on_snake_timer_timeout() -> void:
	if game_over or not game_started: return
	
	var snake = snake_scene.instantiate()
	var spawn_pos = Vector2.ZERO
	
	# Pick a random edge: 0 = Top, 1 = Bottom, 2 = Left, 3 = Right
	var edge = randi() % 4 
	match edge:
		0: spawn_pos = Vector2(randf_range(30, map_size.x - 30), 20)
		1: spawn_pos = Vector2(randf_range(30, map_size.x - 30), map_size.y - 20)
		2: spawn_pos = Vector2(20, randf_range(30, map_size.y - 30))
		3: spawn_pos = Vector2(map_size.x - 20, randf_range(30, map_size.y - 30))

	snake.position = spawn_pos
	add_child(snake)

func _on_heart_timer_timeout() -> void:
	if game_over or not game_started: return
	var current_hearts = get_tree().get_nodes_in_group("hearts").size()
	if current_hearts >= max_hearts_on_map: return 
	
	var new_heart = heart_scene.instantiate()
	new_heart.position = Vector2(randf_range(64, map_size.x - 64), randf_range(64, map_size.y - 64))
	add_child(new_heart)

func _on_time_bomb_timer_timeout() -> void:
	if game_over or not game_started: return
	var bomb = time_bomb_scene.instantiate()
	bomb.position = Vector2(randf_range(130, map_size.x - 130), randf_range(130, map_size.y - 130))
	add_child(bomb)

# ==========================================
# 5. UI & LOGIC
# ==========================================
func _on_start_button_pressed() -> void:
	portal_is_open = false
	portal_cycle_timer = PORTAL_COOLDOWN_DURATION
	if has_node("HUD/HealthLabel"):
		$HUD/HealthLabel.show()
	
	map_multiplier = 1.5
	if has_node("HUD/StartMenu/VBoxContainer/MapSettingRow/MapInput"):
		var selected_idx = $HUD/StartMenu/VBoxContainer/MapSettingRow/MapInput.selected
		match selected_idx:
			0: map_multiplier = 1.5
			1: map_multiplier = 2.5
			2: map_multiplier = 3.5

	map_size = base_screen_size * map_multiplier
	
	if has_node("Background"):
		$Background.scale = Vector2(map_multiplier, map_multiplier)

	var bomb_count = 1
	if has_node("HUD/StartMenu/VBoxContainer/BombSettingRow/BombInput"):
		bomb_count = int($HUD/StartMenu/VBoxContainer/BombSettingRow/BombInput.value)
	
	# Setup the Player
	player.hp = 3
	player.map_size = map_size
	player.game_started = true
	player.game_over = false
	player.show()
	player.global_position = map_size / 2.0
	player.set_camera_limits(map_size)
	update_hp_display(player.hp)
	
	current_snake_spawn_rate = base_snake_spawn_rate
	snake_timer.wait_time = current_snake_spawn_rate
	
	if has_node("HUD/StartMenu"): $HUD/StartMenu.hide()
	if has_node("MenuMusic"): $MenuMusic.stop()
	if has_node("GameMusic"): $GameMusic.play()

	for i in range(bomb_count):
			var new_enemy = enemy_scene.instantiate()
			
			# --- FIX: Safe Spawn Distance ---
			var safe_distance = 250.0 
			var spawn_pos = Vector2.ZERO
			while true:
				spawn_pos = Vector2(randf_range(100, map_size.x - 100), randf_range(100, map_size.y - 100))
				# If the spot is far enough away from the player, break the loop and spawn it!
				if spawn_pos.distance_to(player.global_position) > safe_distance:
					break
					
			new_enemy.position = spawn_pos
			if new_enemy.has_method("set_bounds"): new_enemy.set_bounds(map_size)
			add_child(new_enemy)
	
	coin.position = Vector2(randf_range(64, map_size.x - 64), randf_range(64, map_size.y - 64))
	coin.show()
	game_started = true
	
	main_timer.start()
	if has_node("HeartTimer"):
		$HeartTimer.wait_time = heart_spawn_interval
		$HeartTimer.start()
	if has_node("TimeBombTimer"): $TimeBombTimer.start()
	snake_timer.start()

func update_hp_display(new_hp: int) -> void:
	if has_node("HUD/HealthLabel"):
		var heart_string = ""
		for i in range(new_hp):
			heart_string += "❤️"
		$HUD/HealthLabel.text = heart_string

func update_coin_indicator() -> void:
	var indicator = $HUD/CoinIndicator if has_node("HUD/CoinIndicator") else null
	if not indicator or not game_started or game_over or not coin.visible:
		if indicator: indicator.hide()
		return

	var canvas_transform = get_viewport().get_canvas_transform()
	var coin_screen_pos = canvas_transform * coin.global_position
	var vp_size = get_viewport_rect().size
	if Rect2(Vector2.ZERO, vp_size).has_point(coin_screen_pos):
		indicator.hide()
		return

	indicator.show()
	var screen_center = vp_size * 0.5
	var dir = (coin_screen_pos - screen_center).normalized()
	indicator.rotation = dir.angle()

	var p = 45.0
	var min_b = Vector2(p, p)
	var max_b = vp_size - min_b
	var t_x = INF
	var t_y = INF

	if dir.x > 0: t_x = (max_b.x - screen_center.x) / dir.x
	elif dir.x < 0: t_x = (min_b.x - screen_center.x) / dir.x
	if dir.y > 0: t_y = (max_b.y - screen_center.y) / dir.y
	elif dir.y < 0: t_y = (min_b.y - screen_center.y) / dir.y

	indicator.position = screen_center + dir * min(t_x, t_y)
	indicator.queue_redraw()

func spawn_floating_text(pos: Vector2, text_to_show: String, custom_color: Color = Color(1.0, 0.85, 0.2)) -> void:
	var label = Label.new()
	label.text = text_to_show
	label.position = pos + Vector2(-20, -25)
	label.z_index = 50
	label.add_theme_color_override("font_color", custom_color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)
	
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 35, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.finished.connect(label.queue_free)

func toggle_settings() -> void:
	if not has_node("HUD/SettingsMenu"): return
	var settings = $HUD/SettingsMenu
	settings.visible = not settings.visible
	if game_started and not game_over: get_tree().paused = settings.visible

func _on_settings_button_pressed() -> void: toggle_settings()
func _on_close_button_pressed() -> void: toggle_settings()

func _on_music_slider_value_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(bus_idx, value <= 0.01)
	if value > 0.01: AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_sfx_slider_value_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(bus_idx, value <= 0.01)
	if value > 0.01: AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
