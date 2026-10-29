extends Control

signal reto_ganado(gift: Area2D, player: CharacterBody2D)
signal reto_fallido(gift: Area2D, player: CharacterBody2D)

const ACTIONS: Array[StringName] = [
	&"mov_izq", &"mov_der", &"mov_arr", &"mov_aba"
]
const WRONG_ANIMATION := &"error"


enum Mode { SEQUENCE, MEMORY }
enum StepKind { NORMAL, HOLD, MEMORY }
enum MemoryPhase { NONE, REVEAL, RECALL, TRANSITION }


class ChallengeStep:
	var action: StringName
	var kind: int
	var slot: int = -1
	func _init(a: StringName, k: int, s: int = -1) -> void:
		action = a
		kind = k
		slot = s


@export_group("Dificultad")
@export_range(1.0, 30.0, 0.5) var initial_challenge_duration := 10.0
@export_range(1.0, 30.0, 0.5) var minimum_challenge_duration := 4.0
@export_range(0.0, 1.5, 0.05) var max_darkness := 1.0

@export_group("Modo memoria")
@export_range(0.0, 1.0, 0.05) var memory_mode_probability := 0.2
@export_range(0.1, 3.0, 0.05) var initial_memory_reveal_time := 0.8
@export_range(0.1, 3.0, 0.05) var minimum_memory_reveal_time := 0.25
@export_range(0.1, 3.0, 0.05) var memory_all_at_once_duration := 0.8
@export_range(0.05, 1.0, 0.05) var memory_fade_to_neutral_duration := 0.3
@export_range(0.1, 2.0, 0.05) var memory_correct_fade_duration := 0.25
@export_range(0.0, 1.0, 0.05) var memory_inactive_alpha := 0.35

@export_group("Interfaz")
@export var prompt_spread := Vector2(24.0, 16.0)
@export_range(0.0, 100.0, 1.0) var prompt_inner_radius := 16.0
@export_range(0.0, 100.0, 1.0) var prompt_min_distance_from_previous := 22.0
@export_range(0.05, 1.0, 0.05) var wrong_flash_duration := 0.25
@export_range(0.1, 2.0, 0.1) var failure_hold_duration := 0.35
@export_range(0.05, 1.0, 0.05) var failure_gift_fade_duration := 0.25
@export_range(0.0, 0.5, 0.01) var input_grace_duration := 0.1
@export var error_on_texture: Texture2D

@export_group("Desenfoque del mapa")
@export var blur_rect_path: NodePath = ^"../Desenfocar"
@export_range(0.0, 1.0, 0.05) var challenge_saturation := 1.0
@export_range(0.0, 16.0, 0.5) var challenge_blur := 2.0
@export_range(0.1, 3.0, 0.05) var saturation_fade_duration := 0.5

@export_group("Botón especial")
@export_range(0.0, 1.0, 0.05) var special_probability := 0.2

@export_group("Efecto de acierto")
@export_range(0.05, 1.0, 0.01) var correct_effect_duration := 0.31
@export_range(1.0, 3.0, 0.05) var correct_effect_scale := 4.2
@export_range(2, 8, 1) var correct_effect_pool_size := 4

@export_group("Apertura y recompensa")
@export var candy_textures: Array[Texture2D] = []
@export var gift_progress_path: NodePath = ^"../ProgresoRegalo"
@export_range(0.05, 2.0, 0.05) var glow_duration := 0.55
@export_range(0.05, 2.0, 0.05) var gift_fade_duration := 0.40
@export_range(0.0, 3.0, 0.05) var candy_center_hold_duration := 0.45
@export_range(1.0, 8.0, 0.1) var glow_max_scale := 6.0
@export var glow_tint: Color = Color(1.0, 0.94, 0.75, 0.45)
@export_range(0.1, 2.0, 0.05) var candy_travel_duration := 0.55
@export_range(0.05, 1.0, 0.05) var candy_final_scale := 0.20
@export_range(0.02, 0.2, 0.01) var trail_spawn_interval := 0.02
@export_range(0.05, 1.0, 0.05) var trail_fade_duration := 0.22
@export_range(0.0, 1.0, 0.05) var trail_alpha := 0.2
@export_range(0.1, 1.0, 0.05) var trail_final_scale := 0.65


@onready var arrow_prompt: HoldButton = $BotonesDeFlecha
@onready var backdrop: ColorRect = $Fondo
@onready var gift_preview: AnimatedSprite2D = $GiftPreview
@onready var candy_glow: TextureRect = $CandyGlow
@onready var candy: TextureRect = $Candy
@onready var error_1: TextureRect = $Error1
@onready var error_2: TextureRect = $Error2
@onready var error_3: TextureRect = $Error3
@onready var correct_effect_template: Sprite2D = $EfectoAcierto
@onready var gift_progress: TextureProgressBar = (
	get_node_or_null(gift_progress_path) as TextureProgressBar
)
@onready var blur_rect: ColorRect = (
	get_node_or_null(blur_rect_path) as ColorRect
)


# --- Estado del desafío ---
var _mode: Mode = Mode.SEQUENCE
var _first_gift_safe := false
var _challenge_active := false
var _ending_failure := false
var _resolving_result := false
var _failure_animation_started := false
var _waiting_for_answer_effect := false

# --- Modo memoria ---
var memory_slots: Array[AnimatedSprite2D] = []
var _memory_answers: Array[StringName] = []
var _memory_slot_index := 0
var _memory_phase: MemoryPhase = MemoryPhase.NONE
var _memory_token := 0

# --- Progreso ---
var _steps: Array[ChallengeStep] = []
var _errors := 0
var _step_index := 0

# --- Temporización ---
var _challenge_elapsed := 0.0
var _challenge_duration := 0.0
var _end_hold_remaining := 0.0

# --- Grace de input en modo secuencia ---
var _input_grace_timer := 0.0

# --- Buffer de input en modo memoria ---
var _memory_input_buffer: StringName = &""
var _memory_accept_buffer := false

# --- Prompts ---
var _last_prompt_offset := Vector2.ZERO
var _has_previous_prompt := false

# --- Regalo / jugador / preview ---
var _gift: Area2D = null
var _player: CharacterBody2D = null
var _preview_gift: Area2D = null
var _preview_base_modulate: Color

# --- Iconos de error ---
var _error_icons: Array[TextureRect] = []
var _error_off_textures: Array[Texture2D] = []

# --- Pool del efecto de acierto ---
var _effect_pool: Array[Sprite2D] = []
var _effect_tweens: Array[Tween] = []
var _effect_index := 0

# --- Estela de la golosina ---
var _candy_in_flight := false
var _trail_elapsed := 0.0

# --- Desenfoque del mapa ---
var _saturation_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	candy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	candy_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_preview_base_modulate = gift_preview.modulate

	_error_icons = [error_1, error_2, error_3]
	for icon in _error_icons:
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_error_off_textures.append(icon.texture)

	correct_effect_template.visible = false
	for i in correct_effect_pool_size:
		var fx := correct_effect_template.duplicate() as Sprite2D
		fx.visible = false
		add_child(fx)
		_effect_pool.append(fx)
		_effect_tweens.append(null)

	arrow_prompt.hold_succeeded.connect(_on_hold_succeeded)
	arrow_prompt.hold_failed.connect(_on_hold_failed)

	_init_blur()
	
	memory_slots = _collect_memory_slots()

	call_deferred("_layout_centered_elements")
	_clear_interface()
	visible = false

func _init_blur() -> void:
	if blur_rect == null:
		return
	var mat := blur_rect.material as ShaderMaterial
	if mat == null:
		return
	blur_rect.visible = true
	mat.set_shader_parameter("saturation", 1.0)
	mat.set_shader_parameter("blur_amount", 0.0)


func _layout_centered_elements() -> void:
	var center := size / 2.0
	candy.pivot_offset = candy.size / 2.0
	candy.position = center - candy.size / 2.0
	candy_glow.size = candy.size
	candy_glow.pivot_offset = candy_glow.size / 2.0
	candy_glow.position = candy.position

func _collect_memory_slots() -> Array[AnimatedSprite2D]:
	var result: Array[AnimatedSprite2D] = []
	var root := get_node_or_null(^"BotonesDeMemoria")
	if root == null:
		return result
	for i in range(1, 7):
		var slot := root.get_node_or_null("Slot%d" % i) as AnimatedSprite2D
		if slot != null:
			slot.visible = false
			result.append(slot)
	return result


# --- Loop principal ---

func _process(delta: float) -> void:
	_update_candy_trail(delta)

	if _ending_failure:
		_process_ending_failure(delta)
		return

	if not _challenge_active:
		return

	_process_challenge(delta)


func _update_candy_trail(delta: float) -> void:
	if not _candy_in_flight:
		return
	_trail_elapsed += delta
	if _trail_elapsed >= trail_spawn_interval:
		_trail_elapsed = 0.0
		_spawn_candy_trail()


func _process_ending_failure(delta: float) -> void:
	if _failure_animation_started:
		return
	_end_hold_remaining -= delta
	if _end_hold_remaining <= 0.0:
		_complete_failure()


func _process_challenge(delta: float) -> void:
	_input_grace_timer = maxf(0.0, _input_grace_timer - delta)
	if _is_current_step_hold():
		arrow_prompt.update(delta)
	_process_timer(delta)


func _process_timer(delta: float) -> void:
	if _first_gift_safe:
		return
	if _mode == Mode.MEMORY:
		if _memory_phase != MemoryPhase.RECALL:
			return
	elif arrow_prompt.is_busy():
		return
	_challenge_elapsed += delta
	var time_progress := clampf(
		_challenge_elapsed / _challenge_duration, 0.0, 1.0
	)
	_set_darkness(time_progress * max_darkness)
	if _challenge_elapsed >= _challenge_duration:
		_begin_failure()


func _is_current_step_hold() -> bool:
	return (
		_mode == Mode.SEQUENCE
		and _steps[_step_index].kind == StepKind.HOLD
	)


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if not _challenge_active or _waiting_for_answer_effect:
		return
	if arrow_prompt.is_succeeding():
		return
	if event is InputEventKey and event.echo:
		return

	match _mode:
		Mode.SEQUENCE:
			_handle_sequence_input(event)
		Mode.MEMORY:
			_handle_memory_input(event)

func _handle_sequence_input(event: InputEvent) -> void:
	if _is_current_step_hold():
		_handle_hold_input(event)
	else:
		_handle_normal_input(event)


func _handle_normal_input(event: InputEvent) -> void:
	for action in ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			if action == _steps[_step_index].action:
				_consume_current_prompt(false)
			elif not _first_gift_safe and _input_grace_timer > 0.0:
				pass  # Silenciosamente ignorado
			else:
				_handle_wrong_answer()
			return


func _handle_hold_input(event: InputEvent) -> void:
	for action in ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			if arrow_prompt.handle_press(action):
				return
			if not _first_gift_safe and _input_grace_timer > 0.0:
				return  # Ignorado
			arrow_prompt.show_error(WRONG_ANIMATION)
			_apply_wrong_answer()
			return
	for action in ACTIONS:
		if event.is_action_released(action):
			get_viewport().set_input_as_handled()
			arrow_prompt.handle_release(action)
			return


# --- Manejo de respuestas ---

func _handle_wrong_answer() -> void:
	arrow_prompt.show_error(WRONG_ANIMATION)

	if _first_gift_safe:
		_waiting_for_answer_effect = true
		await get_tree().create_timer(wrong_flash_duration).timeout
		_waiting_for_answer_effect = false
		if _challenge_active:
			_reshow_current_prompt()
		return

	_apply_wrong_answer()


func _apply_wrong_answer() -> void:
	_errors += 1
	_refresh_error_icons()

	if _errors >= 3:
		_begin_failure()
		return

	_waiting_for_answer_effect = true
	await get_tree().create_timer(wrong_flash_duration).timeout
	_waiting_for_answer_effect = false

	if not _challenge_active:
		return

	_consume_current_prompt(true)


func _consume_current_prompt(error: bool) -> void:
	var effect_pos := arrow_prompt.position
	var effect_scale := arrow_prompt.scale

	arrow_prompt.hide_prompt()

	if not error:
		_spawn_correct_effect(effect_pos, effect_scale)
		_step_index += 1
		_input_grace_timer = input_grace_duration

	if _step_index >= _steps.size():
		_finish_success()
	else:
		_show_current_prompt()


func _on_hold_succeeded() -> void:
	_step_index += 1
	_input_grace_timer = input_grace_duration
	if _step_index >= _steps.size():
		_finish_success()
	else:
		_show_current_prompt()


func _on_hold_failed() -> void:
	arrow_prompt.show_error(WRONG_ANIMATION)
	_apply_wrong_answer()


# --- Prompt actual ---

func _show_current_prompt() -> void:
	var step := _steps[_step_index]
	arrow_prompt.position = size / 2.0 + _pick_prompt_offset()
	_show_step_visual(step)


func _reshow_current_prompt() -> void:
	_show_step_visual(_steps[_step_index])


func _show_step_visual(step: ChallengeStep) -> void:
	if step.kind == StepKind.HOLD:
		arrow_prompt.show_hold(step.action)
	else:
		arrow_prompt.show_normal(step.action)


func _pick_prompt_offset() -> Vector2:
	var spread := prompt_spread
	if randf() < 0.2:
		spread = Vector2(24.0, 24.0)

	var inner := clampf(
		prompt_inner_radius, 0.0, minf(spread.x, spread.y) - 1.0
	)

	for _attempt in range(16):
		var candidate := Vector2(
			randf_range(-spread.x, spread.x),
			randf_range(-spread.y, spread.y)
		)
		if candidate.length() < inner:
			continue
		if (
			_has_previous_prompt
			and candidate.distance_to(_last_prompt_offset)
				< prompt_min_distance_from_previous
		):
			continue
		_last_prompt_offset = candidate
		_has_previous_prompt = true
		return candidate

	var dir := Vector2.RIGHT
	if _has_previous_prompt and _last_prompt_offset.length() > 0.01:
		dir = -_last_prompt_offset.normalized()
	var fallback := dir * inner
	_last_prompt_offset = fallback
	_has_previous_prompt = true
	return fallback


# --- Construcción del desafío ---

func _build_steps() -> Array[ChallengeStep]:
	var steps: Array[ChallengeStep] = []
	var length := 3 if _first_gift_safe else _choose_sequence_length()
	for i in length:
		var action: StringName = ACTIONS.pick_random()
		var is_hold := (
			not _first_gift_safe and randf() < special_probability
		)
		steps.append(ChallengeStep.new(
			action,
			StepKind.HOLD if is_hold else StepKind.NORMAL
		))
	return steps


func _choose_sequence_length() -> int:
	var roll := randi_range(1, 100)
	if roll <= 45:
		return 3
	if roll <= 75:
		return 4
	if roll <= 92:
		return 5
	return 6


func _calculate_challenge_duration() -> float:
	var divisor := maxi(GameSession.gifts_total - 1, 1)
	var difficulty_progress := clampf(
		float(GameSession.gifts_collected) / float(divisor),
		0.0,
		1.0
	)
	return lerpf(
		initial_challenge_duration,
		minimum_challenge_duration,
		difficulty_progress
	)

func _start_memory_challenge() -> void:
	arrow_prompt.hide_prompt()
	_memory_input_buffer = &""
	_memory_accept_buffer = false

	_memory_token += 1
	var token := _memory_token

	_memory_answers.clear()
	for i in memory_slots.size():
		var picked: StringName = ACTIONS.pick_random()
		_memory_answers.append(picked)
	_memory_slot_index = 0

	await _reveal_memory_sequence(token)

	if token != _memory_token or not _challenge_active:
		return

	_memory_phase = MemoryPhase.RECALL
	_activate_memory_slot(0)


func _reveal_memory_sequence(token: int) -> void:
	_memory_phase = MemoryPhase.REVEAL

	for slot in memory_slots:
		slot.stop()
		slot.modulate = Color.WHITE
		slot.visible = false

	var reveal_time := _calculate_memory_reveal_time()

	# Mostrar flechas una por una.
	for i in memory_slots.size():
		if token != _memory_token or not _challenge_active:
			return
		var slot := memory_slots[i]
		slot.play(_memory_answers[i])
		slot.modulate = Color.WHITE
		slot.visible = true
		await get_tree().create_timer(reveal_time).timeout

	if token != _memory_token or not _challenge_active:
		return

	# Todas visibles juntas un momento.
	await get_tree().create_timer(memory_all_at_once_duration).timeout

	if token != _memory_token or not _challenge_active:
		return

	# Desvanecer flechas.
	var fade_out := create_tween().set_parallel(true)
	for slot in memory_slots:
		fade_out.tween_property(
			slot, "modulate:a", 0.0, memory_fade_to_neutral_duration
		)
	await fade_out.finished

	if token != _memory_token or not _challenge_active:
		return

	# Cambiar a neutrales, con alpha 0 para fade-in.
	for slot in memory_slots:
		slot.play(&"neutral")
		slot.pause()
		slot.frame = 1
		slot.modulate.a = 0.0

	# Fade-in: slot 0 opaco, resto semitransparente.
	var fade_in := create_tween().set_parallel(true)
	for i in memory_slots.size():
		var target := 1.0 if i == 0 else memory_inactive_alpha
		fade_in.tween_property(
			memory_slots[i], "modulate:a",
			target, memory_fade_to_neutral_duration
		)
	await fade_in.finished

	if token != _memory_token or not _challenge_active:
		return

	# Slot 0 activo (animación en bucle).
	memory_slots[0].play(&"neutral")


func _activate_memory_slot(index: int) -> void:
	var slot := memory_slots[index]
	slot.modulate = Color.WHITE
	slot.visible = true
	slot.play(&"neutral")


func _handle_memory_input(event: InputEvent) -> void:
	if _memory_accept_buffer:
		for action in ACTIONS:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				_memory_input_buffer = action
				return
		return

	if _memory_phase != MemoryPhase.RECALL:
		return

	for action in ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			if action == _memory_answers[_memory_slot_index]:
				_handle_memory_correct()
			else:
				_handle_memory_wrong()
			return


func _handle_memory_correct() -> void:
	_memory_phase = MemoryPhase.TRANSITION
	_memory_accept_buffer = true

	var slot := memory_slots[_memory_slot_index]
	var tween := create_tween()
	tween.tween_property(
		slot, "modulate:a", 0.0, memory_correct_fade_duration
	)
	await tween.finished
	slot.visible = false

	if not _challenge_active:
		_memory_accept_buffer = false
		return

	_memory_slot_index += 1
	if _memory_slot_index >= memory_slots.size():
		_memory_accept_buffer = false
		_memory_input_buffer = &""
		_finish_success()
		return

	_memory_phase = MemoryPhase.RECALL
	_memory_accept_buffer = false
	_activate_memory_slot(_memory_slot_index)
	_consume_memory_buffer()


func _consume_memory_buffer() -> void:
	if _memory_input_buffer == &"":
		return
	var action := _memory_input_buffer
	_memory_input_buffer = &""
	if not _challenge_active or _memory_phase != MemoryPhase.RECALL:
		return
	if action == _memory_answers[_memory_slot_index]:
		_handle_memory_correct()
	# Buffer con acción incorrecta: descartado en silencio


func _handle_memory_wrong() -> void:
	_memory_phase = MemoryPhase.TRANSITION
	_memory_accept_buffer = false
	_memory_input_buffer = &""

	var slot := memory_slots[_memory_slot_index]
	slot.play(WRONG_ANIMATION)

	await get_tree().create_timer(wrong_flash_duration).timeout

	if not _challenge_active:
		return

	_errors += 1
	_refresh_error_icons()

	if _errors >= 3:
		_begin_failure()
		return

	_start_memory_challenge()


func _calculate_memory_reveal_time() -> float:
	var divisor := maxi(GameSession.gifts_total - 1, 1)
	var difficulty_progress := clampf(
		float(GameSession.gifts_collected) / float(divisor),
		0.0, 1.0
	)
	return lerpf(
		initial_memory_reveal_time,
		minimum_memory_reveal_time,
		difficulty_progress
	)


func _hide_memory_slots() -> void:
	for slot in memory_slots:
		slot.visible = false
		slot.stop()
		slot.modulate = Color.WHITE

# --- API pública ---

func update_preview(gift: Area2D, progress: float) -> void:
	if _challenge_active or _ending_failure or _resolving_result:
		return

	progress = clampf(progress, 0.0, 1.0)

	if progress <= 0.0:
		if _preview_gift == gift:
			_preview_gift = null
			gift_preview.visible = false
			visible = false
		return

	if _preview_gift != gift:
		_preview_gift = gift
		gift_preview.play("cerrado")

	visible = true
	backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	gift_preview.visible = true
	gift_preview.modulate = _preview_base_modulate * Color(1.0, 1.0, 1.0, progress)
	arrow_prompt.hide_prompt()
	for icon in _error_icons:
		icon.visible = false


func start_challenge(gift: Area2D, player: CharacterBody2D) -> void:
	if not is_instance_valid(gift) or not is_instance_valid(player):
		return

	_clear_interface()
	_layout_centered_elements()

	_gift = gift
	_player = player
	_preview_gift = gift

	_resolving_result = false
	_failure_animation_started = false
	_candy_in_flight = false

	gift_preview.play("cerrado")
	gift_preview.visible = true
	gift_preview.modulate = _preview_base_modulate

	visible = true
	_challenge_active = true
	_ending_failure = false

	_first_gift_safe = GameSession.gifts_collected == 0
	_mode = _pick_challenge_mode()
	_errors = 0
	_input_grace_timer = 0.0
	_memory_input_buffer = &""
	_memory_accept_buffer = false

	_challenge_elapsed = 0.0
	_challenge_duration = _calculate_challenge_duration()
	_end_hold_remaining = 0.0

	_set_darkness(0.0)
	_set_map_effect(challenge_saturation, challenge_blur)
	_refresh_error_icons()

	if _mode == Mode.MEMORY:
		_start_memory_challenge()
	else:
		_prepare_sequence()
		_show_current_prompt()


func _prepare_sequence() -> void:
	_steps = _build_steps()
	_step_index = 0


func _pick_challenge_mode() -> Mode:
	if _first_gift_safe:
		return Mode.SEQUENCE
	if memory_slots.is_empty():
		return Mode.SEQUENCE
	if randf() < memory_mode_probability:
		return Mode.MEMORY
	return Mode.SEQUENCE


func finish_failure_scare() -> void:
	_clear_interface()
	visible = false

	_ending_failure = false
	_failure_animation_started = false
	_resolving_result = false


# --- Efectos visuales ---

func _spawn_correct_effect(at: Vector2, base_scale: Vector2 = Vector2.ONE) -> void:
	if _effect_pool.is_empty():
		return

	var slot := _effect_index
	_effect_index = (_effect_index + 1) % _effect_pool.size()

	if _effect_tweens[slot] != null and _effect_tweens[slot].is_valid():
		_effect_tweens[slot].kill()

	var fx := _effect_pool[slot]
	fx.position = at
	fx.scale = base_scale
	fx.modulate = Color.WHITE
	fx.visible = true

	var tween := create_tween().set_parallel(true)
	tween.tween_property(
		fx, "scale", base_scale * correct_effect_scale, correct_effect_duration
	)
	tween.tween_property(fx, "modulate:a", 0.0, correct_effect_duration)
	tween.finished.connect(func(): fx.visible = false, CONNECT_ONE_SHOT)

	_effect_tweens[slot] = tween


func _refresh_error_icons() -> void:
	var show_icons := (
		not _first_gift_safe
		and (_challenge_active or _ending_failure)
	)
	for i in _error_icons.size():
		_error_icons[i].texture = (
			error_on_texture if i < _errors else _error_off_textures[i]
		)
		_error_icons[i].visible = show_icons


func _set_darkness(amount: float) -> void:
	backdrop.color = Color(0.0, 0.0, 0.0, clampf(amount, 0.0, 1.0))


func _set_map_effect(
	saturation_target: float,
	blur_target: float,
	duration: float = -1.0
) -> void:
	if blur_rect == null:
		return
	var mat := blur_rect.material as ShaderMaterial
	if mat == null:
		return

	if _saturation_tween != null and _saturation_tween.is_valid():
		_saturation_tween.kill()
		_saturation_tween = null

	if duration < 0.0:
		duration = saturation_fade_duration

	var sat_current_v: Variant = mat.get_shader_parameter("saturation")
	var blur_current_v: Variant = mat.get_shader_parameter("blur_amount")
	var sat_current := 1.0 if sat_current_v == null else float(sat_current_v)
	var blur_current := 0.0 if blur_current_v == null else float(blur_current_v)

	if duration <= 0.0:
		mat.set_shader_parameter("saturation", saturation_target)
		mat.set_shader_parameter("blur_amount", blur_target)
		return

	_saturation_tween = create_tween().set_parallel(true)
	_saturation_tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("saturation", v),
		sat_current, saturation_target, duration
	)
	_saturation_tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("blur_amount", v),
		blur_current, blur_target, duration
	)


# --- Recompensa y golosinas ---

func _play_open_animation() -> void:
	gift_preview.visible = true
	gift_preview.modulate = _preview_base_modulate
	gift_preview.play("abrir")
	await gift_preview.animation_finished


func _play_candy_appearance(texture: Texture2D) -> void:
	candy.texture = texture
	candy_glow.texture = texture
	candy.scale = Vector2.ONE
	candy.modulate = Color.WHITE
	candy.visible = true
	candy_glow.scale = Vector2.ONE * 0.65
	candy_glow.modulate = glow_tint
	candy_glow.visible = true

	var tween := create_tween().set_parallel(true)
	tween.tween_property(
		candy_glow, "scale", Vector2.ONE * glow_max_scale, glow_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(candy_glow, "modulate:a", 0.0, glow_duration)
	tween.tween_property(gift_preview, "modulate:a", 0.0, gift_fade_duration)

	await tween.finished
	candy_glow.visible = false
	gift_preview.visible = false


func _fly_candy_to_counter() -> void:
	var target_position := _get_reward_target_position() - candy.size / 2.0
	_candy_in_flight = true
	_trail_elapsed = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(
		candy, "position", target_position, candy_travel_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		candy, "scale", Vector2.ONE * candy_final_scale, candy_travel_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	await tween.finished
	_candy_in_flight = false
	candy.visible = false


func _get_reward_target_position() -> Vector2:
	var target_center_in_canvas := (
		gift_progress.get_global_transform_with_canvas()
		* (gift_progress.size / 2.0)
	)
	return (
		get_global_transform_with_canvas().affine_inverse()
		* target_center_in_canvas
	)


func _spawn_candy_trail() -> void:
	var ghost := TextureRect.new()
	ghost.texture = candy.texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.size = candy.size
	ghost.position = candy.position
	ghost.pivot_offset = candy.pivot_offset
	ghost.scale = candy.scale
	ghost.modulate = Color(1.0, 1.0, 1.0, trail_alpha)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(ghost)
	move_child(ghost, candy.get_index())

	var tween := create_tween().set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, trail_fade_duration)
	tween.tween_property(
		ghost, "scale", ghost.scale * trail_final_scale, trail_fade_duration
	)
	tween.chain().tween_callback(ghost.queue_free)


# --- Resolución del desafío ---

func _begin_failure() -> void:
	if not _challenge_active:
		return

	_challenge_active = false
	_ending_failure = true
	_resolving_result = true
	_failure_animation_started = false
	_end_hold_remaining = failure_hold_duration

	var darkness_fade := create_tween()
	darkness_fade.tween_property(
		backdrop, "color:a", 0.0, failure_hold_duration
	)

	gift_preview.visible = true
	gift_preview.play("cerrado")
	arrow_prompt.hide_prompt()
	_hide_memory_slots()

	_memory_input_buffer = &""
	_memory_accept_buffer = false
	_input_grace_timer = 0.0

	for icon in _error_icons:
		icon.visible = false


func _complete_failure() -> void:
	if _failure_animation_started:
		return
	_failure_animation_started = true

	await _play_open_animation()

	var failed_gift := _gift
	var failed_player := _player
	_gift = null
	_player = null

	reto_fallido.emit(failed_gift, failed_player)

	var gift_fade := create_tween()
	gift_fade.tween_property(
		gift_preview, "modulate:a", 0.0, failure_gift_fade_duration
	)
	await gift_fade.finished

	_clear_interface()
	visible = false


func _finish_success() -> void:
	if _resolving_result or not _challenge_active:
		return

	_resolving_result = true
	_challenge_active = false

	arrow_prompt.hide_prompt()
	for icon in _error_icons:
		icon.visible = false

	var darkness_fade := create_tween()
	darkness_fade.tween_property(
		backdrop, "color:a", 0.0, gift_fade_duration
	)

	await _play_open_animation()
	await _play_candy_appearance(candy_textures.pick_random())
	await get_tree().create_timer(candy_center_hold_duration).timeout
	await _fly_candy_to_counter()

	var finished_gift := _gift
	var finished_player := _player
	_gift = null
	_player = null

	reto_ganado.emit(finished_gift, finished_player)

	_set_map_effect(1.0, 0.0, trail_fade_duration)

	await get_tree().create_timer(
		trail_fade_duration + trail_spawn_interval
	).timeout

	_clear_interface()
	visible = false
	_resolving_result = false


# --- Limpieza ---

func _clear_interface() -> void:
	_set_darkness(0.0)
	_set_map_effect(1.0, 0.0)

	arrow_prompt.hide_prompt()
	_hide_memory_slots()
	_memory_token += 1
	_memory_phase = MemoryPhase.NONE
	_memory_answers.clear()
	_memory_slot_index = 0
	_memory_input_buffer = &""
	_memory_accept_buffer = false
	_input_grace_timer = 0.0

	for icon in _error_icons:
		icon.visible = false

	for i in _effect_pool.size():
		if _effect_tweens[i] != null and _effect_tweens[i].is_valid():
			_effect_tweens[i].kill()
		_effect_tweens[i] = null
		_effect_pool[i].visible = false
		_effect_pool[i].scale = Vector2.ONE
		_effect_pool[i].modulate = Color.WHITE

	gift_preview.visible = false
	gift_preview.modulate = _preview_base_modulate
	gift_preview.play("cerrado")

	candy.visible = false
	candy_glow.visible = false

	_candy_in_flight = false
	_trail_elapsed = 0.0
	_waiting_for_answer_effect = false

	_preview_gift = null
	_has_previous_prompt = false
	_last_prompt_offset = Vector2.ZERO
	_steps.clear()
	_step_index = 0
