extends Node
## 자동 플레이 테스트. 게임을 띄우고 큰 별을 계속 공격하며 곡 끝까지 진행한다.
## 실행: godot --headless --path . --fixed-fps 60 res://tests/autoplay.tscn
## 옵션(환경변수): AUTOPLAY_INVINCIBLE=0 이면 무적 끔, AUTOPLAY_SHOTS=dir 이면 그 폴더에 주기적으로 화면 캡처

var game: Node
var frame := 0
var shots_dir := ""
var max_bullets := 0
var stats := {}


func _ready() -> void:
	Tune.test_mode = OS.get_environment("AUTOPLAY_TEST") == "1"
	Tune.invincible = OS.get_environment("AUTOPLAY_INVINCIBLE") != "0"
	shots_dir = OS.get_environment("AUTOPLAY_SHOTS")
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	# 테스트는 음악 시계 대신 고정 프레임 시간으로 진행
	game.music.stream = null
	game.start()


func _process(_dt: float) -> void:
	frame += 1
	max_bullets = maxi(max_bullets, game.bullets.size())
	# 간단한 회피: 0.35초 뒤 위치를 예측해 가까운 탄에서 멀어지는 쪽으로 이동
	if frame % 4 == 0 and game.running:
		var push := Vector2.ZERO
		var me_pos: Vector2 = game.me.pos
		for b in game.bullets:
			var fut: Vector2 = b.pos + b.vel * 0.35
			var d: Vector2 = me_pos - fut
			var l := d.length()
			if l < 110.0 and l > 0.01:
				push += d / l * (110.0 - l)
		if push.length() > 30.0:
			game.command_move(me_pos + push.normalized() * 90.0)
			return
	# 큰 별 가장 가까운 것을 공격, 없으면 활동 구역 안을 돌아다님
	if frame % 30 == 0 and game.running:
		var best = null
		var bd := 1e9
		for b in game.bullets:
			if b.big and not b.dead:
				var d: float = b.pos.distance_to(game.player_pos)
				if d < bd:
					bd = d
					best = b
		if best and bd < 900.0:
			game.me.order = {"type": "attack", "target": best}
		elif frame % 120 == 0:
			var a: Rect2 = game.arena
			game.command_move(a.position + a.size * Vector2(randf(), randf()))
	if frame % 300 == 0:
		print("t=%.1f scene=%s bullets=%d forms=%d hp=%d hits=%d kills=%d" % [game.t, game.scene_name, game.bullets.size(), game.formations.size(), game.me.hp, game.hits_taken, game.kills])
	if shots_dir != "":
		game.overview_btn = (frame % 480) >= 240
		if frame % 240 == 239:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/t%03d_%s.png" % [shots_dir, int(game.t), "all" if game.overview_btn else "near"])
	var quit_at := int(OS.get_environment("AUTOPLAY_FRAMES")) if OS.get_environment("AUTOPLAY_FRAMES") != "" else 0
	if quit_at > 0 and frame >= quit_at:
		get_tree().quit()
	if not game.running and frame > 10:
		print("END t=%.1f win=%s hits=%d kills=%d max_bullets=%d" % [game.t, game.t >= 95.9, game.hits_taken, game.kills, max_bullets])
		get_tree().quit()
