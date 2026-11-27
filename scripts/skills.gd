class_name Skills
extends RefCounted
## 스킬 정의. 효과는 game.gd 의 _use_skill() 에 있다.
## 새 스킬은 여기 항목 하나와 _use_skill() 의 분기 하나를 더하면 된다.

const LIST := {
	"dash": {"name": "대시", "key": KEY_SPACE, "key_label": "Space", "cd": 3.5,
		"desc": "마우스 쪽으로 짧게 돌진. 돌진 중엔 맞지 않음"},
	"nova": {"name": "섬광", "key": KEY_Q, "key_label": "Q", "cd": 14.0,
		"desc": "주변의 작은 탄을 지우고 별 노드를 밀어냄"},
}

const DASH_TIME := 0.18
const DASH_SPEED := 1500.0
const NOVA_RADIUS := 260.0
