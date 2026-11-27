class_name UI
extends RefCounted
## 화면 요소 공용 스타일.

const BG := Color("04050c")
const INK := Color("eceefe")
const DIM := Color("9a9ec8")
const GOLD := Color("ffd36b")
const LINE := Color(0.7, 0.75, 1.0, 0.16)


static func box(bg: Color, radius := 12, border := LINE, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func label(text: String, size := 16, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, primary := false, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 40)
	if primary:
		b.add_theme_stylebox_override("normal", box(INK, 999, Color(0, 0, 0, 0), 22))
		b.add_theme_stylebox_override("hover", box(Color.WHITE, 999, Color(0, 0, 0, 0), 22))
		b.add_theme_stylebox_override("pressed", box(GOLD, 999, Color(0, 0, 0, 0), 22))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, Color("05060f"))
	else:
		b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0.6), 999, LINE, 14))
		b.add_theme_stylebox_override("hover", box(Color(0.1, 0.11, 0.2, 0.8), 999, LINE, 14))
		b.add_theme_stylebox_override("pressed", box(Color(0.2, 0.2, 0.35, 0.9), 999, LINE, 14))
		b.add_theme_color_override("font_color", DIM)
		b.add_theme_color_override("font_hover_color", INK)
	return b
