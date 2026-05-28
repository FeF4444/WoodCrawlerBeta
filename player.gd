extends CharacterBody3D

# --- SEÑALES ---
signal vida_cambiada
signal cargas_cambiadas

# --- VARIABLES EXPORTADAS ---
@export_category("Estadísticas de Vida")
@export var vida_maxima: float = 100.0
@export var vida_actual: float = 100.0

@export_category("Movimiento")
@export var velocidad: float = 6.0
@export var aceleracion: float = 15.0

@export_category("Mecánica de Rodar")
@export var velocidad_dash: float = 16.0
@export var duracion_dash: float = 0.25
@export var max_cargas_rodar: int = 3        
@export var tiempo_recarga_carga: float = 2.0 

@export_category("Combate")
@export var tiempo_ataque: float = 0.3

# --- CARGA AUTOMÁTICA DE TUS ARCHIVOS .WAV DESDE LA CARPETA SFX ---
var sonidos_ataque: Array[AudioStream] = [
	load("res://sfx/sfx.wav"),
	load("res://sfx/sfx2.wav"),
	load("res://sfx/sfx3.wav"),
	load("res://sfx/sfx4.wav")
]

var sonidos_daño: Array[AudioStream] = [
	load("res://sfx/daño.wav"),
	load("res://sfx/daño2.wav")
]

var sonido_dash: AudioStream = load("res://sfx/roll2.wav")
var sonido_muerte: AudioStream = load("res://sfx/muerte.wav")

# --- NODOS ONREADY ---
@onready var hitbox_colision: CollisionShape3D = $HitboxAtaque/CollisionShape3D
@onready var sfx_caminar_player: AudioStreamPlayer = $SfxCaminar
@onready var sfx_acciones_player: AudioStreamPlayer = $SfxAcciones

# --- VARIABLES DE ESTADO ---
var esta_atacando: bool = false
var esta_esquivando: bool = false
var direccion_mirada: Vector3 = Vector3.FORWARD
var velocidad_actual_dash: Vector3 = Vector3.ZERO

# --- SISTEMA DE BALANCEO (Cargas) ---
var cargas_actuales: int = 3
var tiempo_acumulado_recarga: float = 0.0

func _ready() -> void:
	vida_actual = vida_maxima
	
	if hitbox_colision:
		hitbox_colision.disabled = true
		
	await get_tree().process_frame
	vida_cambiada.emit()
	cargas_cambiadas.emit(cargas_actuales, max_cargas_rodar)

func _physics_process(delta: float) -> void:
	procesar_recarga_rodar(delta)
	procesar_pruebas_daño()

	if esta_esquivando:
		reproducir_sfx_caminar(false)
		velocity = velocidad_actual_dash
		move_and_slide()
		return
		
	if esta_atacando:
		reproducir_sfx_caminar(false)
		velocity.x = move_toward(velocity.x, 0.0, aceleracion * delta)
		velocity.z = move_toward(velocity.z, 0.0, aceleracion * delta)
		move_and_slide()
		return
		
	procesar_movimiento(delta)
	procesar_combate()

func procesar_movimiento(delta: float) -> void:
	var input_dir := Vector3.ZERO
	
	if Input.is_action_pressed("right"): input_dir.x += 1.0
	if Input.is_action_pressed("left"): input_dir.x -= 1.0
	if Input.is_action_pressed("backward"): input_dir.z += 1.0
	if Input.is_action_pressed("forward"): input_dir.z -= 1.0
		
	input_dir = input_dir.normalized()
	
	var velocidad_objetivo = input_dir * velocidad
	velocity.x = move_toward(velocity.x, velocidad_objetivo.x, aceleracion * delta)
	velocity.z = move_toward(velocity.z, velocidad_objetivo.z, aceleracion * delta)
	
	if input_dir != Vector3.ZERO:
		direccion_mirada = input_dir
		var angulo_objetivo = atan2(-input_dir.x, -input_dir.z)
		rotation.y = lerp_angle(rotation.y, angulo_objetivo, delta * 15.0)
		
		# Activar sonido de caminar
		reproducir_sfx_caminar(true)
	else:
		# Detener sonido de caminar
		reproducir_sfx_caminar(false)
	
	move_and_slide()

func reproducir_sfx_caminar(activar: bool) -> void:
	if !sfx_caminar_player or !sfx_caminar_player.stream: return
	
	if activar:
		if !sfx_caminar_player.playing:
			sfx_caminar_player.play()
	else:
		if sfx_caminar_player.playing:
			sfx_caminar_player.stop()

func procesar_combate() -> void:
	if Input.is_action_just_pressed("rodar") and not esta_esquivando and not esta_atacando:
		if cargas_actuales > 0:
			ejecutar_dash()
		else:
			print("¡No tienes energía para rodar! Cargas: 0")
		return
		
	if Input.is_action_just_pressed("attack") and not esta_atacando and not esta_esquivando:
		ejecutar_ataque()

func ejecutar_dash() -> void:
	esta_esquivando = true
	cargas_actuales -= 1 
	
	# Reproducir roll2.wav
	if sonido_dash and sfx_acciones_player:
		sfx_acciones_player.stream = sonido_dash
		sfx_acciones_player.play()
	
	cargas_cambiadas.emit(cargas_actuales, max_cargas_rodar)
	velocidad_actual_dash = direccion_mirada * velocidad_dash
	
	await get_tree().create_timer(duracion_dash).timeout
	esta_esquivando = false

func procesar_recarga_rodar(delta: float) -> void:
	if cargas_actuales >= max_cargas_rodar:
		tiempo_acumulado_recarga = 0.0
		return
		
	tiempo_acumulado_recarga += delta
	if tiempo_acumulado_recarga >= tiempo_recarga_carga:
		cargas_actuales += 1
		tiempo_acumulado_recarga = 0.0 
		cargas_cambiadas.emit(cargas_actuales, max_cargas_rodar)

func ejecutar_ataque() -> void:
	esta_atacando = true
	
	# Selecciona al azar entre sfx, sfx2, sfx3 o sfx4
	if sfx_acciones_player:
		var audios_validos = sonidos_ataque.filter(func(s): return s != null)
		if audios_validos.size() > 0:
			sfx_acciones_player.stream = audios_validos.pick_random()
			sfx_acciones_player.play()
	
	if hitbox_colision: hitbox_colision.disabled = false
	await get_tree().create_timer(tiempo_ataque).timeout
	if hitbox_colision: hitbox_colision.disabled = true
	esta_atacando = false

func recibir_daño(cantidad: float) -> void:
	vida_actual -= cantidad
	vida_actual = clamp(vida_actual, 0.0, vida_maxima)
	vida_cambiada.emit()
	
	if vida_actual <= 0.0:
		morir()
	else:
		# Selecciona al azar entre daño o daño2
		if sfx_acciones_player:
			var audios_validos = sonidos_daño.filter(func(s): return s != null)
			if audios_validos.size() > 0:
				sfx_acciones_player.stream = audios_validos.pick_random()
				sfx_acciones_player.play()

func morir() -> void:
	reproducir_sfx_caminar(false)
	
	# Reproducir muerte.wav
	if sonido_muerte and sfx_acciones_player:
		sfx_acciones_player.stream = sonido_muerte
		sfx_acciones_player.play()
	
	set_physics_process(false) 
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()

func procesar_pruebas_daño() -> void:
	if Input.is_key_pressed(KEY_K):
		if Input.is_physical_key_pressed(KEY_K) and Engine.get_physics_frames() % 15 == 0:
			recibir_daño(10.0)
