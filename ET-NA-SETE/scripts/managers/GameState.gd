# GameState - Autoload: estado da partida, economia, progresso das hordas/areas.
extends Node

signal money_changed(v)
signal stats_changed
signal game_over(won: bool)
signal wave_state_changed

var playing := false
var paused := false

var money := 120
var score := 0
var kills := 0
var elapsed := 0.0

var hp_max := 100.0
var hp := 100.0
var armor := 0.0

var current_wave := 0            # indice 0..4 (horda atual ou proxima)
var wave_active := false
var boss_alive := false
var unlocked_zones := ["amazonas_sul"]
var gates_open := {}             # nome do gate -> true

var weapons_owned := {"pistol": true, "rifle": false, "shotgun": false}
var ammo_reserve := {"pistol": 60, "rifle": 0, "shotgun": 0}
var mag_ammo := {"pistol": 12, "rifle": 0, "shotgun": 0}
var upgrades := {"damage": 0, "reload": 0, "capacity": 0}
var inventory := {"mine": 0, "tower": 0}
var purchased_once := {}

func reset()->void:
	playing = true; paused = false
	money = 120; score = 0; kills = 0; elapsed = 0.0
	hp_max = 100.0; hp = 100.0; armor = 0.0
	current_wave = 0; wave_active = false; boss_alive = false
	unlocked_zones = ["amazonas_sul"]; gates_open.clear()
	weapons_owned = {"pistol": true, "rifle": false, "shotgun": false}
	ammo_reserve = {"pistol": 60, "rifle": 0, "shotgun": 0}
	mag_ammo = {"pistol": 12, "rifle": 0, "shotgun": 0}
	upgrades = {"damage": 0, "reload": 0, "capacity": 0}
	inventory = {"mine": 0, "tower": 0}
	purchased_once = {}
	emit_signal("money_changed", money); emit_signal("stats_changed")

func add_money(v:int)->void:
	money += v; emit_signal("money_changed", money)

func try_spend(v:int)->bool:
	if money < v: return false
	money -= v; emit_signal("money_changed", money); return true

func damage_player(raw:float)->void:
	if not playing or paused: return
	var d := raw
	if armor > 0.0:
		var absorbed := minf(armor, d*0.5)
		armor -= absorbed; d -= absorbed
	hp = maxf(0.0, hp - d)
	emit_signal("stats_changed")
	if hp <= 0.0:
		emit_signal("game_over", false)

func heal(v:float)->void:
	hp = minf(hp_max, hp+v); emit_signal("stats_changed")

func zone_unlocked(z:String)->bool:
	return z in unlocked_zones

func open_gate(g:String)->void:
	gates_open[g] = true
	# libera zona seguinte associada ao gate
	var next_zone := {"gate_to_praca":"praca","gate_afonso_dir":"afonso_dir",
		"gate_afonso_esq":"afonso_esq","gate_estacao":"amazonas_norte"}
	if g in next_zone:
		var z:String = next_zone[g]
		if not (z in unlocked_zones): unlocked_zones.append(z)
	emit_signal("wave_state_changed")
