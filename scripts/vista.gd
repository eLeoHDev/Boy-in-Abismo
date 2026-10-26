extends Camera2D

@export var player: CharacterBody2D

@export_group("Zonas")
@export var zone_size := Vector2(224.0, 128.0)

@export_group("Peek")
@export var peek_distance := 32.0
@export var peek_margin := 13.0

@export_group("Cámara")
## Qué tan rápido se desplaza entre zonas. Más bajo = más lento.
@export var zone_smoothing := 4.0
## Qué tan rápido se asoma a los bordes.
@export var peek_smoothing := 0.5
## Qué tan rápido vuelve al centro cuando deja de asomarse.
@export var return_smoothing := 8.0


var current_zone := Vector2i.ZERO
var camera_base := Vector2.ZERO
var camera_peek := Vector2.ZERO

# Un flag por borde. Si está en true, no se hace peek hacia ese lado
# hasta que el jugador salga del margen de ese borde.
var suppress := {
	Vector2i.LEFT:  false,
	Vector2i.RIGHT: false,
	Vector2i.UP:    false,
	Vector2i.DOWN:  false,
}


func _ready() -> void:
	current_zone = _get_zone(player.global_position)
	camera_base = _get_zone_center(current_zone)
	global_position = camera_base


func _process(delta: float) -> void:
	_update_zone()
	_clear_suppressions()
	_update_camera(delta)


# --- Zona actual ---

func _update_zone() -> void:
	var new_zone := _get_zone(player.global_position)
	if new_zone == current_zone:
		return

	var diff := new_zone - current_zone
	current_zone = new_zone

	if diff.x > 0:
		suppress[Vector2i.LEFT] = true
	elif diff.x < 0:
		suppress[Vector2i.RIGHT] = true
	if diff.y > 0:
		suppress[Vector2i.UP] = true
	elif diff.y < 0:
		suppress[Vector2i.DOWN] = true


func _clear_suppressions() -> void:
	for dir in suppress.keys():
		if suppress[dir] and not _is_near_edge(dir):
			suppress[dir] = false


# --- Cámara ---

func _update_camera(delta: float) -> void:
	var center := _get_zone_center(current_zone)
	var peek_target := Vector2(_pick_peek_direction()) * peek_distance

	# La base siempre va al centro de la zona a zone_smoothing.
	camera_base = camera_base.lerp(
		center,
		1.0 - exp(-zone_smoothing * delta)
	)

	# El peek usa una velocidad distinta según si se está asomando o volviendo.
	var peek_rate := return_smoothing if peek_target == Vector2.ZERO else peek_smoothing
	camera_peek = camera_peek.lerp(
		peek_target,
		1.0 - exp(-peek_rate * delta)
	)
	
	global_position = camera_base + camera_peek


func _pick_peek_direction() -> Vector2i:
	var local := player.global_position - Vector2(current_zone) * zone_size

	var x_dir := Vector2i.ZERO
	if not suppress[Vector2i.LEFT] and local.x < peek_margin:
		x_dir = Vector2i.LEFT
	elif not suppress[Vector2i.RIGHT] and zone_size.x - local.x < peek_margin:
		x_dir = Vector2i.RIGHT

	var y_dir := Vector2i.ZERO
	if not suppress[Vector2i.UP] and local.y < peek_margin:
		y_dir = Vector2i.UP
	elif not suppress[Vector2i.DOWN] and zone_size.y - local.y < peek_margin:
		y_dir = Vector2i.DOWN

	# Esquina: si hay un borde horizontal y uno vertical activos, al centro.
	if x_dir != Vector2i.ZERO and y_dir != Vector2i.ZERO:
		return Vector2i.ZERO

	return x_dir + y_dir


func _is_near_edge(dir: Vector2i) -> bool:
	var local := player.global_position - Vector2(current_zone) * zone_size
	match dir:
		Vector2i.LEFT:  return local.x < peek_margin
		Vector2i.RIGHT: return zone_size.x - local.x < peek_margin
		Vector2i.UP:    return local.y < peek_margin
		Vector2i.DOWN:  return zone_size.y - local.y < peek_margin
	return false


# --- Utilidades ---

func _get_zone(pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(pos.x / zone_size.x),
		floori(pos.y / zone_size.y)
	)


func _get_zone_center(zone: Vector2i) -> Vector2:
	return Vector2(
		zone.x * zone_size.x + zone_size.x / 2.0,
		zone.y * zone_size.y + zone_size.y / 2.0
	)
