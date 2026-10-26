
extends CanvasLayer

@onready var gift_counter: Label = $GiftCounter
@onready var gift_progress: TextureProgressBar = $ProgresoRegalo

var _progress_tween: Tween
var _has_initialized_progress := false


func _ready() -> void:
	gift_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift_progress.step = 0.01

	GameSession.gift_count_changed.connect(
		_on_gift_count_changed
	)

	_on_gift_count_changed(
		GameSession.gifts_collected,
		GameSession.gifts_total
	)


func _on_gift_count_changed(
	collected: int,
	total: int
) -> void:
	gift_progress.max_value = maxf(float(total), 1.0)

	if not _has_initialized_progress:
		gift_progress.value = float(collected)
		_has_initialized_progress = true
	else:
		if is_instance_valid(_progress_tween):
			if _progress_tween.is_running():
				_progress_tween.kill()

		_progress_tween = create_tween()

		_progress_tween.tween_property(
			gift_progress,
			"value",
			float(collected),
			0.45
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var remaining := maxi(total - collected, 0)

	gift_counter.text = (
        "Regalos: %d / %d\nRestantes: %d"
		% [collected, total, remaining]
	)
