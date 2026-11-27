extends Control
## 전체 맵. 격자(가로 A~F, 세로 1~4)로 내가 어디서 어디를 보는지 보여준다.
## 흰 네모 = 지금 내 화면, 밝은 칸 = 내가 있는 칸, 초록 테두리 = 기체가 다닐 수 있는 구역.

const COLS := 6
const ROWS := 4

var game: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "전체 맵"


static func cell_name(world: Vector2, p: Vector2) -> String:
	var cx := clampi(int(p.x / world.x * COLS), 0, COLS - 1)
	var cy := clampi(int(p.y / world.y * ROWS), 0, ROWS - 1)
	return "%s%d" % [char(65 + cx), cy + 1]


func _draw() -> void:
	var frame := UI.glass(10, 0, 0.8)
	frame.shadow_size = 12
	frame.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	if game == null:
		return
	var s: float = size.x / game.world.x
	var cw := size.x / COLS
	var ch := size.y / ROWS
	# 내가 있는 칸
	var pp: Vector2 = game.player_pos * s
	var cx := clampi(int(pp.x / cw), 0, COLS - 1)
	var cy := clampi(int(pp.y / ch), 0, ROWS - 1)
	draw_rect(Rect2(cx * cw, cy * ch, cw, ch), Color(0.56, 1, 0.76, 0.08))
	# 격자
	var gl := Color(1, 1, 1, 0.05)
	for i in range(1, COLS):
		draw_line(Vector2(i * cw, 0), Vector2(i * cw, size.y), gl, 1.0)
	for j in range(1, ROWS):
		draw_line(Vector2(0, j * ch), Vector2(size.x, j * ch), gl, 1.0)
	var font := get_theme_default_font()
	for i in COLS:
		draw_string(font, Vector2(i * cw + 5, 13), char(65 + i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.28))
	for j in ROWS:
		draw_string(font, Vector2(5, j * ch + ch - 5), str(j + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.28))
	var ar: Rect2 = game.arena
	draw_rect(Rect2(ar.position * s, ar.size * s), Color(0.56, 1, 0.76, 0.45), false, 1.0)
	for b in game.bullets:
		if b.dead:
			continue
		var p: Vector2 = b.pos * s
		if p.x < 0 or p.y < 0 or p.x > size.x or p.y > size.y:
			continue
		var r := 2.6 if b.big else (1.4 if b.form == null else 1.0)
		draw_rect(Rect2(p - Vector2(r, r) * 0.5, Vector2(r, r)), b.col)
	# 들어올 탄 벽 경고
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0)
	for w in game.walls:
		var a2: Rect2 = game.arena
		var p1: Vector2
		var p2: Vector2
		match w.side:
			"left":
				p1 = a2.position; p2 = Vector2(a2.position.x, a2.end.y)
			"right":
				p1 = Vector2(a2.end.x, a2.position.y); p2 = a2.end
			"top":
				p1 = a2.position; p2 = Vector2(a2.end.x, a2.position.y)
			_:
				p1 = Vector2(a2.position.x, a2.end.y); p2 = a2.end
		draw_line(p1 * s, p2 * s, Color(0.83, 1, 0.31, blink), 3.0)
	var vr: Rect2 = game.view_rect()
	var vrr := Rect2(vr.position * s, vr.size * s).intersection(Rect2(Vector2.ZERO, size))
	draw_rect(vrr, Color(1, 1, 1, 0.05))
	draw_rect(vrr, Color(1, 1, 1, 0.8), false, 1.0)
	for pl in game.players:
		var c := UI.MINT if pl.alive() else Color(1, 0.4, 0.4)
		var pp2: Vector2 = pl.pos * s
		draw_texture_rect(UI.TEX_GLOW, Rect2(pp2 - Vector2(9, 9), Vector2(18, 18)), false, Color(c, 0.8))
		draw_circle(pp2, 2.6, c)
