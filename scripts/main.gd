extends Control

const TOTAL_QUESTIONS := 10
const POINTS_PER_ANSWER := 10

const COLOR_BACKGROUND := Color("#0b1230")
const COLOR_PANEL := Color("#fbfaff")
const COLOR_INK := Color("#29264b")
const COLOR_MUTED := Color("#77748f")
const COLOR_PURPLE := Color("#7357e8")
const COLOR_MINT := Color("#27a58f")
const COLOR_ORANGE := Color("#d77b47")

var rng := RandomNumberGenerator.new()
var star_rng := RandomNumberGenerator.new()
var star_positions: Array[Vector3] = []

var score := 0
var streak := 0
var completed_questions := 0
var correct_answer := 0
var answered_correctly := false
var mission_finished := false

var score_value: Label
var streak_value: Label
var question_count: Label
var progress_bar: ProgressBar
var prompt_label: Label
var equation_row: HBoxContainer
var answer_row: HBoxContainer
var first_number_label: Label
var operator_label: Label
var second_number_label: Label
var answer_input: LineEdit
var feedback_label: Label
var next_button: Button
var correct_player: AudioStreamPlayer
var incorrect_player: AudioStreamPlayer


func _ready() -> void:
	rng.randomize()
	_create_starfield()
	_build_audio_players()
	_build_interface()
	_new_question()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND, true)
	draw_circle(Vector2(size.x * 0.04, size.y * 0.76), size.y * 0.28, Color("#111c43"))
	draw_circle(Vector2(size.x * 0.98, size.y * 0.18), size.y * 0.2, Color("#121d43"))
	draw_arc(
		Vector2(size.x * 0.98, size.y * 0.18),
		size.y * 0.155,
		0.1,
		TAU - 0.1,
		72,
		Color("#324078"),
		2.0,
		true
	)

	for star in star_positions:
		var star_color := Color("#e8e8ff")
		star_color.a = 0.35 + star.z * 0.2
		draw_circle(Vector2(star.x * size.x, star.y * size.y), star.z, star_color)

	_draw_rocket(Vector2(size.x * 0.89, size.y * 0.19))


func _create_starfield() -> void:
	star_rng.seed = 682391
	star_positions.clear()
	for _index in range(110):
		star_positions.append(
			Vector3(star_rng.randf(), star_rng.randf(), star_rng.randf_range(0.8, 2.1))
		)


func _draw_rocket(position: Vector2) -> void:
	draw_set_transform(position, -0.55, Vector2.ONE)
	draw_colored_polygon(
		PackedVector2Array([Vector2(0, -27), Vector2(13, 5), Vector2(0, 20), Vector2(-13, 5)]),
		Color("#f7f5ff")
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-12, 4), Vector2(-23, 16), Vector2(-8, 14)]), Color("#ff9d67")
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(12, 4), Vector2(23, 16), Vector2(8, 14)]), Color("#ff9d67")
	)
	draw_circle(Vector2.ZERO, 5.5, Color("#71cfff"))
	draw_colored_polygon(
		PackedVector2Array([Vector2(-6, 18), Vector2(0, 34), Vector2(6, 18)]), Color("#ffd16f")
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _build_audio_players() -> void:
	correct_player = AudioStreamPlayer.new()
	correct_player.stream = _make_tone_stream([523.25, 659.25, 783.99], 0.13)
	add_child(correct_player)

	incorrect_player = AudioStreamPlayer.new()
	incorrect_player.stream = _make_tone_stream([330.0, 246.94], 0.16)
	add_child(incorrect_player)


func _make_tone_stream(notes: Array, note_duration: float) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var frames_per_note := int(SAMPLE_RATE * note_duration)
	var frame_count := frames_per_note * notes.size()
	var sample_data := PackedByteArray()
	sample_data.resize(frame_count * 2)

	for frame in range(frame_count):
		var note_index := mini(int(frame / frames_per_note), notes.size() - 1)
		var frame_in_note := frame % frames_per_note
		var phase := float(frame_in_note) / float(frames_per_note)
		var envelope := sin(PI * phase)
		var frequency: float = notes[note_index]
		var sample := sin(TAU * frequency * float(frame) / SAMPLE_RATE) * envelope * 0.25
		sample_data.encode_s16(frame * 2, int(sample * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = sample_data
	return stream


func _build_interface() -> void:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 54.0
	page.offset_top = 26.0
	page.offset_right = -54.0
	page.offset_bottom = -22.0
	page.add_theme_constant_override("separation", 14)
	add_child(page)

	page.add_child(_build_header())
	page.add_child(_build_intro())
	page.add_child(_build_challenge_card())

	var footer := _make_label(
		"ADDITION + SUBTRACTION  •  EVERY ANSWER IS A NEW ADVENTURE", 11, Color("#a5afd7"), true
	)
	footer.custom_minimum_size = Vector2(0, 22)
	page.add_child(footer)


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 62)
	header.alignment = BoxContainer.ALIGNMENT_CENTER

	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 1)
	var title := _make_label("NUMBER NEBULA", 24, Color("#ffffff"))
	var subtitle := _make_label("MATH QUEST  •  SPACE TRAINING", 10, Color("#a5afd7"))
	brand.add_child(title)
	brand.add_child(subtitle)
	header.add_child(brand)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_build_stat_widget("STAR POINTS", "0", Color("#ffcf70")))
	header.add_child(_build_stat_widget("STREAK", "0", Color("#78d8c6")))
	return header


func _build_stat_widget(caption: String, initial_value: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132, 58)
	panel.add_theme_stylebox_override(
		"panel", _make_panel_style(Color("#172143"), Color("#35416b"), 15, 1)
	)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var star := _make_label("✦", 24, accent)
	row.add_child(star)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	column.add_child(_make_label(caption, 9, Color("#a5afd7")))

	var value := _make_label(initial_value, 20, Color("#ffffff"))
	column.add_child(value)
	if caption == "STAR POINTS":
		score_value = value
	else:
		streak_value = value
	return panel


func _build_intro() -> VBoxContainer:
	var intro := VBoxContainer.new()
	intro.custom_minimum_size = Vector2(0, 104)
	intro.alignment = BoxContainer.ALIGNMENT_CENTER
	intro.add_theme_constant_override("separation", 1)
	intro.add_child(_make_label("Math Quest!", 43, Color("#ffffff")))
	intro.add_child(
		_make_label(
			"Solve the sums. Collect the stars. Become a number hero!", 14, Color("#c2c8e5")
		)
	)
	return intro


func _build_challenge_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 440)
	card.add_theme_stylebox_override(
		"panel", _make_panel_style(COLOR_PANEL, Color("#ffffff"), 26, 0)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var mission_header := HBoxContainer.new()
	mission_header.alignment = BoxContainer.ALIGNMENT_CENTER
	var mission_title := _make_label("✦  SPACE MISSION 01", 12, COLOR_PURPLE)
	mission_header.add_child(mission_title)
	var mission_spacer := Control.new()
	mission_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_header.add_child(mission_spacer)
	question_count = _make_label("PROBLEM 1 OF 10", 11, COLOR_MUTED)
	mission_header.add_child(question_count)
	content.add_child(mission_header)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = TOTAL_QUESTIONS
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 12)
	progress_bar.add_theme_stylebox_override(
		"background", _make_panel_style(Color("#eceaf5"), Color("#eceaf5"), 8, 0)
	)
	progress_bar.add_theme_stylebox_override(
		"fill", _make_panel_style(Color("#8d72f0"), Color("#8d72f0"), 8, 0)
	)
	content.add_child(progress_bar)

	prompt_label = _make_label("What is the answer, space ranger?", 16, COLOR_MUTED, true)
	prompt_label.custom_minimum_size = Vector2(0, 30)
	content.add_child(prompt_label)

	equation_row = HBoxContainer.new()
	equation_row.alignment = BoxContainer.ALIGNMENT_CENTER
	equation_row.custom_minimum_size = Vector2(0, 96)
	equation_row.add_theme_constant_override("separation", 16)
	content.add_child(equation_row)

	first_number_label = _make_label("0", 52, COLOR_INK)
	operator_label = _make_label("+", 48, COLOR_PURPLE)
	second_number_label = _make_label("0", 52, COLOR_INK)
	equation_row.add_child(first_number_label)
	equation_row.add_child(operator_label)
	equation_row.add_child(second_number_label)
	equation_row.add_child(_make_label("=", 42, Color("#b7b3cd")))

	answer_input = LineEdit.new()
	answer_input.custom_minimum_size = Vector2(152, 68)
	answer_input.placeholder_text = "?"
	answer_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	answer_input.max_length = 4
	answer_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	answer_input.add_theme_font_size_override("font_size", 32)
	answer_input.add_theme_color_override("font_color", COLOR_INK)
	answer_input.add_theme_color_override("font_placeholder_color", Color("#a99be5"))
	answer_input.add_theme_stylebox_override(
		"normal", _make_panel_style(Color("#f4f1ff"), Color("#cbc2f2"), 17, 2)
	)
	answer_input.add_theme_stylebox_override(
		"focus", _make_panel_style(Color("#ffffff"), COLOR_PURPLE, 17, 2)
	)
	equation_row.add_child(answer_input)

	var range_note := _make_label(
		"Whole-number answers from 0 to 1,000", 11, Color("#a09db4"), true
	)
	content.add_child(range_note)

	answer_row = HBoxContainer.new()
	answer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	answer_row.add_theme_constant_override("separation", 12)
	content.add_child(answer_row)

	var check_button := _make_button("Check answer  →", Color("#7357e8"))
	check_button.custom_minimum_size = Vector2(190, 56)
	check_button.pressed.connect(_submit_answer)
	answer_input.text_submitted.connect(_on_answer_submitted)
	answer_row.add_child(check_button)

	feedback_label = _make_label("Take your time — you can do it!", 13, COLOR_MUTED, true)
	feedback_label.custom_minimum_size = Vector2(0, 28)
	content.add_child(feedback_label)

	next_button = _make_button("Next problem  →", Color("#27a58f"))
	next_button.custom_minimum_size = Vector2(220, 54)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_button.pressed.connect(_on_next_pressed)
	next_button.hide()
	content.add_child(next_button)

	return card


func _make_label(text: String, font_size: int, color: Color, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_stylebox_override("normal", _make_panel_style(color, color, 16, 0))
	button.add_theme_stylebox_override(
		"hover", _make_panel_style(color.lightened(0.08), color.lightened(0.08), 16, 0)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_panel_style(color.darkened(0.12), color.darkened(0.12), 16, 0)
	)
	button.add_theme_stylebox_override("focus", _make_panel_style(color, Color("#ffd16f"), 16, 2))
	return button


func _make_panel_style(
	background_color: Color, border_color: Color, radius: int, border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _new_question() -> void:
	var is_addition := rng.randf() < 0.5
	var first_number: int
	var second_number: int
	if is_addition:
		first_number = rng.randi_range(0, 1000)
		second_number = rng.randi_range(0, 1000 - first_number)
		correct_answer = first_number + second_number
		operator_label.text = "+"
	else:
		first_number = rng.randi_range(0, 1000)
		second_number = rng.randi_range(0, first_number)
		correct_answer = first_number - second_number
		operator_label.text = "−"

	first_number_label.text = str(first_number)
	second_number_label.text = str(second_number)
	answered_correctly = false
	equation_row.show()
	answer_row.show()
	answer_input.editable = true
	answer_input.clear()
	next_button.hide()
	prompt_label.text = "What is the answer, space ranger?"
	feedback_label.text = "Take your time — you can do it!"
	feedback_label.add_theme_color_override("font_color", COLOR_MUTED)
	_update_progress()
	answer_input.grab_focus()


func _update_progress() -> void:
	var displayed_question := mini(completed_questions + 1, TOTAL_QUESTIONS)
	question_count.text = "PROBLEM %d OF %d" % [displayed_question, TOTAL_QUESTIONS]
	progress_bar.value = completed_questions


func _submit_answer() -> void:
	if answered_correctly or mission_finished:
		return

	var submitted_text := answer_input.text.strip_edges()
	if submitted_text.is_empty() or not submitted_text.is_valid_int():
		feedback_label.text = "Type a whole-number answer first."
		feedback_label.add_theme_color_override("font_color", COLOR_ORANGE)
		return

	var submitted_answer := submitted_text.to_int()
	if submitted_answer < 0 or submitted_answer > 1000:
		feedback_label.text = "Your answer needs to be from 0 to 1,000."
		feedback_label.add_theme_color_override("font_color", COLOR_ORANGE)
		return

	if submitted_answer == correct_answer:
		_handle_correct_answer()
	else:
		_handle_incorrect_answer()


func _handle_correct_answer() -> void:
	score += POINTS_PER_ANSWER
	streak += 1
	completed_questions += 1
	answered_correctly = true
	answer_input.text = str(correct_answer)
	score_value.text = str(score)
	streak_value.text = str(streak)
	feedback_label.text = "Brilliant! +%d points — you earned a star!" % POINTS_PER_ANSWER
	feedback_label.add_theme_color_override("font_color", COLOR_MINT)
	answer_input.editable = false
	answer_row.hide()
	next_button.text = (
		"Finish mission  ★" if completed_questions == TOTAL_QUESTIONS else "Next problem  →"
	)
	next_button.show()
	_update_progress()
	correct_player.play()
	next_button.grab_focus()


func _handle_incorrect_answer() -> void:
	streak = 0
	streak_value.text = str(streak)
	feedback_label.text = "Not quite — give it another try. You’ve got this!"
	feedback_label.add_theme_color_override("font_color", COLOR_ORANGE)
	incorrect_player.play()
	answer_input.select_all()
	answer_input.grab_focus()


func _on_answer_submitted(_submitted_text: String) -> void:
	_submit_answer()


func _on_next_pressed() -> void:
	if mission_finished:
		score = 0
		streak = 0
		completed_questions = 0
		score_value.text = "0"
		streak_value.text = "0"
		mission_finished = false
		next_button.text = "Next problem  →"
		_new_question()
		return

	if completed_questions == TOTAL_QUESTIONS:
		_finish_mission()
		return

	_new_question()


func _finish_mission() -> void:
	mission_finished = true
	prompt_label.text = "MISSION COMPLETE — AMAZING WORK!"
	equation_row.hide()
	answer_row.hide()
	feedback_label.text = "You earned %d points. Ready for another flight?" % score
	feedback_label.add_theme_color_override("font_color", COLOR_MINT)
	question_count.text = "MISSION COMPLETE!"
	progress_bar.value = TOTAL_QUESTIONS
	next_button.text = "Play again  ↻"
	next_button.show()
	next_button.grab_focus()
