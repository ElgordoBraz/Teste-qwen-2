# Player - "cria de BH": movimento relativo a camera, mira RE4, tiro por raycast.
extends CharacterBody3D
class_name Player

@export var walk_speed := 3.6
@export var run_speed := 6.2
@export var gravity := 18.0

var aiming := false
var reloading := false
var reload_t := 0.0
var shoot_cd := 0.0
var dodge_cd := 0.0
var dodge_t := 0.0
var dodge_dir := Vector3.ZERO
var melee_cd := 0.0
var energy_t := 0.0
var current_weapon := "pistol"
var dead := false

var billboard: SpriteBillboard
var cam_pivot: Node3D
var shoulder: Node3D
var camera: Camera3D
var shoot_from: Marker3D
var muzzle_flash: MeshInstance3D
var ray_space: PhysicsRayQueryParameters3D

var yaw := 0.0        # rotacao horizontal da camera (mundo)
var pitch := -0.12    # inclinacao da camera
var mouse_sens := 0.0022

signal died
signal interact_request(target: Node)

func _ready():
	add_to_group("Player")
	collision_layer = 2; collision_mask = 1+2+4   # mundo, player, interaveis(pushed)
	# pivots de camera estilo RE4 (ombro esquerdo)
	cam_pivot = Node3D.new(); add_child(cam_pivot)
	shoulder = Node3D.new(); shoulder.position = Vector3(-0.35, 1.52, 0.0); cam_pivot.add_child(shoulder)
	camera = Camera3D.new(); camera.position = Vector3(0.0, 0.18, 2.1); camera.fov = 55.0
	camera.rotation_degrees = Vector3(-7, 0, 0)
	shoulder.add_child(camera)
	camera.current = true
	shoot_from = Marker3D.new(); shoot_from.position = Vector3(0.25, 1.35, -0.55); add_child(shoot_from)
	muzzle_flash = MeshInstance3D.new()
	var sph := SphereMesh.new(); sph.radius = 0.09; sph.height = 0.18
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.emission_enabled = true; fm.emission = Color(1,0.85,0.4); fm.albedo_color = Color(1,0.9,0.5)
	muzzle_flash.mesh = sph; muzzle_flash.material_override = fm; muzzle_flash.visible = false
	add_child(muzzle_flash)
	# sprite Doom-like 8 direcoes
	billboard = SpriteBillboard.new(); billboard.position = Vector3(0,0,0); add_child(billboard)
	billboard.setup(1.85)
	billboard.load_frames("characters/player", ["idle","run","aim","shoot","melee"],
		["front","fr","right","br","back","bl","left","fl"])
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var tm := Timer.new(); tm.wait_time = 0.32; tm.one_shot = true; tm.autostart = false
	tm.timeout.connect(_footstep); add_child(tm); tm.name="StepTimer"

func _unhandled_input(e)->void:
	if e is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * mouse_sens
		pitch = clampf(pitch - e.relative.y * mouse_sens*0.8, -0.65, 0.42)
	elif e.is_action_pressed("ui_cancel"):
		pass # tratado pelo Main
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
		_switch_weapon(1)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_switch_weapon(-1)

func _switch_weapon(dir:int)->void:
	var order := ["pistol","rifle","shotgun"]
	var i := order.find(current_weapon)
	for k in range(1,4):
		var w:String = order[(i + dir*k) % 3]
		if GameState.weapons_owned.get(w,false):
			current_weapon = w; reloading=false; Audio.play("ui_click"); return

func get_aim_point()->Vector3:
	# raycast a partir da CAMERA determina ponto de impacto (reticulo no centro)
	var from := camera.global_position
	var fwd := -camera.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd*120.0)
	q.exclude = [get_rid()]
	q.collision_mask = 1+2+4+8+16
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return from + fwd*60.0
	return hit.position

func debug_shoot_at(d:Vector3)->void:
	_fire_along(d.normalized())

func _physics_process(delta:float)->void:
	if dead or not GameState.playing: 
		set_physics_process(false); return
	# timers
	shoot_cd = maxf(0,shoot_cd-delta); dodge_cd = maxf(0,dodge_cd-delta)
	melee_cd = maxf(0,melee_cd-delta); energy_t = maxf(0,energy_t-delta)
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0: _finish_reload()
	# entrada
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var running := Input.is_key_pressed(KEY_SHIFT) and not aiming and input_dir != Vector2.ZERO

	# movimento relativo a camera (yaw)
	var move := Vector3.ZERO
	if input_dir != Vector2.ZERO and dodge_t <= 0.0:
		var f := Vector3(-sin(yaw), 0, -cos(yaw))
		var r := Vector3(cos(yaw), 0, -sin(yaw))
		move = (f*(-input_dir.y) + r*input_dir.x).normalized()

	# esquiva (espaco): dash rapido com iframes curtos
	if dodge_t > 0.0:
		velocity = dodge_dir * 11.0
		velocity.y = 0.0
	else:
		var spd := run_speed if running else walk_speed
		if energy_t > 0.0: spd *= 1.35
		if aiming: spd *= 0.55
		velocity.x = move.x * spd
		velocity.z = move.z * spd
	# gravidade
	if not is_on_floor(): velocity.y -= gravity*delta
	else: velocity.y = 0.0

	if Input.is_key_pressed(KEY_SPACE) and dodge_cd<=0.0 and not reloading:
		dodge_dir = move if move!=Vector3.ZERO else -global_transform.basis.z
		dodge_dir.y=0; dodge_dir=dodge_dir.normalized()
		dodge_t=0.28; dodge_cd=1.1; Audio.play("whoosh")
	dodge_t = maxf(0,dodge_t-delta)

	move_and_slide()
	global_position.x = clampf(global_position.x, -75, 75)
	global_position.z = clampf(global_position.z, -145, 45)

	# orientacao do corpo: mira em frente durante aim, senao direcao do movimento
	var face_yaw := yaw
	if move != Vector3.ZERO and not aiming and dodge_t<=0.0:
		face_yaw = atan2(move.x, move.z)
	rotation.y = lerp_angle(rotation.y, face_yaw, 12.0*delta)

	# camera segue pivot com suavizacao e colisao (nao atravessa parede)
	cam_pivot.rotation.y = yaw
	_update_camera(delta)

	# tiro
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not reloading and dodge_t<=0.0:
		_try_shoot()
	if Input.is_key_pressed(KEY_R) and not reloading:
		_start_reload()
	if Input.is_key_pressed(KEY_F) and melee_cd<=0.0:
		_melee()

	# sprite: direcao relativa camera-corpo + estado
	_update_sprite(move, running)

func _update_camera(delta:float)->void:
	shoulder.position = Vector3(-0.35 if not aiming else -0.9, 1.52, 0.0 if not aiming else -0.2)
	shoulder.rotation.x = pitch
	# colisao da camera com o mundo
	var to_body := global_position + Vector3(0,1.4,0) - shoulder.global_position
	var dist := to_body.length()
	var q := PhysicsRayQueryParameters3D.create(shoulder.global_position, to_body + to_body.normalized()*0.3)
	q.collision_mask = 1
	q.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var want := 2.1
	if not hit.is_empty():
		want = maxf(0.55, shoulder.global_position.distance_to(hit.position)-0.18)
	camera.position.z = lerpf(camera.position.z, want, 10.0*delta)
	camera.rotation_degrees.x = -7.0 + rad_to_deg(pitch)*0.25

func _update_sprite(move:Vector3, running:bool)->void:
	shooting_anim_t = maxf(0.0, shooting_anim_t - get_physics_process_delta_time())
	var st := "idle"
	if dead: st = "idle"
	elif dodge_t>0.0: st="run"
	elif melee_cd > 0.35: st="melee"
	elif shooting_anim_t>0.0: st="shoot"
	elif aiming: st="aim"
	elif move!=Vector3.ZERO: st="run"
	billboard.set_state(st)
	billboard.set_direction(_dir_key())

var shooting_anim_t := 0.0

func _dir_key()->String:
	var to_cam := camera.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length_squared()<0.001: return "front"
	# angulo da camera RELATIVO ao facing do corpo. 0 = camera atras => costas? convengao:
	# mostramos a face que esta voltada para a camera. Se camera esta atras, sprite "back".
	var body_fwd := Vector3(sin(rotation.y),0,cos(rotation.y))
	var right := Vector3(body_fwd.z,0,-body_fwd.x)  # direita do corpo
	var a := atan2(to_cam.dot(right), to_cam.dot(body_fwd))  # 0 = camera na frente
	# camera na frente do personagem => vemos seu rosto (front)
	var S2 := PI/8.0
	if abs(a) < S2*1.0: return "front"
	if a >= S2*1.0 and a < S2*3.0: return "fl"
	if a >= S2*3.0 and a < S2*5.0: return "left"
	if a >= S2*5.0 and a < S2*7.0: return "bl"
	if a >= S2*7.0 or a <= -S2*7.0: return "back"
	if a <= -S2*1.0 and a > -S2*3.0: return "fr"
	if a <= -S2*3.0 and a > -S2*5.0: return "right"
	return "br"

func _try_shoot()->void:
	if shoot_cd > 0.0: return
	var w: Dictionary = GameDB.weapons[current_weapon]
	if GameState.mag_ammo[current_weapon] <= 0:
		Audio.play("empty"); shoot_cd = 0.3
		if Input.is_key_pressed(KEY_R): _start_reload()
		return
	GameState.mag_ammo[current_weapon] -= 1
	shoot_cd = 60.0 / w.rpm
	shooting_anim_t = 0.12
	Audio.play("shoot_"+current_weapon, -3.0)
	_flash_muzzle()
	for i in range(int(w.pellets)):
		_fire_along(_aim_direction(w.spread))
	GameState.emit_signal("stats_changed")

func _aim_direction(spread:float)->Vector3:
	var target := get_aim_point()
	var origin := shoot_from.global_position
	var d := target - origin
	if d.length_squared() < 0.0001: d = -global_transform.basis.z
	d = d.normalized()
	d += Vector3(randf_range(-spread,spread), randf_range(-spread,spread)*0.5, randf_range(-spread,spread))
	return d.normalized()

func _fire_along(d:Vector3)->void:
	var space := get_world_3d().direct_space_state
	var from := shoot_from.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + d*GameDB.weapons[current_weapon].range_m)
	q.exclude = [get_rid()]
	q.collision_mask = 1+4+8+16   # mundo, interativeis, enemies, boss
	var hit := space.intersect_ray(q)
	var end := from + d*GameDB.weapons[current_weapon].range_m
	if not hit.is_empty():
		end = hit.position
		_spawn_tracer(from, end)
		var node: Node = hit.collider
		if node.is_in_group("Enemies") and node.has_method("take_damage"):
			var dmg: float = GameDB.weapons[current_weapon].damage * (1.0 + 0.2*GameState.upgrades.damage)
			node.take_damage(dmg, d, self)
			Effects.goo_splat(end)
			Audio.play("impact_flesh",-2.0)
		else:
			Effects.spark(end)
			Audio.play("impact_wall",-8.0)
	else:
		_spawn_tracer(from, end)

func _spawn_tracer(a:Vector3,b:Vector3)->void:
	Effects.tracer(a,b)

func _flash_muzzle()->void:
	muzzle_flash.global_position = shoot_from.global_position
	muzzle_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func(): muzzle_flash.visible=false)

func _start_reload()->void:
	var w: Dictionary = GameDB.weapons[current_weapon]
	var cap := int(w.mag * (1.0 + 0.3*GameState.upgrades.capacity))
	if GameState.mag_ammo[current_weapon] >= cap: return
	if GameState.ammo_reserve[current_weapon] <= 0: return
	reloading = true
	reload_t = w.reload * (1.0 - 0.15*GameState.upgrades.reload)
	Audio.play("reload")

func _finish_reload()->void:
	reloading = false
	var w: Dictionary = GameDB.weapons[current_weapon]
	var cap := int(w.mag * (1.0 + 0.3*GameState.upgrades.capacity))
	var need := cap - GameState.mag_ammo[current_weapon]
	var take: int = mini(need, GameState.ammo_reserve[current_weapon])
	GameState.mag_ammo[current_weapon] += take
	GameState.ammo_reserve[current_weapon] -= take
	GameState.emit_signal("stats_changed")

func _melee()->void:
	# chute de chinelo
	melee_cd = 0.5; shooting_anim_t = 0.3
	Audio.play("whoosh")
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new(); shape.radius = 1.4
	var sh := PhysicsShapeQueryParameters3D.new()
	sh.shape = shape; sh.transform = Transform3D(Basis(), global_position + Vector3(0,0.9,0) - global_transform.basis.z)
	sh.collision_mask = 8+16
	for c in space.intersect_shape(sh, 6):
		var node: Node = c.collider
		if node.is_in_group("Enemies") and node.has_method("take_damage"):
			node.take_damage(30.0, -global_transform.basis.z, self)
			if node.has_method("knockback"): node.knockback(-global_transform.basis.z, 4.0)

func _footstep()->void:
	Audio.play("step", -12.0)

func die()->void:
	if dead: return
	dead = true
	billboard.set_state("death")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	emit_signal("died")
