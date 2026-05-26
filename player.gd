extends CharacterBody3D

# --- VARIABLES EXPORTADAS (Balanceo desde el Inspector) ---
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

# --- NODOS ONREADY ---
@onready var hitbox_colision: CollisionShape3D = $HitboxAtaque/CollisionShape3D

# --- VARIABLES DE ESTADO ---
var esta_atacando: bool = false
var esta_esquivando: bool = false
var direccion_mirada: Vector3 = Vector3.FORWARD
var velocidad_actual_dash: Vector3 = Vector3.ZERO

# --- SISTEMA DE BALANCEO (Cargas) ---
var cargas_actuales: int = 3
var tiempo_acumulado_recarga: float = 0.0

func _ready() -> void:
	# Aseguramos que el ataque empiece apagado
	if hitbox_colision:
		hitbox_colision.disabled = true

func _physics_process(delta: float) -> void:
	procesar_recarga_rodar(delta)

	if esta_esquivando:
		velocity = velocidad_actual_dash
		move_and_slide()
		return
		
	if esta_atacando:
		# Detenemos la inercia para el "peso de combate"
		velocity.x = move_toward(velocity.x, 0.0, aceleracion * delta)
		velocity.z = move_toward(velocity.z, 0.0, aceleracion * delta)
		move_and_slide()
		return
		
	procesar_movimiento(delta)
	procesar_combate()

func procesar_movimiento(delta: float) -> void:
	var input_dir := Vector3.ZERO
	
	if Input.is_action_pressed("right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("backward"): 
		input_dir.z += 1.0
	if Input.is_action_pressed("forward"):  
		input_dir.z -= 1.0
		
	input_dir = input_dir.normalized()
	
	var velocidad_objetivo = input_dir * velocidad
	velocity.x = move_toward(velocity.x, velocidad_objetivo.x, aceleracion * delta)
	velocity.z = move_toward(velocity.z, velocidad_objetivo.z, aceleracion * delta)
	
	if input_dir != Vector3.ZERO:
		direccion_mirada = input_dir
		var angulo_objetivo = atan2(-input_dir.x, -input_dir.z)
		rotation.y = lerp_angle(rotation.y, angulo_objetivo, delta * 15.0)
	
	move_and_slide()

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
	print("¡El títere rodó! Cargas restantes: ", cargas_actuales)
	
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
		print("¡Carga recuperada! Cargas actuales: ", cargas_actuales)

func ejecutar_ataque() -> void:
	esta_atacando = true
	print("¡El títere lanza un golpe!")
	
	hitbox_colision.disabled = false
	await get_tree().create_timer(tiempo_ataque).timeout
	hitbox_colision.disabled = true
	esta_atacando = false
