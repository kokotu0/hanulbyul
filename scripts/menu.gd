extends Control
## 첫 화면: 게임 시작 / 수치 테스트 화면.

var _dots: Array = []
var _t := 0.0


func _ready() -> void:
	for i in 260:
		_dots.append([randf(), randf(), randf() * 0.8 + 0.3, randf() * TAU])
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	var title := UI.label("하떨별", 84, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UI.label("맵 전체가 하나의 그림 · 나는 그 안에서 피한다", 17, UI.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(_gap(18))
	var play := UI.button("게임 시작", true, 18)
	play.custom_minimum_size = Vector2(280, 48)
	play.pressed.connect(_go.bind(false))
	col.add_child(play)
	var test := UI.button("수치 테스트 화면", false, 16)
	test.custom_minimum_size = Vector2(280, 44)
	test.pressed.connect(_go.bind(true))
	col.add_child(test)
	var quit := UI.button("종료", false, 15)
	quit.custom_minimum_size = Vector2(280, 40)
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)
	col.add_child(_gap(10))
	var help := UI.label("WASD 이동 · 큰 별 클릭 조준 · Space 대시 · Q 섬광 · Tab 전체 맵 · Esc 일시정지", 14, UI.DIM)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(help)


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _go(test: bool) -> void:
	Tune.test_mode = test
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	for d in _dots:
		var a := 0.35 + 0.35 * sin(_t * 1.3 + d[3])
		draw_rect(Rect2(Vector2(d[0], d[1]) * size, Vector2(d[2], d[2]) * 1.6), Color(0.6, 0.63, 1.0, a))
