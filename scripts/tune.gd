extends Node
## 핵심 수치 저장소 (autoload "Tune"). 테스트 화면의 슬라이더가 여기 값을 바꾸고,
## 본 게임도 같은 값을 읽는다. 값은 user://tune.cfg 에 저장된다.

signal changed

const SAVE_PATH := "user://tune.cfg"
const BASE_VIEW := Vector2(1280, 800)

## 키: [기본값, 최소, 최대, 단계, 이름, 단위, 그룹]
const SPEC := {
	"map_mult": [3.0, 1.5, 6.0, 0.1, "맵 크기 (기본 화면의 몇 배, 한 변)", "배", 1],
	"view_zoom": [1.35, 0.6, 2.5, 0.05, "화면 확대 (클수록 크게, 좁게 보임)", "배", 1],
	"ship_scale": [1.5, 0.5, 3.0, 0.05, "기체 크기 (판정과 별개)", "배", 2],
	"hit_radius": [3.0, 1.0, 16.0, 0.5, "판정 반경", "px", 2],
	"node_spacing": [48.0, 16.0, 120.0, 2.0, "노드 간격", "px", 3],
	"ship_speed": [320.0, 80.0, 700.0, 10.0, "기체 속도 (별은 이 속도의 90%를 못 넘음)", "px/s", 4],
	"node_speed": [1.0, 0.3, 2.5, 0.05, "노드·탄 속도 배율", "배", 4],
	"attack_range": [230.0, 60.0, 700.0, 10.0, "사거리", "px", 5],
	"attack_cd": [0.6, 0.1, 2.0, 0.05, "공격 주기", "초", 5],
	"max_hp": [5.0, 1.0, 10.0, 1.0, "HP", "칸", 6],
	"margin": [90.0, 40.0, 400.0, 10.0, "바깥 여유 구역", "px", 6],
	"bg_tint": [1.0, 0.0, 1.0, 0.05, "배경 색 세기 (장면마다 바뀜)", "", 6],
}
const GROUPS := {
	1: "① 화면 범위 대 맵 크기",
	2: "② 기체와 판정 크기",
	3: "③ 노드 간격",
	4: "④ 기체 대 노드 속도",
	5: "⑤ 사거리와 공격 주기",
	6: "그 밖에",
}

var v: Dictionary = {}
var test_mode := false
var invincible := false


func _ready() -> void:
	for k in SPEC:
		v[k] = float(SPEC[k][0])
	_load()


func f(key: String) -> float:
	return float(v[key])


func set_value(key: String, value: float) -> void:
	v[key] = value
	_save()
	changed.emit()


func reset_defaults() -> void:
	for k in SPEC:
		v[k] = float(SPEC[k][0])
	_save()
	changed.emit()


func world_size() -> Vector2:
	return BASE_VIEW * f("map_mult")


func summary() -> String:
	var lines := PackedStringArray()
	for k in SPEC:
		lines.append("%s: %s %s" % [SPEC[k][4], _fmt(f(k)), SPEC[k][5]])
	return "\n".join(lines)


func _fmt(x: float) -> String:
	if is_equal_approx(x, roundf(x)):
		return str(int(roundf(x)))
	return "%.2f" % x


func _save() -> void:
	var c := ConfigFile.new()
	for k in v:
		c.set_value("tune", k, v[k])
	c.save(SAVE_PATH)


func _load() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	for k in SPEC:
		v[k] = clampf(float(c.get_value("tune", k, SPEC[k][0])), SPEC[k][1], SPEC[k][2])
