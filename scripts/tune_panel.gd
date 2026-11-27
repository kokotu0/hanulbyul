extends PanelContainer
## 테스트 화면의 수치 패널. 슬라이더를 움직이면 바로 Tune 값이 바뀐다.
## 맵 크기와 노드 간격은 "다시 시작" 또는 다음 그림부터 적용된다.

signal restart_requested
signal menu_requested
signal seek_requested(time: float)

var _value_labels := {}
var _sliders := {}
var _info: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.glass(14, 16, 0.9))
	custom_minimum_size = Vector2(320, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 14)
	scroll.add_child(pad)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	pad.add_child(col)

	col.add_child(UI.title("수치 테스트", 24, Color("fff4d6")))
	var hint := UI.label("움직이면 바로 적용됩니다. 맵 크기는 다시 시작, 노드 간격은 다음 그림부터 적용돼요.", 12, UI.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(280, 0)
	col.add_child(hint)

	var last_group := 0
	for key in Tune.SPEC:
		var spec: Array = Tune.SPEC[key]
		if spec[6] != last_group:
			last_group = spec[6]
			var g := UI.label(Tune.GROUPS[last_group], 14, UI.MINT)
			col.add_child(_spacer(4))
			col.add_child(g)
		var row := HBoxContainer.new()
		var name_l := UI.label(spec[4], 13, UI.DIM)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val_l := UI.label("", 13, UI.INK)
		row.add_child(name_l)
		row.add_child(val_l)
		col.add_child(row)
		var sl := HSlider.new()
		sl.min_value = spec[1]
		sl.max_value = spec[2]
		sl.step = spec[3]
		sl.value = Tune.f(key)
		sl.focus_mode = Control.FOCUS_NONE
		_style_slider(sl)
		sl.value_changed.connect(_on_slider.bind(key))
		col.add_child(sl)
		_value_labels[key] = val_l
		_sliders[key] = sl
		_refresh_label(key)

	col.add_child(_spacer(8))
	col.add_child(UI.label("구간 바로가기", 14, UI.MINT))
	var grid := GridContainer.new()
	grid.columns = 4
	for sec in Track1.SECTIONS:
		var b := UI.button(sec.name, false, 12)
		b.custom_minimum_size = Vector2(0, 32)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: seek_requested.emit(float(sec.t)))
		grid.add_child(b)
	col.add_child(grid)
	var inv := CheckBox.new()
	inv.text = "무적 (맞아도 계속)"
	inv.focus_mode = Control.FOCUS_NONE
	inv.button_pressed = Tune.invincible
	inv.toggled.connect(func(on: bool) -> void: Tune.invincible = on)
	col.add_child(inv)

	var row1 := HBoxContainer.new()
	var restart := UI.button("다시 시작", true, 14)
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(func() -> void: restart_requested.emit())
	var reset := UI.button("기본값", false, 14)
	reset.pressed.connect(_on_reset)
	row1.add_child(restart)
	row1.add_child(reset)
	col.add_child(row1)

	var row2 := HBoxContainer.new()
	var copy := UI.button("값 복사", false, 14)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.pressed.connect(_on_copy)
	var menu := UI.button("메뉴로", false, 14)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	row2.add_child(copy)
	row2.add_child(menu)
	col.add_child(row2)

	_info = UI.label("", 12, UI.DIM)
	col.add_child(_info)


## 슬라이더: 얇은 둥근 트랙 + 민트 채움 + 흰 손잡이
func _style_slider(sl: HSlider) -> void:
	var track := UI.box(Color(1, 1, 1, 0.1), 99, Color(0, 0, 0, 0), 0)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := UI.box(Color(UI.MINT, 0.8), 99, Color(0, 0, 0, 0), 0)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 14:
			var d := Vector2(x + 0.5 - 7, y + 0.5 - 7).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(6.5 - d, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	sl.add_theme_icon_override("grabber", tex)
	sl.add_theme_icon_override("grabber_highlight", tex)


func set_info(text: String) -> void:
	if _info:
		_info.text = text


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_slider(value: float, key: String) -> void:
	Tune.set_value(key, value)
	_refresh_label(key)


func _refresh_label(key: String) -> void:
	_value_labels[key].text = "%s %s" % [Tune._fmt(Tune.f(key)), Tune.SPEC[key][5]]


func _on_reset() -> void:
	Tune.reset_defaults()
	for key in _sliders:
		_sliders[key].set_value_no_signal(Tune.f(key))
		_refresh_label(key)


func _on_copy() -> void:
	DisplayServer.clipboard_set(Tune.summary())
	set_info("클립보드에 복사했어요. 채팅에 붙여넣어 주세요.")
