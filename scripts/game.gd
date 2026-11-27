extends Node2D
## 하떨별 MVP 본 게임. 트랙 1개(Track1).
## 별 노드는 드론처럼 움직인다: 각자 목표 자리를 향해 가속·감속하며 날아가고,
## 무리 전체는 맵을 돌아다니며 회전하고 다른 그림으로 변신한 뒤 맵 끝까지 흩어진다.
## 기체는 활동 구역 안에서만 움직이고, 바깥에서 들어오는 탄은 여유 구역 바깥에서 경고 후 출발한다.
## Tune.test_mode 이면 오른쪽에 수치 슬라이더 패널이 붙는다.

const DrawProxy := preload("res://scripts/draw_proxy.gd")
const Minimap := preload("res://scripts/minimap.gd")
const SongBar := preload("res://scripts/song_bar.gd")
const TunePanel := preload("res://scripts/tune_panel.gd")

const MUSIC_PATH := "res://music/track1.ogg"
const SFX := ["shot", "hit", "boom", "hurt", "clear", "click"]
const COL_MOVE := Color("8fffc2")
const COL_ATTACK := Color("ff6b8a")
const BULLET_CORE := 3.0
const BIG_CORE := 8.0
## 날아오는 탄의 판정 반지름. 보이는 몸통 크기와 같다.
const SHOT_CORE := 4.0
const BIG_HP := 2
const CASCADE_RADIUS := 170.0
const WARN := 1.2
const INVULN := 1.6
const DRONE_VMAX := 430.0
const DRONE_ACCEL := 1500.0
const MAX_BULLETS := 6000
## 날아오는 탄 색. 그림 별 팔레트(금, 살구, 장미, 라벤더, 얼음, 민트, 흰색)와 겹치지 않게 고른다.
const C_SHOT := Color("ff8a5c")
const C_WALL := Color("c9f26b")
const C_SKILL := Color("ff5c93")
const REVIVE_RADIUS := 60.0
const SHIP_ACCEL := 2600.0
const SHIP_DECEL := 3200.0
const SHIP_TURN := 14.0
const STAR_CAP_RATIO := 0.9
const REVIVE_TIME := 2.5


class Formation:
	var name := ""
	var t0 := 0.0
	var dur := 10.0
	var keys: Array = []
	var hold := 5.0
	var n := 1
	var sc := 1.0
	var rot := 0.0
	var wps: Array = []
	var exit := "scatter"
	var sweep := Vector2.RIGHT
	var fire := 0.0
	var center := Vector2.ZERO
	var angle := 0.0
	var scale_k := 1.0
	var alive := true


class Bullet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var col := Color.WHITE
	var big := false
	var hp := BIG_HP
	var life := 1e9
	var dead := false
	var form: Formation = null
	var pts: Array = []
	var dl := 0.0
	var ph := 0.0
	var flash := 0.0
	var die_at := -1.0
	var fire_t := 0.0
	var core := BULLET_CORE
	var cols: Array = []
	var phase := 0
	var rush := 0.0
	var safe_until := -1.0


class Emitter:
	var ev: Dictionary
	var form: Formation = null
	var center := Vector2.ZERO
	var t := 0.0
	var acc := 0.0
	var a0 := 0.0


class Wall:
	var side := "left"
	var spawn_t := 0.0
	var gaps: Array = []
	var speed := 180.0


class RingIn:
	var center := Vector2.ZERO
	var spawn_t := 0.0
	var gap := 0.0
	var speed := 180.0
	var r0 := 2000.0


class Missile:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var target: Bullet = null
	var owner: PlayerState = null
	var life := 1.6
	var age := 0.0
	var trail: Array = []


class Part:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.5
	var m := 1.0
	var col := Color.WHITE


class Mark:
	var pos := Vector2.ZERO
	var t := 0.0
	var col := Color.WHITE


var world := Vector2(3840, 2400)
var arena := Rect2()
var t := 0.0
var running := false
var paused := false
var ev_index := 0
## 시간순으로 정렬한 트랙 이벤트
var events: Array = []
var scene_name := ""
var formations: Array = []
var bullets: Array = []
var emitters: Array = []
var walls: Array = []
var rings: Array = []
var missiles: Array = []
var parts: Array = []
var marks: Array = []

var kills := 0
## 모든 기체. 지금은 나 하나지만 협동 멀티에서는 여기에 동료가 더해진다.
var players: Array = []
var me: PlayerState
var player_pos: Vector2:
	get:
		return me.pos if me else Vector2.ZERO
var hits_taken := 0
var tab_held := false
var overview_btn := false
var zoom_t := 0.0
var hitstop := 0.0
var shake := 0.0
var flash := 0.0
var bg_now := Color("05060f")
var gates: Array = []
var pop_text := ""
var pop_t := 0.0
## 하이라이트 때 카메라를 잠깐 뒤로 빼서 그림 전체가 보이게 (0~1)
var cam_pull := 0.0
var pre_gated := {}
## 영화 같은 휴식 장면 (비어 있으면 평소 플레이)
var cin: Dictionary = {}
var cin_blend := 0.0
var cin_rect := Rect2()
var cin_caption := ""
var region_name := ""
## 지금 구역 전체 (무리 좌표의 기준). arena 는 그 안에서 기술마다 줄고 늘고 미끄러지는 "상자".
var region := Rect2()
var box_anim: Dictionary = {}
## 괴수가 기술을 준비하는 중인 목록
var windups: Array = []
var cam_follow := Vector2.ZERO
var bg_stars: Array = []

var cam: Camera2D
var fx: Node2D
var top: Node2D
var glow_tex: Texture2D
var bg_add: Node2D
var nebula: Array = []
var hp_bar: Control
var skill_chips := {}
var scene_pill: Control
var music: AudioStreamPlayer
var sfx := {}

var ui_root: Control
var song_bar: Control
var time_label: Label
var scene_label: Label
var hp_label: Label
var kill_label: Label
var minimap: Control
var view_btn: Button
var ov_start: Control
var ov_pause: Control
var ov_over: Control
var over_title: Label
var over_text: Label
var tune_panel: PanelContainer
var flash_rect: ColorRect
var skill_label: Control
var cell_label: Label
var letterbox: Array = []
var caption_label: Label


func _ready() -> void:
	events = Track1.EVENTS.duplicate()
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	glow_tex = UI.TEX_GLOW
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	# 블룸 (2D, gl_compatibility 지원). UI 층은 제외된다.
	var env := WorldEnvironment.new()
	env.environment = UI.glow_env()
	add_child(env)

	# 배경 성운·밝은 별 (더하기 섞기)
	bg_add = DrawProxy.new()
	var bmat := CanvasItemMaterial.new()
	bmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	bg_add.material = bmat
	bg_add.painter = _draw_bg_add
	add_child(bg_add)

	fx = DrawProxy.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	fx.painter = _draw_fx
	add_child(fx)
	top = DrawProxy.new()
	top.painter = _draw_top
	add_child(top)

	music = AudioStreamPlayer.new()
	music.volume_db = -3.0
	if ResourceLoader.exists(MUSIC_PATH):
		music.stream = load(MUSIC_PATH)
	add_child(music)
	for k in SFX:
		var path := "res://sfx/%s.wav" % k
		var p := AudioStreamPlayer.new()
		p.max_polyphony = 6
		p.volume_db = -8.0
		if ResourceLoader.exists(path):
			p.stream = load(path)
		add_child(p)
		sfx[k] = p

	_build_ui()
	reset()
	if Tune.test_mode:
		start()


# ---------------------------------------------------------------- 상태

func reset() -> void:
	world = Tune.world_size() * Vector2(Track1.WORLD_WIDE, 1.0)
	region_name = Track1.START_REGION
	region = _region_rect(region_name)
	arena = region
	box_anim = {}
	cin = {}
	cin_blend = 0.0
	windups.clear()
	cam_pull = 0.0
	pre_gated = {}
	pop_t = 0.0
	t = 0.0
	ev_index = 0
	scene_name = Track1.SECTIONS[0].name
	formations.clear()
	bullets.clear()
	emitters.clear()
	walls.clear()
	rings.clear()
	missiles.clear()
	parts.clear()
	marks.clear()
	gates.clear()
	me = PlayerState.new()
	me.pos = Vector2(arena.get_center().x, arena.position.y + arena.size.y * 0.78)
	me.max_hp = int(Tune.f("max_hp"))
	me.hp = me.max_hp
	for k in Skills.LIST:
		me.skill_cd[k] = 0.0
	players = [me]
	hitstop = 0.0
	shake = 0.0
	kills = 0
	hits_taken = 0
	cam_follow = me.pos
	bg_stars.clear()
	var n := int(900 * (world.x * world.y) / (3840.0 * 2400.0))
	for i in n:
		# [위치, 크기, 겹(0 먼 곳 ~ 2 가까운 곳), 위상]
		bg_stars.append([Vector2(randf() * world.x, randf() * world.y), randf() * 0.8 + 0.4, i % 3, randf() * TAU])
	nebula.clear()
	var nrng := RandomNumberGenerator.new()
	nrng.seed = 11
	var hues := [Color("3a4cff"), Color("a03cff"), Color("2fc8ff"), Color("ff4f9a"), Color("5a3cff"), Color("2fffc0")]
	var nn := int(18 * (world.x * world.y) / (3840.0 * 2400.0)) + 6
	for i in nn:
		nebula.append([Vector2(nrng.randf() * world.x, nrng.randf() * world.y), nrng.randf_range(900.0, 1700.0), hues[i % hues.size()], nrng.randf() * TAU, i % 2])
	_layout_minimap()
	var ticks: Array = []
	for s in Track1.SECTIONS:
		if s.t > 0.0:
			ticks.append(s.t / Track1.LENGTH)
	song_bar.ticks = ticks


func start() -> void:
	seek(0.0)


## time 초 지점부터 시작. 그 시각에 진행 중이던 무리와 이미터는 바로 만들어 둔다.
func seek(time: float) -> void:
	reset()
	running = true
	paused = false
	ov_start.visible = false
	ov_over.visible = false
	ov_pause.visible = false
	t = time
	for s in Track1.SECTIONS:
		if s.t <= time:
			scene_name = s.name
	var evs: Array = events
	while ev_index < evs.size() and evs[ev_index].t < time:
		var ev: Dictionary = evs[ev_index]
		if ev.type == "cinematic":
			region_name = ev.to
			region = _region_rect(ev.to)
			arena = region
			for pl in players:
				pl.pos = _spawn_point(arena)
			cam_follow = me.pos
		elif ev.type == "formation" and ev.t + ev.dur > time:
			_spawn_formation(ev, true)
		elif ev.type == "emit" and ev.t + ev.dur > time:
			var e := _spawn_emitter(ev)
			e.t = time - ev.t
		ev_index += 1
	if music.stream:
		music.play(time)


func end_game(win: bool) -> void:
	running = false
	music.stop()
	over_title.text = "클리어" if win else "추락"
	var title := Track1.TITLE
	if win:
		_play("clear")
		# 등급: 맞은 횟수와 격추 수를 함께 본다
		var score := kills * 2 - hits_taken * 5
		var grade := "S" if score >= 40 else ("A" if score >= 24 else ("B" if score >= 10 else "C"))
		over_text.text = "%s · 끝까지 버텼어요\n등급 %s · 맞은 횟수 %d · 큰 별 격추 %d" % [title, grade, hits_taken, kills]
	else:
		over_text.text = "%s · %d%% 지점 (%s)\n큰 별 격추 %d" % [title, int(t / Track1.LENGTH * 100.0), _fmt_time(t), kills]
	ov_over.visible = true


func toggle_pause() -> void:
	if not running:
		return
	paused = not paused
	ov_pause.visible = paused
	music.stream_paused = paused


func _play(k: String) -> void:
	var p: AudioStreamPlayer = sfx.get(k)
	if p and p.stream:
		p.play()


# ---------------------------------------------------------------- 입력

func _input(ev: InputEvent) -> void:
	if ev is InputEventKey:
		if ev.keycode == KEY_TAB:
			tab_held = ev.pressed
			get_viewport().set_input_as_handled()
			return
		if ev.pressed and not ev.echo:
			match ev.keycode:
				KEY_ESCAPE:
					toggle_pause()
				KEY_SPACE:
					use_skill(me, "dash", get_global_mouse_position())
				KEY_Q:
					use_skill(me, "nova", me.pos)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		command(get_global_mouse_position())


## 조작: WASD(또는 방향키)로 이동, 마우스로 큰 별을 클릭하면 그 별을 노려 자동 사격.
## 키를 놓고 있으면 노린 별을 사거리까지 따라간다. 빈 곳을 클릭하면 조준 해제.
func command(wpos: Vector2) -> void:
	if not running or paused or cin_active():
		return
	var target: Bullet = pick(wpos, 40.0 / cam.zoom.x)
	if target:
		me.order = {"type": "attack", "target": target}
		_mark(target.pos, COL_ATTACK)
	else:
		me.order = {}


## 지정 위치로 이동 명령 (자동 플레이 테스트, 나중에 터치 조작용)
func command_move(wpos: Vector2) -> void:
	if not running or paused:
		return
	me.order = {"type": "move", "pos": wpos.clamp(arena.position, arena.end)}


func pick(wpos: Vector2, r: float) -> Bullet:
	var best: Bullet = null
	var bd := r
	for b in bullets:
		if b.big and not b.dead:
			var q: float = b.pos.distance_to(wpos)
			if q < bd:
				bd = q
				best = b
	return best


func _mark(p: Vector2, col: Color) -> void:
	var m := Mark.new()
	m.pos = p
	m.col = col
	marks.append(m)


# ---------------------------------------------------------------- 진행

func _process(delta: float) -> void:
	var dt := minf(delta, 0.033)
	if running and not paused:
		_update(dt)
	_update_camera(dt)
	queue_redraw()
	fx.queue_redraw()
	top.queue_redraw()
	bg_add.queue_redraw()
	minimap.queue_redraw()
	song_bar.progress = t / Track1.LENGTH
	song_bar.queue_redraw()
	time_label.text = "%s / %s" % [_fmt_time(t), _fmt_time(Track1.LENGTH)]
	scene_label.text = scene_name
	hp_bar.hp = maxi(me.hp, 0)
	hp_bar.max_hp = me.max_hp
	hp_bar.modulate = Color(1, 1, 1, 0.45 if me.invuln > 0.0 and fmod(me.invuln, 0.2) < 0.1 else 1.0)
	kill_label.text = "큰 별 격추  %d" % kills
	cell_label.text = "전체 맵  ·  %s 칸" % Minimap.cell_name(world, me.pos)
	flash_rect.color.a = flash * 0.32
	var bh := 64.0 * cin_blend
	letterbox[0].offset_bottom = bh
	letterbox[1].offset_top = -bh
	caption_label.text = cin_caption
	caption_label.modulate.a = clampf(cin_blend * 1.4 - 0.3, 0.0, 1.0)
	skill_label.modulate.a = 1.0 - cin_blend
	for key in skill_chips:
		skill_chips[key].set_cd(me.skill_cd.get(key, 0.0))
	if tune_panel:
		tune_panel.set_info("노드 %d개 · FPS %d · 맞은 횟수 %d" % [bullets.size(), Engine.get_frames_per_second(), hits_taken])


func _update(dt: float) -> void:
	if hitstop > 0.0:
		hitstop -= dt
		return
	# 음악이 있으면 음악 재생 위치에 맞춘다 (박자 싱크).
	if music.playing:
		var mt := music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		# 음악 시계는 덩어리로 갱신되므로 바로 맞추지 않고 조금씩 따라가 끊김을 없앤다
		t += dt
		if absf(mt - t) < 0.25:
			t += (mt - t) * minf(1.0, dt * 2.0)
	else:
		t += dt
	shake = maxf(0.0, shake - dt * 2.0)
	flash = maxf(0.0, flash - dt * 3.0)
	var bg_target := Color("05060f")
	for sec in Track1.SECTIONS:
		if sec.t <= t:
			bg_target = sec.bg
	bg_target = Color("05060f").lerp(bg_target, Tune.f("bg_tint"))
	bg_now = bg_now.lerp(bg_target, minf(1.0, dt * 1.5))
	_run_events()
	_update_cinematic()
	_update_windups(dt)
	if t >= Track1.LENGTH:
		end_game(true)
		return
	_update_formations(dt)
	_update_emitters(dt)
	_update_walls()
	_update_player(dt)
	_update_missiles(dt)
	if _update_bullets(dt):
		return
	for q in parts:
		q.pos += q.vel * dt
		q.vel *= 0.93
		q.m -= dt / q.life
	parts = parts.filter(func(q: Part) -> bool: return q.m > 0.0)
	pop_t = maxf(0.0, pop_t - dt)
	for g in gates:
		g.t += dt
	gates = gates.filter(func(g: Dictionary) -> bool: return g.t < 2.2)
	for m in marks:
		m.t += dt
	marks = marks.filter(func(m: Mark) -> bool: return m.t < 0.5)


func _run_events() -> void:
	for s in Track1.SECTIONS:
		if s.t <= t:
			scene_name = s.name
	var evs: Array = events
	# 무리 탄생 1초 전: 그 자리에 빛 고리를 미리 띄운다
	var j := ev_index
	while j < evs.size() and evs[j].t <= t + 1.0:
		var fe: Dictionary = evs[j]
		var key := "%s@%.2f" % [fe.get("name", ""), fe.t]
		if fe.type == "formation" and not pre_gated.has(key):
			pre_gated[key] = true
			var rr := _region_at(fe.t)
			var p0: Vector2 = rr.position + rr.size * (fe.path[0] as Vector2)
			gates.append({"pos": p0, "t": 0.0, "col": Shapes.TINT[fe.keys[0]]})
			cam_pull = maxf(cam_pull, 0.8)
		j += 1
	while ev_index < evs.size() and evs[ev_index].t <= t:
		var ev: Dictionary = evs[ev_index]
		ev_index += 1
		match ev.type:
			"formation":
				_spawn_formation(ev, false)
			"emit":
				_spawn_emitter(ev)
			"wall":
				var w := Wall.new()
				w.side = ev.side
				w.spawn_t = ev.t + WARN
				w.speed = ev.speed
				var edge_len := arena.size.y if w.side in ["left", "right"] else arena.size.x
				for g in int(ev.gaps):
					# 틈은 활동 구역 안쪽 15~85% 사이, 서로 겹치지 않게
					var lo: float = 0.15 + 0.7 * float(g) / ev.gaps
					var hi: float = 0.15 + 0.7 * float(g + 1) / ev.gaps
					w.gaps.append(randf_range(lo, hi) * edge_len)
				walls.append(w)
			"snap":
				_snap(ev)
			"cinematic":
				cin = {"t0": ev.t, "dur": ev.dur, "from": arena, "to": _region_rect(ev.to)}
				cin_caption = ev.caption
				region_name = ev.to
				region = cin.to
				box_anim = {}
				# 휴식 시작: 날아다니던 탄은 반짝이며 사라지고 대기 중인 벽도 취소
				for b in bullets:
					if b.form == null:
						b.die_at = t + randf() * 0.8
				walls.clear()
				rings.clear()
				for pl in players:
					pl.order = {}
			"clear":
				# 곡 끝맺음: 날아다니던 탄은 반짝이며 사라지고 무리는 흩어져 떠난다
				for b in bullets:
					if b.form == null:
						b.die_at = t + randf() * 1.2
				for f in formations:
					if f.alive:
						f.dur = t - f.t0
				emitters.clear()
				walls.clear()
				rings.clear()
			"box":
				# 기술에 맞춰 다닐 수 있는 상자가 줄고 늘고 미끄러진다
				if cin.is_empty():
					var fr: Rect2 = ev.rect
					var to := Rect2(region.position + region.size * fr.position, region.size * fr.size)
					box_anim = {"t0": ev.t, "dur": ev.get("dur", 0.9), "from": arena, "to": to}
			"windup":
				var f := _find_form(ev.at)
				if f:
					cam_pull = 1.0
					windups.append({"f": f, "t0": ev.t, "ev": ev, "aim": me.pos, "lock": false, "center": f.center})
			"ring_in":
				var r := RingIn.new()
				r.center = _arena_point(ev.at)
				r.spawn_t = ev.t + WARN
				r.speed = ev.speed
				r.gap = randf() * TAU
				var far := 0.0
				var rr := cur_region_rect().grow(Tune.f("margin"))
				for c in [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)]:
					far = maxf(far, r.center.distance_to(c))
				r.r0 = far + 40.0
				rings.append(r)


## 하이라이트: 화면이 번쩍이고, 무리가 바깥으로 확 퍼지며, 중심에서 탄 고리가 터져 나간다.
func _snap(ev: Dictionary) -> void:
	cam_pull = 1.0
	var f := _find_form(ev.at)
	var c: Vector2 = f.center if f else arena.get_center()
	var ns := Tune.f("node_speed")
	flash = 1.0
	shake = 0.7
	_play("boom")
	if f:
		for b in bullets:
			if b.form == f:
				b.vel += (b.pos - c).normalized() * float(ev.power) * randf_range(0.7, 1.3) * ns
				b.rush = 1.0
	var cnt: int = int(ev.get("ring", 0) * Tune.f("density"))
	for k in ev.get("waves", 1):
		var a0 := randf() * TAU
		for i in cnt:
			var an := a0 + float(i) / cnt * TAU
			_shot(c, Vector2.from_angle(an) * (170.0 + 50.0 * k) * ns, C_SHOT)


func _arena_point(f: Vector2) -> Vector2:
	var r := cur_region_rect()
	return r.position + r.size * f


## 지금 기준이 되는 구역. 휴식 장면 중에는 옮겨 갈 구역.
## time 시각에 기준이 될 구역 (그때까지의 마지막 휴식 장면의 목적지)
func _region_at(time: float) -> Rect2:
	var name: String = Track1.START_REGION
	for ev in events:
		if ev.t > time:
			break
		if ev.type == "cinematic":
			name = ev.to
	return _region_rect(name)


func cur_region_rect() -> Rect2:
	return region


func _region_rect(name: String) -> Rect2:
	var r: Rect2 = Track1.REGIONS[name]
	var rect := Rect2(world * r.position, world * r.size)
	var mg := minf(Tune.f("margin"), minf(rect.size.x, rect.size.y) * 0.3)
	return rect.grow(-mg)


func _spawn_point(r: Rect2) -> Vector2:
	return Vector2(r.get_center().x, r.position.y + r.size.y * 0.78)


func cin_active() -> bool:
	return not cin.is_empty()


## 살짝 지나쳤다 돌아오는 탄력 있는 움직임
static func _ease_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c := 1.4
	var y := x - 1.0
	return 1.0 + (c + 1.0) * y * y * y + c * y * y


static func _lerp_rect(a: Rect2, b: Rect2, w: float) -> Rect2:
	return Rect2(a.position.lerp(b.position, w), a.size.lerp(b.size, w))


## 휴식 장면 진행: 다닐 수 있는 구역이 새 구역으로 옮겨 가고, 카메라는 두 구역을 함께 담은 채 옆으로 이동한다.
func _update_cinematic() -> void:
	if not box_anim.is_empty():
		var bu: float = (t - box_anim.t0) / box_anim.dur
		if bu >= 1.0:
			arena = box_anim.to
			box_anim = {}
		else:
			arena = _lerp_rect(box_anim.from, box_anim.to, _ease_back(bu))
	if cin.is_empty():
		return
	var u: float = (t - cin.t0) / cin.dur
	var from: Rect2 = cin.from
	var to: Rect2 = cin.to
	var w := _sm(u)
	if u >= 1.0:
		arena = to
		cin = {}
		return
	arena = _lerp_rect(from, to, w)
	var size := from.size.max(to.size) * 1.12
	var c := from.get_center().lerp(to.get_center(), w)
	cin_rect = Rect2(c - size * 0.5, size)


## 괴수의 기술 준비: 빛이 모이고 예고선이 보이다가, 끝나는 순간 그 기술이 날아온다.
func _update_windups(dt: float) -> void:
	for wu in windups:
		var f: Formation = wu.f
		var ev: Dictionary = wu.ev
		if f.alive:
			wu.center = f.center
		var u: float = (t - wu.t0) / ev.dur
		if u < 0.7:
			wu.aim = me.pos
		elif not wu.lock:
			wu.lock = true
			_play("click")
		# 빛이 중심으로 모여드는 입자
		if parts.size() < 1200:
			for i in 3:
				var a := randf() * TAU
				var q := Part.new()
				var r := randf_range(260.0, 520.0)
				q.pos = wu.center + Vector2.from_angle(a) * r
				q.vel = -Vector2.from_angle(a) * r * 1.6
				q.life = 0.6
				q.col = Shapes.TINT[f.keys[0]]
				parts.append(q)
		if u >= 1.0:
			_fire_attack(wu)
			wu.done = true
	windups = windups.filter(func(wu: Dictionary) -> bool: return not wu.get("done", false))


## 예고선이 가리키는 방향들
func _attack_dirs(wu: Dictionary) -> Array:
	var ev: Dictionary = wu.ev
	var base: float = (wu.aim - wu.center).angle()
	var dirs: Array = []
	var n: int = ev.get("count", 3)
	match ev.attack:
		"beams":
			var spread: float = ev.get("spread", 0.8)
			for i in n:
				dirs.append(base + (float(i) / maxf(n - 1, 1) - 0.5) * spread * 2.0)
		"claws":
			for i in n:
				dirs.append(base + (i - (n - 1) * 0.5) * 0.35)
		_:
			for i in n:
				dirs.append(base + PI + i * 0.9)
	return dirs


func _fire_attack(wu: Dictionary) -> void:
	var e := Emitter.new()
	e.form = wu.f
	e.center = wu.center
	var ev: Dictionary = wu.ev
	e.ev = {"kind": ev.attack, "dur": 1.6, "dirs": _attack_dirs(wu), "speed": 260.0, "count": ev.get("count", 3)}
	emitters.append(e)
	flash = maxf(flash, 0.6)
	shake = maxf(shake, 0.5)
	_play("boom")


func _find_form(name: String) -> Formation:
	for f in formations:
		if f.name == name and f.alive:
			return f
	return null


func _spawn_formation(ev: Dictionary, settled: bool) -> void:
	var f := Formation.new()
	f.name = ev.name
	f.t0 = ev.t
	f.dur = ev.dur
	f.keys = ev.keys
	f.hold = ev.hold
	f.rot = ev.rot
	f.exit = ev.exit
	f.fire = ev.fire
	f.sweep = ev.get("sweep", Vector2.RIGHT).normalized()
	f.sc = cur_region_rect().size.x * ev.size / Shapes.W
	for p in ev.path:
		f.wps.append(_arena_point(p))
	var step := Tune.f("node_spacing") / f.sc
	var sets: Array = []
	var n_max := 0
	for key in f.keys:
		var pts := Shapes.sample(key, step)
		if pts.is_empty():
			pts = [Vector2.ZERO]
		sets.append(pts)
		n_max = maxi(n_max, pts.size())
	f.n = sets.size()
	_form_pose(f, t - f.t0)
	formations.append(f)
	if not settled:
		# 새 무리가 태어나는 자리: 빛 고리가 퍼지고 그 중심에서 별들이 쏟아져 나온다
		_burst(f.center, Color.WHITE, 30, 360.0)
		cam_pull = maxf(cam_pull, 0.8)
		flash = maxf(flash, 0.35)
	var room := MAX_BULLETS - bullets.size()
	n_max = mini(n_max, maxi(room, 0))
	for i in n_max:
		var b := Bullet.new()
		b.form = f
		b.big = randf() < float(ev.big)
		b.core = BIG_CORE if b.big else BULLET_CORE
		b.fire_t = randf_range(1.0, 1.0 + f.fire)
		for si in sets.size():
			var s: Array = sets[si]
			var lp: Vector2 = s[mini(s.size() - 1, int(float(i) * s.size() / n_max))]
			b.pts.append(lp)
			b.cols.append(Shapes.color_at(f.keys[si], lp))
		b.dl = float(i) / n_max * 0.5
		b.ph = randf() * TAU
		b.col = b.cols[0]
		b.pos = _drone_target(b, t - f.t0) if settled else f.center
		if not settled:
			b.safe_until = t + 1.4
		bullets.append(b)


func _spawn_emitter(ev: Dictionary) -> Emitter:
	var e := Emitter.new()
	e.ev = ev
	e.a0 = randf() * TAU
	var at = ev.at
	if at is String:
		e.form = _find_form(at)
		e.center = e.form.center if e.form else arena.get_center()
	else:
		e.center = _arena_point(at)
	emitters.append(e)
	return e


## 무리의 중심, 각도, 크기를 시간에 따라 계산. 경로는 waypoint 를 부드럽게 잇는다.
func _form_pose(f: Formation, tt: float) -> void:
	var u := clampf(tt / f.dur, 0.0, 1.0) * (f.wps.size() - 1)
	var i := mini(int(u), f.wps.size() - 2)
	var w := u - i
	var a: Vector2 = f.wps[i]
	var b: Vector2 = f.wps[i + 1]
	var pre: Vector2 = f.wps[maxi(i - 1, 0)]
	var post: Vector2 = f.wps[mini(i + 2, f.wps.size() - 1)]
	f.center = a.cubic_interpolate(b, pre, post, w)
	f.angle = f.rot * tt
	f.scale_k = lerpf(0.12, 1.0, _sm(tt / 2.4)) * (1.0 + 0.05 * sin(tt * 1.3))


func _drone_target(b: Bullet, tt: float) -> Vector2:
	var f := b.form
	var phase := clampi(int((tt - b.dl) / f.hold), 0, f.n - 1)
	var local: Vector2 = b.pts[phase]
	var bob := Vector2(sin(t * 1.9 + b.ph), cos(t * 1.6 + b.ph * 1.3)) * 7.0
	return f.center + (local * f.sc * f.scale_k).rotated(f.angle) + bob


func _update_formations(dt: float) -> void:
	for f in formations:
		var tt: float = t - f.t0
		if tt <= f.dur:
			_form_pose(f, tt)
		else:
			f.alive = false
	formations = formations.filter(func(f: Formation) -> bool: return t - f.t0 < f.dur + 12.0)
	var ns := Tune.f("node_speed")
	var cap := star_cap()
	var vmax := minf(DRONE_VMAX * ns, cap)
	var accel := DRONE_ACCEL * ns
	for b in bullets:
		if b.form == null or b.dead or b.die_at >= 0.0:
			continue
		var f: Formation = b.form
		var tt: float = t - f.t0
		var desired: Vector2
		if f.alive:
			var tgt := _drone_target(b, tt)
			var phase := clampi(int((tt - b.dl) / f.hold), 0, f.n - 1)
			if phase != b.phase:
				# 장면 전환: 한 번 확 흩어졌다가 빠르게 새 자리로 몰려간다
				b.phase = phase
				b.rush = 1.0
				b.vel += (b.pos - f.center).normalized() * randf_range(250.0, 520.0) * ns
			b.rush = maxf(0.0, b.rush - dt * 0.6)
			b.col = b.col.lerp(b.cols[phase], minf(1.0, dt * 2.5))
			var vm: float = minf(vmax * (1.0 + 1.6 * b.rush), cap)
			desired = (tgt - b.pos) * (3.2 + 2.0 * b.rush)
			if desired.length() > vm:
				desired = desired.normalized() * vm
			# 큰 별의 반격
			if b.big and f.fire > 0.0 and tt > 3.0:
				b.fire_t -= dt
				if b.fire_t <= 0.0:
					b.fire_t = f.fire * randf_range(0.8, 1.2)
					if b.pos.distance_to(me.pos) < 1100.0:
						var a0: float = (me.pos - b.pos).angle()
						for k in [-1, 0, 1]:
							_shot(b.pos, Vector2.from_angle(a0 + k * 0.22) * 210.0 * ns, C_SKILL)
		else:
			match f.exit:
				"collapse":
					desired = (f.center - b.pos) * 2.5
					if b.pos.distance_to(f.center) < 40.0:
						b.die_at = t + randf() * 0.2
				"sweep":
					desired = f.sweep * vmax * 1.1
				_:
					var d: Vector2 = b.pos - f.center
					desired = (d.normalized() if d.length() > 1.0 else Vector2.from_angle(b.ph)) * vmax * 1.15
			if not Rect2(Vector2(-120, -120), world + Vector2(240, 240)).has_point(b.pos):
				b.dead = true
		b.vel = b.vel.move_toward(desired, accel * (1.0 + b.rush) * dt).limit_length(cap)
		b.pos += b.vel * dt


## 별과 탄의 최고 속도. 어떤 별도 기체가 도망가는 속도보다 빠를 수 없다.
func star_cap() -> float:
	return Tune.f("ship_speed") * STAR_CAP_RATIO


func _shot(p: Vector2, v: Vector2, col: Color, life := 1e9) -> void:
	if bullets.size() >= MAX_BULLETS:
		return
	var b := Bullet.new()
	b.pos = p
	b.vel = v.limit_length(star_cap())
	b.col = col
	b.core = SHOT_CORE
	b.life = life * v.length() / maxf(b.vel.length(), 1.0) if life < 1e8 else life
	bullets.append(b)


func _update_emitters(dt: float) -> void:
	var ns := Tune.f("node_speed")
	for e in emitters:
		var ev: Dictionary = e.ev
		e.t += dt
		e.acc += dt
		if e.form and e.form.alive:
			e.center = e.form.center
		var sp: float = ev.speed * ns
		var dn := Tune.f("density")
		match ev.kind:
			"spiral", "flower":
				var srate: float = ev.rate / maxf(dn, 0.1)
				while e.acc > srate:
					e.acc -= srate
					var arms: int = ev.arms
					for a in arms:
						var spin: float = e.t * (1.1 if ev.kind == "spiral" else 0.0) + (sin(e.t * 2.0) * 0.8 if ev.kind == "flower" else 0.0)
						var an: float = e.a0 + spin + a * TAU / arms
						_shot(e.center, Vector2.from_angle(an) * sp, C_SHOT)
			"beams":
				# 예고선을 따라 굵은 빛줄기
				while e.acc > 0.09:
					e.acc -= 0.09
					for d in ev.dirs:
						var dir := Vector2.from_angle(d)
						for side in [-1, 1]:
							_shot(e.center + dir * 60.0 + dir.orthogonal() * side * 14.0, dir * ev.speed * ns, C_SKILL)
				if e.t > 1.2:
					e.ev.kind = "done"
			"claws":
				# 발톱 세 번: 부채꼴 탄막이 바깥으로 휘몰아친다
				var hits: int = e.ev.get("hit", 0)
				if hits < ev.dirs.size() and e.t >= hits * 0.35:
					var d: float = ev.dirs[hits]
					var nclaw := maxi(6, int(26 * dn))
					for i in nclaw:
						var an := d + (float(i) / (nclaw - 1) - 0.5) * 2.1
						_shot(e.center + Vector2.from_angle(an) * 90.0, Vector2.from_angle(an) * ev.speed * ns * (0.85 + 0.15 * sin(i * 0.7)), C_SKILL)
					e.ev.hit = hits + 1
			"rings_burst":
				pass
			"rings":
				if not ev.has("rate"):
					# 기술로 쓰는 원형 파동: 틈이 있는 고리 여러 겹 (틈 방향은 예고선)
					var w: int = e.ev.get("hit", 0)
					if w < ev.dirs.size() and e.t >= w * 0.45:
						var gap: float = ev.dirs[w]
						var nr := maxi(12, int(96 * dn))
						for i in nr:
							var an := float(i) / nr * TAU
							if absf(wrapf(an - gap, -PI, PI)) < 0.3:
								continue
							_shot(e.center, Vector2.from_angle(an) * 170.0 * ns, C_SHOT)
						e.ev.hit = w + 1
					continue
				while e.acc > ev.rate:
					e.acc -= ev.rate
					var gap := randf() * TAU
					var cnt: int = maxi(12, int(ev.count * dn))
					for i in cnt:
						var an := float(i) / cnt * TAU
						if absf(wrapf(an - gap, -PI, PI)) < 0.28:
							continue
						_shot(e.center, Vector2.from_angle(an) * sp, C_SHOT)
	emitters = emitters.filter(func(e: Emitter) -> bool: return e.t < e.ev.dur)


## 경고 시간이 지난 벽과 고리를 실제 탄으로 만든다. 출발점은 맵 가장자리(활동 구역 바깥).
func _update_walls() -> void:
	var ns := Tune.f("node_speed")
	var gap_w := 300.0
	var spacing := 22.0
	for w in walls:
		if t < w.spawn_t:
			continue
		var horiz: bool = w.side in ["left", "right"]
		# 출발선: 구역 테두리에서 여유 구역만큼 바깥
		var out := Tune.f("margin")
		var lo := (arena.position.y if horiz else arena.position.x) - out
		var span := (arena.size.y if horiz else arena.size.x) + out * 2.0
		var s := 0.0
		while s < span:
			var along := s - out
			var in_gap := false
			for g in w.gaps:
				if absf(along - g) < gap_w * 0.5:
					in_gap = true
			if not in_gap:
				var p: Vector2
				var v: Vector2
				var q := lo + s
				match w.side:
					"left":
						p = Vector2(arena.position.x - out, q); v = Vector2(1, 0)
					"right":
						p = Vector2(arena.end.x + out, q); v = Vector2(-1, 0)
					"top":
						p = Vector2(q, arena.position.y - out); v = Vector2(0, 1)
					_:
						p = Vector2(q, arena.end.y + out); v = Vector2(0, -1)
				_shot(p, v * w.speed * ns, C_WALL)
			s += spacing
		w.speed = -1.0
	walls = walls.filter(func(w: Wall) -> bool: return w.speed > 0.0)
	for r in rings:
		if t < r.spawn_t:
			continue
		var v: float = r.speed * ns
		var cnt := int(TAU * r.r0 / 70.0)
		for i in cnt:
			var an := float(i) / cnt * TAU
			if absf(wrapf(an - r.gap, -PI, PI)) * r.r0 < 170.0:
				continue
			var dir := Vector2.from_angle(an)
			_shot(r.center + dir * r.r0, -dir * v, C_WALL, r.r0 / v + 0.6)
		r.speed = -1.0
	rings = rings.filter(func(r: RingIn) -> bool: return r.speed > 0.0)


func _update_player(dt: float) -> void:
	# 내 기체 입력 (멀티에서는 동료 기체의 입력이 네트워크로 들어와 같은 함수를 탄다)
	var mv := Vector2.ZERO
	if me.alive():
		mv.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		mv.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	for pl in players:
		_step_player(pl, dt, mv if pl == me else Vector2.ZERO)
	_update_revive(dt)


func _step_player(pl: PlayerState, dt: float, mv: Vector2) -> void:
	var spd := Tune.f("ship_speed")
	var rng := Tune.f("attack_range")
	pl.cd = maxf(0.0, pl.cd - dt)
	pl.invuln = maxf(0.0, pl.invuln - dt)
	pl.recoil = maxf(0.0, pl.recoil - dt * 8.0)
	for k in pl.skill_cd:
		pl.skill_cd[k] = maxf(0.0, pl.skill_cd[k] - dt)
	if pl.downed:
		return
	if cin_active():
		# 휴식 장면: 조작 없이 새 구역으로 날아간다 (무적)
		var tgt := _spawn_point(cin.to)
		var left: float = maxf(cin.t0 + cin.dur * 0.75 - t, 0.2)
		var d := tgt - pl.pos
		var sp := minf(d.length() / left, d.length() / dt)
		pl.pos += d.normalized() * sp * dt if d.length() > 1.0 else Vector2.ZERO
		if d.length() > 4.0:
			pl.angle = d.angle()
		pl.invuln = maxf(pl.invuln, 0.6)
		pl.order = {}
		return
	if pl.dash_t > 0.0:
		pl.dash_t -= dt
		pl.pos = (pl.pos + pl.dash_dir * Skills.DASH_SPEED * dt).clamp(arena.position, arena.end)
		if randf() < 0.8:
			_burst(pl.pos, Color("9fe8ff"), 1, 40.0)
		return
	if pl.order.get("type", "") == "attack" and (pl.order.target == null or pl.order.target.dead):
		pl.order = {}
	if mv == Vector2.ZERO and not pl.order.is_empty():
		var tgt: Vector2 = pl.order.pos if pl.order.type == "move" else pl.order.target.pos
		var d := tgt - pl.pos
		var l := d.length()
		if pl.order.type == "move":
			if l <= spd * dt:
				pl.pos = tgt
				pl.order = {}
			else:
				mv = d / l
		elif l > rng * 0.92:
			mv = d / l
	# 가속·감속으로 부드럽게 움직이고, 방향도 부드럽게 돈다
	var want_vel := mv.normalized() * spd if mv != Vector2.ZERO else Vector2.ZERO
	var acc := SHIP_ACCEL if want_vel != Vector2.ZERO else SHIP_DECEL
	pl.vel = pl.vel.move_toward(want_vel, acc * dt)
	pl.pos += pl.vel * dt
	var clamped := pl.pos.clamp(arena.position, arena.end)
	if clamped.x != pl.pos.x:
		pl.vel.x = 0.0
	if clamped.y != pl.pos.y:
		pl.vel.y = 0.0
	pl.pos = clamped
	var want = null
	if pl.vel.length() > 30.0:
		want = pl.vel.angle()
	if pl.order.get("type", "") == "attack":
		var d: Vector2 = pl.order.target.pos - pl.pos
		if d.length() <= rng:
			want = d.angle()
			# 유도 미사일이라 기체가 완전히 돌지 않아도 쏜다
			if pl.cd <= 0.0:
				_fire(pl, pl.order.target)
	if want != null:
		pl.angle += _angd(pl.angle, want) * (1.0 - exp(-SHIP_TURN * dt))
	# 기울기(뱅크): 옆으로 움직일 때 살짝 기울어 보이게
	var side_v := pl.vel.dot(Vector2.from_angle(pl.angle + PI / 2)) / maxf(spd, 1.0)
	pl.bank = lerpf(pl.bank, clampf(side_v, -1.0, 1.0), 1.0 - exp(-8.0 * dt))


func use_skill(pl: PlayerState, key: String, aim: Vector2) -> void:
	if cin_active() or not running or paused or pl.downed or pl.skill_cd.get(key, 1.0) > 0.0:
		return
	pl.skill_cd[key] = Skills.LIST[key].cd
	match key:
		"dash":
			var d := aim - pl.pos
			pl.dash_dir = d.normalized() if d.length() > 4.0 else Vector2.from_angle(pl.angle)
			pl.dash_t = Skills.DASH_TIME
			pl.angle = pl.dash_dir.angle()
			if pl.order.get("type", "") == "move":
				pl.order = {}
			_play("click")
		"nova":
			_play("boom")
			shake = 0.3
			_burst(pl.pos, Color("9ff5d0"), 50, Skills.NOVA_RADIUS * 1.6)
			var r2 := Skills.NOVA_RADIUS * Skills.NOVA_RADIUS
			for b in bullets:
				var d: Vector2 = b.pos - pl.pos
				if d.length_squared() > r2:
					continue
				if b.form == null:
					b.dead = true
				else:
					b.vel += d.normalized() * 700.0
			pl.invuln = maxf(pl.invuln, 0.4)


func _fire(pl: PlayerState, target: Bullet) -> void:
	pl.cd = Tune.f("attack_cd")
	pl.side = -pl.side
	var side := Vector2.from_angle(pl.angle + PI / 2) * 6.0 * pl.side
	var la := pl.angle + 0.7 * pl.side
	var q := Missile.new()
	q.pos = pl.pos + side
	q.target = target
	q.owner = pl
	q.vel = Vector2.from_angle(la) * 260.0
	missiles.append(q)
	pl.recoil = 1.0
	_play("shot")


func _update_missiles(dt: float) -> void:
	for q in missiles:
		q.life -= dt
		q.age += dt
		q.trail.append(q.pos)
		if q.trail.size() > 9:
			q.trail.pop_front()
		if not q.target.dead:
			var d: Vector2 = q.target.pos - q.pos
			var l := maxf(d.length(), 0.001)
			var sp: float = 380.0 + q.age * 900.0
			var kk := minf(1.0, dt * (3.0 + q.age * 18.0))
			q.vel += (d / l * sp - q.vel) * kk
			if l < 16.0:
				q.life = 0.0
				_burst(q.pos, Color.WHITE, 6, 140.0)
				var tg: Bullet = q.target
				tg.flash = 0.14
				tg.vel += q.vel.normalized() * 160.0
				hitstop = maxf(hitstop, 0.015)
				tg.hp -= 1
				_play("hit")
				if tg.hp <= 0:
					_kill(tg, q.owner)
		q.pos += q.vel * dt
	missiles = missiles.filter(func(q: Missile) -> bool: return q.life > 0.0)


## 큰 별 격추: 주변 노드가 순서대로 무너지고, 사거리 안의 다음 큰 별을 자동으로 노린다.
func _kill(tg: Bullet, by: PlayerState) -> void:
	tg.dead = true
	kills += 1
	if by:
		by.kills += 1
	_burst(tg.pos, tg.col, 28, 280.0)
	_play("boom")
	hitstop = 0.04
	shake = 0.35
	# 보상: 주변 별과 날아오던 탄이 함께 무너지고, 섬광 쿨다운이 줄고, 6개마다 HP 1칸 회복
	for b in bullets:
		if b.dead or b.big or b.die_at >= 0.0:
			continue
		var q: float = b.pos.distance_to(tg.pos)
		if q < CASCADE_RADIUS * (1.4 if b.form == null else 1.0):
			b.die_at = t + q / 420.0
			b.vel += (b.pos - tg.pos) / maxf(q, 1.0) * 160.0
	if by:
		by.skill_cd["nova"] = maxf(0.0, by.skill_cd.get("nova", 0.0) - 2.5)
		if by.kills % 6 == 0 and by.hp < by.max_hp and not by.downed:
			by.hp += 1
			_burst(by.pos, Color("9ff5d0"), 24, 200.0)
			pop_text = "HP +1"
			pop_t = 1.2
	if me.order.get("type", "") == "attack" and me.order.target == tg:
		var best: Bullet = null
		var bd := Tune.f("attack_range") * 1.4
		for b in bullets:
			if b.big and not b.dead:
				var q: float = b.pos.distance_to(me.pos)
				if q < bd:
					bd = q
					best = b
		me.order = {"type": "attack", "target": best, "auto": true} if best else {}


## 탄 이동과 충돌. 모두 쓰러져 게임이 끝나면 true.
func _update_bullets(dt: float) -> bool:
	var hr := Tune.f("hit_radius")
	var hit_list: Array = []
	var targets: Array = []
	for pl in players:
		if pl.alive() and pl.invuln <= 0.0 and pl.dash_t <= 0.0:
			targets.append(pl)
	# 날아가는 탄은 지금 구역에서 한참 벗어나면 사라진다
	var bounds := cur_region_rect().grow(Tune.f("margin") + 700.0)
	for b in bullets:
		if b.dead:
			continue
		if b.die_at >= 0.0:
			if t >= b.die_at:
				b.dead = true
				_burst(b.pos, b.col, 3, 110.0)
				continue
			b.vel = (b.vel * 0.9).limit_length(star_cap())
			b.pos += b.vel * dt
			continue
		if b.flash > 0.0:
			b.flash = maxf(0.0, b.flash - dt)
		if b.form == null:
			b.pos += b.vel * dt
			b.life -= dt
			if b.life <= 0.0 or not bounds.has_point(b.pos):
				b.dead = true
				continue
		if t < b.safe_until:
			continue
		var rr: float = hr + b.core
		for pl in targets:
			if pl in hit_list:
				continue
			var pp: Vector2 = pl.pos
			if absf(b.pos.x - pp.x) < rr and absf(b.pos.y - pp.y) < rr and b.pos.distance_squared_to(pp) < rr * rr:
				hit_list.append(pl)
				if not b.big:
					b.dead = true
	bullets = bullets.filter(func(b: Bullet) -> bool: return not b.dead)
	for pl in hit_list:
		_damage(pl)
	return _check_all_down()


func _damage(pl: PlayerState) -> void:
	hits_taken += 1
	pl.hits += 1
	_burst(pl.pos, Color("ff9fcf"), 26, 260.0)
	_play("hurt")
	shake = 0.5
	pl.invuln = INVULN
	# 주변 작은 탄을 지워 연속 피격을 막는다
	for b in bullets:
		if b.form == null and b.pos.distance_squared_to(pl.pos) < 90.0 * 90.0:
			b.dead = true
	if not Tune.invincible:
		pl.hp -= 1
		if pl.hp <= 0:
			pl.downed = true
			pl.revive = 0.0
			pl.order = {}
			_burst(pl.pos, Color.WHITE, 40, 320.0)


## 모두 쓰러지면 추락. 협동에서는 쓰러진 동료 위에 머물러 살릴 수 있다.
func _check_all_down() -> bool:
	for pl in players:
		if pl.alive():
			return false
	end_game(false)
	return true


func _update_revive(dt: float) -> void:
	for pl in players:
		if not pl.downed:
			continue
		var helper := false
		for other in players:
			if other != pl and other.alive() and other.pos.distance_to(pl.pos) < REVIVE_RADIUS:
				helper = true
		pl.revive = clampf(pl.revive + (dt / REVIVE_TIME if helper else -dt * 0.5), 0.0, 1.0)
		if pl.revive >= 1.0:
			pl.downed = false
			pl.hp = 2
			pl.invuln = 2.0
			_burst(pl.pos, Color("9ff5d0"), 30, 260.0)


static func _sm(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _burst(p: Vector2, col: Color, n: int, s: float) -> void:
	if parts.size() > 1500:
		return
	for i in n:
		var q := Part.new()
		q.pos = p
		q.vel = Vector2.from_angle(randf() * TAU) * randf() * s
		q.life = 0.4 + randf() * 0.5
		q.col = col
		parts.append(q)


static func _angd(a: float, b: float) -> float:
	return wrapf(b - a, -PI, PI)


# ---------------------------------------------------------------- 카메라

func _view_size() -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	if tune_panel:
		vs.x -= tune_panel.size.x + 20.0
	return vs


func _update_camera(dt: float) -> void:
	var overview := tab_held or overview_btn
	zoom_t += ((1.0 if overview else 0.0) - zoom_t) * minf(1.0, dt * 8.0)
	var vs := _view_size()
	var fit := minf(vs.x / world.x, vs.y / world.y) * 0.96
	var k := lerpf(Tune.f("view_zoom"), fit, zoom_t)
	cam_follow += (me.pos - cam_follow) * (1.0 - exp(-9.0 * dt))
	var pos := cam_follow.lerp(world * 0.5, zoom_t)
	# 하이라이트·탄생·기술 준비 때 잠깐 뒤로 빠진다
	cam_pull = maxf(0.0, cam_pull - dt * 0.35)
	k *= lerpf(1.0, 0.5, _sm(cam_pull) * (1.0 - zoom_t))
	# 휴식 장면: 멀리 빠져서 두 구역을 함께 보며 옆으로 이동
	cin_blend += ((1.0 if cin_active() else 0.0) - cin_blend) * minf(1.0, dt * 2.2)
	if cin_blend > 0.001:
		var ck := minf(vs.x / cin_rect.size.x, vs.y / cin_rect.size.y)
		k = lerpf(k, ck, cin_blend)
		pos = pos.lerp(cin_rect.get_center(), cin_blend)
	var full := get_viewport().get_visible_rect().size
	var shift := (full.x - vs.x) * 0.5 / k
	cam.zoom = Vector2(k, k)
	cam.position = pos + Vector2(shift, 0)
	cam.offset = Vector2(randf() - 0.5, randf() - 0.5) * 14.0 * shake / k if shake > 0.0 else Vector2.ZERO


## 지금 화면에 보이는 월드 영역 (테스트 패널 제외).
func view_rect() -> Rect2:
	var vs := _view_size()
	var full := get_viewport().get_visible_rect().size
	var k := cam.zoom.x
	var shift := (full.x - vs.x) * 0.5 / k
	var c := cam.position - Vector2(shift, 0)
	return Rect2(c - vs / k * 0.5, vs / k)


func _screen_world_rect() -> Rect2:
	var full := get_viewport().get_visible_rect().size
	var k := cam.zoom.x
	return Rect2(cam.position + cam.offset - full / k * 0.5, full / k).grow(40.0 / k)


# ---------------------------------------------------------------- 그리기

func _draw() -> void:
	var k := cam.zoom.x
	var vr := _screen_world_rect()
	draw_rect(Rect2(Vector2.ZERO, world), bg_now.darkened(0.5))
	draw_rect(arena, bg_now)
	# 3겹 별밭: 먼 별은 카메라를 덜 따라와 깊이감이 생긴다
	var cc := cam.position
	for s in bg_stars:
		var layer: int = s[2]
		var q: Vector2 = _par_pos(s[0], layer, cc, vr)
		if not vr.has_point(q):
			continue
		var r: float = s[1] * (0.7 + layer * 0.45) / k
		var a: float = (0.22 + 0.16 * layer) * (0.7 + 0.3 * sin(t * 1.4 + s[3]))
		draw_rect(Rect2(q, Vector2(r, r)), Color(0.72, 0.77, 1.0, a))
	draw_rect(Rect2(Vector2.ZERO, world), Color(1, 1, 1, 0.06), false, 1.5 / k)
	var moving := not box_anim.is_empty() or not cin.is_empty()
	var ba := 0.28 + (0.4 + 0.3 * sin(t * 20.0) if moving else 0.0)
	draw_rect(arena, Color(0.56, 1, 0.76, ba), false, (1.5 + (3.0 if moving else 0.0)) / k)
	# 상자 모서리 장식
	var cl := minf(arena.size.x, arena.size.y) * 0.05
	var cco := Color(0.56, 1, 0.76, 0.7)
	for corner in [arena.position, Vector2(arena.end.x, arena.position.y), arena.end, Vector2(arena.position.x, arena.end.y)]:
		var sx := 1.0 if corner.x == arena.position.x else -1.0
		var sy := 1.0 if corner.y == arena.position.y else -1.0
		draw_line(corner, corner + Vector2(cl * sx, 0), cco, 3.0 / k)
		draw_line(corner, corner + Vector2(0, cl * sy), cco, 3.0 / k)
	# 괴수 기술 예고
	for wu in windups:
		var u: float = clampf((t - wu.t0) / wu.ev.dur, 0.0, 1.0)
		var blink := 0.6 + 0.4 * sin(t * (10.0 + 20.0 * u))
		var col := Color(1, 0.45, 0.6, (0.12 + 0.5 * u) * blink)
		var c0: Vector2 = wu.center
		match wu.ev.attack:
			"beams":
				# 넓고 흐린 띠 + 가는 심지 = 레이저 조준선
				for d in _attack_dirs(wu):
					var dir := Vector2.from_angle(d)
					var wdt := (10.0 + 30.0 * u) / maxf(k, 0.2) * 0.5
					draw_line(c0, c0 + dir * 4000.0, Color(col, col.a * 0.35), wdt)
					draw_line(c0, c0 + dir * 4000.0, Color(1, 0.75, 0.85, col.a), maxf(wdt * 0.12, 1.5 / k))
			"claws":
				for d in _attack_dirs(wu):
					draw_arc(c0, 160.0 + 500.0 * u, d - 1.05, d + 1.05, 32, Color(1, 0.68, 0.36, col.a), 6.0 / k)
			_:
				for i in 3:
					draw_arc(c0, fmod(t * 300.0 + i * 220.0, 900.0) + 100.0, 0, TAU, 96, Color(1, 1, 1, col.a * 0.6), 3.0 / k)
				for d in _attack_dirs(wu):
					var gd := Vector2.from_angle(d)
					draw_line(c0 + gd * 120.0, c0 + gd * 900.0, Color(0.56, 1, 0.76, col.a), 6.0 / k)
	# 바깥 탄 경고
	for w in walls:
		var a := clampf(1.0 - (w.spawn_t - t) / WARN, 0.0, 1.0)
		var blink := 0.5 + 0.5 * sin(t * 18.0)
		var col := Color(1, 0.83, 0.42, (0.25 + 0.55 * blink) * a)
		_draw_wall_warning(w, col, k)
	for r in rings:
		var a := clampf(1.0 - (r.spawn_t - t) / WARN, 0.0, 1.0)
		draw_arc(r.center, arena.size.x * 0.03, 0, TAU, 32, Color(1, 1, 1, 0.5 * a), 2.0 / k)
		var gdir := Vector2.from_angle(r.gap)
		draw_line(r.center, r.center + gdir * arena.size.x * 0.25, Color(0.56, 1, 0.76, 0.5 * a), 3.0 / k)
	var rng := Tune.f("attack_range")
	if me.order.get("type", "") == "attack":
		draw_arc(me.pos, rng, 0, TAU, 96, Color(1, 0.42, 0.54, 0.18), 1.5 / k)
		draw_dashed_line(me.pos, me.order.target.pos, Color(1, 0.42, 0.54, 0.5), 1.5 / k, 8.0)
	elif me.order.get("type", "") == "move":
		draw_dashed_line(me.pos, me.order.pos, Color(0.56, 1, 0.76, 0.3), 1.5 / k, 8.0)
	if Tune.test_mode and me.order.get("type", "") != "attack":
		draw_arc(me.pos, rng, 0, TAU, 96, Color(1, 0.42, 0.54, 0.1), 1.0 / k)


## 시차 별 위치: 겹마다 카메라를 따라오는 정도가 다르고, 화면 안으로 감싸 넣는다.
func _par_pos(p: Vector2, layer: int, cc: Vector2, vr: Rect2) -> Vector2:
	var f := 0.35 + layer * 0.25
	var q := p + (cc - world * 0.5) * (1.0 - f)
	q.x = vr.position.x + fposmod(q.x - vr.position.x, world.x)
	q.y = vr.position.y + fposmod(q.y - vr.position.y, world.y)
	return q


## 배경(더하기 섞기): 장면 색을 따라가는 성운 + 밝은 별 반짝이
func _draw_bg_add(c: CanvasItem) -> void:
	var k := cam.zoom.x
	var vr := _screen_world_rect()
	var tint_k := clampf(Tune.f("bg_tint"), 0.0, 1.0)
	var lum := maxf(bg_now.r, maxf(bg_now.g, bg_now.b))
	var sec := Color(bg_now.r / maxf(lum, 0.02), bg_now.g / maxf(lum, 0.02), bg_now.b / maxf(lum, 0.02))
	var na := 0.03 + 0.11 * tint_k
	var cc := cam.position
	for n in nebula:
		var sz: float = n[1]
		var p: Vector2 = n[0] + (cc - world * 0.5) * 0.35
		if not vr.grow(sz).has_point(p):
			continue
		var col: Color = (n[2] as Color).lerp(sec, 0.55)
		c.draw_set_transform(p, n[3] + t * 0.004, Vector2.ONE)
		c.draw_texture_rect(UI.TEX_SMOKE_A if n[4] == 0 else UI.TEX_SMOKE_B, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color(col, na))
	c.draw_set_transform(Vector2.ZERO)
	# 활동 구역 안쪽 가장자리의 은은한 민트 빛
	for i in 4:
		c.draw_rect(arena.grow(-(i + 0.5) * 7.0 / k), Color(0.56, 1, 0.76, 0.05 * (4 - i) / 4.0), false, 7.0 / k)
	# 가까운 겹 별 일부는 반짝이 텍스처
	for i in range(0, bg_stars.size(), 7):
		var s: Array = bg_stars[i]
		if s[2] != 2:
			continue
		var q: Vector2 = _par_pos(s[0], 2, cc, vr)
		if not vr.has_point(q):
			continue
		var tw := 0.5 + 0.5 * sin(t * 1.7 + s[3])
		var r := (6.0 + 7.0 * tw) / k
		c.draw_texture_rect(UI.TEX_SPARKLE, Rect2(q - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.7, 0.8, 1.0, 0.15 + 0.35 * tw))


func _draw_wall_warning(w: Wall, col: Color, k: float) -> void:
	var x0 := arena.position
	var x1 := arena.end
	var a: Vector2
	var b: Vector2
	match w.side:
		"left":
			a = Vector2(x0.x, x0.y); b = Vector2(x0.x, x1.y)
		"right":
			a = Vector2(x1.x, x0.y); b = Vector2(x1.x, x1.y)
		"top":
			a = Vector2(x0.x, x0.y); b = Vector2(x1.x, x0.y)
		_:
			a = Vector2(x0.x, x1.y); b = Vector2(x1.x, x1.y)
	draw_line(a, b, Color(col, col.a * 0.35), 14.0 / k)
	draw_line(a, b, col, 3.0 / k)
	var dir := (b - a).normalized()
	for g in w.gaps:
		var c: Vector2 = a + dir * g
		draw_line(c - dir * 150.0, c + dir * 150.0, Color(0.56, 1, 0.76, col.a * 0.4), 16.0 / k)
		draw_line(c - dir * 150.0, c + dir * 150.0, Color(0.56, 1, 0.76, col.a * 1.2), 4.0 / k)


func _draw_fx(c: CanvasItem) -> void:
	var k := cam.zoom.x
	var vr := _screen_world_rect()
	for b in bullets:
		if not vr.has_point(b.pos):
			continue
		var free: bool = b.form == null
		var r := 22.0 if b.big else maxf(b.core * 3.0 if free else 7.0, 3.5 / k)
		var gc: Color = b.col
		if free:
			gc.a = 0.28
		elif not b.big:
			# 그림 별은 은은하게, 막 태어난 별은 더 흐리게
			gc.a = 0.18 * (0.35 if t < b.safe_until else 1.0)
		c.draw_texture_rect(glow_tex, Rect2(b.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, gc)
		if b.big:
			# 큰 별: 천천히 도는 십자 섬광
			var br := 30.0
			c.draw_set_transform(b.pos, t * 0.8 + b.ph, Vector2.ONE)
			c.draw_texture_rect(UI.TEX_BURST, Rect2(-br, -br, br * 2.0, br * 2.0), false, Color(b.col.lerp(Color.WHITE, 0.4), 0.85))
			c.draw_set_transform(Vector2.ZERO)
		elif free and false:
			# (꼬리는 화면이 지저분해져서 끔)
			var sp: float = b.vel.length()
			if sp > 1.0:
				var L: float = clampf(sp * 0.09, 6.0, 60.0) + b.core * 2.0
				var wdt: float = maxf(b.core * 2.6, 3.0 / k)
				c.draw_set_transform(b.pos, (-b.vel).angle() - PI / 2.0, Vector2.ONE)
				c.draw_texture_rect(UI.TEX_STREAK, Rect2(-wdt * 0.5, -b.core, wdt, L), false, Color(b.col, 0.55))
				c.draw_set_transform(Vector2.ZERO)
		if b.flash > 0.0:
			var fr := r * 1.6
			c.draw_texture_rect(UI.TEX_FLARE, Rect2(b.pos - Vector2(fr, fr) * 1.6, Vector2(fr, fr) * 3.2), false, Color(1, 1, 1, b.flash / 0.14))
	for q in missiles:
		var n: int = q.trail.size()
		for i in n:
			var tr := 3.0 + 4.0 * float(i) / maxf(n, 1)
			c.draw_texture_rect(glow_tex, Rect2(q.trail[i] - Vector2(tr, tr), Vector2(tr, tr) * 2.0), false, Color(0.55, 0.85, 1, float(i) / n * 0.6))
		c.draw_texture_rect(UI.TEX_FLARE, Rect2(q.pos - Vector2(26, 26), Vector2(52, 52)), false, Color("e8fbff"))
	for q in parts:
		var pr: float = 6.0 + 10.0 * q.m
		c.draw_texture_rect(UI.TEX_FLARE, Rect2(q.pos - Vector2(pr, pr) * 1.5, Vector2(pr, pr) * 3.0), false, Color(q.col, q.m))
		c.draw_texture_rect(glow_tex, Rect2(q.pos - Vector2(pr, pr) * 0.5, Vector2(pr, pr)), false, Color(q.col, q.m * 0.6))
	for wu in windups:
		var u: float = clampf((t - wu.t0) / wu.ev.dur, 0.0, 1.0)
		var gr := 40.0 + 160.0 * u + 20.0 * sin(t * 14.0)
		c.draw_texture_rect(glow_tex, Rect2(wu.center - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1, 0.6, 0.78, 0.5 + 0.4 * u))
		var rr := gr * (1.6 - 0.5 * fmod(t * 2.0, 1.0))
		c.draw_texture_rect(UI.TEX_RING, Rect2(wu.center - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(1, 0.55, 0.75, 0.35 * u))
	for g in gates:
		var a: float = 1.0 - g.t / 2.2
		var core := 60.0 + 40.0 * sin(g.t * 9.0)
		c.draw_texture_rect(glow_tex, Rect2(g.pos - Vector2(core, core), Vector2(core, core) * 2.0), false, Color(g.col, a))
		for ring in 3:
			var rr: float = (g.t * 900.0 + ring * 160.0) * 1.12
			c.draw_texture_rect(UI.TEX_RING, Rect2(g.pos - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(g.col, a * 0.45))
	# 기체 엔진 불꽃 + 은은한 바닥 빛
	var visible_ship := me.invuln <= 0.0 or fmod(me.invuln, 0.16) < 0.09
	if visible_ship and me.alive():
		var s := Tune.f("ship_scale") * maxf(1.0, 0.55 / k)
		var dir := Vector2.from_angle(me.angle)
		var spd := clampf(me.vel.length() / maxf(Tune.f("ship_speed"), 1.0), 0.0, 1.0)
		var rear := me.pos - dir * ((UI.TEX_SHIP.get_size().y * 0.5 - 7.0) * SHIP_PX + me.recoil * 3.0) * s
		var fl := (12.0 + 16.0 * spd + randf() * 3.0) * s
		var fw := 6.5 * s * (1.0 - 0.3 * absf(me.bank))
		c.draw_set_transform(rear, me.angle - PI / 2.0, Vector2.ONE)
		c.draw_texture_rect(UI.TEX_FLAME, Rect2(-fw * 0.5, -fl, fw, fl), false, Color(0.3, 0.65, 1.0, 0.95))
		c.draw_texture_rect(UI.TEX_FLAME, Rect2(-fw * 0.28, -fl * 0.6, fw * 0.56, fl * 0.6), false, Color(1, 1, 1, 0.95))
		c.draw_set_transform(Vector2.ZERO)
		var gr2 := 16.0 * s
		c.draw_texture_rect(glow_tex, Rect2(rear - Vector2(gr2, gr2) * 0.5, Vector2(gr2, gr2)), false, Color(0.4, 0.7, 1.0, 0.7))
		c.draw_texture_rect(glow_tex, Rect2(me.pos - Vector2(gr2, gr2) * 1.5, Vector2(gr2, gr2) * 3.0), false, Color(0.35, 0.6, 1.0, 0.16))


func _draw_top(c: CanvasItem) -> void:
	var k := cam.zoom.x
	var vr := _screen_world_rect()
	_draw_bullets(c, vr, k)
	for b in bullets:
		if b.big and b.hp < BIG_HP and vr.has_point(b.pos):
			c.draw_arc(b.pos, 14, -PI / 2, -PI / 2 + TAU * b.hp / BIG_HP, 24, Color(1, 1, 1, 0.85), 2.0, true)
	for m in marks:
		var r: float = 8.0 + m.t * 60.0
		var col := Color(m.col, 1.0 - m.t * 2.0)
		c.draw_set_transform(m.pos, 0, Vector2(1, 0.55))
		c.draw_texture_rect(UI.TEX_RING, Rect2(-r, -r, r * 2.0, r * 2.0), false, col)
		c.draw_set_transform(Vector2.ZERO)
	# 조준 중인 큰 별: 도는 조준선
	if me.order.get("type", "") == "attack":
		var tg: Bullet = me.order.target
		if tg and not tg.dead:
			var rr := 26.0 + 2.0 * sin(t * 8.0)
			c.draw_set_transform(tg.pos, t * 1.5, Vector2.ONE)
			c.draw_texture_rect(UI.TEX_RETICLE, Rect2(-rr, -rr, rr * 2.0, rr * 2.0), false, Color(COL_ATTACK, 0.9))
			c.draw_set_transform(Vector2.ZERO)
	# 기체 (무적 시간엔 깜빡임)
	var visible_ship := me.invuln <= 0.0 or fmod(me.invuln, 0.16) < 0.09
	var s := Tune.f("ship_scale") * maxf(1.0, 0.55 / k)
	if visible_ship:
		_draw_ship(c, me, s)
	if me.invuln > 0.0:
		var ir := 24.0 * s
		c.draw_texture_rect(UI.TEX_RING, Rect2(me.pos - Vector2(ir, ir), Vector2(ir, ir) * 2.0), false, Color(1, 0.62, 0.81, me.invuln / INVULN * 0.8))
	# 판정 (실제 크기): 빨간 점 + 흰 테두리. 기체 그림 위에 늘 보인다.
	var hr := Tune.f("hit_radius")
	var hd := maxf(hr, 1.5 / k)
	c.draw_circle(me.pos, hd + 1.5 / k, Color.WHITE)
	c.draw_circle(me.pos, hd, Color("ff2d55"))
	if Tune.test_mode:
		c.draw_arc(me.pos, hr + SHOT_CORE, 0, TAU, 32, Color(1, 0.42, 0.54, 0.6), 1.0 / k)
	# 보상 글자
	if pop_t > 0.0:
		var font := ui_root.get_theme_default_font()
		var fs := int(20.0 / k)
		var pp := me.pos + Vector2(-30, -44) / k + Vector2(0, -pop_t * 20.0)
		c.draw_string_outline(font, pp, pop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(5.0 / k), Color(0, 0, 0, 0.5 * minf(1.0, pop_t)))
		c.draw_string(font, pp, pop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.62, 0.96, 0.82, minf(1.0, pop_t)))
	# 화면 밖 경고: 화면 가장자리에 화살표
	var sr := _screen_world_rect().grow(-60.0 / k)
	for w in walls:
		var target := _wall_point_near(w, me.pos)
		if not sr.has_point(target):
			_edge_arrow(c, sr, target, C_WALL, k)
	for r in rings:
		_edge_arrow(c, sr, r.center + (me.pos - r.center).normalized() * 99999.0, C_WALL, k)
	# 큰 별 하이라이트
	if running and zoom_t < 0.5:
		var h := pick(get_global_mouse_position(), 34.0 / k)
		if h:
			var hr2 := 24.0
			c.draw_set_transform(h.pos, -t * 1.2, Vector2.ONE)
			c.draw_texture_rect(UI.TEX_RETICLE, Rect2(-hr2, -hr2, hr2 * 2.0, hr2 * 2.0), false, Color(COL_ATTACK, 0.6))
			c.draw_set_transform(Vector2.ZERO)


const _UNIT := [Vector2(1, 0), Vector2(0.866, 0.5), Vector2(0.5, 0.866), Vector2(0, 1), Vector2(-0.5, 0.866), Vector2(-0.866, 0.5),
	Vector2(-1, 0), Vector2(-0.866, -0.5), Vector2(-0.5, -0.866), Vector2(0, -1), Vector2(0.5, -0.866), Vector2(0.866, -0.5)]
const C_OUTLINE := Color(0.02, 0.02, 0.07, 0.85)
## 스프라이트 1px 당 월드 크기 (ship_scale 1 기준)
const SHIP_PX := 0.3
var _unit_poly := PackedVector2Array(_UNIT)
var _diamond := PackedVector2Array([Vector2(1.6, 0), Vector2(0, 1), Vector2(-1.2, 0), Vector2(0, -1)])
var _spark := PackedVector2Array()


## 탄 그리기. 종류마다 색과 모양이 다르고, 보이는 몸통 = 판정 크기.
##   주황 쌀알 = 무리가 뿌리는 탄 / 연두 화살촉 = 바깥에서 들어오는 벽·고리 / 분홍 구슬 = 괴수 기술
##   그림 별(드론) = 팔레트 색 반짝이, 큰 별 = 흰 8각 별(부술 수 있음)
## 모두 "밝은 흰 심지 + 색 테두리 + 얇은 어두운 외곽선" 구조라 블룸 위에서도 또렷하다.
func _draw_bullets(c: CanvasItem, vr: Rect2, k: float) -> void:
	if _spark.is_empty():
		for i in 8:
			_spark.append(Vector2.from_angle(i * PI / 4.0) * (1.0 if i % 2 == 0 else 0.34))
	var spin := t * 1.2
	var ol := 1.2 / k
	for b in bullets:
		if not vr.has_point(b.pos):
			continue
		if b.big:
			var poly := PackedVector2Array()
			var poly_o := PackedVector2Array()
			var poly_i := PackedVector2Array()
			for i in 8:
				var an := i * PI / 4.0 + spin
				var rr := 2.6 if i % 2 == 1 else 9.0
				poly.append(b.pos + Vector2.from_angle(an) * rr)
				poly_o.append(b.pos + Vector2.from_angle(an) * (rr + 1.8))
				poly_i.append(b.pos + Vector2.from_angle(an) * rr * 0.55)
			c.draw_colored_polygon(poly_o, C_OUTLINE)
			c.draw_colored_polygon(poly, b.col.lerp(Color.WHITE, 0.55))
			c.draw_colored_polygon(poly_i, Color.WHITE)
			continue
		if b.form != null:
			# 그림 별: 팔레트 색 반짝이 (작은 판정, 은은하게)
			var a := 0.6 * (0.4 if t < b.safe_until else 1.0)
			var sr: float = b.core * 1.6
			c.draw_set_transform(b.pos, spin * 0.5 + b.ph, Vector2(sr, sr))
			c.draw_colored_polygon(_spark, Color(b.col, a))
			c.draw_set_transform(Vector2.ZERO)
			c.draw_circle(b.pos, b.core * 0.6, Color(1, 1, 1, a))
			continue
		var r: float = b.core
		var ang: float = b.vel.angle()
		if b.col == C_WALL:
			# 화살촉: 진행 방향으로 뾰족
			c.draw_set_transform(b.pos, ang, Vector2(r * 1.25 + ol, r + ol))
			c.draw_colored_polygon(_diamond, C_OUTLINE)
			c.draw_set_transform(b.pos, ang, Vector2(r * 1.25, r))
			c.draw_colored_polygon(_diamond, b.col)
			c.draw_set_transform(b.pos + Vector2.from_angle(ang) * r * 0.15, ang, Vector2(r * 0.75, r * 0.55))
			c.draw_colored_polygon(_diamond, Color(1, 1, 0.94))
		elif b.col == C_SKILL:
			# 구슬: 색 테두리 + 하얀 심지
			c.draw_circle(b.pos, r + ol, C_OUTLINE)
			c.draw_circle(b.pos, r, b.col)
			c.draw_circle(b.pos, r * 0.6, Color(1, 0.94, 0.97))
		else:
			# 쌀알: 진행 방향으로 길쭉
			c.draw_set_transform(b.pos, ang, Vector2(r * 1.7 + ol, r + ol))
			c.draw_colored_polygon(_unit_poly, C_OUTLINE)
			c.draw_set_transform(b.pos, ang, Vector2(r * 1.7, r))
			c.draw_colored_polygon(_unit_poly, b.col)
			c.draw_set_transform(b.pos + Vector2.from_angle(ang) * r * 0.2, ang, Vector2(r * 1.15, r * 0.55))
			c.draw_colored_polygon(_unit_poly, Color(1, 0.97, 0.92))
		c.draw_set_transform(Vector2.ZERO)


## 기체: Kenney 우주선 스프라이트. 기울면 옆으로 납작해지고, 쏠 때 뒤로 살짝 밀린다.
## 엔진 불꽃은 _draw_fx (더하기 층)에서 그린다.
func _draw_ship(c: CanvasItem, pl: PlayerState, s: float) -> void:
	var dir := Vector2.from_angle(pl.angle)
	var p := pl.pos - dir * pl.recoil * 3.0 * s
	var f := s * SHIP_PX
	var ts := UI.TEX_SHIP.get_size()
	var tint := Color.WHITE if pl.color == Color.WHITE else pl.color.lerp(Color.WHITE, 0.5)
	c.draw_set_transform(p, pl.angle + PI / 2.0, Vector2(f * (1.0 - 0.35 * absf(pl.bank)), f))
	c.draw_texture_rect(UI.TEX_SHIP, Rect2(-ts * 0.5, ts), false, tint)
	c.draw_set_transform(Vector2.ZERO)


func _wall_point_near(w: Wall, p: Vector2) -> Vector2:
	match w.side:
		"left":
			return Vector2(arena.position.x, clampf(p.y, arena.position.y, arena.end.y))
		"right":
			return Vector2(arena.end.x, clampf(p.y, arena.position.y, arena.end.y))
		"top":
			return Vector2(clampf(p.x, arena.position.x, arena.end.x), arena.position.y)
		_:
			return Vector2(clampf(p.x, arena.position.x, arena.end.x), arena.end.y)


func _edge_arrow(c: CanvasItem, sr: Rect2, target: Vector2, col: Color, k: float) -> void:
	var from := sr.get_center()
	var dir := (target - from).normalized()
	if dir == Vector2.ZERO:
		return
	# 화면 사각형과 만나는 점
	var tx := (sr.size.x * 0.5) / maxf(absf(dir.x), 0.0001)
	var ty := (sr.size.y * 0.5) / maxf(absf(dir.y), 0.0001)
	var p := from + dir * minf(tx, ty)
	var blink := 0.55 + 0.45 * sin(t * 16.0)
	var sz := 18.0 / k
	var pts := PackedVector2Array([p + dir * sz, p - dir * sz * 0.6 + dir.orthogonal() * sz * 0.8, p - dir * sz * 0.6 - dir.orthogonal() * sz * 0.8])
	c.draw_colored_polygon(pts, Color(col, blink))


static func _fmt_time(x: float) -> String:
	return "%d:%02d" % [int(x / 60.0), int(fmod(x, 60.0))]


# ---------------------------------------------------------------- 화면 UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)

	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
		ui_root.add_child(bar)
		letterbox.append(bar)
	caption_label = UI.title("", 28, Color("ffe6a8"))
	caption_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	caption_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.offset_bottom = -16
	ui_root.add_child(caption_label)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0.97, 0.9, 0)
	ui_root.add_child(flash_rect)

	# 스킬 (아래 가운데): 키 칩 + 쿨다운 원
	var skills := HBoxContainer.new()
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skills.add_theme_constant_override("separation", 8)
	skills.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skills.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skills.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skills.offset_bottom = -14
	for key in Skills.LIST:
		var chip := UI.SkillChip.new()
		chip.key_label = Skills.LIST[key].key_label
		chip.skill_name = Skills.LIST[key].name
		chip.cd_max = Skills.LIST[key].cd
		chip.custom_minimum_size = Vector2(138 if chip.key_label.length() > 2 else 112, 40)
		skills.add_child(chip)
		skill_chips[key] = chip
	ui_root.add_child(skills)
	skill_label = skills

	# 곡 진행 (위 가운데)
	var song := VBoxContainer.new()
	song.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song.set_anchors_preset(Control.PRESET_CENTER_TOP)
	song.custom_minimum_size = Vector2(460, 0)
	song.position = Vector2(-230, 14)
	song.add_theme_constant_override("separation", 2)
	ui_root.add_child(song)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UI.label(Track1.TITLE, 14, UI.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label = UI.label("0:00 / 1:36", 13, UI.DIM)
	row.add_child(title)
	row.add_child(time_label)
	song.add_child(row)
	song_bar = SongBar.new()
	song_bar.custom_minimum_size = Vector2(460, 14)
	song_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song.add_child(song_bar)
	var pill_row := CenterContainer.new()
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_pill = UI.pill("", 13, UI.GOLD)
	scene_label = scene_pill.get_meta("label")
	pill_row.add_child(scene_pill)
	song.add_child(UI.label("", 2))
	song.add_child(pill_row)

	# HP, 격추 (왼쪽 위): 유리 패널
	var stats_panel := PanelContainer.new()
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.position = Vector2(14, 14)
	stats_panel.add_theme_stylebox_override("panel", UI.glass(12, 14, 0.6))
	ui_root.add_child(stats_panel)
	var stats := VBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 4)
	stats_panel.add_child(stats)
	var hp_row := HBoxContainer.new()
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_row.add_theme_constant_override("separation", 10)
	hp_label = UI.label("HP", 13, UI.DIM)
	hp_row.add_child(hp_label)
	hp_bar = UI.HpBar.new()
	hp_bar.custom_minimum_size = Vector2(140, 18)
	hp_row.add_child(hp_bar)
	stats.add_child(hp_row)
	kill_label = UI.label("", 12, UI.DIM)
	stats.add_child(kill_label)

	# 미니맵 (왼쪽 아래)
	minimap = Minimap.new()
	minimap.game = self
	ui_root.add_child(minimap)
	cell_label = UI.label("", 12, UI.DIM)
	ui_root.add_child(cell_label)

	# 도구 (오른쪽 아래)
	var tools := HBoxContainer.new()
	tools.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tools.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tools.add_theme_constant_override("separation", 8)
	ui_root.add_child(tools)
	view_btn = UI.button("전체 보기  Tab", false, 13)
	view_btn.custom_minimum_size = Vector2(0, 38)
	view_btn.toggle_mode = true
	view_btn.toggled.connect(func(on: bool) -> void: overview_btn = on)
	tools.add_child(view_btn)

	if Tune.test_mode:
		tune_panel = TunePanel.new()
		tune_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		tune_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		tune_panel.offset_left = -330
		tune_panel.offset_right = -10
		tune_panel.offset_top = 10
		tune_panel.offset_bottom = -10
		tune_panel.restart_requested.connect(start)
		tune_panel.menu_requested.connect(_to_menu)
		tune_panel.seek_requested.connect(seek)
		ui_root.add_child(tune_panel)
		tools.offset_right = -376
		song.position.x -= 170
		skills.offset_left -= 170
		skills.offset_right -= 170
	else:
		tools.offset_right = -14
	tools.offset_left = tools.offset_right
	tools.offset_bottom = -14
	tools.offset_top = -14

	# 오버레이
	ov_start = _overlay("하떨별", "노래 한 곡이 끝날 때까지 버티세요. HP가 다 닳으면 추락합니다.\n\n초록 테두리 밖으로는 못 나가요. 노란 경고선이 깜빡이면 바깥에서 탄 벽이 들어옵니다.\n초록 틈으로 피하세요.", [["시작", start, true], ["메뉴로", _to_menu, false]], true)
	ov_pause = _overlay("일시정지", "", [["계속하기", toggle_pause, true], ["처음부터", start, false], ["메뉴로", _to_menu, false]])
	ov_pause.visible = false
	ov_over = _overlay("추락", "", [["다시 하기", start, true], ["메뉴로", _to_menu, false]])
	ov_over.visible = false
	over_title = ov_over.get_meta("title")
	over_text = ov_over.get_meta("text")

	get_viewport().size_changed.connect(_layout_minimap)


func _layout_minimap() -> void:
	if minimap == null:
		return
	var full := get_viewport().get_visible_rect().size
	var w := clampf(full.x * 0.2, 160.0, 280.0)
	var h := w * world.y / world.x
	minimap.size = Vector2(w, h)
	minimap.position = Vector2(14, full.y - h - 14)
	cell_label.position = Vector2(18, full.y - h - 36)


func _overlay(title: String, text: String, buttons: Array, keys := false) -> Control:
	var ov := ColorRect.new()
	ov.color = Color(0.01, 0.012, 0.035, 0.72)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(ov)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var card := PanelContainer.new()
	var sb := UI.glass(18, 36, 0.86)
	sb.content_margin_top = 28
	sb.content_margin_bottom = 30
	sb.shadow_size = 30
	sb.shadow_color = Color(0, 0, 0, 0.5)
	card.add_theme_stylebox_override("panel", sb)
	cc.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	var tl := UI.title(title, 56, Color("fff4d6"))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tl)
	var tx := UI.label(text, 15, UI.DIM)
	tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tx)
	if keys:
		var kr := HBoxContainer.new()
		kr.alignment = BoxContainer.ALIGNMENT_CENTER
		kr.add_theme_constant_override("separation", 14)
		for kv in [["WASD", "이동"], ["클릭", "큰 별 조준"], ["Space", "대시"], ["Q", "섬광"], ["Tab", "전체 맵"], ["Esc", "일시정지"]]:
			kr.add_child(UI.key_hint(kv[0], kv[1]))
		col.add_child(kr)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(UI.label("", 4))
	col.add_child(row)
	for b in buttons:
		var btn := UI.button(b[0], b[2], 16)
		btn.custom_minimum_size = Vector2(150, 46)
		btn.pressed.connect(b[1])
		row.add_child(btn)
	ov.set_meta("title", tl)
	ov.set_meta("text", tx)
	return ov


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
