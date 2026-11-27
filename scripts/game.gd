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
const BIG_HP := 3
const CASCADE_RADIUS := 170.0
const WARN := 1.2
const INVULN := 1.6
const DRONE_VMAX := 430.0
const DRONE_ACCEL := 1500.0
const MAX_BULLETS := 6000
const REVIVE_RADIUS := 60.0
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
var cam_follow := Vector2.ZERO
var bg_stars: Array = []

var cam: Camera2D
var fx: Node2D
var top: Node2D
var glow_tex: Texture2D
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
var skill_label: Label
var cell_label: Label


func _ready() -> void:
	events = Track1.EVENTS.duplicate()
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	glow_tex = _make_glow()
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()

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
	world = Tune.world_size()
	var mg := minf(Tune.f("margin"), minf(world.x, world.y) * 0.3)
	arena = Rect2(Vector2(mg, mg), world - Vector2(mg, mg) * 2.0)
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
	var n := int(520 * (world.x * world.y) / (3840.0 * 2400.0))
	for i in n:
		bg_stars.append([Vector2(randf() * world.x, randf() * world.y), randf() * 0.8 + 0.3])
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
		if ev.type == "formation" and ev.t + ev.dur > time:
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
		var grade := "S" if hits_taken == 0 else ("A" if hits_taken <= 1 else ("B" if hits_taken <= 3 else "C"))
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
	if not running or paused:
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
	minimap.queue_redraw()
	song_bar.progress = t / Track1.LENGTH
	song_bar.queue_redraw()
	time_label.text = "%s / %s" % [_fmt_time(t), _fmt_time(Track1.LENGTH)]
	scene_label.text = "장면 · " + scene_name
	hp_label.text = "HP  " + "●".repeat(maxi(me.hp, 0)) + "○".repeat(maxi(me.max_hp - me.hp, 0))
	hp_label.modulate = Color(1, 1, 1, 0.45 if me.invuln > 0.0 and fmod(me.invuln, 0.2) < 0.1 else 1.0)
	kill_label.text = "큰 별 격추 %d" % kills
	cell_label.text = "전체 맵 · 지금 %s 칸 · 흰 네모 = 내 화면" % Minimap.cell_name(world, me.pos)
	flash_rect.color.a = flash * 0.32
	var sk := PackedStringArray()
	for key in Skills.LIST:
		var cdv: float = me.skill_cd.get(key, 0.0)
		sk.append("%s %s %s" % [Skills.LIST[key].key_label, Skills.LIST[key].name, "준비" if cdv <= 0.0 else "%.0f초" % ceilf(cdv)])
	skill_label.text = "   ·   ".join(sk)
	if tune_panel:
		tune_panel.set_info("노드 %d개 · FPS %d · 맞은 횟수 %d" % [bullets.size(), Engine.get_frames_per_second(), hits_taken])


func _update(dt: float) -> void:
	if hitstop > 0.0:
		hitstop -= dt
		return
	# 음악이 있으면 음악 재생 위치에 맞춘다 (박자 싱크).
	if music.playing:
		var mt := music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		t = mt if absf(mt - (t + dt)) < 0.25 else t + dt
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
			"ring_in":
				var r := RingIn.new()
				r.center = _arena_point(ev.at)
				r.spawn_t = ev.t + WARN
				r.speed = ev.speed
				r.gap = randf() * TAU
				var far := 0.0
				for c in [Vector2.ZERO, Vector2(world.x, 0), world, Vector2(0, world.y)]:
					far = maxf(far, r.center.distance_to(c))
				r.r0 = far + 40.0
				rings.append(r)


## 하이라이트: 화면이 번쩍이고, 무리가 바깥으로 확 퍼지며, 중심에서 탄 고리가 터져 나간다.
func _snap(ev: Dictionary) -> void:
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
	var cnt: int = ev.get("ring", 0)
	for k in ev.get("waves", 1):
		var a0 := randf() * TAU
		for i in cnt:
			var an := a0 + float(i) / cnt * TAU
			_shot(c, Vector2.from_angle(an) * (170.0 + 50.0 * k) * ns, Color("fff8ec"))


func _arena_point(f: Vector2) -> Vector2:
	return arena.position + arena.size * f


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
	f.sc = arena.size.x * ev.size / Shapes.W
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
		gates.append({"pos": f.center, "t": 0.0, "col": Shapes.TINT[f.keys[0]]})
		_burst(f.center, Color.WHITE, 30, 360.0)
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
							_shot(b.pos, Vector2.from_angle(a0 + k * 0.22) * 210.0 * ns, Color("ff9fcf"))
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
		match ev.kind:
			"spiral", "flower":
				while e.acc > ev.rate:
					e.acc -= ev.rate
					var arms: int = ev.arms
					for a in arms:
						var spin: float = e.t * (1.1 if ev.kind == "spiral" else 0.0) + (sin(e.t * 2.0) * 0.8 if ev.kind == "flower" else 0.0)
						var an: float = e.a0 + spin + a * TAU / arms
						_shot(e.center, Vector2.from_angle(an) * sp, Color("9fe8ff") if ev.kind == "spiral" else Color("c9b2ff"))
			"rings":
				while e.acc > ev.rate:
					e.acc -= ev.rate
					var gap := randf() * TAU
					var cnt: int = ev.count
					for i in cnt:
						var an := float(i) / cnt * TAU
						if absf(wrapf(an - gap, -PI, PI)) < 0.28:
							continue
						_shot(e.center, Vector2.from_angle(an) * sp, Color("ff9fcf"))
	emitters = emitters.filter(func(e: Emitter) -> bool: return e.t < e.ev.dur)


## 경고 시간이 지난 벽과 고리를 실제 탄으로 만든다. 출발점은 맵 가장자리(활동 구역 바깥).
func _update_walls() -> void:
	var ns := Tune.f("node_speed")
	var gap_w := 300.0
	var spacing := 54.0
	for w in walls:
		if t < w.spawn_t:
			continue
		var horiz: bool = w.side in ["left", "right"]
		var edge_len := arena.size.y if horiz else arena.size.x
		var span := world.y if horiz else world.x
		var s := 0.0
		while s < span:
			var along := s - (arena.position.y if horiz else arena.position.x)
			var in_gap := false
			for g in w.gaps:
				if absf(along - g) < gap_w * 0.5:
					in_gap = true
			if not in_gap:
				var p: Vector2
				var v: Vector2
				match w.side:
					"left":
						p = Vector2(4, s); v = Vector2(1, 0)
					"right":
						p = Vector2(world.x - 4, s); v = Vector2(-1, 0)
					"top":
						p = Vector2(s, 4); v = Vector2(0, 1)
					_:
						p = Vector2(s, world.y - 4); v = Vector2(0, -1)
				_shot(p, v * w.speed * ns, Color("ffd36b"))
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
			_shot(r.center + dir * r.r0, -dir * v, Color.WHITE, r.r0 / v + 0.6)
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
	var want = null
	if mv != Vector2.ZERO:
		pl.pos += mv.normalized() * spd * dt
		want = mv.angle()
	pl.pos = pl.pos.clamp(arena.position, arena.end)
	if pl.order.get("type", "") == "attack":
		var d: Vector2 = pl.order.target.pos - pl.pos
		if d.length() <= rng:
			want = d.angle()
			if pl.cd <= 0.0 and absf(_angd(pl.angle, want)) < 0.25:
				_fire(pl, pl.order.target)
	if want != null:
		pl.angle += clampf(_angd(pl.angle, want), -12.0 * dt, 12.0 * dt)


func use_skill(pl: PlayerState, key: String, aim: Vector2) -> void:
	if not running or paused or pl.downed or pl.skill_cd.get(key, 1.0) > 0.0:
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
	for b in bullets:
		if b.dead or b.big or b.die_at >= 0.0:
			continue
		var q: float = b.pos.distance_to(tg.pos)
		if q < CASCADE_RADIUS:
			b.die_at = t + q / 420.0
			b.vel += (b.pos - tg.pos) / maxf(q, 1.0) * 160.0
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
	var bounds := Rect2(Vector2(-80, -80), world + Vector2(160, 160))
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
	cam_follow += (me.pos - cam_follow) * minf(1.0, dt * 8.0)
	var pos := cam_follow.lerp(world * 0.5, zoom_t)
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
	draw_rect(Rect2(Vector2.ZERO, world), bg_now.darkened(0.45))
	draw_rect(arena, bg_now)
	var sc := Color("3a3e66")
	for s in bg_stars:
		var p: Vector2 = s[0]
		if vr.has_point(p):
			var r: float = s[1] / k * 0.6 + s[1] * 0.4
			draw_rect(Rect2(p, Vector2(r, r)), sc)
	draw_rect(Rect2(Vector2.ZERO, world), Color(1, 1, 1, 0.08), false, 2.0 / k)
	draw_rect(arena, Color(0.56, 1, 0.76, 0.16), false, 2.0 / k)
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


func _draw_wall_warning(w: Wall, col: Color, k: float) -> void:
	var horiz: bool = w.side in ["left", "right"]
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
	draw_line(a, b, col, 6.0 / k)
	var dir := (b - a).normalized()
	for g in w.gaps:
		var c: Vector2 = a + dir * g
		draw_line(c - dir * 150.0, c + dir * 150.0, Color(0.56, 1, 0.76, col.a * 1.2), 8.0 / k)


func _draw_fx(c: CanvasItem) -> void:
	var k := cam.zoom.x
	var vr := _screen_world_rect()
	var spin := t * 1.2
	for b in bullets:
		if not vr.has_point(b.pos):
			continue
		var free: bool = b.form == null
		var r := 20.0 if b.big else maxf(11.0 if free else 9.0, 3.0 / k)
		c.draw_texture_rect(glow_tex, Rect2(b.pos - Vector2(r, r), Vector2(r, r) * 2.0), false, b.col)
		if b.flash > 0.0:
			var fr := r * 1.6
			c.draw_texture_rect(glow_tex, Rect2(b.pos - Vector2(fr, fr), Vector2(fr, fr) * 2.0), false, Color(1, 1, 1, b.flash / 0.14))
		if b.big:
			var poly := PackedVector2Array()
			for i in 8:
				var an := i * PI / 4.0 + spin
				poly.append(b.pos + Vector2.from_angle(an) * (2.2 if i % 2 == 1 else 8.0))
			c.draw_colored_polygon(poly, Color.WHITE)
		else:
			# 날아오는 탄은 심을 더 크고 밝게 해서 그림 노드보다 잘 보이게
			c.draw_circle(b.pos, maxf(2.4 if free else 1.4, 1.2 / k), Color(1, 1, 1, 1.0 if free else 0.8))
	for q in missiles:
		var n: int = q.trail.size()
		for i in n:
			c.draw_texture_rect(glow_tex, Rect2(q.trail[i] - Vector2(5, 5), Vector2(10, 10)), false, Color(0.62, 0.85, 1, float(i) / n * 0.5))
		c.draw_texture_rect(glow_tex, Rect2(q.pos - Vector2(9, 9), Vector2(18, 18)), false, Color("e8fbff"))
	for q in parts:
		c.draw_texture_rect(glow_tex, Rect2(q.pos - Vector2(6, 6), Vector2(12, 12)), false, Color(q.col, q.m))
	for g in gates:
		var a: float = 1.0 - g.t / 2.2
		var core := 60.0 + 40.0 * sin(g.t * 9.0)
		c.draw_texture_rect(glow_tex, Rect2(g.pos - Vector2(core, core), Vector2(core, core) * 2.0), false, Color(g.col, a))
		for ring in 3:
			var rr: float = (g.t * 900.0 + ring * 160.0)
			c.draw_arc(g.pos, rr, 0, TAU, 96, Color(g.col, a * 0.5), 4.0 / k)


func _draw_top(c: CanvasItem) -> void:
	var k := cam.zoom.x
	var vr := _screen_world_rect()
	for b in bullets:
		if b.big and b.hp < BIG_HP and vr.has_point(b.pos):
			c.draw_arc(b.pos, 13, -PI / 2, -PI / 2 + TAU * b.hp / BIG_HP, 24, Color(1, 1, 1, 0.75), 2.0)
	for m in marks:
		var r: float = 5.0 + m.t * 32.0
		var col := Color(m.col, 1.0 - m.t * 2.0)
		c.draw_set_transform(m.pos, 0, Vector2(1, 0.55))
		c.draw_arc(Vector2.ZERO, r, 0, TAU, 32, col, 2.0 / maxf(k, 0.3))
		c.draw_set_transform(Vector2.ZERO)
	# 기체 (무적 시간엔 깜빡임)
	var visible_ship := me.invuln <= 0.0 or fmod(me.invuln, 0.16) < 0.09
	var s := Tune.f("ship_scale") * maxf(1.0, 0.55 / k)
	if visible_ship:
		c.draw_set_transform(me.pos, me.angle, Vector2(s, s))
		var back := -me.recoil * 3.0
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(13 + back, 0), Vector2(-8 + back, -9), Vector2(-4 + back, 0), Vector2(-8 + back, 9)
		]), Color.WHITE)
		c.draw_set_transform(Vector2.ZERO)
	if me.invuln > 0.0:
		c.draw_arc(me.pos, 18.0 * Tune.f("ship_scale") * maxf(1.0, 0.55 / k), 0, TAU, 32, Color(1, 0.62, 0.81, me.invuln / INVULN * 0.7), 2.0 / k)
	# 판정 (실제 크기)
	var hr := Tune.f("hit_radius")
	c.draw_circle(me.pos, maxf(hr, 1.0 / k), COL_ATTACK)
	if Tune.test_mode:
		c.draw_arc(me.pos, hr + BULLET_CORE, 0, TAU, 32, Color(1, 0.42, 0.54, 0.6), 1.0 / k)
	# 큰 별 하이라이트
	if running and zoom_t < 0.5:
		var h := pick(get_global_mouse_position(), 34.0 / k)
		if h:
			c.draw_arc(h.pos, 17, 0, TAU, 32, COL_ATTACK, 2.0)


func _make_glow() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


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

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 0.97, 0.9, 0)
	ui_root.add_child(flash_rect)

	# 스킬 (아래 가운데)
	skill_label = UI.label("", 14, UI.INK)
	skill_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skill_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.offset_bottom = -14
	ui_root.add_child(skill_label)

	# 곡 진행 (위 가운데)
	var song := VBoxContainer.new()
	song.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song.set_anchors_preset(Control.PRESET_CENTER_TOP)
	song.custom_minimum_size = Vector2(460, 0)
	song.position = Vector2(-230, 12)
	song.add_theme_constant_override("separation", 4)
	ui_root.add_child(song)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UI.label("♪ " + Track1.TITLE, 14, UI.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label = UI.label("0:00 / 1:36", 14, UI.DIM)
	row.add_child(title)
	row.add_child(time_label)
	song.add_child(row)
	song_bar = SongBar.new()
	song_bar.custom_minimum_size = Vector2(460, 12)
	song_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song.add_child(song_bar)
	scene_label = UI.label("", 16, UI.GOLD)
	scene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	song.add_child(scene_label)

	# HP, 격추 (왼쪽 위)
	var stats := VBoxContainer.new()
	stats.position = Vector2(14, 10)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(stats)
	hp_label = UI.label("", 18, Color("ff9fcf"))
	kill_label = UI.label("", 13, UI.DIM)
	stats.add_child(hp_label)
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
	view_btn = UI.button("전체 보기 (Tab)", false, 14)
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
		tools.offset_right = -350
		song.position.x -= 170
		skill_label.position.x -= 300
	else:
		tools.offset_right = -10
	tools.offset_bottom = -10

	# 오버레이
	ov_start = _overlay("하떨별", "노래 한 곡이 끝날 때까지 버티세요. HP가 다 닳으면 추락합니다.\nWASD 이동 · 큰 별 클릭하면 조준 후 자동 사격 · Space 대시 · Q 섬광 · Tab 누르고 있으면 전체 맵 · Esc 일시정지\n초록 테두리 밖으로는 못 나가요. 노란 경고선이 깜빡이면 바깥에서 탄 벽이 들어옵니다. 초록 틈으로 피하세요.", [["시작", start, true], ["메뉴로", _to_menu, false]])
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
	var w := clampf(full.x * 0.22, 160.0, 300.0)
	var h := w * world.y / world.x
	minimap.size = Vector2(w, h)
	minimap.position = Vector2(10, full.y - h - 10)
	cell_label.position = Vector2(12, full.y - h - 32)


func _overlay(title: String, text: String, buttons: Array) -> Control:
	var ov := ColorRect.new()
	ov.color = Color(0.008, 0.012, 0.04, 0.8)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(ov)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	cc.add_child(col)
	var tl := UI.label(title, 64, UI.GOLD)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tl)
	var tx := UI.label(text, 16, UI.DIM)
	tx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tx)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for b in buttons:
		var btn := UI.button(b[0], b[2], 16)
		btn.custom_minimum_size = Vector2(140, 44)
		btn.pressed.connect(b[1])
		row.add_child(btn)
	ov.set_meta("title", tl)
	ov.set_meta("text", tx)
	return ov


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
