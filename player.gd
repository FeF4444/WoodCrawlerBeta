extends CharacterBody3D
# 1. Definimos la lista con todas las opciones para esa dirección
const OPCIONES_ROOM_1 = [
	"res://rooms/room1_este.tscn",
	"res://rooms/room2_este.tscn",
	"res://rooms/room3_este.tscn",
	"res://rooms/room4_este.tscn",
]

# 2. Creamos la variable que elegirá una al azar
var room_1_este: String

func _ready():
	# pick_random() toma un elemento al azar de la lista
	room_1_este = OPCIONES_ROOM_1.pick_random()
	print("La habitación elegida es: ", room_1_este)
	# --- VARIABLES EXPORTADAS (Balanceo desde el Inspector) ---
@export_category("Movimiento")
@export var velocidad: float = 6.0
@export var aceleracion: float = 15.0

@export_category("Mecánica de Rodar")
@export var velocidad_dash: float = 16.0
@export var duracion_dash: float = 0.25
@export var max_cargas_rodar: int = 3       # Límite de 3 usos
@export var tiempo_recarga_carga: float = 2.0 # Segundos que tarda en recargar UN uso
@onready var hitbox_colision: CollisionShape3D = $HitboxAtaque/CollisionShape3D

@export_category("Combate")
@export var tiempo_ataque: float = 0.3

# --- VARIABLES DE ESTADO ---
var esta_atacando: bool = false
var esta_esquivando: bool = false
var direccion_mirada: Vector3 = Vector3.FORWARD
var velocidad_actual_dash: Vector3 = Vector3.ZERO

# --- SISTEMA DE BALANCEO (Cargas) ---
var cargas_actuales: int = 3
var tiempo_acumulado_recarga: float = 0.0

func _physics_process(delta: float) -> void:
	# 1. Sistema automático de recarga de rodamientos
	procesar_recarga_rodar(delta)

	# 2. Si está esquivando, se aplica el impulso y se ignora el resto
	if esta_esquivando:
		velocity = velocidad_actual_dash
		move_and_slide()
		return
		
	# 3. Si está atacando, se congela por completo (Peso de combate)
	if esta_atacando:
		return
		
	procesar_movimiento(delta)
	procesar_combate()

func procesar_movimiento(delta: float) -> void:
	var input_dir := Vector3.ZERO
	
	# Usando tus nuevas claves personalizadas del Input Map
	if Input.is_action_pressed("right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("backward"): # En 3D, ir hacia atrás es avanzar en el eje Z positivo
		input_dir.z += 1.0
	if Input.is_action_pressed("forward"):  # Ir hacia adelante es restar en el eje Z
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
	# Activar Rodamiento con tu clave "rodar"
	if Input.is_action_just_pressed("rodar") and not esta_esquivando and not esta_atacando:
		# REGLA DE BALANCEO: Solo rueda si tiene al menos 1 carga
		if cargas_actuales > 0:
			ejecutar_dash()
		else:
			print("¡No tienes energía para rodar! Cargas: 0")
		return
		
	# Activar Ataque con tu clave "attack"
	if Input.is_action_just_pressed("attack") and not esta_atacando and not esta_esquivando:
		ejecutar_ataque()

func ejecutar_dash() -> void:
	esta_esquivando = true
	cargas_actuales -= 1 # Consumir una carga de forma inmediata
	print("¡El títere rodó! Cargas restantes: ", cargas_actuales)
	
	velocidad_actual_dash = direccion_mirada * velocidad_dash
	
	await get_tree().create_timer(duracion_dash).timeout
	esta_esquivando = false

func procesar_recarga_rodar(delta: float) -> void:
	# Si ya tenemos el máximo de cargas, no hace falta calcular nada
	if cargas_actuales >= max_cargas_rodar:
		tiempo_acumulado_recarga = 0.0
		return
		
	# Acumular el tiempo que pasa en cada fotograma del juego (delta)
	tiempo_acumulado_recarga += delta
	
	# Cuando el tiempo acumulado supera el tiempo de espera (ej. 2 segundos)
	if tiempo_acumulado_recarga >= tiempo_recarga_carga:
		cargas_actuales += 1
		tiempo_acumulado_recarga = 0.0 # Reiniciar el contador para la siguiente carga
		print("¡Carga recuperada! Cargas actuales: ", cargas_actuales)

func ejecutar_ataque() -> void:
	esta_atacando = true
	print("¡El títere lanza un golpe hacia adelante!")
	
	# 1. Encender el hitbox del arma en el escenario
	hitbox_colision.disabled = false
	
	# 2. Esperar el tiempo que dura el ataque activo
	await get_tree().create_timer(tiempo_ataque).timeout
	
	# 3. Apagar el hitbox inmediatamente para que no siga haciendo daño
	hitbox_colision.disabled = true
	esta_atacando = false


@warning_ignore("unused_parameter")
func _on_area_3d_body_entered(body: Node3D) -> void:
	get_tree().change_scene_to_file(room_1_este)	


func _on_salida_norte_body_entered(body: Node3D) -> void:
		print("rl jugador paso por la puerta del norte")


func _on_salida_este_body_entered(body: Node3D) -> void:
		print("rl jugador paso por la puerta del estea")


func _on_salida_sur_body_entered(body: Node3D) -> void:
		print("rl jugador paso por la puerta del sur")
