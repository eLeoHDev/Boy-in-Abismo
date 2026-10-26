extends AnimatedSprite2D
class_name HoldButton

signal hold_succeeded
signal hold_failed

enum State { IDLE, GROWING, AT_FULL, OVERSHOOT, SHRINKING, SUCCEEDING }

var grow_speed := 3.1
var shrink_speed := 0.6
var overshoot_extra := 0.6
var overshoot_grace := 0.3
var reaction_window := 0.2
var success_fade_duration := 0.3
var grace_time := 0.2
@export var ring_off_texture: Texture2D
@export var ring_on_texture: Texture2D

@onready var ring: Sprite2D = $HoldRing
@onready var fill: Sprite2D = $HoldFill

var _state := State.IDLE
var _fill := 0.0
var _full_timer := 0.0
var _overshoot_timer := 0.0
var _pressed_time := 0.0
var _action: StringName = &""


func _ready() -> void:
	_hide_hold_visuals()


func is_busy() -> bool:
	return _state != State.IDLE


func is_succeeding() -> bool:
	return _state == State.SUCCEEDING


func show_normal(action: StringName) -> void:
	_state = State.IDLE
	_fill = 0.0
	_hide_hold_visuals()
	modulate = Color.WHITE
	visible = true
	play(action)


func show_hold(action: StringName) -> void:
	_action = action
	_state = State.IDLE
	_fill = 0.0
	_pressed_time = 0.0
	_full_timer = 0.0
	_overshoot_timer = 0.0
	modulate = Color.WHITE
	visible = true
	play(action)
	pause()
	frame = 0
	ring.texture = ring_off_texture
	ring.visible = true
	fill.scale = Vector2.ZERO
	fill.visible = true


func show_error(error_anim: StringName) -> void:
	_state = State.IDLE
	_fill = 0.0
	_hide_hold_visuals()
	modulate = Color.WHITE
	visible = true
	play(error_anim)


func hide_prompt() -> void:
	_state = State.IDLE
	_fill = 0.0
	_hide_hold_visuals()
	stop()
	visible = false


func handle_press(action: StringName) -> bool:
	if action != _action:
		return false
	if _state != State.IDLE and _state != State.SHRINKING:
		return false
	if _state == State.IDLE:
		_pressed_time = 0.0
	_state = State.GROWING
	_show_static_frame(1)
	return true


func handle_release(action: StringName) -> bool:
	if action != _action:
		return false
	match _state:
		State.GROWING:
			if _pressed_time < grace_time:
				_reset_after_cancel()
			else:
				_state = State.SHRINKING
				_show_static_frame(0)
			return true
		State.AT_FULL:
			_succeed()
			return true
		State.OVERSHOOT:
			_fail()
			return true
	return false


func update(delta: float) -> void:
	match _state:
		State.GROWING:
			_pressed_time += delta
			_fill += grow_speed * delta
			if _fill >= 1.0:
				_fill = 1.0
				_enter_full()
			_update_fill_visual()
		State.AT_FULL:
			_pressed_time += delta
			_full_timer -= delta
			if _full_timer <= 0.0:
				_enter_overshoot()
		State.OVERSHOOT:
			_pressed_time += delta
			var max_fill := 1.0 + overshoot_extra
			if _fill < max_fill:
				_fill = minf(_fill + grow_speed * delta, max_fill)
				_update_fill_visual()
			else:
				_overshoot_timer -= delta
				if _overshoot_timer <= 0.0:
					_fail()
		State.SHRINKING:
			_fill -= shrink_speed * delta
			if _fill <= 0.0:
				_fill = 0.0
				_update_fill_visual()
				_fail()
			else:
				_update_fill_visual()


func _show_static_frame(frame_index: int) -> void:
	play(_action)
	pause()
	frame = frame_index


func _enter_full() -> void:
	_state = State.AT_FULL
	_full_timer = reaction_window
	ring.texture = ring_on_texture


func _enter_overshoot() -> void:
	_state = State.OVERSHOOT
	_overshoot_timer = overshoot_grace
	ring.texture = ring_off_texture


func _update_fill_visual() -> void:
	fill.scale = Vector2.ONE * _fill


func _hide_hold_visuals() -> void:
	ring.visible = false
	fill.visible = false
	fill.scale = Vector2.ZERO


func _reset_after_cancel() -> void:
	_state = State.IDLE
	_fill = 0.0
	_pressed_time = 0.0
	_full_timer = 0.0
	_overshoot_timer = 0.0
	fill.scale = Vector2.ZERO
	_show_static_frame(0)


func _succeed() -> void:
	_state = State.SUCCEEDING
	_fill = 0.0
	_hide_hold_visuals()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, success_fade_duration)
	await tween.finished
	modulate.a = 1.0
	_state = State.IDLE
	hold_succeeded.emit()


func _fail() -> void:
	_state = State.IDLE
	_fill = 0.0
	_hide_hold_visuals()
	hold_failed.emit()
