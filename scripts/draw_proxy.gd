extends Node2D
## 그리기를 다른 노드에 맡기는 레이어. 블렌드 모드를 레이어별로 나누려고 쓴다.

var painter: Callable


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
