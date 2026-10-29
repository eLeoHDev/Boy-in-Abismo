extends Node

signal gift_count_changed(collected: int, total: int)
signal all_gifts_collected

var gifts_collected: int = 0
var gifts_total: int = 0
var initialized: bool = false


# Inicializa la cuenta al comenzar una partida.
func start_new_game(total: int) -> void:
	gifts_collected = 0
	gifts_total = maxi(total, 0)
	initialized = true

	gift_count_changed.emit(gifts_collected, gifts_total)


# Inicializa solamente si todavía no existe una partida.
func initialize_if_needed(total: int) -> void:
	if initialized:
		return

	start_new_game(total)


# Registra una recompensa conseguida.
func collect_gift() -> void:
	if gifts_collected >= gifts_total:
		return

	gifts_collected += 1

	gift_count_changed.emit(gifts_collected, gifts_total)

	if gifts_total > 0 and gifts_collected >= gifts_total:
		all_gifts_collected.emit()


# Devuelve cuántos regalos faltan.
func gifts_remaining() -> int:
	return maxi(gifts_total - gifts_collected, 0)
