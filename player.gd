extends Area2D

# ==========================================
# SIGNALS (How Player talks to Main Level)
# ==========================================
signal health_changed(new_hp: int)
signal player_died

# ==========================================
# CONSTANTS & EXPORTS
# ==========================================
const SPEED: float = 300.0
const MAX_HP: int = 5

@export var spell_scene: PackedScene 

# ==========================================
# STATE VARIABLES
# ==========================================
var hp: int = 3
var is_invincible: bool = false
var can_shoot: bool = true
var shoot_cooldown: float = 0.25

# Managed externally by the Main Level
var map_size: Vector2 = Vector2(1152, 648)
var game_started: bool = false
var game_over: bool = false

# ==========================================
# NODE REFERENCES
# ==========================================
@onready var staff_tip: Node2D = $StaffTip if has_node("StaffTip") else null

# ==========================================
# ENGINE LIFECYCLE
# ==========================================
func _ready() -> void:
	add_to_group("player")
	area_entered.connect(_on_area_entered)

func set_camera_limits(rect_size: Vector2) -> void:
	if has_node("Camera2D"):
		var cam = $Camera2D
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(rect_size.x)
		cam.limit_bottom = int(rect_size.y)

func _process(delta: float) -> void:
	if game_over or not game_started:
		return
	
	# 1. Aiming
	rotation = (get_global_mouse_position() - global_position).angle()

	# 2. Movement (Restored your custom WASD checks!)
	var velocity = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D): velocity.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A): velocity.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S): velocity.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W): velocity.y -= 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * SPEED

	position += velocity * delta

	# 3. Map Boundaries
	position.x = clamp(position.x, 32, map_size.x - 32)
	position.y = clamp(position.y, 32, map_size.y - 32)

func _unhandled_input(event: InputEvent) -> void:
	if not game_started or game_over or not can_shoot:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cast_spell()

# ==========================================
# COMBAT METHODS
# ==========================================
func cast_spell() -> void:
	if spell_scene == null:
		return
		
	can_shoot = false
	var spawn_pos = staff_tip.global_position if staff_tip else global_position
	var shoot_dir = (get_global_mouse_position() - spawn_pos).normalized()

	# --- FIX: Play Spell Sound from Main Level ---
	if get_parent().has_node("SpellSound"):
		get_parent().get_node("SpellSound").play()

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
	health_changed.emit(hp) 
	
	get_tree().call_group("camera", "shake", 8.0)
	
	# --- FIX: Ask the Main Level to spawn the floating text ---
	if get_parent().has_method("spawn_floating_text"):
		get_parent().spawn_floating_text(global_position, "-1 HP 💔", Color(1.0, 0.25, 0.25))
	
	# Visual damage feedback
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 0.6), 0.1)
	tween.parallel().tween_property(self, "scale", Vector2(0.85, 0.85), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.3)
	
	if hp <= 0:
		player_died.emit() 
		return
		
	await tween.finished
	is_invincible = false

# ==========================================
# COLLISION HANDLING
# ==========================================
func _on_area_entered(area: Area2D) -> void:
	if is_invincible or game_over or not game_started:
		return

	if area.is_in_group("enemies"):
		# --- FIX: Play Bouncing Bomb Hit Sound ---
		if get_parent().has_node("BombSound"):
			get_parent().get_node("BombSound").play()
		take_damage()
		
	elif area.is_in_group("time_bombs") or area.is_in_group("snakes"):
		take_damage()
		
	elif area.is_in_group("hearts"):
		if hp < MAX_HP:
			hp += 1
			health_changed.emit(hp)
			if get_parent().has_method("spawn_floating_text"):
				get_parent().spawn_floating_text(area.global_position, "+1 HP ❤️", Color(0.3, 1.0, 0.4))
			if get_parent().has_node("HealSound"):
				get_parent().get_node("HealSound").play()
		area.queue_free()
