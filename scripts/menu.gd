extends Control
## 첫 화면: 게임 시작 / 수치 테스트 화면.
## 배경: 성운 + 3겹 별밭(시차) + 가끔 떨어지는 별똥별, 가운데 제목 아래 기체가 떠 있다.

const DrawProxy := preload("res://scripts/draw_proxy.gd")

var _stars: Array = []
var _nebula: Array = []
var _falls: Array = []
var _t := 0.0
var _add: Node2D
var _top: Node2D
var _title: Label


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 360:
		# [x, y, 크기, 위상, 겹(0 먼 곳 ~ 2 가까운 곳)]
		_stars.append([rng.randf(), rng.randf(), rng.randf() * 0.8 + 0.4, rng.randf() * TAU, rng.randi() % 3])
	var hues := [Color("3a4cff"), Color("b03cff"), Color("2fd3ff"), Color("ff4fa0"), Color("5a3cff")]
	for i in 9:
		_nebula.append([Vector2(rng.randf(), rng.randf() * 0.9 + 0.05), rng.randf_range(0.35, 0.7), hues[i % hues.size()], rng.randf() * TAU, i % 2])

	var env := WorldEnvironment.new()
	env.environment = UI.glow_env()
	add_child(env)

	_add = DrawProxy.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = mat
	_add.painter = _draw_add
	add_child(_add)
	_top = DrawProxy.new()
	_top.painter = _draw_top
	add_child(_top)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	var kicker := UI.label("STARFALL  ·  BULLET HELL", 13, Color(UI.MINT, 0.8))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	_title = UI.title("하떨별", 112, Color("fff4d6"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	var sub := UI.label("맵 전체가 하나의 그림  ·  나는 그 안에서 피한다", 17, UI.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(_gap(124))
	var play := UI.button("게임 시작", true, 18)
	play.custom_minimum_size = Vector2(300, 52)
	play.pressed.connect(_go.bind(false))
	col.add_child(_center(play))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var test := UI.button("수치 테스트", false, 15)
	test.custom_minimum_size = Vector2(146, 42)
	test.pressed.connect(_go.bind(true))
	row.add_child(test)
	var quit := UI.button("종료", false, 15)
	quit.custom_minimum_size = Vector2(146, 42)
	quit.pressed.connect(func() -> void: get_tree().quit())
	row.add_child(quit)
	col.add_child(_center(row))

	# 아래쪽 조작 안내
	var help := HBoxContainer.new()
	help.add_theme_constant_override("separation", 18)
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_bottom = -28
	help.alignment = BoxContainer.ALIGNMENT_CENTER
	for kv in [["WASD", "이동"], ["클릭", "큰 별 조준"], ["Space", "대시"], ["Q", "섬광"], ["Tab", "전체 맵"], ["Esc", "일시정지"]]:
		help.add_child(UI.key_hint(kv[0], kv[1]))
	add_child(help)


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


func _go(test: bool) -> void:
	Tune.test_mode = test
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _process(dt: float) -> void:
	_t += dt
	# 별똥별
	if randf() < dt * 0.9:
		_falls.append([Vector2(randf() * size.x * 1.2, -40), Vector2(-260, 520).rotated(randf_range(-0.15, 0.15)) * randf_range(0.8, 1.3), 0.0])
	for f in _falls:
		f[0] += f[1] * dt
		f[2] += dt
	_falls = _falls.filter(func(f: Array) -> bool: return f[2] < 2.5)
	queue_redraw()
	_add.queue_redraw()
	_top.queue_redraw()


func _par() -> Vector2:
	# 마우스에 따라 살짝 움직이는 시차
	var m := get_local_mouse_position() / maxf(size.x, 1.0) - Vector2(0.5, 0.5)
	return m.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)) + Vector2(sin(_t * 0.07), cos(_t * 0.05)) * 0.3


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	# 아래로 갈수록 약간 밝은 남색
	var grad := PackedColorArray([Color("05060f"), Color("05060f"), Color("0b0f2a"), Color("0b0f2a")])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), grad)
	var par := _par()
	for d in _stars:
		var layer: int = d[4]
		var depth := 6.0 + layer * 14.0
		var p := Vector2(fposmod(d[0] * size.x + par.x * depth + _t * (2.0 + layer * 3.0), size.x), fposmod(d[1] * size.y + par.y * depth, size.y))
		var a: float = (0.25 + 0.2 * layer) * (0.6 + 0.4 * sin(_t * 1.3 + d[3]))
		var r: float = d[2] * (0.8 + layer * 0.5)
		draw_rect(Rect2(p, Vector2(r, r)), Color(0.72, 0.76, 1.0, a))


func _draw_add(c: CanvasItem) -> void:
	var par := _par()
	for n in _nebula:
		var tex: Texture2D = UI.TEX_SMOKE_A if n[4] == 0 else UI.TEX_SMOKE_B
		var sz: float = size.x * n[1]
		var p: Vector2 = n[0] * size + par * 30.0
		c.draw_set_transform(p, n[3] + _t * 0.01, Vector2.ONE)
		c.draw_texture_rect(tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color(n[2], 0.16))
	c.draw_set_transform(Vector2.ZERO)
	# 밝은 별 몇 개는 반짝이 텍스처로
	for i in range(0, _stars.size(), 9):
		var d: Array = _stars[i]
		var p := Vector2(fposmod(d[0] * size.x + par.x * 34.0 + _t * 8.0, size.x), fposmod(d[1] * size.y + par.y * 34.0, size.y))
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + d[3])
		var r := 10.0 + 10.0 * tw
		c.draw_texture_rect(UI.TEX_SPARKLE, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.75, 0.85, 1.0, 0.25 + 0.5 * tw))
	for f in _falls:
		var a: float = sin(clampf(f[2] / 2.5, 0.0, 1.0) * PI)
		var dir: Vector2 = f[1].normalized()
		c.draw_set_transform(f[0] - dir * 70.0, dir.angle() - PI / 2, Vector2.ONE)
		c.draw_texture_rect(UI.TEX_STREAK, Rect2(-5, -70, 10, 140), false, Color(1, 0.9, 0.7, 0.8 * a))
		c.draw_set_transform(Vector2.ZERO)
		c.draw_texture_rect(UI.TEX_FLARE, Rect2(f[0] - Vector2(24, 24), Vector2(48, 48)), false, Color(1, 0.95, 0.85, a))
	# 제목 뒤 후광
	if _title:
		var tc := _title.global_position + _title.size * 0.5
		var gw := 520.0 + 20.0 * sin(_t * 1.5)
		c.draw_texture_rect(UI.TEX_GLOW, Rect2(tc - Vector2(gw, gw * 0.42), Vector2(gw * 2.0, gw * 0.84)), false, Color(1, 0.75, 0.35, 0.16))
		# 기체 (제목 아래에서 둥실)
		var sp := tc + Vector2(0, 148 + 6.0 * sin(_t * 1.8))
		var fl := 0.8 + 0.2 * sin(_t * 40.0)
		c.draw_texture_rect(UI.TEX_FLAME, Rect2(sp + Vector2(-9, 18), Vector2(18, 52 * fl)), false, Color(0.35, 0.7, 1.0, 0.9))
		c.draw_texture_rect(UI.TEX_FLAME, Rect2(sp + Vector2(-5, 18), Vector2(10, 30 * fl)), false, Color(1, 1, 1, 0.9))
		c.draw_texture_rect(UI.TEX_GLOW, Rect2(sp - Vector2(70, 50), Vector2(140, 100)), false, Color(0.3, 0.6, 1.0, 0.18))



func _draw_top(c: CanvasItem) -> void:
	if _title == null:
		return
	var tc := _title.global_position + _title.size * 0.5
	var sp := tc + Vector2(0, 148 + 6.0 * sin(_t * 1.8))
	var tw := UI.TEX_SHIP.get_size() * 0.62
	c.draw_texture_rect(UI.TEX_SHIP, Rect2(sp - tw * 0.5, tw), false)
