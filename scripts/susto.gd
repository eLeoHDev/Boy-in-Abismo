
extends Control

signal finished

@export var screamer_texture: Texture2D

@export_group("Animación")
@export_range(0.01, 0.5, 0.01) var start_scale := 0.06
@export_range(0.05, 1.0, 0.05) var grow_duration := 0.16
@export_range(0.0, 3.0, 0.05) var hold_duration := 0.55
@export_range(0.05, 2.0, 0.05) var fade_duration := 0.30
@export_range(0.1, 0.5, 0.05) var cover_margin := 1.15

@onready var image: TextureRect = $ImgSusto

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Usar el tamaño nativo de la textura y escalarla por código.
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE

	visible = false


func play_scare(texture_override: Texture2D = null) -> void:
	if visible:
		return

	if is_instance_valid(_tween) and _tween.is_running():
		_tween.kill()

	if texture_override != null:
		image.texture = texture_override
	elif screamer_texture != null:
		image.texture = screamer_texture

	if image.texture == null:
		push_warning("ScareEffect no tiene una textura asignada.")
		finished.emit()
		return

	var viewport_size := get_viewport_rect().size / 2
	var texture_size := Vector2(image.texture.get_size())

	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		finished.emit()
		return

	# Centrar la imagen sin alterar su proporción.
	image.size = texture_size
	image.position = (viewport_size - texture_size) / 2.0
	image.pivot_offset = texture_size / 2.0

	var scale_to_cover := maxf(
		viewport_size.x / texture_size.x,
		viewport_size.y / texture_size.y
	) * cover_margin

	# Preparar la aparición desde el centro.
	image.scale = Vector2.ONE * start_scale
	image.modulate = Color.WHITE
	image.visible = true

	visible = true

	_tween = create_tween()

	# 1. Crecimiento rápido hasta cubrir la pantalla.
	_tween.tween_property(
		image,
		"scale",
		Vector2.ONE * scale_to_cover,
		grow_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Mantener el susto visible un momento.
	_tween.tween_interval(hold_duration)

	# 3. Desvanecer la imagen.
	_tween.tween_property(
		image,
		"modulate:a",
		0.0,
		fade_duration
	)

	_tween.tween_callback(_finish_scare)


func _finish_scare() -> void:
	visible = false
	image.scale = Vector2.ONE
	image.modulate = Color.WHITE

	finished.emit()
