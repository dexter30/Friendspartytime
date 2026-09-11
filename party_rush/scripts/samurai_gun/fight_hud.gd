class_name FightHud
extends CanvasLayer

## Samurai Gun HUD: a Smash-style card per fighter (portrait, tag, damage percent that
## heats up in colour, remaining stocks), centre-screen banners, screen flashes and the
## end-of-match results panel.

const CARD_SIZE := Vector2(232.0, 108.0)

var _cards: Array[Dictionary] = []
var _card_row: HBoxContainer
var _banner: Label
var _sub_banner: Label
var _flash: ColorRect
var _results: PanelContainer
var _results_portrait: FighterVisual
var _results_title: Label
var _results_name: Label
var _results_tagline: Label
var _results_prompt: Label
var _hint: Label


class StockRow extends Node2D:
	var fighter_data: Dictionary = {}
	var count: int = 5

	func _draw() -> void:
		if fighter_data.is_empty():
			return
		var color: Color = fighter_data["color"]
		var points := FighterRoster.shape_points(fighter_data["shape"], 8.0)
		for i in range(SamuraiGunState.STOCKS_PER_FIGHTER):
			var center := Vector2(10.0 + i * 22.0, 10.0)
			var poly := PackedVector2Array()
			for p in points:
				poly.append(p + center)
			if i < count:
				draw_colored_polygon(poly, color)
				var closed := poly.duplicate()
				closed.append(poly[0])
				draw_polyline(closed, color.darkened(0.45), 1.5, true)
			else:
				var closed := poly.duplicate()
				closed.append(poly[0])
				draw_polyline(closed, Color(1.0, 1.0, 1.0, 0.18), 1.5, true)


func _ready() -> void:
	layer = 5
	_build_static_ui()


func setup(fighters: Array[Fighter]) -> void:
	for card in _cards:
		card["panel"].queue_free()
	_cards.clear()
	for fighter in fighters:
		_cards.append(_build_card(fighter))


func _process(_delta: float) -> void:
	for card in _cards:
		var fighter: Fighter = card["fighter"]
		if not is_instance_valid(fighter):
			continue
		var label: Label = card["percent"]
		label.text = "%d%%" % int(round(fighter.percent))
		label.add_theme_color_override("font_color", _percent_color(fighter.percent))
		var stocks: StockRow = card["stocks"]
		if stocks.count != fighter.stocks:
			stocks.count = fighter.stocks
			stocks.queue_redraw()
		var panel: PanelContainer = card["panel"]
		panel.modulate.a = 1.0 if fighter.stocks > 0 else 0.35


func pulse_card(fighter: Fighter, strength: float) -> void:
	for card in _cards:
		if card["fighter"] != fighter:
			continue
		var label: Label = card["percent"]
		label.pivot_offset = label.size * 0.5
		var tween := label.create_tween()
		tween.tween_property(label, "scale", Vector2.ONE * (1.25 + strength * 0.5), 0.06).set_trans(Tween.TRANS_SINE)
		tween.tween_property(label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var panel: PanelContainer = card["panel"]
		var shake := panel.create_tween()
		for i in range(4):
			shake.tween_property(panel, "position:x", panel.position.x + randf_range(-6.0, 6.0) * strength, 0.03)
		shake.tween_property(panel, "position:x", panel.position.x, 0.03)


func show_banner(text: String, color: Color = Color(1.0, 0.92, 0.35), from_scale: float = 1.8) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * from_scale
	_banner.modulate.a = 0.0
	var tween := _banner.create_tween().set_parallel(true)
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_banner, "modulate:a", 1.0, 0.1)


func hide_banner(fade: float = 0.2) -> void:
	var tween := _banner.create_tween()
	tween.tween_property(_banner, "modulate:a", 0.0, fade)
	tween.tween_callback(func() -> void: _banner.visible = false)


func show_sub_banner(text: String) -> void:
	_sub_banner.text = text
	_sub_banner.visible = true
	_sub_banner.modulate.a = 0.0
	var tween := _sub_banner.create_tween()
	tween.tween_property(_sub_banner, "modulate:a", 1.0, 0.2)


func hide_sub_banner() -> void:
	_sub_banner.visible = false


func flash_screen(color: Color, duration: float) -> void:
	_flash.color = color
	_flash.visible = true
	_flash.modulate.a = 1.0
	var tween := _flash.create_tween()
	tween.tween_property(_flash, "modulate:a", 0.0, duration)
	tween.tween_callback(func() -> void: _flash.visible = false)


func show_results(winner: Fighter) -> void:
	_results_portrait.set_fighter(winner.fighter_data)
	_results_portrait.facing = 1
	_results_title.text = "%s WINS!" % SamuraiGunState.participant_tag(winner.selection)
	_results_title.add_theme_color_override("font_color", SamuraiGunState.participant_color(winner.selection))
	_results_name.text = winner.fighter_name()
	_results_name.add_theme_color_override("font_color", winner.fighter_color().lightened(0.2))
	_results_tagline.text = "\"%s\"" % winner.fighter_data.get("tagline", "")
	_results_prompt.text = "Jump — Rematch      Heavy — Character Select      Esc — Main Menu"
	_results.visible = true
	_results.pivot_offset = _results.size * 0.5
	_results.scale = Vector2(0.7, 0.7)
	_results.modulate.a = 0.0
	var tween := _results.create_tween().set_parallel(true)
	tween.tween_property(_results, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_results, "modulate:a", 1.0, 0.2)


func set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = text != ""


func _percent_color(percent: float) -> Color:
	if percent < 60.0:
		return Color.WHITE.lerp(Color(1.0, 0.9, 0.3), percent / 60.0)
	if percent < 110.0:
		return Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.45, 0.15), (percent - 60.0) / 50.0)
	return Color(1.0, 0.45, 0.15).lerp(Color(0.85, 0.08, 0.1), clampf((percent - 110.0) / 60.0, 0.0, 1.0))


func _build_static_ui() -> void:
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	add_child(_flash)

	_card_row = HBoxContainer.new()
	_card_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_card_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card_row.offset_top = -CARD_SIZE.y - 18.0
	_card_row.offset_bottom = -18.0
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.add_theme_constant_override("separation", 26)
	add_child(_card_row)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.offset_left = -400.0
	_banner.offset_right = 400.0
	_banner.offset_top = -110.0
	_banner.offset_bottom = 10.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 96)
	_banner.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.1))
	_banner.add_theme_constant_override("outline_size", 16)
	_banner.visible = false
	add_child(_banner)

	_sub_banner = Label.new()
	_sub_banner.set_anchors_preset(Control.PRESET_CENTER)
	_sub_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub_banner.offset_left = -400.0
	_sub_banner.offset_right = 400.0
	_sub_banner.offset_top = 10.0
	_sub_banner.offset_bottom = 50.0
	_sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_banner.add_theme_font_size_override("font_size", 26)
	_sub_banner.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	_sub_banner.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.1))
	_sub_banner.add_theme_constant_override("outline_size", 8)
	_sub_banner.visible = false
	add_child(_sub_banner)

	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_left = -500.0
	_hint.offset_right = 500.0
	_hint.offset_top = 14.0
	_hint.offset_bottom = 40.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 0.85))
	_hint.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.1))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.visible = false
	add_child(_hint)

	_results = PanelContainer.new()
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results.offset_left = -300.0
	_results.offset_right = 300.0
	_results.offset_top = -210.0
	_results.offset_bottom = 150.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.12, 0.92)
	style.border_color = Color(1.0, 0.85, 0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18.0)
	_results.add_theme_stylebox_override("panel", style)
	_results.visible = false
	add_child(_results)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	_results.add_child(vbox)

	_results_title = Label.new()
	_results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_title.add_theme_font_size_override("font_size", 40)
	_results_title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	_results_title.add_theme_constant_override("outline_size", 8)
	vbox.add_child(_results_title)

	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = Vector2(0.0, 150.0)
	vbox.add_child(portrait_holder)
	_results_portrait = FighterVisual.new()
	_results_portrait.radius = 58.0
	_results_portrait.position = Vector2(282.0, 78.0)
	portrait_holder.add_child(_results_portrait)

	_results_name = Label.new()
	_results_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_name.add_theme_font_size_override("font_size", 30)
	vbox.add_child(_results_name)

	_results_tagline = Label.new()
	_results_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_tagline.add_theme_font_size_override("font_size", 16)
	_results_tagline.add_theme_color_override("font_color", Color(0.75, 0.78, 0.9))
	vbox.add_child(_results_tagline)

	_results_prompt = Label.new()
	_results_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_prompt.add_theme_font_size_override("font_size", 15)
	_results_prompt.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(_results_prompt)


func _build_card(fighter: Fighter) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.1, 0.82)
	style.border_color = SamuraiGunState.participant_color(fighter.selection)
	style.set_border_width_all(3)
	style.border_width_top = 6
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override("panel", style)
	_card_row.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = Vector2(72.0, 0.0)
	hbox.add_child(portrait_holder)
	var portrait := FighterVisual.new()
	portrait.radius = 26.0
	portrait.position = Vector2(36.0, 48.0)
	portrait.set_fighter(fighter.fighter_data)
	portrait_holder.add_child(portrait)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.text = "%s  %s" % [SamuraiGunState.participant_tag(fighter.selection), fighter.fighter_name()]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", SamuraiGunState.participant_color(fighter.selection).lightened(0.2))
	vbox.add_child(name_label)

	var percent := Label.new()
	percent.text = "0%"
	percent.add_theme_font_size_override("font_size", 42)
	percent.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	percent.add_theme_constant_override("outline_size", 8)
	vbox.add_child(percent)

	var stocks_holder := Control.new()
	stocks_holder.custom_minimum_size = Vector2(120.0, 20.0)
	vbox.add_child(stocks_holder)
	var stocks := StockRow.new()
	stocks.fighter_data = fighter.fighter_data
	stocks.count = fighter.stocks
	stocks_holder.add_child(stocks)

	return {"fighter": fighter, "panel": panel, "percent": percent, "stocks": stocks, "portrait": portrait}
