# GameDB - Autoload: banco de dados central de configuracao.
# Tudo ajustavel aqui: armas, inimigos, hordas, economia, precos, melhorias.
extends Node

# ---------------- ARMAS ----------------
var weapons := {
	"pistol": {
		name="Pistola", damage=18.0, rpm=320, mag=12, reserve_max=120, reload=1.4,
		range_m=60.0, spread=0.012, pellets=1, auto=false, price_ammo=40, ammo_per_pack=24,
	},
	"rifle": {
		name="Rifle de Assalto", damage=13.0, rpm=640, mag=30, reserve_max=240, reload=2.1,
		range_m=90.0, spread=0.03, pellets=1, auto=true, price_ammo=70, ammo_per_pack=40,
		unlock_price=350,
	},
	"shotgun": {
		name="Escopeta", damage=10.0, rpm=75, mag=6, reserve_max=48, reload=2.6,
		range_m=28.0, spread=0.09, pellets=7, auto=false, price_ammo=60, ammo_per_pack=12,
		unlock_price=450,
	},
}

# upgrades
var upgrades := {
	"damage":  {name="Melhoria de Dano",   base_price=200, mult=1.5, step=0.20, max_level=4},
	"reload":  {name="Melhoria de Recarga",base_price=180, mult=1.5, step=0.15, max_level=4},
	"capacity":{name="Melhoria de Capacidade",base_price=160,mult=1.5,step=0.30,max_level=4},
}

# ---------------- INIMIGOS ----------------
var enemies := {
	"common": {scene="res://scenes/enemies/AlienCommon.tscn", hp=60, speed=2.6, damage=10,
		attack_range=2.2, attack_cd=1.1, score=100, coin_min=8, coin_max=18, drop=0.45, height=1.75},
	"runner": {scene="res://scenes/enemies/AlienRunner.tscn", hp=35, speed=5.4, damage=8,
		attack_range=2.0, attack_cd=0.9, lunge_speed=11.0, score=140, coin_min=10, coin_max=22, drop=0.4, height=1.2},
	"shooter": {scene="res://scenes/enemies/AlienShooter.tscn", hp=50, speed=2.2, damage=12,
		attack_range=16.0, keep_distance=11.0, attack_cd=2.2, proj_speed=14.0, score=160,
		coin_min=12, coin_max=26, drop=0.5, height=1.8},
	"tank": {scene="res://scenes/enemies/AlienTank.tscn", hp=320, speed=1.5, damage=26,
		attack_range=3.2, attack_cd=1.8, lunge_speed=7.0, score=320, coin_min=30, coin_max=55, drop=0.8, height=2.5},
	"boss": {scene="res://scenes/enemies/BossLord.tscn", hp=2600, speed=2.0, damage=34,
		attack_range=5.0, attack_cd=1.6, score=2500, coin_min=250, coin_max=400, drop=1.0, height=5.2},
}

# dificuldade global multiplica vida/dano dos inimigos por horda
var wave_difficulty := [1.0, 1.1, 1.25, 1.45, 1.7]

# ---------------- HORDAS ----------------
# spawn_points: nomes de pontos na cena World; areas: zona ativa (rect X,Z) p/ spawn aleatorio
var waves := [
	{	id=1, area="Av. Amazonas", zone="amazonas_sul",
		composition={"common":10}, burst=3, interval=2.6, max_alive=5,
		spawn_area=Rect2(-14,-4,-12,26), next_gate="gate_to_praca"},
	{	id=2, area="Praca Sete / Pirulito", zone="praca",
		composition={"common":8,"runner":6}, burst=4, interval=2.4, max_alive=7,
		spawn_area=Rect2(-46,-56,92,52), next_gate="gate_afonso_dir"},
	{	id=3, area="Av. Afonso Pena (direita)", zone="afonso_dir",
		composition={"common":8,"runner":6,"shooter":5}, burst=4, interval=2.2, max_alive=8,
		spawn_area=Rect2(16,-46,26,44), next_gate="gate_afonso_esq"},
	{	id=4, area="Av. Afonso Pena (esquerda)", zone="afonso_esq",
		composition={"common":10,"runner":6,"shooter":6,"tank":3}, burst=5, interval=2.0, max_alive=9,
		spawn_area=Rect2(-42,-46,26,44), next_gate="gate_estacao"},
	{	id=5, area="Amazonas -> Estacao Central", zone="amazonas_norte",
		composition={"common":8,"runner":6,"shooter":5,"tank":3}, burst=5, interval=1.9, max_alive=9,
		spawn_area=Rect2(-14,-122,-12,40), boss_at=18, next_gate=""},
]

# economia da loja
var shop_items := [
	{id="ammo_pistol", name="Municao de Pistola (24)", price=40, kind="ammo", weapon="pistol"},
	{id="ammo_rifle", name="Municao de Rifle (40)", price=70, kind="ammo", weapon="rifle"},
	{id="ammo_shotgun", name="Municao de Escopeta (12)", price=60, kind="ammo", weapon="shotgun"},
	{id="medkit", name="Kit Medico (+45 HP)", price=60, kind="heal", amount=45},
	{id="energy", name="Energetico (velocidade)", price=45, kind="energy"},
	{id="vest", name="Colete (+60 armadura)", price=80, kind="vest", amount=60},
	{id="unlock_rifle", name="Comprar Rifle de Assalto", price=350, kind="unlock", weapon="rifle", once=true},
	{id="unlock_shotgun", name="Comprar Escopeta", price=450, kind="unlock", weapon="shotgun", once=true},
	{id="up_damage", name="Melhoria: Dano +20%", price=200, kind="upgrade", upgrade="damage"},
	{id="up_reload", name="Melhoria: Recarga -15%", price=180, kind="upgrade", upgrade="reload"},
	{id="up_capacity", name="Melhoria: Capacidade +30%", price=160, kind="upgrade", upgrade="capacity"},
	{id="mine", name="Mina (x2)", price=90, kind="trap", trap="mine", qty=2},
	{id="tower", name="Torre Automatica", price=140, kind="trap", trap="tower", qty=1},
]

func upgrade_price(kind:String, level:int)->int:
	var u:=upgrades[kind]
	return int(u.base_price * pow(u.mult, level))

func wave_config(i:int)->Dictionary:
	if i>=0 and i<waves.size(): return waves[i]
	return {}
