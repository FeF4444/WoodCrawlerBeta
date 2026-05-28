extends CharacterBody3D

# NUEVO: Señal para avisar al juego que la vida cambió
signal vida_cambiada
# NUEVO: Señal para avisar al juego que los dashes cambiaron
signal cargas_cambiadas

# --- VARIABLES EXPORTADAS (Balanceo desde el Inspector) ---
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
	# Aseguramos que la vida actual empiece al máximo al iniciar la partida
	vida_actual = vida_maxima
	
	if hitbox_colision:
		hitbox_colision.disabled = true
		
	# CORRECCIÓN: Esperamos a que todo el juego cargue bien antes de avisar los valores
	await get_tree().process_frame
	vida_cambiada.emit()
	cargas_cambiadas.emit(cargas_actuales, max_cargas_rodar)

func _physics_process(delta: float) -> void:
	procesar_recarga_rodar(delta)
	procesar_pruebas_daño() # NUEVO: Función de escucha para pruebas de daño

	if esta_esquivando:
		velocity = velocidad_actual_dash
		move_and_slide()
		return
		
	if esta_atacando:
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
	
	# Le avisamos a Mundo.gd que gastamos un dash
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
		print("¡Carga recuperada! Cargas actuales: ", cargas_actuales)
		# Le avisamos a Mundo.gd que recuperamos un dash
		cargas_cambiadas.emit(cargas_actuales, max_cargas_rodar)

func ejecutar_ataque() -> void:
	esta_atacando = true
	print("¡El títere lanza un golpe!")
	
	if hitbox_colision: hitbox_colision.disabled = false
	await get_tree().create_timer(tiempo_ataque).timeout
	if hitbox_colision: hitbox_colision.disabled = true
	esta_atacando = false

# Permite recibir daño y avisa mediante la señal 'vida_cambiada'
func recibir_daño(cantidad: float) -> void:
	vida_actual -= cantidad
	vida_actual = clamp(vida_actual, 0.0, vida_maxima) # Evitamos que la vida baje de 0
	print("💥 ¡Daño recibido! Vida actual: ", vida_actual)
	
	vida_cambiada.emit() # Le avisamos a Mundo.gd para que actualice la barra
	
	if vida_actual <= 0.0:
		morir()

func morir() -> void:
	print("💀 El títere ha caído en combate...")
	
	# Desactivamos el procesamiento para que el jugador no se pueda mover mientras muere
	set_physics_process(false) 
	
	# Esperamos 1.5 segundos en pantalla para que el jugador asimile su derrota
	await get_tree().create_timer(1.5).timeout
	
	# Reiniciamos la escena principal (Mundo) desde cero de forma limpia
	get_tree().reload_current_scene()

# Presiona la tecla K para probar que la barra baje de 10 en 10
func procesar_pruebas_daño() -> void:
	if Input.is_key_pressed(KEY_K) and Input.is_action_just_pressed("ui_accept" if false else "ui_cancel" if false else "") == false:
		# Hacemos una comprobación simple para que baje solo al pulsar una vez la tecla K física
		if Input.is_physical_key_pressed(KEY_K) and Engine.get_physics_frames() % 15 == 0:
			recibir_daño(10.0)
