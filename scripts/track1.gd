class_name Track1
extends RefCounted
## 트랙 1 "별이 내리는 밤" 레벨 데이터. 120 BPM, 한 마디 2초, 96초.
##
## 맵은 가로로 긴 하늘이고, 기체가 다닐 수 있는 "구역(region)"이 장면마다 바뀐다.
## 구역 좌표는 맵 전체 기준 비율. 이벤트의 위치(path, at)는 "그 이벤트가 시작될 때의 구역" 기준 비율:
## (0,0) 왼쪽 위, (1,1) 오른쪽 아래. 구역 밖으로 나간 좌표(예: 1.4)는 구역 바깥 하늘을 뜻한다.
##
## 이벤트 종류
##   formation  별 노드(드론) 무리. keys 그림을 hold 초씩 돌아가며 만들고, path 를 따라 이동하며 회전한다.
##              exit: scatter(맵 끝까지 흩어짐) / collapse(중심으로 모여 사라짐) / sweep(한 방향으로 빠져나감)
##              fire: 큰 별이 기체를 노려 쏘는 주기(초). 0 이면 안 쏨.
##   emit       무리 중심(at = 무리 이름) 또는 고정 위치에서 탄을 뿌림. kind: spiral / rings / flower
##   wall       맵 바깥(구역 밖 여유 구역)에서 한 줄로 들어오는 탄. 1.2초 전에 경고선이 보인다.
##   ring_in    구역 바깥 큰 원에서 안쪽으로 조여 오는 고리. 틈이 하나 있다.
##   snap       하이라이트. 화면이 번쩍이고 무리가 바깥으로 확 퍼지며 중심에서 탄 고리가 터진다.
##   cinematic  영화 같은 휴식 장면. 조작이 잠기고 카메라가 멀리 빠져 옆으로 이동하며,
##              다닐 수 있는 구역이 to 구역으로 바뀐다. 기체는 새 구역으로 자동으로 날아간다(무적).
##   box        다닐 수 있는 상자를 기술에 맞춰 바꾼다. rect = 지금 구역 기준 비율 Rect2(x, y, 너비, 높이).
##              살짝 지나쳤다 돌아오는 탄력으로 0.9초 동안 변한다. 상자 밖에 있던 기체는 안으로 밀려 들어온다.
##   clear      날아다니던 탄을 지우고 무리를 떠나보낸다 (곡 끝맺음)
##   windup     괴수(at 무리)가 기술을 준비하는 모습. dur 동안 빛이 모이고 예고선이 보이며,
##              끝나는 순간 그 기술(attack: beams / claws / rings)이 실제로 날아온다.
##
## 흐름: 서쪽 하늘에서 집결(0~32) → [휴식 장면] 동쪽으로 이동, 괴수가 다가오며 기술 준비 →
##       결전(40~64) → [휴식 장면] 하늘 전체로 넓어지고 하트 무리가 기술 준비 → 피날레(72~92) → 끝맺음
## 장면 전환은 다섯 번: 16초 초승달→날개, 32초 괴수 등장, 51초 괴수 발톱, 64초 하트 등장, 81.5초 하트→별

const TITLE := "별이 내리는 밤"
const LENGTH := 96.0
const BPM := 120.0
## 맵 가로 비율 (기본 맵 크기 대비). 구역을 옆으로 옮길 자리를 만든다.
const WORLD_WIDE := 1.6

const REGIONS := {
	"west": Rect2(0.0, 0.0, 0.62, 1.0),
	"east": Rect2(0.38, 0.0, 0.62, 1.0),
	"full": Rect2(0.0, 0.0, 1.0, 1.0),
}
const START_REGION := "west"

## bg: 장면마다 바뀌는 배경색 (테스트 화면의 "배경 색 세기"로 조절, 0이면 늘 검은색)
const SECTIONS := [
	{"t": 0.0, "name": "도입", "bg": Color("05060f")},
	{"t": 8.0, "name": "집결", "bg": Color("0a1030")},
	{"t": 32.0, "name": "괴수의 그림자", "bg": Color("0c0614")},
	{"t": 40.0, "name": "결전", "bg": Color("1c0a2c")},
	{"t": 64.0, "name": "폭풍 전야", "bg": Color("061c26")},
	{"t": 72.0, "name": "피날레", "bg": Color("260c1c")},
	{"t": 92.0, "name": "끝맺음", "bg": Color("05060f")},
]

const EVENTS := [
	# ── 도입 + 집결 (0~32, 서쪽): 한 무리가 천천히 돌며 초승달 → 날개로 변신
	{"t": 0.5, "type": "formation", "name": "A", "keys": ["crescent", "wing"], "hold": 15.5,
		"dur": 31.0, "size": 0.62, "rot": 0.07, "big": 0.03, "fire": 0.0, "exit": "scatter",
		"path": [Vector2(0.5, 0.5), Vector2(0.38, 0.42), Vector2(0.62, 0.4), Vector2(0.66, 0.6), Vector2(0.4, 0.62), Vector2(0.5, 0.5)]},
	{"t": 8.0, "type": "emit", "kind": "spiral", "at": "A", "dur": 4.0, "arms": 4, "rate": 0.16, "speed": 140.0},
	{"t": 10.8, "type": "wall", "side": "left", "gaps": 2, "speed": 170.0},
	{"t": 16.0, "type": "snap", "at": "A", "power": 520.0, "ring": 60, "waves": 1},
	{"t": 18.0, "type": "emit", "kind": "spiral", "at": "A", "dur": 4.0, "arms": 5, "rate": 0.14, "speed": 150.0},
	{"t": 20.8, "type": "wall", "side": "top", "gaps": 2, "speed": 170.0},
	{"t": 24.0, "type": "emit", "kind": "rings", "at": "A", "dur": 5.0, "rate": 1.0, "count": 64, "speed": 140.0},
	{"t": 26.8, "type": "wall", "side": "right", "gaps": 1, "speed": 180.0},

	# ── 휴식 장면 1 (32~40): 카메라가 빠지며 동쪽으로 이동. 동쪽 하늘 바깥에서 별 괴수가 천천히 다가와
	#    양손에 빛을 모은다(빔 예고선). 40초 박자에 맞춰 빔이 쏟아지며 결전 시작.
	{"t": 32.0, "type": "cinematic", "dur": 7.6, "to": "east", "caption": "저 멀리서 무언가 다가온다"},
	{"t": 32.5, "type": "formation", "name": "M", "keys": ["beast"], "hold": 99.0,
		"dur": 31.0, "size": 0.5, "rot": 0.0, "big": 0.05, "fire": 3.4, "exit": "collapse",
		"path": [Vector2(1.2, 0.42), Vector2(0.95, 0.42), Vector2(0.72, 0.42), Vector2(0.6, 0.4), Vector2(0.5, 0.36), Vector2(0.36, 0.42), Vector2(0.55, 0.38), Vector2(0.62, 0.42)]},
	{"t": 36.4, "type": "windup", "at": "M", "dur": 3.6, "attack": "beams", "count": 5, "spread": 0.9},
	{"t": 40.0, "type": "snap", "at": "M", "power": 420.0, "ring": 64, "waves": 1},

	# ── 결전 (40~64, 동쪽): 괴수와 싸운다. 큰 별을 부수며 피하기. 51초에 발톱을 휘두른다.
	{"t": 43.0, "type": "emit", "kind": "rings", "at": "M", "dur": 4.5, "rate": 1.0, "count": 70, "speed": 150.0},
	{"t": 46.6, "type": "wall", "side": "right", "gaps": 1, "speed": 190.0},
	{"t": 48.2, "type": "windup", "at": "M", "dur": 2.8, "attack": "claws", "count": 3},
	{"t": 51.0, "type": "snap", "at": "M", "power": 600.0, "ring": 80, "waves": 2},
	{"t": 54.0, "type": "ring_in", "at": Vector2(0.5, 0.5), "speed": 180.0},
	{"t": 56.0, "type": "emit", "kind": "flower", "at": "M", "dur": 5.5, "arms": 6, "rate": 0.12, "speed": 160.0},
	{"t": 59.6, "type": "wall", "side": "top", "gaps": 1, "speed": 200.0},
	{"t": 59.6, "type": "wall", "side": "bottom", "gaps": 1, "speed": 200.0},

	# ── 휴식 장면 2 (64~71.6): 구역이 하늘 전체로 넓어진다. 하트 무리가 피어나며 원형 파동을 모은다.
	{"t": 64.0, "type": "cinematic", "dur": 7.6, "to": "full", "caption": "하늘 전체가 노래한다"},
	{"t": 64.5, "type": "formation", "name": "E", "keys": ["heart", "star5"], "hold": 17.0,
		"dur": 27.0, "size": 0.5, "rot": 0.1, "big": 0.05, "fire": 2.4, "exit": "scatter",
		"path": [Vector2(0.5, 0.5), Vector2(0.45, 0.48), Vector2(0.55, 0.52), Vector2(0.5, 0.5)]},
	{"t": 68.6, "type": "windup", "at": "E", "dur": 3.4, "attack": "rings", "count": 3},
	{"t": 72.0, "type": "snap", "at": "E", "power": 700.0, "ring": 96, "waves": 2},

	# ── 피날레 (72~92, 하늘 전체)
	{"t": 75.0, "type": "emit", "kind": "spiral", "at": "E", "dur": 5.0, "arms": 6, "rate": 0.11, "speed": 170.0},
	{"t": 77.6, "type": "ring_in", "at": Vector2(0.3, 0.5), "speed": 190.0},
	{"t": 81.5, "type": "snap", "at": "E", "power": 800.0, "ring": 100, "waves": 2},
	{"t": 83.6, "type": "wall", "side": "left", "gaps": 1, "speed": 210.0},
	{"t": 83.6, "type": "wall", "side": "right", "gaps": 1, "speed": 210.0},
	{"t": 85.6, "type": "wall", "side": "top", "gaps": 2, "speed": 210.0},
	{"t": 86.0, "type": "emit", "kind": "rings", "at": "E", "dur": 4.5, "rate": 0.8, "count": 90, "speed": 160.0},
	{"t": 92.0, "type": "clear"},

	# ── 상자 변화 (기술마다 다닐 수 있는 영역이 바뀜)
	{"t": 7.4, "type": "box", "rect": Rect2(0.22, 0.18, 0.56, 0.64)},
	{"t": 12.6, "type": "box", "rect": Rect2(0, 0, 1, 1)},
	{"t": 23.4, "type": "box", "rect": Rect2(0.06, 0.34, 0.88, 0.36)},
	{"t": 29.4, "type": "box", "rect": Rect2(0, 0, 1, 1)},
	{"t": 42.4, "type": "box", "rect": Rect2(0.12, 0.12, 0.5, 0.76)},
	{"t": 47.6, "type": "box", "rect": Rect2(0.2, 0.2, 0.6, 0.6)},
	{"t": 50.4, "type": "box", "rect": Rect2(0.04, 0.3, 0.92, 0.42)},
	{"t": 53.4, "type": "box", "rect": Rect2(0, 0, 1, 1)},
	{"t": 55.4, "type": "box", "rect": Rect2(0.28, 0.22, 0.44, 0.56)},
	{"t": 61.6, "type": "box", "rect": Rect2(0, 0, 1, 1)},
	{"t": 74.4, "type": "box", "rect": Rect2(0.28, 0.16, 0.44, 0.68)},
	{"t": 80.4, "type": "box", "rect": Rect2(0, 0, 1, 1)},
	{"t": 85.4, "type": "box", "rect": Rect2(0.38, 0.04, 0.24, 0.92)},
	{"t": 90.6, "type": "box", "rect": Rect2(0, 0, 1, 1)},

	# ── 끝맺음 (92~96): 흩어진 별이 맵 끝으로 빠져나가는 걸 보며 마무리
]
