extends Node2D

const W := 540.0
const H := 960.0
const GROUND_Y := 830.0
const BH := 34.0   # vertical distance between stacked pancakes (smaller = tighter stack)
const BASE_W := 260.0
const MIN_W := 70.0
const PERFECT_TOL := 7.0
const WOB_LIMIT := 45.0
const CAM_TOP := 660.0
const SLIDER_GAP := 150.0
const MASC_PLAY := 165.0
const PANCAKE_H := 1.9   # drawn pancake height as a multiple of BH (about 65 px)
const FALL_GRAV := 2600.0
const START_LIVES := 3
const MUSIC_BPM := 110
const MUSIC_NOTES := [
	[64, 0.5], [67, 0.5], [72, 1.0], [69, 0.5], [67, 0.5], [64, 1.0],
	[62, 0.5], [64, 0.5], [67, 1.0], [64, 0.5], [62, 0.5], [60, 1.0],
	[60, 0.5], [64, 0.5], [67, 1.0], [69, 0.5], [72, 0.5], [69, 1.0],
	[67, 1.0], [64, 1.0], [62, 1.0], [0, 1.0],
	[69, 0.5], [72, 0.5], [76, 1.0], [74, 0.5], [72, 0.5], [69, 1.0],
	[67, 0.5], [69, 0.5], [72, 1.0], [69, 0.5], [67, 0.5], [64, 1.0],
	[62, 0.5], [67, 0.5], [69, 1.0], [67, 0.5], [64, 0.5], [62, 1.0],
	[60, 2.0], [0, 2.0],
]   # [midi_note, beats], 0 = rest
const MILESTONES := {
	10: ["NICE!", Color(0.6, 1.0, 0.7)],
	25: ["WOW!", Color(1.0, 0.85, 0.3)],
	50: ["LEGEND!", Color(1.0, 0.5, 0.7)],
	100: ["UNSTOPPABLE!", Color(0.6, 0.8, 1.0)],
}
# Pool of daily tasks. 3 different kinds are picked each day, seeded by the date.
const TASK_POOL := [
	{"kind": "height", "goal": 15, "reward": 15, "name": "Stack 15 pancakes in one run"},
	{"kind": "height", "goal": 25, "reward": 20, "name": "Stack 25 pancakes in one run"},
	{"kind": "height", "goal": 40, "reward": 30, "name": "Stack 40 pancakes in one run"},
	{"kind": "row", "goal": 3, "reward": 15, "name": "Land 3 perfects in a row"},
	{"kind": "row", "goal": 5, "reward": 20, "name": "Land 5 perfects in a row"},
	{"kind": "heal", "goal": 1, "reward": 30, "name": "Win back a life"},
	{"kind": "perfects", "goal": 15, "reward": 20, "name": "Land 15 perfects today"},
	{"kind": "coins", "goal": 50, "reward": 20, "name": "Collect 50 coins in one run"},
	{"kind": "score", "goal": 40, "reward": 20, "name": "Score 40 in one run"},
	{"kind": "score", "goal": 80, "reward": 30, "name": "Score 80 in one run"},
]
const TASKS_RECT := Rect2(14, 76, 76, 76)
const MUTE_RECT := Rect2(450, 76, 76, 76)
const REVIVE_COST := 50
const REVIVE_RECT := Rect2(110, 365, 320, 80)
const SAVE_PATH := "user://save.cfg"

const MASCOTS := ["orpheus", "hedgehog"]
const OUTFITS := ["", "chef", "hacker", "wizard"]
const OUTFIT_COST := {"chef": 30, "hacker": 100, "wizard": 250}
const BGS := ["bg_sky", "bg_kitchen", "bg_night", "bg_peach", "bg_pink"]
const FOLDERS := ["", "characters/", "blocks/", "ui/", "backgrounds/"]
const TRIM := ["pancake", "plate", "rail", "coin", "heart", "heart_empty", "lock", "button", "logo", "clipboard", "tshirt", "sound_on", "sound_off"]

const GO_RECT := Rect2(150, 800, 240, 110)
const WARD_RECT := Rect2(30, 810, 100, 100)
const MASC_RECT := Rect2(410, 810, 100, 100)
const RETRY_RECT := Rect2(150, 240, 240, 110)
const HOME_RECT := Rect2(200, 850, 140, 56)
const BACK_RECT := Rect2(170, 890, 200, 54)
const TAB_RECTS := [Rect2(60, 478, 200, 56), Rect2(280, 478, 200, 56)]

var bg_fallback: Array = [Color("a8d8ff"), Color("ffe9a8"), Color("6c7396"), Color("ffc999"), Color("f8c8d8")]

var state := "title"
var t := 0.0

var best := 0
var total_coins := 0
var mascot := "orpheus"
var owned: Array = []
var outfit_of := {"orpheus": "", "hedgehog": ""}

var blocks: Array = []
var cur_x := 0.0
var cur_w := BASE_W
var slide_dir := 1.0
var dropping := false
var drop_y := 0.0
var lives := START_LIVES
var score := 0
var run_coins := 0
var combo := 0
var wob := 0.0
var cam := 0.0
var input_lock := 0.0
var is_dying := false
var over_delay := 0.0
var over_age := 0.0
var revived := false      # one paid revive per run
var was_low := false      # dropped to 1 life at some point (for the comeback bonus)
var task_date := ""
var task_ids: Array = [0, 3, 5]
var task_prog: Array = [0, 0, 0]
var task_done: Array = [false, false, false]
var heart_pulse := 0.0   # heart bounce animation timer (1 -> 0)

var hop_t := 1.0
var hop_amp := 55.0
var hop_speed := 3.2
var pose_name := "balance"
var pose_t := 0.0
var beam_t := 0.0
var beam_x := 0.0
var beam_y := 0.0
var shake := 0.0
var debris: Array = []
var popups: Array = []
var parts: Array = []

var _cache := {}
var snd := {}
var players: Array = []
var music: AudioStreamPlayer
var muted := false


func _ready() -> void:
	randomize()
	load_save()
	AudioServer.set_bus_mute(0, muted)
	build_sounds()
	start_music()
	queue_redraw()


func load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		check_task_day()
		return
	best = int(cf.get_value("g", "best", 0))
	total_coins = int(cf.get_value("g", "coins", 0))
	mascot = str(cf.get_value("g", "mascot", "orpheus"))
	owned = cf.get_value("g", "owned", [])
	outfit_of["orpheus"] = str(cf.get_value("g", "o_orpheus", ""))
	outfit_of["hedgehog"] = str(cf.get_value("g", "o_hedgehog", ""))
	muted = bool(cf.get_value("g", "muted", false))
	task_date = str(cf.get_value("g", "t_date", ""))
	var tp: Array = cf.get_value("g", "t_prog", [0, 0, 0])
	var td: Array = cf.get_value("g", "t_done", [false, false, false])
	if tp.size() == 3 and td.size() == 3:
		task_prog = tp
		task_done = td
	check_task_day()


## New day: progress resets. Today's 3 tasks are always picked from the date, so they change every day.
func check_task_day() -> void:
	var today := Time.get_date_string_from_system()
	if task_date != today:
		task_date = today
		task_prog = [0, 0, 0]
		task_done = [false, false, false]
	pick_tasks()


## Picks 3 tasks of different kinds, seeded by the date (same all day, different tomorrow).
func pick_tasks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = task_date.hash()
	var idx: Array = range(TASK_POOL.size())
	for a in range(idx.size() - 1, 0, -1):
		var b := rng.randi_range(0, a)
		var tmp: Variant = idx[a]
		idx[a] = idx[b]
		idx[b] = tmp
	var kinds: Array = []
	var picked: Array = []
	for k in idx:
		var kind: String = TASK_POOL[k]["kind"]
		if not kinds.has(kind):
			kinds.append(kind)
			picked.append(k)
			if picked.size() == 3:
				break
	task_ids = picked


## Tells every task of this kind about an event.
func task_event(kind: String, val: int) -> void:
	for i in 3:
		var tdef: Dictionary = TASK_POOL[int(task_ids[i])]
		if tdef["kind"] == kind:
			update_task(i, val)


## Progress for one task. Finishing it pays coins once per day.
func update_task(i: int, val: int) -> void:
	if bool(task_done[i]):
		return
	var tdef: Dictionary = TASK_POOL[int(task_ids[i])]
	if tdef["kind"] == "heal" or tdef["kind"] == "perfects":
		task_prog[i] = int(task_prog[i]) + val
	else:
		task_prog[i] = maxi(int(task_prog[i]), val)
	if int(task_prog[i]) >= int(tdef["goal"]):
		task_done[i] = true
		add_coins(int(tdef["reward"]))
		add_popup("TASK DONE! +%d" % int(tdef["reward"]), W * 0.5, 570.0, Color(0.6, 1.0, 0.7))
		play_snd("unlock")
		save_game()


## Popup and dance when the tower passes a milestone. Returns true if one was hit.
func check_milestone(n: int) -> bool:
	if not MILESTONES.has(n):
		return false
	var m: Array = MILESTONES[n]
	add_popup(str(m[0]), W * 0.5, 270.0, m[1])
	burst(Vector2(W * 0.5, 420.0), 24, m[1])
	set_pose("happy", 1.2)
	play_snd("unlock")
	return true


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("g", "best", best)
	cf.set_value("g", "coins", total_coins)
	cf.set_value("g", "mascot", mascot)
	cf.set_value("g", "owned", owned)
	cf.set_value("g", "o_orpheus", outfit_of["orpheus"])
	cf.set_value("g", "o_hedgehog", outfit_of["hedgehog"])
	cf.set_value("g", "muted", muted)
	cf.set_value("g", "t_date", task_date)
	cf.set_value("g", "t_prog", task_prog)
	cf.set_value("g", "t_done", task_done)
	cf.save(SAVE_PATH)


## Procedural sound: builds a simple sine/square/noise wave with a fade-out envelope.
func make_wave(freq: float, dur: float, vol: float = 0.35, slide: float = 0.0, kind: int = 0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var p: float = float(i) / float(n)
		var f: float = freq + slide * p
		phase += TAU * f / float(rate)
		var s: float = sin(phase)
		if kind == 1:
			s = 1.0 if s > 0.0 else -1.0
		elif kind == 2:
			s = randf() * 2.0 - 1.0
		var env: float = (1.0 - p) * minf(1.0, float(i) / 200.0)
		var v: int = int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func build_sounds() -> void:
	snd["click"] = make_wave(520.0, 0.06, 0.3, 200.0, 1)
	snd["cut"] = make_wave(150.0, 0.16, 0.4, -60.0, 2)
	snd["perfect"] = make_wave(660.0, 0.28, 0.35, 520.0, 0)
	snd["miss"] = make_wave(320.0, 0.40, 0.35, -220.0, 1)
	snd["life"] = make_wave(240.0, 0.40, 0.4, -170.0, 1)
	snd["heal"] = make_wave(500.0, 0.35, 0.35, 700.0, 0)
	snd["over"] = make_wave(330.0, 0.70, 0.4, -270.0, 1)
	snd["unlock"] = make_wave(520.0, 0.30, 0.35, 500.0, 0)
	snd["no"] = make_wave(160.0, 0.15, 0.35, 0.0, 1)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


## Background music. Uses assets/music.ogg or music.mp3 if present, otherwise plays the tune in MUSIC_NOTES (if any).
func start_music() -> void:
	var stream: AudioStream = null
	for ext in ["ogg", "mp3"]:
		var path := "res://assets/music.%s" % ext
		if ResourceLoader.exists(path):
			var loaded = load(path)
			if loaded is AudioStreamOggVorbis:
				loaded.loop = true
				stream = loaded
			elif loaded is AudioStreamMP3:
				loaded.loop = true
				stream = loaded
			if stream != null:
				break
	if stream == null and not MUSIC_NOTES.is_empty():
		stream = build_tune()
	if stream == null:
		return
	music = AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = -12.0
	add_child(music)
	music.play()


## Turns MUSIC_NOTES into a looping wave with a soft synth tone.
func build_tune() -> AudioStreamWAV:
	var rate := 22050
	var spb: float = 60.0 / float(MUSIC_BPM)
	var data := PackedByteArray()
	var phase := 0.0
	for n in MUSIC_NOTES:
		var midi: int = int(n[0])
		var beats: float = float(n[1])
		var count: int = int(float(rate) * spb * beats)
		var base: int = data.size()
		data.resize(base + count * 2)
		var freq: float = 440.0 * pow(2.0, float(midi - 69) / 12.0)
		for i in count:
			var p: float = float(i) / float(count)
			var env: float = minf(1.0, float(i) / 300.0) * minf(1.0, (1.0 - p) * 6.0)
			var v := 0.0
			if midi > 0:
				phase += TAU * freq / float(rate)
				v = sin(phase) * 0.7 + sin(phase * 2.0) * 0.15
			data.encode_s16(base + i * 2, int(clampf(v * env * 0.3, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(data.size() / 2)
	return w


## Mutes or unmutes all audio (music and sound effects) and remembers the choice.
func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	save_game()
	if not muted:
		play_snd("click")


func play_snd(nm: String) -> void:
	if not snd.has(nm):
		return
	for p in players:
		var ap: AudioStreamPlayer = p
		if not ap.playing:
			ap.stream = snd[nm]
			ap.play()
			return


## Texture loader with cache. Transparent padding is auto-trimmed so any exported art lines up.
func get_tex(nm: String) -> Dictionary:
	if _cache.has(nm):
		return _cache[nm]
	var entry := {"t": null, "r": Rect2()}
	for f in FOLDERS:
		var path := "res://assets/%s%s.png" % [f, nm]
		if ResourceLoader.exists(path):
			var tx := load(path) as Texture2D
			if tx != null:
				entry["t"] = tx
				var r := Rect2(Vector2.ZERO, tx.get_size())
				if nm in TRIM:
					var img := tx.get_image()
					if img != null:
						if img.is_compressed():
							img.decompress()
						var ur := alpha_rect(img)
						if ur.size.x > 0.0 and ur.size.y > 0.0:
							r = ur
				entry["r"] = r
				break
	_cache[nm] = entry
	return entry


## Bounding box of the visible pixels. Ignores faint leftover alpha (shadows, background-remover fringe).
func alpha_rect(img: Image) -> Rect2:
	var iw := img.get_width()
	var ih := img.get_height()
	var sc: float = minf(1.0, 160.0 / float(maxi(iw, ih)))
	var small: Image = img.duplicate()
	small.resize(maxi(1, int(iw * sc)), maxi(1, int(ih * sc)))
	var x0 := small.get_width()
	var y0 := small.get_height()
	var x1 := -1
	var y1 := -1
	for y in small.get_height():
		for x in small.get_width():
			if small.get_pixel(x, y).a > 0.3:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2(0, 0, iw, ih)
	var rx: float = floorf(float(x0) / sc)
	var ry: float = floorf(float(y0) / sc)
	var rw: float = minf(ceilf(float(x1 + 1) / sc), float(iw)) - rx
	var rh: float = minf(ceilf(float(y1 + 1) / sc), float(ih)) - ry
	return Rect2(rx, ry, rw, rh)


func dimg(nm: String, rect: Rect2, mod: Color = Color.WHITE) -> bool:
	var e: Dictionary = get_tex(nm)
	if e["t"] == null:
		return false
	draw_texture_rect_region(e["t"], rect, e["r"], mod)
	return true


func dfit(nm: String, center: Vector2, max_w: float, max_h: float, mod: Color = Color.WHITE) -> bool:
	var e: Dictionary = get_tex(nm)
	if e["t"] == null:
		return false
	var r: Rect2 = e["r"]
	var sc: float = minf(max_w / r.size.x, max_h / r.size.y)
	var sz: Vector2 = r.size * sc
	draw_texture_rect_region(e["t"], Rect2(center - sz * 0.5, sz), r, mod)
	return true


func txt(s: String, cx: float, y: float, size: int, col: Color = Color.WHITE, outline: int = 8) -> void:
	var f: Font = ThemeDB.fallback_font
	var pos := Vector2(cx - 300.0, y)
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_CENTER, 600.0, size, outline, Color(0.18, 0.2, 0.3))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_CENTER, 600.0, size, col)


func draw_button(r: Rect2, label: String, size: int, col: Color) -> void:
	if not dimg("button", r):
		draw_rect(r, Color(0.95, 0.97, 1.0))
		draw_rect(r, Color(0.45, 0.52, 0.68), false, 5.0)
	txt(label, r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5 + size * 0.35, size, col, 6)


## Button with an icon image (assets/ui/<icon>.png). Falls back to text if the icon is missing.
func draw_icon_button(r: Rect2, icon: String, label: String) -> void:
	draw_button(r, "", 24, Color.WHITE)
	if not dfit(icon, r.get_center(), r.size.x * 0.7, r.size.y * 0.7):
		txt(label, r.get_center().x, r.get_center().y + 7.0, 18, Color(0.4, 0.5, 0.7), 5)


func draw_bg(idx: int) -> void:
	var nm: String = BGS[idx % BGS.size()]
	var e: Dictionary = get_tex(nm)
	if e["t"] != null:
		var tex: Texture2D = e["t"]
		var ts: Vector2 = tex.get_size()
		var sc: float = maxf(W / ts.x, H / ts.y)
		var src_size := Vector2(W, H) / sc
		var src := Rect2((ts - src_size) * 0.5, src_size)
		draw_texture_rect_region(tex, Rect2(0, 0, W, H), src)
		return
	draw_rect(Rect2(0, 0, W, H), bg_fallback[idx % bg_fallback.size()])
	draw_rect(Rect2(0, H - 130, W, 130), Color(0.78, 0.58, 0.38))


func draw_plate(gy: float) -> void:
	if not dfit("plate", Vector2(W * 0.5, gy + 18.0), 420.0, 170.0):
		draw_rect(Rect2(W * 0.5 - 190, gy, 380, 26), Color(0.93, 0.9, 1.0))
		draw_rect(Rect2(W * 0.5 - 190, gy, 380, 26), Color(0.5, 0.45, 0.7), false, 4.0)


## Draws a pancake; sy gives the squash and stretch bounce.
func dpancake(cx: float, ytop: float, w: float, mod: Color = Color.WHITE, sy: float = 1.0) -> void:
	var full_h: float = BH * PANCAKE_H * sy
	var bottom: float = ytop + BH * 1.1
	var r := Rect2(cx - w * 0.5, bottom - full_h, w, full_h)
	if dimg("pancake", r, mod):
		return
	draw_rect(Rect2(cx - w * 0.5, ytop, w, BH), Color(0.93, 0.7, 0.3) * mod)
	draw_rect(Rect2(cx - w * 0.5, ytop, w, BH * 0.4), Color(0.8, 0.5, 0.15) * mod)
	draw_rect(Rect2(cx - w * 0.5 + w * 0.4, ytop + 4.0, w * 0.2, 10.0), Color(1.0, 0.92, 0.45) * mod)
	draw_rect(Rect2(cx - w * 0.5, ytop, w, BH), Color(0.25, 0.15, 0.08), false, 3.0)


func draw_heart(c: Vector2, full: bool, sc: float = 1.0) -> void:
	var nm := "heart" if full else "heart_empty"
	if dfit(nm, c, 44.0 * sc, 44.0 * sc):
		return
	var col := Color(0.9, 0.2, 0.25) if full else Color(0.7, 0.7, 0.72)
	draw_circle(c + Vector2(-9, -5) * sc, 11.0 * sc, col)
	draw_circle(c + Vector2(9, -5) * sc, 11.0 * sc, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-19, -1) * sc, c + Vector2(19, -1) * sc, c + Vector2(0, 20) * sc]), col)


func draw_coin_pill() -> void:
	draw_rect(Rect2(14, 14, 180, 52), Color(0.1, 0.15, 0.3, 0.45))
	if not dfit("coin", Vector2(42, 40), 38.0, 38.0):
		draw_circle(Vector2(42, 40), 17.0, Color(1.0, 0.85, 0.2))
		draw_arc(Vector2(42, 40), 17.0, 0.0, TAU, 24, Color(0.3, 0.2, 0.0), 3.0)
	txt(str(total_coins), 125.0, 52.0, 32, Color(1.0, 0.95, 0.4), 6)


func draw_mascot(m: String, outfit: String, pose: String, feet: Vector2, size: float) -> void:
	var nm: String
	if pose == "cry":
		nm = m + "_cry"
	elif outfit != "":
		nm = m + "_" + outfit
	else:
		nm = m + "_" + pose
	if get_tex(nm)["t"] == null:
		nm = m + "_" + pose
	var rect := Rect2(feet.x - size * 0.5, feet.y - size * 0.93, size, size)
	if dimg(nm, rect):
		return
	var body := Color(1, 1, 1) if m == "orpheus" else Color(1.0, 0.72, 0.5)
	var c := Vector2(feet.x, feet.y - size * 0.36)
	draw_circle(c, size * 0.29, Color(0.15, 0.15, 0.15))
	draw_circle(c, size * 0.265, body)
	draw_circle(c + Vector2(-size * 0.08, -size * 0.05), size * 0.025, Color.BLACK)
	draw_circle(c + Vector2(size * 0.08, -size * 0.05), size * 0.025, Color.BLACK)
	if pose == "cry":
		draw_arc(c + Vector2(0, size * 0.12), size * 0.07, PI + 0.3, TAU - 0.3, 10, Color.BLACK, 3.0)
		draw_circle(c + Vector2(-size * 0.1, size * 0.0), size * 0.02, Color(0.3, 0.6, 1.0))
	else:
		draw_arc(c + Vector2(0, size * 0.03), size * 0.08, 0.3, PI - 0.3, 10, Color.BLACK, 3.0)
	draw_line(c + Vector2(-size * 0.26, 0), c + Vector2(-size * 0.42, -size * 0.06), Color.BLACK, 6.0)
	draw_line(c + Vector2(size * 0.26, 0), c + Vector2(size * 0.42, -size * 0.06), Color.BLACK, 6.0)
	draw_line(c + Vector2(-size * 0.08, size * 0.26), c + Vector2(-size * 0.08, size * 0.36), Color.BLACK, 6.0)
	draw_line(c + Vector2(size * 0.08, size * 0.26), c + Vector2(size * 0.08, size * 0.36), Color.BLACK, 6.0)


func new_game() -> void:
	blocks = [{"x": W * 0.5, "w": BASE_W}]
	lives = START_LIVES
	score = 0
	run_coins = 0
	combo = 0
	wob = 0.0
	cam = 0.0
	dropping = false
	is_dying = false
	over_delay = 0.0
	over_age = 0.0
	debris.clear()
	popups.clear()
	parts.clear()
	hop_t = 1.0
	pose_t = 0.0
	beam_t = 0.0
	shake = 0.0
	input_lock = 0.25
	check_task_day()
	revived = false
	was_low = false
	heart_pulse = 0.0
	spawn_slider()
	state = "play"


func spawn_slider() -> void:
	var top: Dictionary = blocks.back()
	cur_w = top["w"]
	var from_left := randf() < 0.5
	cur_x = -cur_w * 0.5 if from_left else W + cur_w * 0.5
	slide_dir = 1.0 if from_left else -1.0


## Difficulty curve: speed rises every 20 blocks up to a cap.
func slide_speed() -> float:
	return clampf(230.0 + 40.0 * floorf(blocks.size() / 20.0), 230.0, 420.0)


func top_world_y() -> float:
	return GROUND_Y - float(blocks.size()) * BH


func slider_top() -> float:
	return top_world_y() - SLIDER_GAP - BH


func bg_index() -> int:
	return int(floorf(blocks.size() / 10.0)) % BGS.size()


## Tower wobble effect: sway grows toward the top; too much wobble topples the tower.
func sway(i: int) -> float:
	var n := blocks.size()
	if n <= 1:
		return 0.0
	return wob * 0.6 * sin(t * 2.3) * float(i) / float(maxi(n - 1, 8))


func set_pose(p: String, dur: float) -> void:
	pose_name = p
	pose_t = dur


func add_popup(s: String, x: float, y: float, col: Color) -> void:
	popups.append({"s": s, "x": x, "y": y, "life": 1.1, "col": col})


func add_coins(n: int) -> void:
	run_coins += n
	total_coins += n


func burst(p: Vector2, n: int, col: Color) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(80.0, 280.0)
		parts.append({"p": p, "v": Vector2(cos(a), sin(a) - 0.6) * sp, "life": randf_range(0.5, 0.9), "col": col})


func add_debris(x: float, y_screen: float, w: float, dir: float, is_miss: bool) -> void:
	var d := dir
	if d == 0.0:
		d = 1.0 if randf() < 0.5 else -1.0
	var speed := 420.0 if is_miss else randf_range(220.0, 320.0)
	debris.append({
		"x": x, "y": y_screen, "w": maxf(w, 20.0),
		"vx": d * speed, "vy": 0.0 if is_miss else -60.0,
		"rot": 0.0, "vr": d * randf_range(0.3, 1.0), "miss": is_miss
	})


func lose_life() -> void:
	lives -= 1
	if lives == 1:
		was_low = true
	shake = 0.3
	set_pose("cry", 0.9)
	if lives <= 0:
		is_dying = true
		over_delay = 0.8
		set_pose("cry", 5.0)
		play_snd("over")
	else:
		play_snd("life")


func play_tap() -> void:
	if dropping or is_dying or input_lock > 0.0:
		return
	dropping = true
	drop_y = slider_top()


## Core mechanic. Perfect: bonus coins and score. Slightly off: overhang is cut off.
## Very off: cut plus a lost life. Full miss: the pancake flies off the side and a life is lost.
func resolve_drop() -> void:
	dropping = false
	var top: Dictionary = blocks.back()
	var tx: float = top["x"]
	var tw: float = top["w"]
	var d: float = cur_x - tx
	var overlap: float = cur_w - absf(d)
	var land_y: float = top_world_y() - BH

	if overlap < 14.0:
		var mdir: float = 1.0 if d > 0.0 else -1.0
		add_debris(cur_x, land_y + cam, cur_w, mdir, true)
		combo = 0
		play_snd("miss")
		add_popup("MISS!", W * 0.5, 330.0, Color(1.0, 0.45, 0.45))
		lose_life()
		hop_amp = 150.0
		hop_speed = 1.9
		hop_t = 0.0
		spawn_slider()
		return

	if absf(d) <= PERFECT_TOL:
		blocks.append({"x": tx, "w": tw})
		combo += 1
		task_event("row", combo)
		task_event("perfects", 1)
		score += 2
		add_coins(3)
		wob = maxf(0.0, wob - 8.0)
		beam_t = 0.5
		beam_x = tx
		beam_y = land_y
		set_pose("happy", 0.7)
		burst(Vector2(tx, land_y + cam), 14, Color(1.0, 0.95, 0.5))
		var label := "PERFECT!" if combo < 2 else "PERFECT x%d" % combo
		add_popup(label, W * 0.5, 330.0, Color(1.0, 0.95, 0.4))
		play_snd("perfect")
		if combo >= 5 and lives < START_LIVES:
			lives += 1
			combo = 0
			pop_heart()
			task_event("heal", 1)
			if lives == START_LIVES and was_low:
				was_low = false
				add_coins(10)
				add_popup("COMEBACK! +10 coins", W * 0.5, 510.0, Color(1.0, 0.85, 0.3))
			add_popup("BOUNCE BACK! +1 LIFE", W * 0.5, 390.0, Color(1.0, 0.6, 0.7))
			play_snd("heal")
	else:
		var left: float = maxf(cur_x - cur_w * 0.5, tx - tw * 0.5)
		var right: float = minf(cur_x + cur_w * 0.5, tx + tw * 0.5)
		var nw: float = maxf(right - left, MIN_W)
		var nx: float = (left + right) * 0.5
		var cut_w: float = cur_w - (right - left)
		if cur_x > tx:
			add_debris(right + cut_w * 0.5, land_y + cam, cut_w, 1.0, false)
		else:
			add_debris(left - cut_w * 0.5, land_y + cam, cut_w, -1.0, false)
		blocks.append({"x": nx, "w": nw})
		score += 1
		add_coins(1)
		combo = 0
		play_snd("cut")
		if overlap < cur_w * 0.45:
			wob += 16.0
			add_popup("TOO OFF!", W * 0.5, 330.0, Color(1.0, 0.5, 0.4))
			lose_life()
		else:
			wob += 4.0
	task_event("height", blocks.size() - 1)
	task_event("score", score)
	task_event("coins", run_coins)
	if check_milestone(blocks.size() - 1):
		hop_amp = 130.0
		hop_speed = 2.2
	else:
		hop_amp = 55.0
		hop_speed = 3.2
	hop_t = 0.0
	spawn_slider()


## Life gained: the new heart bounces, sparkles, and the screen shakes.
func pop_heart() -> void:
	heart_pulse = 1.0
	shake = 0.25
	burst(Vector2(W - 40.0 - float(lives - 1) * 50.0, 40.0), 14, Color(1.0, 0.5, 0.65))


## Paid revive: spend coins to continue the run with 1 life.
func try_revive() -> void:
	if total_coins < REVIVE_COST:
		play_snd("no")
		return
	total_coins -= REVIVE_COST
	revived = true
	was_low = true
	lives = 1
	pop_heart()
	is_dying = false
	dropping = false
	wob = 0.0
	combo = 0
	pose_t = 0.0
	input_lock = 0.5
	save_game()
	add_popup("BOUNCE BACK!", W * 0.5, 330.0, Color(1.0, 0.6, 0.7))
	play_snd("heal")
	spawn_slider()
	state = "play"


## Wobble limit reached: the top pancakes fall and a life is lost.
func topple() -> void:
	var remove := mini(3, blocks.size() - 1)
	for i in remove:
		var b: Dictionary = blocks.pop_back()
		var y_top: float = GROUND_Y - float(blocks.size() + 1) * BH
		var side: float = 1.0 if randf() < 0.5 else -1.0
		add_debris(b["x"], y_top + cam, b["w"], side, false)
	wob = 0.0
	add_popup("TOWER FELL!", W * 0.5, 330.0, Color(1.0, 0.5, 0.4))
	lose_life()
	var top: Dictionary = blocks.back()
	cur_w = top["w"]


func finish_game() -> void:
	state = "over"
	over_age = 0.0
	if score > best:
		best = score
	save_game()


func _process(dt: float) -> void:
	t += dt
	match state:
		"play":
			update_play(dt)
		"over":
			over_age += dt
			update_effects(dt)
		_:
			pass
	queue_redraw()


func update_effects(dt: float) -> void:
	hop_t = minf(1.0, hop_t + dt * hop_speed)
	pose_t = maxf(0.0, pose_t - dt)
	beam_t = maxf(0.0, beam_t - dt)
	shake = maxf(0.0, shake - dt)
	heart_pulse = maxf(0.0, heart_pulse - dt * 1.4)

	var i := debris.size() - 1
	while i >= 0:
		var d: Dictionary = debris[i]
		d["vy"] = float(d["vy"]) + FALL_GRAV * dt
		d["x"] = float(d["x"]) + float(d["vx"]) * dt
		d["y"] = float(d["y"]) + float(d["vy"]) * dt
		d["rot"] = float(d["rot"]) + float(d["vr"]) * dt
		if float(d["y"]) > H + 150.0 or float(d["x"]) < -300.0 or float(d["x"]) > W + 300.0:
			debris.remove_at(i)
		i -= 1

	i = parts.size() - 1
	while i >= 0:
		var p: Dictionary = parts[i]
		var v: Vector2 = p["v"]
		v.y += 600.0 * dt
		p["v"] = v
		p["p"] = Vector2(p["p"]) + v * dt
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			parts.remove_at(i)
		i -= 1

	i = popups.size() - 1
	while i >= 0:
		var q: Dictionary = popups[i]
		q["y"] = float(q["y"]) - 50.0 * dt
		q["life"] = float(q["life"]) - dt
		if float(q["life"]) <= 0.0:
			popups.remove_at(i)
		i -= 1


func update_play(dt: float) -> void:
	input_lock = maxf(0.0, input_lock - dt)
	update_effects(dt)

	var cam_target: float = maxf(0.0, CAM_TOP - top_world_y())
	cam = lerpf(cam, cam_target, 1.0 - exp(-6.0 * dt))

	if is_dying:
		over_delay -= dt
		if over_delay <= 0.0:
			finish_game()
		return

	wob = maxf(0.0, wob - 1.0 * dt)
	if wob >= WOB_LIMIT and not dropping:
		topple()
		if is_dying:
			return

	if dropping:
		drop_y += 1500.0 * dt
		if drop_y >= top_world_y() - BH:
			resolve_drop()
	else:
		cur_x += slide_dir * slide_speed() * dt
		if cur_x > W - cur_w * 0.5 + 30.0:
			slide_dir = -1.0
		elif cur_x < cur_w * 0.5 - 30.0:
			slide_dir = 1.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			handle_tap(get_local_mouse_position())
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_SPACE:
			handle_tap(Vector2(-100, -100))


func handle_tap(p: Vector2) -> void:
	match state:
		"title":
			if GO_RECT.has_point(p):
				play_snd("click")
				new_game()
			elif MUTE_RECT.has_point(p):
				toggle_mute()
			elif TASKS_RECT.has_point(p):
				play_snd("click")
				check_task_day()
				state = "tasks"
			elif WARD_RECT.has_point(p):
				play_snd("click")
				state = "wardrobe"
			elif MASC_RECT.has_point(p):
				play_snd("click")
				var idx: int = (MASCOTS.find(mascot) + 1) % MASCOTS.size()
				mascot = MASCOTS[idx]
				save_game()
		"wardrobe":
			if BACK_RECT.has_point(p):
				play_snd("click")
				save_game()
				state = "title"
				return
			for i in 2:
				var tr: Rect2 = TAB_RECTS[i]
				if tr.has_point(p):
					mascot = MASCOTS[i]
					play_snd("click")
			for i in 4:
				if cell_rect(i).has_point(p):
					select_outfit(OUTFITS[i])
		"tasks":
			if BACK_RECT.has_point(p):
				play_snd("click")
				state = "title"
		"play":
			if MUTE_RECT.has_point(p):
				toggle_mute()
			else:
				play_tap()
		"over":
			if over_age < 0.35:
				return
			if not revived and REVIVE_RECT.has_point(p):
				try_revive()
				return
			if RETRY_RECT.has_point(p) or p.x < 0.0:
				play_snd("click")
				new_game()
			elif HOME_RECT.has_point(p):
				play_snd("click")
				state = "title"


func cell_rect(i: int) -> Rect2:
	var col := i % 2
	var row := floori(i / 2.0)
	return Rect2(80.0 + col * 200.0, 548.0 + row * 174.0, 180.0, 160.0)


func is_owned(m: String, o: String) -> bool:
	return o == "" or owned.has(m + "_" + o)


func select_outfit(o: String) -> void:
	if is_owned(mascot, o):
		outfit_of[mascot] = o
		play_snd("click")
	else:
		var cost: int = OUTFIT_COST[o]
		if total_coins >= cost:
			total_coins -= cost
			owned.append(mascot + "_" + o)
			outfit_of[mascot] = o
			play_snd("unlock")
		else:
			play_snd("no")
	save_game()


func _draw() -> void:
	match state:
		"title":
			draw_title()
		"wardrobe":
			draw_wardrobe()
		"tasks":
			draw_tasks()
		"play":
			draw_play(true)
		"over":
			draw_play(false)
			draw_over()


func draw_title() -> void:
	draw_bg(0)
	draw_coin_pill()
	txt("BEST " + str(best), W - 110.0, 52.0, 30, Color.WHITE, 6)
	if not dfit("logo", Vector2(W * 0.5, 190.0), 470.0, 230.0):
		txt("STACK", W * 0.5, 160.0, 96, Color(1.0, 0.85, 0.3), 12)
		txt("ATTACK", W * 0.5, 255.0, 96, Color(1.0, 0.55, 0.45), 12)
	txt("BOUNCE BACK", W * 0.5, 345.0, 34, Color(1.0, 0.95, 0.7), 7)
	var gy := 640.0
	draw_plate(gy)
	dpancake(W * 0.5, gy - BH, BASE_W)
	var bob: float = sin(t * 3.0) * 3.0
	draw_mascot(mascot, outfit_of[mascot], "balance", Vector2(W * 0.5, gy - BH + 4.0 + bob), 270.0)
	draw_button(GO_RECT, "GO", 72, Color(0.9, 0.35, 0.35))
	draw_icon_button(WARD_RECT, "tshirt", "DRESS")
	draw_icon_button(TASKS_RECT, "clipboard", "TASKS")
	draw_icon_button(MUTE_RECT, "sound_off" if muted else "sound_on", "OFF" if muted else "ON")
	draw_button(MASC_RECT, "", 24, Color(0.4, 0.5, 0.7))
	var other: String = MASCOTS[(MASCOTS.find(mascot) + 1) % MASCOTS.size()]
	draw_mascot(other, "", "balance", MASC_RECT.position + Vector2(50, 90), 100.0)


func draw_wardrobe() -> void:
	draw_bg(1)
	draw_coin_pill()
	txt("WARDROBE", W * 0.5, 110.0, 58, Color(1.0, 0.85, 0.3), 10)
	var gy := 430.0
	draw_plate(gy)
	dpancake(W * 0.5, gy - BH, BASE_W)
	draw_mascot(mascot, outfit_of[mascot], "balance", Vector2(W * 0.5, gy - BH + 4.0), 290.0)
	for i in 2:
		var tr: Rect2 = TAB_RECTS[i]
		draw_button(tr, MASCOTS[i].to_upper(), 26, Color(0.9, 0.35, 0.35) if MASCOTS[i] == mascot else Color(0.4, 0.5, 0.7))
	for i in 4:
		var r := cell_rect(i)
		var o: String = OUTFITS[i]
		draw_rect(r, Color(0.9, 0.93, 0.98, 0.92))
		draw_rect(r, Color(0.5, 0.58, 0.72), false, 4.0)
		draw_mascot(mascot, o, "balance", Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y - 4.0), 170.0)
		if not is_owned(mascot, o):
			draw_rect(r, Color(0.1, 0.12, 0.2, 0.62))
			if not dfit("lock", Vector2(r.position.x + r.size.x * 0.5, r.position.y + 62.0), 60.0, 60.0):
				draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 22.0, r.position.y + 50.0, 44.0, 34.0), Color(1.0, 0.85, 0.2))
			txt(str(OUTFIT_COST[o]), r.position.x + r.size.x * 0.5, r.position.y + 138.0, 34, Color(1.0, 0.95, 0.4), 6)
		if outfit_of[mascot] == o:
			draw_rect(r, Color(0.9, 0.3, 0.3), false, 6.0)
	draw_button(BACK_RECT, "BACK", 30, Color(0.4, 0.5, 0.7))


func draw_tasks() -> void:
	draw_bg(2)
	draw_coin_pill()
	txt("DAILY TASKS", W * 0.5, 160.0, 58, Color(1.0, 0.85, 0.3), 10)
	for i in 3:
		var tdef: Dictionary = TASK_POOL[int(task_ids[i])]
		var r := Rect2(40.0, 220.0 + float(i) * 170.0, 460.0, 150.0)
		draw_rect(r, Color(0.1, 0.15, 0.3, 0.8))
		draw_rect(r, Color(0.5, 0.58, 0.72), false, 4.0)
		txt(str(tdef["name"]), r.position.x + r.size.x * 0.5, r.position.y + 55.0, 28, Color.WHITE, 5)
		var goal: int = int(tdef["goal"])
		var prog: int = mini(int(task_prog[i]), goal)
		var bar := Rect2(r.position.x + 30.0, r.position.y + 80.0, r.size.x - 60.0, 22.0)
		draw_rect(bar, Color(0.25, 0.3, 0.45))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(prog) / float(goal), bar.size.y)), Color(0.6, 1.0, 0.7))
		if bool(task_done[i]):
			txt("DONE!  +%d coins" % int(tdef["reward"]), r.position.x + r.size.x * 0.5, r.position.y + 132.0, 26, Color(0.6, 1.0, 0.7), 5)
		else:
			txt("%d / %d     reward +%d coins" % [prog, goal, int(tdef["reward"])], r.position.x + r.size.x * 0.5, r.position.y + 132.0, 26, Color(1.0, 0.95, 0.4), 5)
	txt("New tasks every day", W * 0.5, 800.0, 28, Color.WHITE, 5)
	draw_button(BACK_RECT, "BACK", 30, Color(0.4, 0.5, 0.7))


func draw_play(show_hud: bool) -> void:
	draw_bg(bg_index())
	var shake_off := Vector2.ZERO
	if shake > 0.0:
		shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 24.0
	draw_set_transform(shake_off, 0.0, Vector2.ONE)

	draw_plate(GROUND_Y + cam)

	if beam_t > 0.0:
		draw_rect(Rect2(beam_x - 70.0, beam_y + cam - 620.0, 140.0, 620.0 + BH), Color(1.0, 1.0, 0.8, beam_t * 0.9))

	var n := blocks.size()
	for i in n:
		var b: Dictionary = blocks[i]
		var bx: float = float(b["x"]) + sway(i)
		var ytop: float = GROUND_Y - float(i + 1) * BH + cam
		var sy := 1.0
		if i == n - 1 and hop_t < 1.0:
			sy = 1.0 - sin(hop_t * PI * 2.0) * (1.0 - hop_t) * 0.3
		dpancake(bx, ytop, float(b["w"]), Color.WHITE, sy)

	var top_b: Dictionary = blocks[n - 1]
	var mx: float = float(top_b["x"]) + sway(n - 1)
	var feet_y: float = GROUND_Y - float(n) * BH + cam + 4.0
	feet_y += sin(t * 3.0) * 2.0 - sin(clampf(hop_t, 0.0, 1.0) * PI) * hop_amp
	var pose := "balance"
	if pose_t > 0.0 and pose_name == "cry":
		pose = "cry"
	elif hop_t < 1.0:
		pose = "jump"
	elif pose_t > 0.0:
		pose = pose_name
	draw_mascot(mascot, outfit_of[mascot], pose, Vector2(mx, feet_y), MASC_PLAY)
	if wob > WOB_LIMIT * 0.6 and sin(t * 12.0) > -0.3:
		txt("!", mx + 70.0, feet_y - 140.0, 70, Color(1.0, 0.25, 0.25), 10)

	if not is_dying:
		var st: float = (drop_y if dropping else slider_top()) + cam
		var rail_y: float = slider_top() + cam + BH * 0.8
		if not dimg("rail", Rect2(0.0, rail_y, W, 30.0)):
			draw_rect(Rect2(0.0, rail_y, W, 14.0), Color(0.7, 0.5, 0.3))
		dpancake(cur_x, st, cur_w)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for d in debris:
		var dd: Dictionary = d
		draw_set_transform(Vector2(float(dd["x"]), float(dd["y"]) + BH * 0.5), float(dd["rot"]), Vector2.ONE)
		dpancake(0.0, -BH * 0.5, float(dd["w"]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for p in parts:
		var pd: Dictionary = p
		var life: float = float(pd["life"])
		draw_circle(pd["p"], 4.0 + 5.0 * life, Color(pd["col"]))

	if show_hud:
		draw_hud()
	for q in popups:
		var qd: Dictionary = q
		var a: float = clampf(float(qd["life"]) * 2.0, 0.0, 1.0)
		var c: Color = qd["col"]
		c.a = a
		txt(str(qd["s"]), float(qd["x"]), float(qd["y"]), 46, c, 8)


func draw_hud() -> void:
	draw_coin_pill()
	draw_icon_button(MUTE_RECT, "sound_off" if muted else "sound_on", "OFF" if muted else "ON")
	for i in START_LIVES:
		var hs := 1.0
		if i == lives - 1 and heart_pulse > 0.0:
			hs = 1.0 + 0.7 * sin(heart_pulse * PI)
		draw_heart(Vector2(W - 40.0 - float(i) * 50.0, 40.0), i < lives, hs)
	txt(str(score), W * 0.5, 190.0, 110, Color.WHITE, 12)


func draw_over() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.12, 0.2, 0.55))
	txt(str(score), W * 0.5, 190.0, 110, Color.WHITE, 12)
	draw_button(RETRY_RECT, "RETRY", 54, Color(0.9, 0.35, 0.35))
	draw_mascot(mascot, "", "cry", Vector2(W * 0.5, 800.0), 380.0)
	if not revived:
		var can := total_coins >= REVIVE_COST
		draw_button(REVIVE_RECT, "BOUNCE BACK %d" % REVIVE_COST, 30, Color(0.9, 0.35, 0.35) if can else Color(0.5, 0.5, 0.55))
	var line := "BEST " + str(best) + "     +" + str(run_coins) + " coins"
	txt(line, W * 0.5, 838.0, 34, Color.WHITE, 6)
	draw_button(HOME_RECT, "HOME", 28, Color(0.4, 0.5, 0.7))
