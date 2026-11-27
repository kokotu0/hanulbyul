extends Node
## 비디오 레벨 JSON 읽기 검사. 그림 등록, 이벤트 형식, 별 짝(같은 번호 유지)을 확인하고 숫자를 출력한다.
## 실행: godot --headless --path . res://tests/video_level_check.tscn
## 다른 파일 검사: VIDEO_LEVEL=res://levels/이름.json (또는 절대 경로)

const VideoLevelScript := preload("res://scripts/video_level.gd")


func _ready() -> void:
	var path := OS.get_environment("VIDEO_LEVEL")
	if path == "":
		path = "res://levels/sample.json"
	var lv: Dictionary = VideoLevelScript.load_level(path)
	var ok := not lv.is_empty()
	if ok:
		print("제목 %s, 길이 %.1f초, BPM %.0f" % [lv.TITLE, lv.LENGTH, lv.BPM])
		print("컷 %d개 %s, 키프레임 %d개, 키프레임당 별 %d개" % [lv.CUTS.size(), str(lv.CUTS), lv.KEYFRAMES, lv.STARS])
		print("구간 %d개, 이벤트 %d개" % [lv.SECTIONS.size(), lv.EVENTS.size()])
		ok = ok and lv.CUTS.size() <= 5
		var types := {}
		for e in lv.EVENTS:
			types[e.type] = int(types.get(e.type, 0)) + 1
			if e.type == "formation":
				ok = ok and e.path[0] is Vector2
				var counts: Array = []
				var mn := INF
				for key in e.keys:
					var pts: Array = Shapes.sample(key, 1.0)
					counts.append(pts.size())
					ok = ok and pts.size() == lv.STARS
					mn = minf(mn, _min_dist(pts))
				# 같은 번호 별의 키프레임 간 이동 (캔버스 단위, 240 = 화면 너비)
				var tot := 0.0
				var mx := 0.0
				var n := 0
				for i in range(1, e.keys.size()):
					var a: Array = Shapes.sample(e.keys[i - 1], 1.0)
					var b: Array = Shapes.sample(e.keys[i], 1.0)
					for j in a.size():
						var d: float = (a[j] as Vector2).distance_to(b[j])
						tot += d
						mx = maxf(mx, d)
						n += 1
				print("무리 %s: 그림 %d개, 별 수 %s~%s, 서로 다른 점 사이 최소 거리 %.2f, 이동 평균 %.2f / 최대 %.2f (캔버스 단위)" % [
					e.name, e.keys.size(), counts.min(), counts.max(), mn, tot / maxi(n, 1), mx])
				var c0: Color = Shapes.color_at(e.keys[0], Shapes.sample(e.keys[0], 1.0)[0])
				print("  첫 별 색 %s, 대표색 %s" % [c0.to_html(false), (Shapes.TINT[e.keys[0]] as Color).to_html(false)])
				# 노드 간격이 넓으면 솎아 냄 (짝 유지)
				print("  step 12 로 솎으면 %d개" % Shapes.sample(e.keys[0], 12.0).size())
			if e.type in ["wall", "emit"]:
				ok = ok and (e.get("gaps", 1) is int) and (e.get("arms", 1) is int)
		print("이벤트 종류: %s" % str(types))
		var bg_ok: bool = lv.SECTIONS[0].bg is Color
		ok = ok and bg_ok and lv.REGIONS[lv.START_REGION] is Rect2
	print("VIDEO_LEVEL_CHECK %s" % ("OK" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _min_dist(pts: Array) -> float:
	var mn := INF
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			var d: float = (pts[i] as Vector2).distance_to(pts[j])
			if d > 0.001:
				mn = minf(mn, d)
	return mn
