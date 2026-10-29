extends Node2D

# para las partículas que viajan del regalo abierto fallido a la nueva ubicación
signal contenido_reubicado(
	source: Area2D,
	destination: Area2D
)

@onready var gift_minigame: Control = $CanvasLayer/MinijuegoRegalo
@onready var scare_effect: Control = $CanvasLayer/Susto
@onready var regalos_del_mapa: Array = get_tree().get_nodes_in_group("map_gifts")

var _pending_failed_gift: Area2D = null
var _pending_failed_player: CharacterBody2D = null
var _gift_failure_waiting_for_scare := false

const GIFT_RELOCATION_EFFECT := preload(
	"res://scenes/efecto_de_reubicado.tscn"
)

func _ready() -> void:
	var gifts := get_tree().get_nodes_in_group("map_gifts")
	GameSession.initialize_if_needed(gifts.size())
	_connect_gifts(gifts)
	_connect_minigame_and_scare()


func _connect_gifts(gifts: Array) -> void:
	for gift in gifts:
		gift.charge_progress_changed.connect(_on_gift_charge_progress_changed)
		gift.challenge_requested.connect(_on_gift_challenge_requested)


func _connect_minigame_and_scare() -> void:
	gift_minigame.reto_ganado.connect(_cuando_reto_ganado)
	gift_minigame.reto_fallido.connect(_cuando_reto_fallido)
	scare_effect.finished.connect(_on_scare_effect_finished)


func _on_gift_charge_progress_changed(
	gift: Area2D,
	progress: float
) -> void:
	gift_minigame.call("update_preview", gift, progress)


func _on_gift_challenge_requested(
	gift: Area2D,
	player: CharacterBody2D
) -> void:
	gift_minigame.call("start_challenge", gift, player)


func _cuando_reto_ganado(
	gift: Area2D,
	player: CharacterBody2D
) -> void:
	if not is_instance_valid(gift):
		return

	if not is_instance_valid(player):
		return

	gift.call("open_empty")
	GameSession.collect_gift()
	player.call("finish_gift_challenge")


func _cuando_reto_fallido(
	gift: Area2D,
	player: CharacterBody2D
) -> void:
	_pending_failed_gift = gift
	_pending_failed_player = player
	_gift_failure_waiting_for_scare = true

	if is_instance_valid(gift):
		gift.call("open_empty")

	scare_effect.call("play_scare")



func _on_scare_effect_finished() -> void:
	# Ignorar otros sustos que no pertenezcan al minijuego.
	if not _gift_failure_waiting_for_scare:
		return

	_gift_failure_waiting_for_scare = false

	gift_minigame.call("finish_failure_scare")

	if is_instance_valid(_pending_failed_gift):
		var source := _pending_failed_gift
		var destination := _choose_open_empty_gift(source)

		if not is_instance_valid(destination):
			push_warning("No se halló otra caja vacía; se usará la misma")
			destination = source

		destination.call("refill_with_content")

		# Efecto visual del contenido mudándose al nuevo regalo.
		# Solo si hubo mudanza real (el fallback usa source == destination).
		if source != destination:
			var effect := GIFT_RELOCATION_EFFECT.instantiate()
			add_child(effect)
			effect.play(source.global_position, destination.global_position)

		contenido_reubicado.emit(source, destination)

	if is_instance_valid(_pending_failed_player):
		_pending_failed_player.call("finish_gift_challenge")

	_pending_failed_gift = null
	_pending_failed_player = null


func _choose_open_empty_gift(excluded: Area2D) -> Area2D:
	var candidates: Array[Area2D] = []

	for node in regalos_del_mapa:
		if node == excluded:
			continue

		if not node.has_method("is_open_empty"):
			continue

		if not bool(node.call("is_open_empty")):
			continue

		var gift := node as Area2D

		if gift != null:
			candidates.append(gift)

	if candidates.is_empty():
		return null

	return candidates.pick_random()
