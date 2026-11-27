class_name PlayerState
extends RefCounted
## 기체 한 대의 상태. 지금은 혼자 하지만, 협동 멀티를 붙일 때 기체마다 이 객체를 하나씩 둔다.
## 네트워크로 주고받을 값: pos, angle, hp, downed, revive, order 의 목표, 스킬 쿨다운.
## 쓰러진(downed) 기체 위에 살아 있는 동료가 머무르면 revive 가 차올라 다시 일어난다.

var id := 0
var name := "나"
var color := Color.WHITE
var is_local := true

var pos := Vector2.ZERO
var angle := -PI / 2
var cd := 0.0
var side := 1.0
var recoil := 0.0
var order: Dictionary = {}

var hp := 5
var max_hp := 5
var invuln := 0.0
var downed := false
var revive := 0.0

## 스킬 이름 → 남은 쿨다운(초)
var skill_cd := {}
var dash_t := 0.0
var dash_dir := Vector2.ZERO

var hits := 0
var kills := 0


func alive() -> bool:
	return not downed
