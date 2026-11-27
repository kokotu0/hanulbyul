class_name VideoLevel
extends RefCounted
## 뮤직비디오 → 레벨 변환기(tools/video_to_level.py)가 만든 levels/<이름>.json 을 읽는다.
##
## load_level() 은 키프레임마다 별 좌표를 Shapes.register_points 로 그림 등록하고(키: "vid_<이름>_<번호>"),
## Track1 과 같은 모양의 사전을 돌려준다:
##   TITLE, LENGTH, BPM, WORLD_WIDE, REGIONS(Rect2), START_REGION, SECTIONS(bg = Color), EVENTS(path = Vector2 ...),
##   그리고 덤으로 CUTS(컷 시각), KEYFRAMES(키프레임 수), STARS(키프레임당 별 수), MUSIC(음악 경로, 없으면 "").
## 게임에서 쓰려면 game.gd 가 Track1.* 대신 이 사전 값을 읽게 하면 된다.

## JSON 에서 숫자는 전부 실수로 오므로, 정수여야 하는 필드는 되돌린다.
const INT_FIELDS := ["gaps", "arms", "count", "ring", "waves"]


static func load_level(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("비디오 레벨을 열 수 없음: %s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary) or data.get("format", "") != "hanulbyul-video-level":
		push_error("비디오 레벨 형식이 아님: %s" % path)
		return {}
	var meta: Dictionary = data.meta
	register_shapes(data)

	var regions := {}
	for k in data.regions:
		var r: Array = data.regions[k]
		regions[k] = Rect2(r[0], r[1], r[2], r[3])
	var sections: Array = []
	for s in data.sections:
		sections.append({"t": float(s.t), "name": String(s.name), "bg": Color(String(s.bg))})
	var events: Array = []
	for e in data.events:
		events.append(_convert_event(e))
	return {
		"TITLE": String(data.title),
		"LENGTH": float(data.length),
		"BPM": float(data.bpm),
		"WORLD_WIDE": float(data.world_wide),
		"REGIONS": regions,
		"START_REGION": String(data.start_region),
		"SECTIONS": sections,
		"EVENTS": events,
		"CUTS": data.cuts,
		"KEYFRAMES": data.keyframes.size(),
		"STARS": int(meta.stars),
		"MUSIC": String(meta.get("music", "")),
	}


## 키프레임 별 좌표(프레임 기준 0..1)를 Shapes 캔버스(240x135, 중심 기준)에 맞춰 등록.
## 영상 비율을 지키며 캔버스 안에 꽉 차게 놓는다 (16:9 영상이면 캔버스와 딱 맞음).
static func register_shapes(data: Dictionary) -> void:
	var aspect := float(data.meta.aspect)
	var k := minf(Shapes.W / aspect, Shapes.H)
	var half := Vector2(aspect * k, k) * 0.5
	# 격자 이웃 간격 = 화면 너비 / cols → 캔버스 단위
	var spacing := aspect * k / float(data.meta.cols)
	for kf in data.keyframes:
		var pts := PackedVector2Array()
		var cols: Array = []
		var count := {}
		for i in kf.points.size():
			var p: Array = kf.points[i]
			pts.append(Vector2(p[0] * aspect * k, p[1] * k) - half)
			var cname := String(kf.colors[i])
			cols.append(Shapes.PALETTE.get(cname, Shapes.PALETTE.white))
			count[cname] = int(count.get(cname, 0)) + 1
		# 대표색: 가장 많이 쓰인 팔레트 색
		var best := "white"
		for c in count:
			if count[c] > int(count.get(best, 0)):
				best = c
		Shapes.register_points(String(kf.key), pts, cols, Shapes.PALETTE[best], spacing)


static func _convert_event(e: Dictionary) -> Dictionary:
	var out := e.duplicate(true)
	if out.has("path"):
		var path: Array = []
		for p in out.path:
			path.append(Vector2(p[0], p[1]))
		out.path = path
	if out.has("at") and out.at is Array:
		out.at = Vector2(out.at[0], out.at[1])
	if out.has("rect"):
		var r: Array = out.rect
		out.rect = Rect2(r[0], r[1], r[2], r[3])
	if out.has("sweep"):
		out.sweep = Vector2(out.sweep[0], out.sweep[1])
	if out.has("keys"):
		var keys: Array = []
		for key in out.keys:
			keys.append(String(key))
		out.keys = keys
	for fld in INT_FIELDS:
		if out.has(fld):
			out[fld] = int(out[fld])
	return out
