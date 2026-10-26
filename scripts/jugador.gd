
extends CharacterBody2D

@export var sprite: AnimatedSprite2D
@export var speed := 116.0
@export var acceleration := 1700.0
@export var deceleration := 950.0
@export var float_height := 1.0
@export var float_speed := 6.0

@export_group("Sombra")
@export var shadow: Sprite2D
@export var shadow_base_scale := 1.0 ## escala base
@export_range(0.0, 1.0, 0.05) var shadow_min_scale := 0.6 ## achicamiento al estar arriba del todo.
@export_range(0.0, 1.0, 0.05) var shadow_base_alpha := 1 ## opacidad base
@export_range(0.0, 1.0, 0.05) var shadow_min_alpha := 0.5 ## desvanecimiento al estar arriba del todo.

@onready var player_light: PointLight2D = $Luz


enum PlayerState {
	FREE,
	ENTERING_HIDE,
	HIDDEN,
	EXITING_HIDE,
	GIFT_CHALLENGE
}

var state: PlayerState = PlayerState.FREE
var current_hide: Node2D = null

var float_time := 0.0
var sprite_start_position := Vector2.ZERO

var facing_right := false
var is_turning := false


func _ready() -> void:
	sprite_start_position = sprite.position
	sprite.animation_finished.connect(_on_sprite_animation_finished)


func _physics_process(delta: float) -> void:
	match state:
		PlayerState.FREE:
			var direction := Input.get_vector(
				"mov_izq", "mov_der", "mov_arr", "mov_aba"
			)

			_apply_movement(direction, delta)

			# Una colisión puede haber iniciado el escondite
			# durante move_and_slide().
			if state != PlayerState.FREE:
				return

			_maybe_start_turn(direction)
			_update_animation(direction)
			_update_float(delta)

		PlayerState.ENTERING_HIDE:
			velocity = Vector2.ZERO

		PlayerState.HIDDEN:
			velocity = Vector2.ZERO

			if _movement_key_just_pressed():
				_start_exit_hide()

		PlayerState.EXITING_HIDE:
			velocity = Vector2.ZERO
			
		PlayerState.GIFT_CHALLENGE:
			velocity = Vector2.ZERO


func _apply_movement(direction: Vector2, delta: float) -> void:
	var target := direction * speed
	var rate := acceleration if direction != Vector2.ZERO else deceleration

	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()


func _maybe_start_turn(direction: Vector2) -> void:
	if is_turning or direction.x == 0.0:
		return

	var desired_right := direction.x > 0.0

	if desired_right != facing_right:
		facing_right = desired_right
		is_turning = true
		sprite.play("frente")


func _update_animation(direction: Vector2) -> void:
	if is_turning:
		return

	if direction != Vector2.ZERO:
		sprite.play("andando")
	else:
		sprite.play("quieto")

#==========================
#=== Flotación y sombra ===
#==========================
func _update_float(delta: float) -> void:
	float_time += delta * float_speed
	var wave := sin(float_time)              # -1 (arriba) a +1 (abajo)
	sprite.position.y = sprite_start_position.y + wave * float_height
	_update_shadow(wave)


func _update_shadow(wave: float) -> void:
	# Normalizamos: 0 = arriba del todo, 1 = abajo del todo.
	var t := (wave + 1.0) * 0.5

	var scale_factor := lerpf(shadow_min_scale, 1.0, t)
	var alpha_factor := lerpf(shadow_min_alpha, 1.0, t)

	shadow.scale = Vector2.ONE * shadow_base_scale * scale_factor
	shadow.modulate.a = shadow_base_alpha * alpha_factor


# Para estados donde NO flota (quieto, escondido, etc.).
func _set_shadow_rest() -> void:
	shadow.scale = Vector2.ONE * shadow_base_scale
	shadow.modulate.a = shadow_base_alpha

#=================
#=== Escondite ===
#=================
func try_enter_hide(hide_spot: Node2D) -> void:
	if state != PlayerState.FREE:
		return

	current_hide = hide_spot

	# Alinear el personaje con el punto de origen del pozo.
	global_position = hide_spot.global_position
	velocity = Vector2.ZERO

	# Cancelar un posible giro en curso.
	is_turning = false
	sprite.stop()
	sprite.position = sprite_start_position

	# Ocultar el personaje real, su luz y sombra.
	sprite.visible = false
	player_light.visible = false
	shadow.visible = false

	_change_state(PlayerState.ENTERING_HIDE)
	hide_spot.call("play_enter", self)


# Se llama al terminar la animación de entrada.
func finish_enter_hide(hide_spot: Node2D) -> void:
	if state != PlayerState.ENTERING_HIDE or current_hide != hide_spot:
		return
	_change_state(PlayerState.HIDDEN)


# Comprueba si se acaba de pulsar alguna flecha.
func _movement_key_just_pressed() -> bool:
	return (
		Input.is_action_just_pressed("mov_izq")
		or Input.is_action_just_pressed("mov_der")
		or Input.is_action_just_pressed("mov_arr")
		or Input.is_action_just_pressed("mov_aba")
	)


# Comienza la animación de salida.
func _start_exit_hide() -> void:
	if state != PlayerState.HIDDEN or current_hide == null:
		return

	velocity = Vector2.ZERO
	_change_state(PlayerState.EXITING_HIDE)
	current_hide.call("play_exit")


# Se llama al terminar la animación de salida.
func finish_exit_hide(hide_spot: Node2D) -> void:
	if state != PlayerState.EXITING_HIDE or current_hide != hide_spot:
		return

	current_hide = null
	velocity = Vector2.ZERO

	sprite.position = sprite_start_position
	sprite.play("quieto")
	sprite.visible = true
	player_light.visible = true
	shadow.visible = true
	_set_shadow_rest()

	_change_state(PlayerState.FREE)


func _change_state(new_state: PlayerState) -> void:
	state = new_state

# ===Cuadro de frente===

func _on_sprite_animation_finished() -> void:
	if not is_turning or sprite.animation != "frente":
		return

	sprite.flip_h = facing_right
	is_turning = false

# =============================
# === Minijuego de regalos ====
# =============================


# Comienza el minijuego de un regalo.

# Comienza el minijuego de un regalo.
func begin_gift_challenge() -> bool:
	if state != PlayerState.FREE:
		return false

	velocity = Vector2.ZERO
	is_turning = false

	sprite.position = sprite_start_position
	sprite.play("quieto")
	sprite.stop()

	_set_shadow_rest()

	_change_state(PlayerState.GIFT_CHALLENGE)
	return true


# Recupera el control cuando termina el minijuego.
func finish_gift_challenge() -> void:
	if state != PlayerState.GIFT_CHALLENGE:
		return

	velocity = Vector2.ZERO

	sprite.position = sprite_start_position
	sprite.play("quieto")
	_set_shadow_rest()

	_change_state(PlayerState.FREE)
