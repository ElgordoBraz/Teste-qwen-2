# SpriteBillboard - camada visual 2D (estilo Doom) que encara a camera e escolhe
# o frame conforme angulo relativo personagem-camera. Nao afeta colisao nem IA.
extends Node3D
class_name SpriteBillboard

var quad := QuadMesh.new()
var mat := StandardMaterial3D.new()
var mi: MeshInstance3D
var shadow: MeshInstance3D

var height := 1.8            # altura do personagem em metros (sprite escala coerente)
var frames := {}             # dir_key -> Array[Texture2D]
var anim_speed := 6.0
var _t := 0.0
var _dir := "front"
var _state := "idle"
var _enabled := true

func setup(h:float)->void:
	height = h
	quad.size = Vector2(h*0.75, h)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi = MeshInstance3D.new(); mi.mesh = quad; mi.material_override = mat
	add_child(mi)
	# sombra no chao
	var sq := QuadMesh.new(); sq.size = Vector2(h*0.55, h*0.55)
	sq.orientation = Plane3D(Vector3(0,1,0),0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0,0,0,0.38)
	shadow = MeshInstance3D.new(); shadow.mesh = sq; shadow.material_override = sm
	shadow.position = Vector3(0,0.02,0); add_child(shadow)

func load_frames(kind:String, states:Array[String], dirs:Array[String])->void:
	for st in states:
		for d in dirs:
			var arr:Array[Texture2D] = []
			var base := "res://assets/%s/" % kind
			var path := base + st + "_" + d + ".png"
			if ResourceLoader.exists(path):
				arr.append(load(path))
			else:
				# multi-frame: st_dir_0.png, st_dir_1.png ...
				var i := 0
				while true:
					var p2 := base + st + "_" + d + "_" + str(i) + ".png"
					if ResourceLoader.exists(p2): arr.append(load(p2)); i+=1
					else: break
			if not arr.is_empty(): frames[st+"_"+d] = arr

func set_state(s:String)->void:
	if _state != s: _state = s; _t = 0.0

func set_direction(d:String)->void:
	_dir = d

func _process(delta:float)->void:
	if not _enabled: return
	# billboard: yaw para encarar camera
	var cam := get_viewport().get_camera_3d()
	if cam:
		var to_cam := cam.global_position - global_position
		to_cam.y = 0.0
		if to_cam.length_squared() > 0.01:
			rotation.y = atan2(to_cam.x, to_cam.z)
	# estado atual
	var st := _state
	var key := st + "_" + _dir
	if not frames.has(key):
		key = "idle_" + _dir
	if not frames.has(key):
		key = st + "_front"
	if not frames.has(key):
		return
	var arr: Array = frames[key]
	if arr.is_empty(): return
	_t += delta * anim_speed
	var idx := int(_t) % arr.size()
	mat.albedo_texture = arr[idx]
	# escala vertical pelo angulo da camera (evita achatamento quando camera alta)
	if cam:
		var flat := to_flat_ratio(cam)
		mi.scale = Vector3(1.0, clampf(flat, 0.6, 1.0), 1.0)
		mi.position.y = height/2.0
		shadow.visible = true

func to_flat_ratio(cam:Camera3D)->float:
	var g := global_position
	var d := cam.global_position - g
	var horiz := Vector2(d.x, d.z).length()
	var vert := absf(d.y)
	if horiz < 0.001: return 0.6
	return horiz / maxf(horiz, vert*1.4)
