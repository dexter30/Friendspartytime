extends Control

## Samurai Gun character select. Each of the three local players joins with Jump, moves a
## coloured cursor over the roster grid, confirms with Jump/Light and backs out with Heavy.
## A lone player gets a CPU opponent so the arena always has at least two fighters.

const GRID_COLUMNS := 4
const CELL_SIZE := Vector2(164.0, 150.0)
const CELL_GAP := 16.0
const SLOT_COLORS_DIM := Color(0.5, 0.52, 0.6)

## Per-slot state: "empty" -> "picking" -> "ready".
var _slots: Array[Dictionary] = []
var _cells: Array[Dictionary] = []
var _grid_origin := Vector2.ZERO
var _cursor_layer: Node2D
var _time := 0.0
var _starting := false

@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _grid_holder: Control = $GridHolder
@onready var _slot_row: HBoxContainer = $SlotRow
@onready var _start_prompt: Label = $StartPrompt
@onready var _footer: Label = $Footer


func _ready() -> void:
	Engine.time_scale = 1.0
	_footer.text = "P1: WASD move · Space jump · F light · G heavy      P2: Arrows · Enter · / light · . heavy      P3: IJKL · U jump · O light · P heavy      Gamepads: Stick · A · X · B      Esc: menu"
	_build_backdrop()
	_build_grid()
	_build_slots()
	_cursor_layer = Node2D.new()
	_cursor_layer.name = "Cursors"
	_cursor_layer.z_index = 5
	_cursor_layer.draw.connect(_draw_cursors)
	add_child(_cursor_layer)
	_animate_title()
	_refresh_slot_panels()


func _process(delta: float) -> void:
	_time += delta
	_cursor_layer.queue_redraw()
	if _starting:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	for i in range(SamuraiGunState.MAX_PLAYERS):
		_handle_slot_input(i)
	_update_start_prompt()


func _action(slot: int, suffix: String) -> String:
	return "p%d_%s" % [slot + 1, suffix]


func _handle_slot_input(i: int) -> void:
	var slot := _slots[i]
	var jump := Input.is_action_just_pressed(_action(i, "jump"))
	var light := Input.is_action_just_pressed(_action(i, "light"))
	var heavy := Input.is_action_just_pressed(_action(i, "heavy"))
	match slot["state"]:
		"empty":
			if jump or light:
				slot["state"] = "picking"
				_pop_cell(slot["cursor"])
				_refresh_slot_panels()
		"picking":
			var moved := false
			if Input.is_action_just_pressed(_action(i, "left")):
				slot["cursor"] = _move_cursor(slot["cursor"], -1, 0)
				moved = true
			elif Input.is_action_just_pressed(_action(i, "right")):
				slot["cursor"] = _move_cursor(slot["cursor"], 1, 0)
				moved = true
			elif Input.is_action_just_pressed(_action(i, "forward")):
				slot["cursor"] = _move_cursor(slot["cursor"], 0, -1)
				moved = true
			elif Input.is_action_just_pressed(_action(i, "back")):
				slot["cursor"] = _move_cursor(slot["cursor"], 0, 1)
				moved = true
			if moved:
				_pop_cell(slot["cursor"])
				_refresh_slot_panels()
			if jump or light:
				slot["state"] = "ready"
				_pop_cell(slot["cursor"])
				_refresh_slot_panels()
			elif heavy:
				slot["state"] = "empty"
				_refresh_slot_panels()
		"ready":
			if heavy:
				slot["state"] = "picking"
				_refresh_slot_panels()
			elif jump and _can_start():
				_start_match()


func _move_cursor(index: int, dx: int, dy: int) -> int:
	var count := FighterRoster.count()
	var rows := int(ceil(count / float(GRID_COLUMNS)))
	var col := index % GRID_COLUMNS
	var row := int(index / float(GRID_COLUMNS))
	col = wrapi(col + dx, 0, GRID_COLUMNS)
	row = wrapi(row + dy, 0, rows)
	var new_index := row * GRID_COLUMNS + col
	if new_index >= count:
		new_index = count - 1 if dy != 0 else (row * GRID_COLUMNS)
	return new_index


func _can_start() -> bool:
	var ready := 0
	for slot in _slots:
		if slot["state"] == "picking":
			return false
		if slot["state"] == "ready":
			ready += 1
	return ready >= 1


func _update_start_prompt() -> void:
	var ready := 0
	var picking := 0
	for slot in _slots:
		if slot["state"] == "ready":
			ready += 1
		elif slot["state"] == "picking":
			picking += 1
	if ready == 0:
		_start_prompt.text = "Press Jump to join"
		_start_prompt.modulate.a = 0.6 + 0.4 * absf(sin(_time * 3.0))
	elif picking > 0:
		_start_prompt.text = "Waiting for everyone to lock in..."
		_start_prompt.modulate.a = 0.8
	elif ready == 1:
		_start_prompt.text = "Press Jump to FIGHT a CPU  (others can still join)"
		_start_prompt.modulate.a = 0.7 + 0.3 * absf(sin(_time * 5.0))
	else:
		_start_prompt.text = "Press Jump to FIGHT!"
		_start_prompt.modulate.a = 0.7 + 0.3 * absf(sin(_time * 5.0))


func _start_match() -> void:
	_starting = true
	var selections: Array[Dictionary] = []
	for i in range(_slots.size()):
		if _slots[i]["state"] == "ready":
			selections.append({"player_index": i, "fighter_index": _slots[i]["cursor"], "is_cpu": false})
	if selections.size() == 1:
		var cpu_slot := 1 if selections[0]["player_index"] != 1 else 2
		var cpu_pick := FighterRoster.random_index()
		if cpu_pick == selections[0]["fighter_index"]:
			cpu_pick = (cpu_pick + 1) % FighterRoster.count()
		selections.append({"player_index": cpu_slot, "fighter_index": cpu_pick, "is_cpu": true})
	SamuraiGunState.set_selections(selections)
	_start_prompt.text = "FIGHT!"
	_start_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_start_prompt.pivot_offset = _start_prompt.size * 0.5
	var tween := create_tween()
	tween.tween_property(_start_prompt, "scale", Vector2(1.4, 1.4), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.35)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file("res://scenes/samurai_gun/arena.tscn"))


# --- Building the screen --------------------------------------------------------------

func _build_backdrop() -> void:
	var backdrop := Node2D.new()
	backdrop.name = "Backdrop"
	backdrop.draw.connect(_draw_backdrop.bind(backdrop))
	add_child(backdrop)
	move_child(backdrop, 1)
	var petals := CPUParticles2D.new()
	petals.amount = 40
	petals.lifetime = 8.0
	petals.preprocess = 8.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(760.0, 10.0)
	petals.position = Vector2(700.0, -20.0)
	petals.direction = Vector2(-0.4, 1.0)
	petals.spread = 15.0
	petals.gravity = Vector2(-10.0, 30.0)
	petals.initial_velocity_min = 40.0
	petals.initial_velocity_max = 80.0
	petals.scale_amount_min = 2.0
	petals.scale_amount_max = 4.0
	petals.color = Color(1.0, 0.7, 0.8, 0.5)
	backdrop.add_child(petals)


func _draw_backdrop(node: Node2D) -> void:
	var size := get_viewport_rect().size
	var moon := Vector2(size.x - 150.0, 120.0)
	node.draw_circle(moon, 150.0, Color(1.0, 0.93, 0.7, 0.05))
	node.draw_circle(moon, 100.0, Color(1.0, 0.94, 0.75, 0.08))
	node.draw_circle(moon, 78.0, Color(0.98, 0.94, 0.8, 0.9))
	node.draw_circle(moon + Vector2(-26.0, -14.0), 14.0, Color(0.9, 0.86, 0.72))
	node.draw_circle(moon + Vector2(22.0, 26.0), 9.0, Color(0.9, 0.86, 0.72))
	var ridge := PackedVector2Array([Vector2(0.0, size.y), Vector2(0.0, size.y - 120.0)])
	var x := 0.0
	var i := 0
	while x < size.x:
		ridge.append(Vector2(x, size.y - 120.0 - absf(sin(i * 1.9)) * 90.0))
		x += 160.0
		i += 1
	ridge.append(Vector2(size.x, size.y - 120.0))
	ridge.append(Vector2(size.x, size.y))
	node.draw_colored_polygon(ridge, Color(0.1, 0.07, 0.17))


func _build_grid() -> void:
	var count := FighterRoster.count()
	var rows := int(ceil(count / float(GRID_COLUMNS)))
	var grid_size := Vector2(GRID_COLUMNS * CELL_SIZE.x + (GRID_COLUMNS - 1) * CELL_GAP, rows * CELL_SIZE.y + (rows - 1) * CELL_GAP)
	_grid_holder.custom_minimum_size = grid_size
	_grid_holder.size = grid_size
	_grid_holder.position = Vector2((get_viewport_rect().size.x - grid_size.x) * 0.5, 118.0)
	_grid_origin = _grid_holder.position

	for i in range(count):
		var data := FighterRoster.get_fighter(i)
		var col := i % GRID_COLUMNS
		var row := int(i / float(GRID_COLUMNS))
		# A plain Panel (not a container) so the portrait and name keep manual positions.
		var cell := Panel.new()
		cell.position = Vector2(col * (CELL_SIZE.x + CELL_GAP), row * (CELL_SIZE.y + CELL_GAP))
		cell.size = CELL_SIZE
		cell.pivot_offset = CELL_SIZE * 0.5
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.09, 0.18, 0.95)
		style.border_color = data["color"].darkened(0.2)
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		cell.add_theme_stylebox_override("panel", style)
		_grid_holder.add_child(cell)

		var visual := FighterVisual.new()
		visual.radius = 36.0
		visual.position = Vector2(CELL_SIZE.x * 0.5, 58.0)
		visual.set_fighter(data)
		cell.add_child(visual)

		var name_label := Label.new()
		name_label.text = data["name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.position = Vector2(0.0, CELL_SIZE.y - 40.0)
		name_label.size = Vector2(CELL_SIZE.x, 32.0)
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", data["color"].lightened(0.35))
		name_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
		name_label.add_theme_constant_override("outline_size", 5)
		cell.add_child(name_label)
		_cells.append({"panel": cell, "visual": visual})


func _build_slots() -> void:
	for i in range(SamuraiGunState.MAX_PLAYERS):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(340.0, 150.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.07, 0.15, 0.9)
		style.border_color = GameState.PLAYER_COLORS[i]
		style.set_border_width_all(2)
		style.border_width_top = 6
		style.set_corner_radius_all(12)
		style.set_content_margin_all(12.0)
		panel.add_theme_stylebox_override("panel", style)
		_slot_row.add_child(panel)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		panel.add_child(hbox)

		var portrait_holder := Control.new()
		portrait_holder.custom_minimum_size = Vector2(96.0, 0.0)
		hbox.add_child(portrait_holder)
		var portrait := FighterVisual.new()
		portrait.radius = 40.0
		portrait.position = Vector2(48.0, 62.0)
		portrait.set_fighter(FighterRoster.get_fighter(i))
		portrait.visible = false
		portrait_holder.add_child(portrait)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(vbox)

		var tag := Label.new()
		tag.text = "P%d  %s" % [i + 1, GameState.PLAYER_NAMES[i]]
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])
		vbox.add_child(tag)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(name_label)

		var status := Label.new()
		status.add_theme_font_size_override("font_size", 14)
		status.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(status)

		_slots.append({
			"state": "empty",
			"cursor": i % FighterRoster.count(),
			"panel": panel,
			"portrait": portrait,
			"name": name_label,
			"status": status,
			"style": style,
		})


func _refresh_slot_panels() -> void:
	for i in range(_slots.size()):
		var slot := _slots[i]
		var portrait: FighterVisual = slot["portrait"]
		var name_label: Label = slot["name"]
		var status: Label = slot["status"]
		var style: StyleBoxFlat = slot["style"]
		var data := FighterRoster.get_fighter(slot["cursor"])
		match slot["state"]:
			"empty":
				portrait.visible = false
				name_label.text = "—"
				name_label.add_theme_color_override("font_color", SLOT_COLORS_DIM)
				status.text = "Press Jump to join"
				style.border_color = GameState.PLAYER_COLORS[i].darkened(0.5)
				style.bg_color = Color(0.08, 0.07, 0.15, 0.6)
			"picking":
				portrait.visible = true
				portrait.set_fighter(data)
				name_label.text = data["name"]
				name_label.add_theme_color_override("font_color", data["color"].lightened(0.3))
				status.text = "\"%s\"\nJump: lock in   Heavy: leave" % data["tagline"]
				style.border_color = GameState.PLAYER_COLORS[i]
				style.bg_color = Color(0.08, 0.07, 0.15, 0.9)
			"ready":
				portrait.visible = true
				portrait.set_fighter(data)
				name_label.text = data["name"]
				name_label.add_theme_color_override("font_color", data["color"].lightened(0.3))
				status.text = "READY!   (Heavy: change)"
				style.border_color = Color(1.0, 0.9, 0.35)
				style.bg_color = Color(0.14, 0.12, 0.08, 0.95)
		(slot["panel"] as PanelContainer).add_theme_stylebox_override("panel", style)


func _pop_cell(index: int) -> void:
	if index < 0 or index >= _cells.size():
		return
	var panel: Panel = _cells[index]["panel"]
	var tween := panel.create_tween()
	tween.tween_property(panel, "scale", Vector2(1.08, 1.08), 0.06)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_title() -> void:
	_title.pivot_offset = _title.size * 0.5
	var tween := _title.create_tween().set_loops()
	tween.tween_property(_title, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw_cursors() -> void:
	for i in range(_slots.size()):
		var slot := _slots[i]
		if slot["state"] == "empty":
			continue
		var index: int = slot["cursor"]
		var col := index % GRID_COLUMNS
		var row := int(index / float(GRID_COLUMNS))
		var cell_pos := _grid_origin + Vector2(col * (CELL_SIZE.x + CELL_GAP), row * (CELL_SIZE.y + CELL_GAP))
		var inset := 4.0 + i * 7.0
		var rect := Rect2(cell_pos + Vector2(inset, inset), CELL_SIZE - Vector2(inset, inset) * 2.0)
		var color := GameState.PLAYER_COLORS[i]
		var pulse := 0.75 + 0.25 * sin(_time * 6.0 + i)
		if slot["state"] == "ready":
			color = Color(1.0, 0.9, 0.35)
			pulse = 1.0
		var draw_color := Color(color.r, color.g, color.b, pulse)
		_cursor_layer.draw_rect(rect, draw_color, false, 4.0)
		# Player badge on a corner, each player gets their own corner.
		var badge_pos := rect.position + Vector2(rect.size.x - 20.0, 4.0) if i == 0 else (rect.position + Vector2(4.0, 4.0) if i == 1 else rect.position + Vector2(rect.size.x - 20.0, rect.size.y - 24.0))
		_cursor_layer.draw_rect(Rect2(badge_pos, Vector2(18.0, 20.0)), color)
		var font := ThemeDB.fallback_font
		_cursor_layer.draw_string(font, badge_pos + Vector2(2.0, 15.0), "P%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.03, 0.08))
		if slot["state"] == "ready":
			_cursor_layer.draw_string(font, rect.position + Vector2(8.0, rect.size.y - 8.0), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.9, 0.35))
