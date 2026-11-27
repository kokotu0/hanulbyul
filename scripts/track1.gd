class_name Track1
extends RefCounted
## 트랙 1 "별이 내리는 밤" 레벨 데이터. 120 BPM, 한 마디 2초, 96초.
## 좌표는 모두 "활동 구역"(기체가 다닐 수 있는 영역) 기준 비율: (0,0) 왼쪽 위, (1,1) 오른쪽 아래.
##
## 이벤트 종류
##   formation  별 노드(드론) 무리. keys 그림을 hold 초씩 돌아가며 만들고, path 를 따라 이동하며 회전한다.
##              exit: scatter(맵 끝까지 흩어짐) / collapse(중심으로 모여 사라짐) / sweep(한 방향으로 빠져나감)
##              fire: 큰 별이 기체를 노려 쏘는 주기(초). 0 이면 안 쏨.
##   emit       무리 중심(at = 무리 이름) 또는 고정 위치에서 탄을 뿌림. kind: spiral / rings / flower
##   wall       맵 바깥(활동 구역 밖 여유 구역)에서 한 줄로 들어오는 탄. 1.2초 전에 경고선이 보인다.
##   ring_in    맵 바깥 큰 원에서 안쪽으로 조여 오는 고리. 틈이 하나 있다.
##   snap       하이라이트. 화면이 번쩍이고 무리가 바깥으로 확 퍼지며 중심에서 탄 고리가 터진다.
##              박자가 크게 떨어지는 순간에 둔다. 그 직전 2~3초는 탄을 비워 숨 돌릴 틈을 준다.
##
## 장면 전환(그림이 바뀌는 순간)은 곡 하나에 다섯 번 정도로 아낀다. 전환 때 별들은 한 번 확 흩어졌다가
## 빠르게 새 자리로 몰려간다. 전환 사이에는 무리가 천천히 떠다니며 숨 쉬듯 움직인다.
##   전환 ① 16초 초승달 → 날개   ② 39초 톱니 등장   ③ 51초 톱니 → 폭발
##        ④ 72초 하트 등장       ⑤ 82초 하트 → 별
##
## 난이도 곡선: 도입(쉬움) → 집결 → 숨 고르기 → 결전(큰 별이 반격) → 다리 → 피날레(가장 촘촘) → 끝맺음

const TITLE := "별이 내리는 밤"
const LENGTH := 96.0
const BPM := 120.0
## bg: 장면마다 바뀌는 배경색 (테스트 화면의 "배경 색 세기"로 조절, 0이면 늘 검은색)
const SECTIONS := [
	{"t": 0.0, "name": "도입", "bg": Color("05060f")},
	{"t": 8.0, "name": "집결", "bg": Color("0a1030")},
	{"t": 32.0, "name": "숨 고르기", "bg": Color("05060f")},
	{"t": 40.0, "name": "결전", "bg": Color("1c0a2c")},
	{"t": 64.0, "name": "다리", "bg": Color("061c26")},
	{"t": 72.0, "name": "피날레", "bg": Color("260c1c")},
	{"t": 92.0, "name": "끝맺음", "bg": Color("05060f")},
]

const EVENTS := [
	# ── 도입 + 집결 (0~32): 한 무리가 맵을 천천히 돌며 초승달 → 날개로 변신
	{"t": 0.5, "type": "formation", "name": "A", "keys": ["crescent", "wing"], "hold": 15.5,
		"dur": 31.0, "size": 0.62, "rot": 0.07, "big": 0.03, "fire": 0.0, "exit": "scatter",
		"path": [Vector2(0.5, 0.5), Vector2(0.38, 0.42), Vector2(0.62, 0.4), Vector2(0.66, 0.6), Vector2(0.4, 0.62), Vector2(0.5, 0.5)]},
	{"t": 16.0, "type": "snap", "at": "A", "power": 520.0, "ring": 36, "waves": 1},
	{"t": 8.0, "type": "emit", "kind": "spiral", "at": "A", "dur": 4.0, "arms": 4, "rate": 0.16, "speed": 140.0},
	{"t": 10.8, "type": "wall", "side": "left", "gaps": 2, "speed": 170.0},
	{"t": 18.0, "type": "emit", "kind": "spiral", "at": "A", "dur": 4.0, "arms": 5, "rate": 0.14, "speed": 150.0},
	{"t": 20.8, "type": "wall", "side": "top", "gaps": 2, "speed": 170.0},
	{"t": 24.0, "type": "emit", "kind": "rings", "at": "A", "dur": 5.0, "rate": 1.0, "count": 64, "speed": 140.0},
	{"t": 26.8, "type": "wall", "side": "right", "gaps": 1, "speed": 180.0},

	# ── 숨 고르기 (32~40): 작은 별 무리가 대각선으로 맵을 가로지른다. 고리 하나.
	{"t": 32.0, "type": "formation", "name": "B", "keys": ["star5"], "hold": 99.0,
		"dur": 7.5, "size": 0.26, "rot": 0.6, "big": 0.06, "fire": 0.0, "exit": "sweep", "sweep": Vector2(1, 0.6),
		"path": [Vector2(0.08, 0.15), Vector2(0.5, 0.45), Vector2(0.92, 0.85)]},

	# ── 결전 (40~64): 크게 도는 톱니 → 폭발. 큰 별이 반격한다. 벽과 고리가 번갈아 온다.
	{"t": 39.0, "type": "formation", "name": "C", "keys": ["gear", "burst"], "hold": 12.0,
		"dur": 24.5, "size": 0.7, "rot": 0.22, "big": 0.04, "fire": 3.2, "exit": "collapse",
		"path": [Vector2(0.5, 0.5), Vector2(0.3, 0.5), Vector2(0.5, 0.35), Vector2(0.7, 0.5), Vector2(0.5, 0.65), Vector2(0.5, 0.5)]},
	{"t": 40.0, "type": "snap", "at": "C", "power": 650.0, "ring": 48, "waves": 2},
	{"t": 51.0, "type": "snap", "at": "C", "power": 700.0, "ring": 56, "waves": 2},
	{"t": 42.0, "type": "emit", "kind": "rings", "at": "C", "dur": 6.0, "rate": 0.9, "count": 80, "speed": 150.0},
	{"t": 47.6, "type": "wall", "side": "left", "gaps": 1, "speed": 190.0},
	{"t": 47.6, "type": "wall", "side": "right", "gaps": 1, "speed": 190.0},
	{"t": 53.0, "type": "ring_in", "at": Vector2(0.5, 0.5), "speed": 180.0},
	{"t": 56.0, "type": "emit", "kind": "flower", "at": "C", "dur": 6.0, "arms": 6, "rate": 0.12, "speed": 160.0},
	{"t": 59.6, "type": "wall", "side": "top", "gaps": 1, "speed": 200.0},
	{"t": 59.6, "type": "wall", "side": "bottom", "gaps": 1, "speed": 200.0},

	# ── 다리 (64~72): 작은 불꽃과 초승달 무리가 서로 엇갈려 돈다. 벽이 좌우로 번갈아.
	{"t": 63.5, "type": "formation", "name": "D1", "keys": ["flame"], "hold": 99.0,
		"dur": 8.0, "size": 0.3, "rot": 0.35, "big": 0.05, "fire": 2.6, "exit": "scatter",
		"path": [Vector2(0.2, 0.25), Vector2(0.45, 0.7), Vector2(0.75, 0.3), Vector2(0.8, 0.75)]},
	{"t": 63.5, "type": "formation", "name": "D2", "keys": ["crescent"], "hold": 99.0,
		"dur": 8.0, "size": 0.3, "rot": -0.35, "big": 0.05, "fire": 2.6, "exit": "scatter",
		"path": [Vector2(0.8, 0.75), Vector2(0.55, 0.3), Vector2(0.25, 0.7), Vector2(0.2, 0.25)]},
	{"t": 65.6, "type": "wall", "side": "left", "gaps": 2, "speed": 210.0},

	# ── 피날레 (72~92): 맵 거의 전체를 덮는 무리. 하트 → 별.
	{"t": 71.5, "type": "formation", "name": "E", "keys": ["heart", "star5"], "hold": 10.0,
		"dur": 20.0, "size": 0.84, "rot": 0.1, "big": 0.05, "fire": 2.2, "exit": "scatter",
		"path": [Vector2(0.5, 0.5), Vector2(0.45, 0.48), Vector2(0.55, 0.52), Vector2(0.5, 0.5)]},
	{"t": 72.0, "type": "snap", "at": "E", "power": 800.0, "ring": 64, "waves": 3},
	{"t": 81.5, "type": "snap", "at": "E", "power": 800.0, "ring": 72, "waves": 2},
	{"t": 74.0, "type": "emit", "kind": "spiral", "at": "E", "dur": 5.0, "arms": 6, "rate": 0.11, "speed": 170.0},
	{"t": 77.6, "type": "ring_in", "at": Vector2(0.35, 0.5), "speed": 190.0},
	{"t": 88.0, "type": "ring_in", "at": Vector2(0.65, 0.5), "speed": 190.0},
	{"t": 83.6, "type": "wall", "side": "left", "gaps": 1, "speed": 210.0},
	{"t": 83.6, "type": "wall", "side": "top", "gaps": 1, "speed": 210.0},
	{"t": 85.6, "type": "wall", "side": "right", "gaps": 1, "speed": 210.0},
	{"t": 85.6, "type": "wall", "side": "bottom", "gaps": 1, "speed": 210.0},
	{"t": 86.0, "type": "emit", "kind": "rings", "at": "E", "dur": 5.0, "rate": 0.8, "count": 90, "speed": 160.0},

	# ── 끝맺음 (92~96): 흩어진 별이 맵 끝으로 빠져나가는 걸 보며 마무리
]
