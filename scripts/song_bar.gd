extends Control
## 곡 진행 바. 금색 점은 다음 패턴(장면)이 시작되는 지점.

var progress := 0.0
var ticks: Array = []


func _draw() -> void:
	var w := size.x
	var y := size.y * 0.5
	var h := 4.0
	var p := clampf(progress, 0, 1)
	UI.bar(self, Rect2(0, y - h * 0.5, w, h), Color(1, 1, 1, 0.1))
	if p > 0.0:
		UI.bar(self, Rect2(0, y - h * 0.5, maxf(w * p, h), h), Color(UI.MINT, 0.9))
		# 진행 막대의 앞쪽만 하얗게 빛나게
		var head := w * p
		draw_texture_rect(UI.TEX_GLOW, Rect2(head - 14, y - 14, 28, 28), false, Color(UI.MINT, 0.7))
		draw_circle(Vector2(head, y), 4.0, Color.WHITE)
	for t in ticks:
		var x: float = w * t
		var passed: bool = t <= p
		draw_circle(Vector2(x, y), 3.2, Color(0.02, 0.03, 0.08, 1))
		draw_circle(Vector2(x, y), 2.2, Color(UI.GOLD, 0.45) if passed else UI.GOLD)
