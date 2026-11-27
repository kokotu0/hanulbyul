extends Control
## 곡 진행 바. 금색 눈금은 다음 패턴이 시작되는 지점.

var progress := 0.0
var ticks: Array = []


func _draw() -> void:
	var w := size.x
	var y := size.y * 0.5
	draw_rect(Rect2(0, y - 2, w, 4), Color(1, 1, 1, 0.14))
	draw_rect(Rect2(0, y - 2, w * clampf(progress, 0, 1), 4), UI.INK)
	for t in ticks:
		draw_rect(Rect2(w * t - 1, y - 5, 2, 10), Color(1, 0.83, 0.42, 0.7))
