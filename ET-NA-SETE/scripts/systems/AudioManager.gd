# AudioManager - Autoload: efeitos, música e ambiente com bus separados.
extends Node

var sfx_cache := {}
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

func _ready():
	AudioServer.add_bus(1); AudioServer.set_bus_name(1, "SFX")
	AudioServer.add_bus(2); AudioServer.set_bus_name(2, "Music")
	music_player = AudioStreamPlayer.new(); music_player.bus = "Music"; add_child(music_player)
	ambient_player = AudioStreamPlayer.new(); ambient_player.bus = "SFX"; ambient_player.volume_db = -14.0
	add_child(ambient_player)

func _load(name:String)->AudioStream:
	if not sfx_cache.has(name):
		var p := "res://assets/audio/%s.wav" % name
		if ResourceLoader.exists(p):
			sfx_cache[name] = load(p)
		else:
			sfx_cache[name] = null
	return sfx_cache[name]

func play(name:String, vol_db:=0.0, max_poly:=6)->void:
	var st := _load(name)
	if st == null: return
	# limita polifonia por som
	var cnt := 0
	for c in get_children():
		if c is AudioStreamPlayer and c.stream == st and c.playing: cnt += 1
	if cnt >= max_poly: return
	var pl := AudioStreamPlayer.new()
	pl.stream = st; pl.volume_db = vol_db; pl.bus = "SFX"
	add_child(pl); pl.finished.connect(pl.queue_free); pl.play()

func play_at(name:String, pos:Vector3, vol_db:=0.0)->void:
	var st := _load(name)
	if st == null: return
	var pl := AudioStreamPlayer3D.new()
	pl.stream = st; pl.volume_db = vol_db; pl.bus = "SFX"
	pl.max_distance = 45.0; pl.unit_volume_db = -8.0
	add_child(pl)
	get_tree().current_scene.add_child(pl)
	pl.global_position = pos
	pl.finished.connect(pl.queue_free); pl.play()

func set_music(on:bool)->void:
	if on:
		var st := _load("music")
		if st is AudioStreamWAV:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0; st.loop_end = st.data.size()/2
		music_player.stream = st; music_player.volume_db = -10.0; music_player.play()
	else:
		music_player.stop()

func set_ambient(on:bool)->void:
	if on:
		var st := _load("ambient")
		if st is AudioStreamWAV:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0; st.loop_end = st.data.size()/2
		ambient_player.stream = st; ambient_player.play()
	else:
		ambient_player.stop()

func set_sfx_volume(v:float)->void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(clampf(v,0.0001,1.0)))

func set_music_volume(v:float)->void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(clampf(v,0.0001,1.0)))
