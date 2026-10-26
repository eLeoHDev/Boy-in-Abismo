extends Node2D

## Duración total del viaje en segundos por distancia de pantalla.
## Se usa speed-based para adaptar a mapas de distinto tamaño.
@export var travel_speed := 500.0
@export var min_travel_duration := 1.2
@export var max_travel_duration := 3.5

@export var fade_out_duration := 0.4
@export var trail_linger_time := 0.6

@onready var core: Sprite2D = $Base
@onready var trail: GPUParticles2D = $Cola
@onready var glow: PointLight2D = $Luz


func play(from: Vector2, to: Vector2) -> void:
	global_position = from

	var distance := from.distance_to(to)
	var duration := clampf(
		distance / travel_speed,
		min_travel_duration,
		max_travel_duration
	)

	var move := create_tween()
	move.tween_property(self, "global_position", to, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await move.finished

	# Llegó al destino: apagar emisión y desvanecer el núcleo.
	trail.emitting = false

	var fade := create_tween().set_parallel(true)
	fade.tween_property(core, "modulate:a", 0.0, fade_out_duration)
	if glow != null:
		fade.tween_property(glow, "energy", 0.0, fade_out_duration)
	await fade.finished

	# Esperar que las últimas partículas del rastro mueran.
	await get_tree().create_timer(trail_linger_time).timeout
	queue_free()
