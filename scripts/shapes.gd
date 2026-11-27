class_name Shapes
extends RefCounted
## 그림(상징) 정의. 240x135 크기의 로컬 캔버스 안에서 "안쪽인지" 판정하는 함수로 정의하고,
## 노드 간격만큼 격자로 훑어 노드 좌표를 만든다. 결과는 캔버스 중심(120, 67) 기준 좌표.

const W := 240.0
const H := 135.0
const CENTER := Vector2(120, 67)

## 별빛 팔레트. 그림 노드는 이 색들 중 2~3개를 그라데이션으로 칠한다.
## (탄은 따로: 벽 = 금색, 고리 = 장미, 나선 = 얼음, 반격 = 장미)
const PALETTE := {
	"gold": Color("ffd36b"),
	"amber": Color("ffae5c"),
	"peach": Color("ffc9a3"),
	"rose": Color("ff8fb8"),
	"lavender": Color("b9a6ff"),
	"ice": Color("9fe8ff"),
	"mint": Color("9ff5d0"),
	"white": Color("fff8ec"),
}

## 그림마다 [색 목록, 칠하는 방식]. radial = 중심→바깥, vertical = 위→아래, angle = 둘레를 따라
const SCHEME := {
	"crescent": [["white", "gold", "amber"], "radial"],
	"flame": [["white", "gold", "amber", "rose"], "vertical_up"],
	"wing": [["white", "ice", "lavender"], "radial"],
	"gear": [["lavender", "ice", "lavender"], "angle"],
	"burst": [["white", "peach", "rose"], "radial"],
	"heart": [["peach", "rose", "lavender"], "vertical"],
	"star5": [["white", "gold", "peach"], "radial"],
	"beast": [["white", "rose", "lavender"], "vertical"],
}

## 그림의 대표색 (미니맵, 폭발 등). register_points 로 등록한 그림의 색도 여기에 추가되므로 static var.
static var TINT := {
	"crescent": Color("ffd36b"),
	"flame": Color("ffae5c"),
	"wing": Color("9fe8ff"),
	"gear": Color("b9a6ff"),
	"burst": Color("ffc9a3"),
	"heart": Color("ff8fb8"),
	"star5": Color("ffd36b"),
	"beast": Color("ff8fb8"),
}

static var _cache := {}
static var _polys := {}


## 노드 좌표 목록. 그림의 바운딩 박스가 240x135 캔버스를 꽉 채우도록 늘린 뒤,
## 늘어난 좌표 기준으로 step 간격이 되게 훑는다.
static func sample(key: String, step: float) -> Array:
	step = maxf(step, 1.0)
	var ck := "%s@%.3f" % [key, step]
	if _cache.has(ck):
		return _cache[ck]
	if _points.has(key):
		var thinned := _thin_points(key, step)
		_cache[ck] = thinned
		return thinned
	var bb := _bbox(key)
	var k := minf(W / bb.size.x, H / bb.size.y)
	var src_step := step / k
	var pts: Array = []
	var row := 0
	var y := bb.position.y
	while y <= bb.end.y:
		var x := bb.position.x + ((src_step * 0.5) if row % 2 == 1 else 0.0)
		while x <= bb.end.x:
			var p := Vector2(x, y)
			if inside(key, p):
				pts.append((p - bb.get_center()) * k)
			x += src_step
		y += src_step
		row += 1
	# 중심 기준 각도로 정렬하면 그림이 바뀔 때 노드가 가까운 자리로 이동한다.
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.angle() < b.angle())
	_cache[ck] = pts
	return pts


static var _bboxes := {}


static func _bbox(key: String) -> Rect2:
	if _bboxes.has(key):
		return _bboxes[key]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var y := 0.0
	while y < H:
		var x := 0.0
		while x < W:
			if inside(key, Vector2(x, y)):
				lo = lo.min(Vector2(x, y))
				hi = hi.max(Vector2(x, y))
			x += 1.0
		y += 1.0
	var r := Rect2(lo, (hi - lo).max(Vector2(4, 4)))
	_bboxes[key] = r
	return r


## 그림 안의 한 점(sample 결과 좌표)의 색. 팔레트를 그라데이션으로 섞는다.
static func color_at(key: String, p: Vector2) -> Color:
	if _points.has(key):
		var cd: Dictionary = _points[key].cols
		if cd.has(p):
			return cd[p]
		return TINT.get(key, PALETTE.white)
	var sch: Array = SCHEME.get(key, [["white", "gold"], "radial"])
	var cols: Array = sch[0]
	var u := 0.0
	match sch[1]:
		"radial":
			u = clampf(p.length() / (H * 0.62), 0.0, 1.0)
		"vertical":
			u = clampf((p.y + H * 0.5) / H, 0.0, 1.0)
		"vertical_up":
			u = clampf(1.0 - (p.y + H * 0.5) / H, 0.0, 1.0)
		"angle":
			u = 0.5 + 0.5 * sin(p.angle() * 5.0)
	var x := u * (cols.size() - 1)
	var i := mini(int(x), cols.size() - 2)
	return (PALETTE[cols[i]] as Color).lerp(PALETTE[cols[i + 1]], x - i)


## 이미지로 그림 등록. 밝거나 불투명한 픽셀이 노드 자리가 된다.
## 나중에 뮤직비디오 프레임을 넣으면 이 함수로 장면마다 그림을 만들면 된다.
static var _images := {}


static func register_image(key: String, img: Image, threshold := 0.5) -> void:
	var im := img.duplicate() as Image
	im.resize(int(W), int(H), Image.INTERPOLATE_BILINEAR)
	_images[key] = [im, threshold]
	_bboxes.erase(key)
	for ck in _cache.keys():
		if String(ck).begins_with(key + "@"):
			_cache.erase(ck)


## 점 목록으로 그림 등록 (뮤직비디오 → 레벨 변환기 결과용, scripts/video_level.gd 가 부른다).
## pts: 캔버스 중심(0,0) 기준 좌표 (sample 결과와 같은 좌표계, 대략 ±120 x ±67).
## cols: 점마다 색 (비우면 tint). 점 순서를 그대로 지키므로(각도 정렬 안 함) 같은 개수의 그림끼리는
## i 번째 별이 i 번째 점으로 간다 → 변환기가 맞춰 둔 별 짝이 게임에서도 유지된다.
## spacing: 점 사이 최소 간격(캔버스 단위). 게임의 노드 간격(step)이 이보다 크면 같은 간격으로 솎아 낸다.
static var _points := {}


static func register_points(key: String, pts: PackedVector2Array, cols: Array = [], tint := Color.WHITE, spacing := 0.0) -> void:
	var arr: Array = []
	var cd := {}
	for i in pts.size():
		arr.append(pts[i])
		if i < cols.size() and not cd.has(pts[i]):
			cd[pts[i]] = cols[i]
	_points[key] = {"pts": arr, "cols": cd, "spacing": spacing}
	TINT[key] = tint
	_bboxes.erase(key)
	for ck in _cache.keys():
		if String(ck).begins_with(key + "@"):
			_cache.erase(ck)


## step 이 등록 간격보다 크면 번호 간격(stride)으로 솎는다. 개수가 같은 그림끼리는 같은 번호가 남아 짝이 유지된다.
static func _thin_points(key: String, step: float) -> Array:
	var d: Dictionary = _points[key]
	var arr: Array = d.pts
	var sp: float = d.spacing
	if sp <= 0.0 or step <= sp * 1.05:
		return arr
	var stride := maxi(1, ceili(pow(step / sp, 2.0)))
	var out: Array = []
	for i in range(0, arr.size(), stride):
		out.append(arr[i])
	return out


static func inside(key: String, p: Vector2) -> bool:
	if _images.has(key):
		var im: Image = _images[key][0]
		var px := im.get_pixel(clampi(int(p.x), 0, int(W) - 1), clampi(int(p.y), 0, int(H) - 1))
		return px.a * px.get_luminance() >= _images[key][1]
	match key:
		"crescent":
			return p.distance_to(Vector2(115, 65)) < 56.0 and p.distance_to(Vector2(142, 48)) > 50.0
		"flame":
			return Geometry2D.is_point_in_polygon(p, _poly("flame"))
		"burst":
			return Geometry2D.is_point_in_polygon(p, _poly("burst"))
		"star5":
			return Geometry2D.is_point_in_polygon(p, _poly("star5"))
		"wing":
			if p.distance_to(Vector2(120, 78)) < 14.0:
				return true
			for i in 5:
				var c := Vector2(120.0 - 30.0 - i * 10.0, 70.0 - i * 9.0)
				var rot := -0.45 - i * 0.08
				if _in_ellipse(p, c, 46.0 - i * 5.0, 8.0, rot):
					return true
				var c2 := Vector2(240.0 - c.x, c.y)
				if _in_ellipse(p, c2, 46.0 - i * 5.0, 8.0, -rot):
					return true
			return false
		"gear":
			var d := p - Vector2(120, 67)
			var r := d.length()
			if r <= 46.0 and r >= 20.0:
				return true
			for k in 10:
				var a := k * PI / 5.0
				var dir := Vector2.from_angle(a)
				var along := d.dot(dir)
				var perp := absf(d.cross(dir))
				if along >= 42.0 and along <= 62.0 and perp <= 8.0:
					return true
			return false
		"beast":
			# 별 괴수: 몸통, 머리, 뿔, 팔과 발톱, 다리. 눈은 비워 둔다.
			if p.distance_to(Vector2(108, 34)) < 5.0 or p.distance_to(Vector2(132, 34)) < 5.0:
				return false
			if _in_ellipse(p, Vector2(120, 80), 44.0, 30.0, 0.0):
				return true
			if p.distance_to(Vector2(120, 38)) < 21.0:
				return true
			if Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(102, 26), Vector2(86, 0), Vector2(110, 20)])):
				return true
			if Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(138, 26), Vector2(154, 0), Vector2(130, 20)])):
				return true
			for side in [-1.0, 1.0]:
				var sh := Vector2(120 + side * 38.0, 68)
				var el := Vector2(120 + side * 78.0, 50)
				var hand := Vector2(120 + side * 100.0, 30)
				if _in_capsule(p, sh, el, 9.0) or _in_capsule(p, el, hand, 7.0):
					return true
				for k in 3:
					var tip := hand + Vector2(side * (6.0 + k * 6.0), -14.0 + k * 9.0)
					if _in_capsule(p, hand, tip + Vector2(side * 6.0, -4.0), 3.0):
						return true
				if _in_capsule(p, Vector2(120 + side * 22.0, 100), Vector2(120 + side * 34.0, 132), 8.0):
					return true
			return false
		"heart":
			var u := (p.x - 120.0) / 52.0
			var w := -(p.y - 62.0) / 52.0
			var q := u * u + w * w - 1.0
			return q * q * q - u * u * w * w * w <= 0.0
	return false


static func _in_capsule(p: Vector2, a: Vector2, b: Vector2, r: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= r


static func _in_ellipse(p: Vector2, c: Vector2, rx: float, ry: float, rot: float) -> bool:
	var d := (p - c).rotated(-rot)
	return (d.x * d.x) / (rx * rx) + (d.y * d.y) / (ry * ry) <= 1.0


static func _poly(key: String) -> PackedVector2Array:
	if _polys.has(key):
		return _polys[key]
	var pts := PackedVector2Array()
	match key:
		"flame":
			var start := Vector2(120, 125)
			var segs := [
				[Vector2(60, 120), Vector2(62, 60), Vector2(100, 40)],
				[Vector2(98, 62), Vector2(110, 70), Vector2(116, 72)],
				[Vector2(112, 40), Vector2(126, 18), Vector2(140, 8)],
				[Vector2(138, 40), Vector2(180, 60), Vector2(170, 95)],
				[Vector2(166, 115), Vector2(150, 125), Vector2(120, 125)],
			]
			var cur := start
			for s in segs:
				for i in range(1, 17):
					var t := i / 16.0
					pts.append(_bez(cur, s[0], s[1], s[2], t))
				cur = s[2]
		"burst":
			for i in 24:
				var a := i * PI / 12.0
				var rr := 18.0 if i % 2 == 1 else 64.0
				pts.append(Vector2(120 + cos(a) * rr * 1.3, 67 + sin(a) * rr))
		"star5":
			for i in 10:
				var a := -PI / 2 + i * PI / 5.0
				var rr := 26.0 if i % 2 == 1 else 64.0
				pts.append(Vector2(120 + cos(a) * rr * 1.25, 72 + sin(a) * rr))
	_polys[key] = pts
	return pts


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t
