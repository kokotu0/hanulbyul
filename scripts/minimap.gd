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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	if game == null:
		return
	var s: float = size.x / game.world.x
	var cw := size.x / COLS
	var ch := size.y / ROWS
	# 내가 있는 칸
	var pp: Vector2 = game.player_pos * s
	var cx := clampi(int(pp.x / cw), 0, COLS - 1)
	var cy := clampi(int(pp.y / ch), 0, ROWS - 1)
	draw_rect(Rect2(cx * cw, cy * ch, cw, ch), Color(0.56, 1, 0.76, 0.1))
	# 격자
	var gl := Color(1, 1, 1, 0.08)
	for i in range(1, COLS):
		draw_line(Vector2(i * cw, 0), Vector2(i * cw, size.y), gl, 1.0)
	for j in range(1, ROWS):
		draw_line(Vector2(0, j * ch), Vector2(size.x, j * ch), gl, 1.0)
	var font := get_theme_default_font()
	for i in COLS:
		draw_string(font, Vector2(i * cw + 3, 10), char(65 + i), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.3))
	for j in ROWS:
		draw_string(font, Vector2(2, j * ch + ch - 3), str(j + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.3))
	var ar: Rect2 = game.arena
	draw_rect(Rect2(ar.position * s, ar.size * s), Color(0.56, 1, 0.76, 0.3), false, 1.0)
	for b in game.bullets:
		if b.dead:
			continue
		var p: Vector2 = b.pos * s
		if p.x < 0 or p.y < 0 or p.x > size.x or p.y > size.y:
			continue
		var r := 2.6 if b.big else (1.4 if b.form == null else 1.0)
		draw_rect(Rect2(p - Vector2(r, r) * 0.5, Vector2(r, r)), b.col)
	var vr: Rect2 = game.view_rect()
	draw_rect(Rect2(vr.position * s, vr.size * s), Color(1, 1, 1, 0.85), false, 1.0)
	for pl in game.players:
		var c := Color("8fffc2") if pl.alive() else Color(1, 0.4, 0.4)
		draw_rect(Rect2(pl.pos * s - Vector2(2.5, 2.5), Vector2(5, 5)), c)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.22), false, 1.0)
