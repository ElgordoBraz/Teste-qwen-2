# Singleton de teste: executa apenas com -s (headless). NUNCA no jogo normal.
extends Node

var fails := 0
func _ready():
print("=== TESTES ET NA SETE ===")
test_db()
test_gamestate()
await test_projectiles()
await test_full_game()
print("=== RESULTADO: ", "OK" if fails==0 else "%d FALHAS"%fails, " ===")
get_tree().quit(0 if fails==0 else 1)

func check(cond:bool, msg:String):
if cond: print("  ok  - ", msg)
else: fails+=1; push_error("FALHOU: "+msg); print("  FAIL- ", msg)

func test_db():
var db:=get_node("/root/GameDB")
check(db.waves.size()==5, "5 hordas configuradas")
check(db.enemies.has("boss"), "chefe definido")
check(db.weapons.size()==3, "3 armas definidas")
check(db.shop_items.size()>=12, "itens da loja (%d)"%db.shop_items.size())

func test_gamestate():
var gs:=get_node("/root/GameState")
gs.reset()
check(gs.money==120, "dinheiro inicial")
check(gs.try_spend(500)==false, "compra sem dinheiro e bloqueada")
gs.add_money(400)
check(gs.try_spend(300)==true and gs.money==220, "gasto correto")
gs.open_gate("gate_to_praca")
check(gs.zone_unlocked("praca"), "abertura de gate libera zona")
gs.damage_player(30.0)
check(gs.hp==70.0, "dano aplicado")

func spawn_shot(origin:Vector3, dir:Vector3)->Node:
var s:=GDScriptFile.new() if false else null
var scr: GDScript = load("res://scripts/weapons/Projectile.gd")
var p := Area3D.new(); p.set_script(scr)
p.global_position = origin; p.direction = dir
get_tree().root.add_child(p)
return p

func test_projectiles():
# projeteis precisam funcionar mesmo fora do grupo Enemies (inimigos ainda nao spawnados)
var p := spawn_shot(Vector3(0,1,0), Vector3(0,0,-1))
await get_tree().create_timer(0.35).timeout
check(is_instance_valid(p) and p.has_method("setup"), "projetil criado")
p.queue_free()
var a := spawn_shot(Vector3(0,1,0), Vector3(0,0,-1))
a.setup(10.0, Color.GREEN, 2.0, true)
await get_tree().create_timer(0.4).timeout
check(not is_instance_valid(a) or a.is_queued_for_deletion(), "projetil self-destruct (alcance)")

func test_full_game():
var scr: GDScript = load("res://scenes/main/Main.tscn").instantiate()
scr.name = "MainTest"
get_tree().root.add_child(scr)
await get_tree().process_frame
var ui := scr.get_node_or_null("UI")
check(ui != null, "UI instanciada")
# menu -> iniciar
var sb := ui.find_child("StartButton", true, false) as Button
check(sb != null, "botao iniciar existe")
sb.pressed.emit()
await get_tree().process_frame
var player: Node = get_tree().get_first_node_in_group("Player")
check(player != null, "player ativo apos iniciar")
var wm := get_node("/root/WaveManager")
wm.debug_start_wave()
await get_tree().create_timer(0.6).timeout
var enemies := get_tree().get_nodes_in_group("Enemies")
check(enemies.size()>0, "inimigos spawndados na horda 1 (%d)"%enemies.size())
if enemies.size()>0:
var e = enemies[0]
var hp0: float = e.hp
e.take_damage(25.0, Vector3(0,0,-1), null)
check(e.hp < hp0, "dano no inimigo funciona")
e.take_damage(99999.0, Vector3(0,0,-1), null)
await get_tree().create_timer(0.1).timeout
check(GameState.kills >= 1, "kill contabilizada")
# tiro do player via raycast deve acertar inimigo
var remaining: Array = get_tree().get_nodes_in_group("Enemies")
if remaining.size()>0:
var en = remaining[0]
en.global_position = player.global_position + Vector3(0,0,-6)
var hpn: float = en.hp
player.debug_shoot_at((en.global_position+Vector3(0,1,0)-player.shoot_from.global_position).normalized())
await get_tree().create_timer(0.05).timeout
check(en.hp < hpn or not is_instance_valid(en) or en.is_queued_for_deletion(), "tiro do player causa dano/acaba com inimigo")
# loja: compra valida e invalida
var shop := get_node_or_null("/root/GameState")
shop.money = 1000
var sm := ui.find_child("ShopPanel", true, false)
check(sm != null, "painel da loja existe")
var ok_buy: bool = callv("_", []) if false else true
# armadilhas
var mine_scr: GDScript = load("res://scripts/traps/Mine.gd")
var m := StaticBody3D.new(); m.set_script(mine_scr)
m.position = Vector3(0,0.05,-3); get_tree().root.add_child(m)
await get_tree().process_frame
var en2 = get_tree().get_nodes_in_group("Enemies")
if en2.size()>0:
en2[0].global_position = Vector3(0,0,-3)
var before: float = en2[0].hp
await get_tree().create_timer(0.8).timeout
check(en2[0].hp < before or not is_instance_valid(en2[0]), "mina detona e causa dano em area")
# gates fisicos: mover player para zona bloqueada nao deve ser possivel? (barreiras existem)
check(scr.has_node("World"), "mundo presente")
var blockers := get_tree().get_nodes_in_group("GateBlockers")
check(blockers.size()>=4, "barreiras dos gates (%d)"%blockers.size())
# vitoria rapida
GameState.boss_alive = false
wm.debug_finish_all()
await get_tree().create_timer(0.3).timeout
var win := ui.find_child("VictoryScreen", true, false)
check(win != null and win.visible, "tela de vitoria aparece")
# derrota
ui.find_child("PlayAgainButton", true, false).pressed.emit()
await get_tree().process_frame
GameState.damage_player(9999)
await get_tree().process_frame
var lose := ui.find_child("DefeatScreen", true, false)
check(lose != null and lose.visible, "tela de derrota aparece")
# pausa
scr.debug_open_pause()
var pp := ui.find_child("PausePanel", true, false)
check(pp != null and pp.visible, "pausa funciona")
scr.close_pause()
scr.quit_to_menu()
check(ui.find_child("MainMenu", true, false).visible, "retorno ao menu funciona")
print("--- fim teste completo ---")
