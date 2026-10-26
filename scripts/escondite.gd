
extends Area2D

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var _player: Node2D = null
var _is_exiting := false


func _ready() -> void:
	animation.visible = false

	body_entered.connect(_on_body_entered)
	animation.animation_finished.connect(_on_animation_finished)


# Se ejecuta cuando un cuerpo entra en el área del pozo.
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if not body.has_method("try_enter_hide"):
		return

	body.call("try_enter_hide", self)


# El jugador pide comenzar la entrada.
func play_enter(player: Node2D) -> void:
	_player = player
	_is_exiting = false

	animation.visible = true
	animation.stop()
	animation.play("entrar")


# El jugador pide salir del pozo.
func play_exit() -> void:
	if not is_instance_valid(_player):
		return

	_is_exiting = true
	animation.play("salir")


# Se ejecuta cuando las animaciones terminan
func _on_animation_finished() -> void:
	if not is_instance_valid(_player):
		return

	if _is_exiting:
		# La animación de salida ya terminó.
		animation.visible = false

		_player.call("finish_exit_hide", self)

		_player = null
		_is_exiting = false
	else:
		# La cabeza queda visible en el último fotograma.
		_player.call("finish_enter_hide", self)
