class_name UI
extends RefCounted
## 화면 요소 공용 스타일: 색, 글꼴, 패널, 버튼, 그리고 HUD 위젯(HP 칸, 스킬 칩).
## 애셋 출처는 ASSETS.md 참고.

const BG := Color("04050c")
const INK := Color("eef0ff")
const DIM := Color("a2a7cc")
const FAINT := Color(0.64, 0.68, 0.86, 0.55)
const GOLD := Color("ffd36b")
const MINT := Color("8fffc2")
const PINK := Color("ff6b8a")
const LINE := Color(0.72, 0.78, 1.0, 0.14)
const GLASS := Color(0.035, 0.04, 0.09, 0.72)
const SHADOW := Color(0, 0, 0, 0.55)

const FONT_TITLE := preload("res://fonts/Pretendard-Black.otf")

## 효과 텍스처 (흰색 + 알파). modulate 로 색을 입혀 쓴다.
const TEX_GLOW := preload("res://assets/fx/glow.png")
const TEX_FLARE := preload("res://assets/fx/flare.png")
const TEX_SPARKLE := preload("res://assets/fx/sparkle.png")
const TEX_BURST := preload("res://assets/fx/star_burst.png")
const TEX_RING := preload("res://assets/fx/ring.png")
const TEX_STREAK := preload("res://assets/fx/streak.png")
const TEX_FLAME := preload("res://assets/fx/flame.png")
const TEX_SMOKE_A := preload("res://assets/fx/smoke_a.png")
const TEX_SMOKE_B := preload("res://assets/fx/smoke_b.png")
const TEX_RETICLE := preload("res://assets/fx/reticle.png")
const TEX_SHIP := preload("res://assets/ships/player.png")


## 2D 블룸. gl_compatibility 에서도 동작한다 (배경 모드 = 캔버스).
## UI(CanvasLayer 1 이상)는 번지지 않게 0번 층까지만 적용.
static func glow_env() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.background_canvas_max_layer = 0
	e.glow_enabled = true
	e.glow_normalized = false
	e.glow_intensity = 0.55
	e.glow_strength = 1.0
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 0.8
	e.glow_hdr_scale = 2.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		e.set_glow_level(i, 1.0 if i in [1, 2, 3, 4] else 0.0)
	return e


static func box(bg: Color, radius := 12, border := LINE, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s


## 반투명 유리 패널 (그림자 포함)
static func glass(radius := 12, pad := 12, alpha := 0.72) -> StyleBoxFlat:
	var s := box(Color(GLASS, alpha), radius, LINE, pad)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	return s


static func label(text: String, size := 16, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# 게임 화면 위에서도 읽히도록 부드러운 그림자
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size := 64, color := INK) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", FONT_TITLE)
	l.add_theme_color_override("font_shadow_color", Color(0.02, 0.0, 0.08, 0.35))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 24))
	l.add_theme_constant_override("shadow_outline_size", 0)
	return l


## 작은 알약 모양 태그 (장면 이름 등)
static func pill(text: String, size := 13, color := GOLD) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := box(Color(GLASS, 0.6), 999, Color(color, 0.35), 12)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.set_meta("label", l)
	return p


static func button(text: String, primary := false, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 40)
	var r := 10
	if primary:
		var n := box(Color("f2f4ff"), r, Color(0, 0, 0, 0), 22)
		n.shadow_color = Color(0.56, 1, 0.76, 0.25)
		n.shadow_size = 14
		var h := box(Color.WHITE, r, Color(0, 0, 0, 0), 22)
		h.shadow_color = Color(0.56, 1, 0.76, 0.45)
		h.shadow_size = 20
		var p := box(MINT, r, Color(0, 0, 0, 0), 22)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", p)
		b.add_theme_stylebox_override("hover_pressed", p)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, Color("070914"))
	else:
		b.add_theme_stylebox_override("normal", box(Color(0.06, 0.07, 0.14, 0.62), r, LINE, 16))
		b.add_theme_stylebox_override("hover", box(Color(0.11, 0.13, 0.24, 0.85), r, Color(0.72, 0.78, 1.0, 0.3), 16))
		var pr := box(Color(0.16, 0.2, 0.3, 0.9), r, Color(MINT, 0.6), 16)
		b.add_theme_stylebox_override("pressed", pr)
		b.add_theme_stylebox_override("hover_pressed", pr)
		b.add_theme_color_override("font_color", DIM)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", MINT)
		b.add_theme_color_override("font_hover_pressed_color", MINT)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## 키 모양 칩 + 설명 (메뉴·도움말용)
static func key_hint(key: String, desc: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kp := PanelContainer.new()
	kp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := box(Color(1, 1, 1, 0.08), 6, Color(1, 1, 1, 0.22), 7)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	sb.border_width_bottom = 2
	kp.add_theme_stylebox_override("panel", sb)
	kp.add_child(label(key, 12, INK))
	row.add_child(kp)
	row.add_child(label(desc, 13, DIM))
	return row


## 둥근 막대 하나 그리기 (StyleBoxFlat 재사용)
static func bar(ci: CanvasItem, r: Rect2, col: Color, radius := 99.0) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(int(minf(radius, minf(r.size.x, r.size.y) * 0.5)))
	s.anti_aliasing = true
	s.draw(ci.get_canvas_item(), r)


## HP 칸: 기울어진 캡슐들. 남은 칸은 민트, 1칸 남으면 분홍으로 깜빡인다.
class HpBar extends Control:
	var hp := 5
	var max_hp := 5
	var hurt := 0.0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(150, 18)

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var n := maxi(max_hp, 1)
		var gap := 4.0
		var w := minf(22.0, (size.x - gap * (n - 1)) / n)
		var h := 12.0
		var y := (size.y - h) * 0.5
		var low := hp <= 1
		var col := UI.PINK if low else UI.MINT
		var pulse := 0.65 + 0.35 * sin(_t * 9.0) if low else 1.0
		for i in n:
			var x := i * (w + gap)
			var sk := 3.0
			var poly := PackedVector2Array([Vector2(x + sk, y), Vector2(x + w + sk, y), Vector2(x + w - sk, y + h), Vector2(x - sk, y + h)])
			if i < hp:
				draw_texture_rect(UI.TEX_GLOW, Rect2(x - 8, y - 9, w + 16, h + 18), false, Color(col, 0.28 * pulse))
				draw_colored_polygon(poly, Color(col, pulse))
				draw_colored_polygon(PackedVector2Array([poly[0], poly[1], poly[1] + Vector2(-1.2, 4), poly[0] + Vector2(-1.2, 4)]), Color(1, 1, 1, 0.45 * pulse))
			else:
				draw_colored_polygon(poly, Color(1, 1, 1, 0.07))
				draw_polyline(poly + PackedVector2Array([poly[0]]), Color(1, 1, 1, 0.18), 1.0, true)


## 스킬 칩: 둥근 사각형 + 키 이름 + 쿨다운이 시계 방향으로 차오름.
class SkillChip extends Control:
	var key_label := ""
	var skill_name := ""
	var cd := 0.0
	var cd_max := 1.0
	var _ready_flash := 0.0
	var _was_ready := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(120, 40)

	func set_cd(v: float) -> void:
		var ready := v <= 0.0
		if ready and not _was_ready:
			_ready_flash = 1.0
		_was_ready = ready
		cd = v
		_ready_flash = maxf(0.0, _ready_flash - get_process_delta_time() * 2.5)
		queue_redraw()

	func _draw() -> void:
		var ready := cd <= 0.0
		var font := get_theme_default_font()
		var r := Rect2(Vector2.ZERO, size)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(UI.GLASS, 0.78)
		bg.set_corner_radius_all(10)
		bg.border_color = Color(UI.MINT, 0.55 + 0.45 * _ready_flash) if ready else UI.LINE
		bg.set_border_width_all(1)
		bg.anti_aliasing = true
		if ready:
			bg.shadow_color = Color(UI.MINT, 0.12 + 0.4 * _ready_flash)
			bg.shadow_size = 8
		bg.draw(get_canvas_item(), r)
		# 키 칩
		var kw := font.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
		var kr := Rect2(8, (size.y - 22) * 0.5, maxf(kw, 24.0), 22)
		var kb := StyleBoxFlat.new()
		kb.bg_color = Color(UI.MINT, 0.18) if ready else Color(1, 1, 1, 0.06)
		kb.set_corner_radius_all(6)
		kb.border_color = Color(UI.MINT, 0.6) if ready else Color(1, 1, 1, 0.16)
		kb.set_border_width_all(1)
		kb.border_width_bottom = 2
		kb.anti_aliasing = true
		kb.draw(get_canvas_item(), kr)
		draw_string(font, Vector2(kr.position.x, kr.position.y + 16), key_label, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 12, UI.INK if ready else UI.DIM)
		var tx := kr.end.x + 8.0
		draw_string(font, Vector2(tx, size.y * 0.5 + 5), skill_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.INK if ready else UI.DIM)
		# 쿨다운 원
		var c := Vector2(size.x - 18, size.y * 0.5)
		var rad := 9.0
		draw_arc(c, rad, 0, TAU, 32, Color(1, 1, 1, 0.12), 2.5, true)
		if ready:
			draw_circle(c, 3.5, UI.MINT)
			draw_texture_rect(UI.TEX_GLOW, Rect2(c - Vector2(12, 12), Vector2(24, 24)), false, Color(UI.MINT, 0.5))
		else:
			var k := 1.0 - clampf(cd / maxf(cd_max, 0.01), 0.0, 1.0)
			draw_arc(c, rad, -PI / 2, -PI / 2 + TAU * k, 32, Color(UI.MINT, 0.85), 2.5, true)
			draw_string(font, c + Vector2(-12, 4), "%d" % ceili(cd), HORIZONTAL_ALIGNMENT_CENTER, 24, 10, UI.DIM)
