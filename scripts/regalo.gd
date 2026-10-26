extends Area2D
class_name Regalo

signal charge_progress_changed(gift: Area2D, progress: float)
signal challenge_requested(gift: Area2D, player: CharacterBody2D)

enum GiftState {
	AVAILABLE,
	CHALLENGE,
	OPEN_EMPTY
}

@export_group("Carga del minijuego")
@export_range(0.1, 5.0, 0.1) var hold_duration := 1.0
@export_range(0.1, 2.0, 0.1) var preview_fade_out_duration := 0.4

@export_group("Flotación")
@export var float_height := 1.0
@export var float_speed := 4.0

@export_group("Sombra")
@export var shadow_base_scale := 1.0
@export_range(0.0, 1.0, 0.05) var shadow_min_scale := 0.6
@export_range(0.0, 1.0, 0.05) var shadow_base_alpha := 1.0
@export_range(0.0, 1.0, 0.05) var shadow_min_alpha := 0.5

@onready var visual: AnimatedSprite2D = $Visual
@onready var shadow: Sprite2D = $Sombra
@onready var opened_visual: Sprite2D = $VisualAbierto
@onready var gift_light: PointLight2D = $Luz

var _state: GiftState = GiftState.AVAILABLE

var _player: CharacterBody2D = null
var _visual_start_position := Vector2.ZERO

var _charge_progress := 0.0
var _float_time := 0.0

var _blocked_until_exit := false


func _ready() -> void:
	add_to_group("map_gifts")

	_visual_start_position = visual.position

	visual.play("default")
	opened_visual.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _state == GiftState.OPEN_EMPTY:
		return

	_update_float(delta)

	if _state == GiftState.CHALLENGE:
		return

	if _player != null and not is_instance_valid(_player):
		_player = null

	var previous_progress := _charge_progress

	var can_charge := (
		is_instance_valid(_player)
		and not _blocked_until_exit
	)

	if can_charge:
		_charge_progress = minf(
			_charge_progress + delta / hold_duration,
			1.0
		)
	else:
		_charge_progress = move_toward(
			_charge_progress,
			0.0,
			delta / preview_fade_out_duration
		)

	if not is_equal_approx(previous_progress, _charge_progress):
		charge_progress_changed.emit(self, _charge_progress)

	if can_charge and _charge_progress >= 1.0:
		var accepted := bool(
			_player.call("begin_gift_challenge")
		)

		if accepted:
			_state = GiftState.CHALLENGE
			challenge_requested.emit(self, _player)
		else:
			_blocked_until_exit = true
			_charge_progress = 0.0
			charge_progress_changed.emit(self, 0.0)


func _update_float(delta: float) -> void:
	_float_time += delta * float_speed

	var wave := sin(_float_time)

	visual.position.y = (
		_visual_start_position.y + wave * float_height
	)

	_update_shadow(wave)


func _update_shadow(wave: float) -> void:
	var t := (wave + 1.0) * 0.5

	var scale_factor := lerpf(shadow_min_scale, 1.0, t)
	var alpha_factor := lerpf(shadow_min_alpha, 1.0, t)

	shadow.scale = Vector2.ONE * shadow_base_scale * scale_factor
	shadow.modulate.a = shadow_base_alpha * alpha_factor


func _set_shadow_rest() -> void:
	shadow.scale = Vector2.ONE * shadow_base_scale
	shadow.modulate.a = shadow_base_alpha


func _on_body_entered(body: Node2D) -> void:
	if _state != GiftState.AVAILABLE:
		return

	if is_instance_valid(_player):
		return

	if not body.has_method("begin_gift_challenge"):
		return

	var character := body as CharacterBody2D

	if character == null:
		return

	_player = character


func _on_body_exited(body: Node2D) -> void:
	if body != _player or _state == GiftState.CHALLENGE:
		return

	_player = null
	_blocked_until_exit = false

# Convierte el regalo lleno en una caja vacía.
# Se llama tanto al ganar como al fracasar.
func open_empty() -> void:
	if _state == GiftState.OPEN_EMPTY:
		return

	_state = GiftState.OPEN_EMPTY

	_player = null
	_charge_progress = 0.0
	_blocked_until_exit = false

	visual.position = _visual_start_position
	visual.visible = false

	opened_visual.visible = true

	shadow.visible = true
	_set_shadow_rest()

	charge_progress_changed.emit(self, 0.0)
	set_deferred("monitoring", false)


# Devuelve el contenido a esta ubicación.
func refill_with_content() -> void:
	if _state != GiftState.OPEN_EMPTY:
		return

	_state = GiftState.AVAILABLE

	_player = null
	_charge_progress = 0.0
	_blocked_until_exit = false

	opened_visual.visible = false

	visual.position = _visual_start_position
	visual.visible = true
	visual.play("default")

	shadow.visible = true
	_set_shadow_rest()

	set_deferred("monitoring", true)


func is_open_empty() -> bool:
	return _state == GiftState.OPEN_EMPTY


# Permite cancelar un desafío sin abrir la caja.
# Lo utilizaremos si el monstruo interrumpe el minijuego.
func cancel_challenge() -> void:
	if _state != GiftState.CHALLENGE:
		return

	_state = GiftState.AVAILABLE
	_charge_progress = 0.0

	_blocked_until_exit = is_instance_valid(_player)

	charge_progress_changed.emit(self, 0.0)
