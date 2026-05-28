extends Node3D

# --- NODOS ONREADY ---
@onready var room_container: Node3D = $RoomContainer
@onready var barra_vida: ProgressBar = $CanvasLayer/ProgressBar 
@onready var barra_dash: ProgressBar = $CanvasLayer/ProgressBarDash # <-- CONFIGURADO COMO BARRA SIMPLE

var jugador: CharacterBody3D = null

# Historial de habitaciones visitadas
var historial_habitaciones: Array[String] = []
var indice_habitacion_actual: int = -1

# Guarda CÓMO ENTRÓ el jugador a la sala actual
var historial_entradas: Array[String] = [""]

# Lista de tus habitaciones disponibles
var pool_de_cuartos: Array[String] = [
	"res://rooms/room1.tscn",
	"res://rooms/room2.tscn",
	"res://rooms/room3.tscn"
]

func _enter_tree() -> void:
	for hijo in get_children():
		if hijo is CharacterBody3D:
			jugador = hijo
			break

func _ready() -> void:
	historial_habitaciones.append("res://rooms/cuarto_base.tscn")
	indice_habitacion_actual = 0
	
	cargar_habitacion(0, "") 
	
	if jugador == null:
		print("ADVERTENCIA: No se encontró al jugador en la raíz de Mundo.")
	
	# CONEXIÓN DE SEÑALES: Vinculamos el jugador con la interfaz
	if jugador:
		if barra_vida:
			jugador.vida_cambiada.connect(_on_jugador_vida_cambiada)
		if barra_dash:
			jugador.cargas_cambiadas.connect(_on_jugador_cargas_cambiadas)

func cargar_habitacion(indice: int, puerta_aparicion: String) -> void:
	indice_habitacion_actual = indice
	
	for cuarto_viejo in room_container.get_children():
		cuarto_viejo.queue_free()
		
	var ruta_a_cargar = historial_habitaciones[indice_habitacion_actual]
	var nueva_escena = load(ruta_a_cargar) as PackedScene
	
	if nueva_escena:
		var nueva_room = nueva_escena.instantiate()
		room_container.add_child(nueva_room)
		conectar_puertas(nueva_room)
		
		var nombre_cuarto = ruta_a_cargar.get_file() 
		print("--------------------------------------------------")
		print("HABITACIÓN CARGADA: [ ", nombre_cuarto, " ] (Índice: ", indice_habitacion_actual, ")")
		print("Puerta por la que entraste (Tu única vía de RETORNO): ", historial_entradas[indice_habitacion_actual].to_upper())
		print("--------------------------------------------------")
		
		if not puerta_aparicion.is_empty():
			colocar_jugador_en_puerta(nueva_room, puerta_aparicion)

func conectar_puertas(cuarto_nodo: Node) -> void:
	var direcciones = ["norte", "sur", "este", "oeste"]
	
	for dir in direcciones:
		var nombre_puerta = "salida " + dir
		var puerta = cuarto_nodo.find_child(nombre_puerta, true, false)
		
		if puerta and puerta.has_signal("body_entered"):
			var callback = _on_puerta_tocada.bind(dir)
			puerta.body_entered.connect(callback)

func _on_puerta_tocada(body: Node3D, direccion_puerta: String) -> void:
	if jugador == null or body != jugador:
		return
		
	jugador.velocity = Vector3.ZERO
	
	# Mapeo inverso de direcciones (Salida -> Entrada)
	var mapeo_opuestos = {
		"norte": "sur",
		"sur": "norte",
		"este": "oeste",
		"oeste": "este"
	}
	
	var puerta_de_entrada_actual = historial_entradas[indice_habitacion_actual]
	
	# =========================================================================
	# REGLA DE ORO PARA RETROCEDER:
	# =========================================================================
	if direccion_puerta == puerta_de_entrada_actual and indice_habitacion_actual > 0:
		var indice_anterior = indice_habitacion_actual - 1
		var puerta_aparicion_anterior = mapeo_opuestos[direccion_puerta]
		
		print("<- RETROCEDIENDO por la puerta: ", direccion_puerta)
		call_deferred("cargar_habitacion", indice_anterior, puerta_aparicion_anterior)
		
	# =========================================================================
	# REGLA DE ORO PARA AVANZAR:
	# =========================================================================
	else:
		var puerta_aparicion_siguiente = mapeo_opuestos[direccion_puerta]
		
		# Si el jugador retrocedió y toma una puerta NUEVA, borramos el "futuro"
		if indice_habitacion_actual < historial_habitaciones.size() - 1:
			if historial_entradas[indice_habitacion_actual + 1] != puerta_aparicion_siguiente:
				historial_habitaciones = historial_habitaciones.slice(0, indice_habitacion_actual + 1)
				historial_entradas = historial_entradas.slice(0, indice_habitacion_actual + 1)

		# Si es terreno nuevo
		if indice_habitacion_actual == historial_habitaciones.size() - 1:
			var nueva_ruta = pool_de_cuartos.pick_random()
			historial_habitaciones.append(nueva_ruta)
			historial_entradas.append(puerta_aparicion_siguiente)
			
		var siguiente_indice = indice_habitacion_actual + 1
		
		print("-> AVANZANDO por la puerta: ", direccion_puerta)
		call_deferred("cargar_habitacion", siguiente_indice, puerta_aparicion_siguiente)

func colocar_jugador_en_puerta(cuarto_nodo: Node, direccion_puerta: String) -> void:
	var direccion_limpia = direccion_puerta.to_lower().strip_edges()
	var nombre_puerta = "salida " + direccion_limpia
	
	# Intento 1: Búsqueda exacta
	var puerta = cuarto_nodo.find_child(nombre_puerta, true, false)
	
	# Intento 2: Búsqueda flexible por si hay problemas de mayúsculas en el editor
	if puerta == null:
		for hijo in cuarto_nodo.get_children(true):
			if hijo.name.to_lower() == nombre_puerta:
				puerta = hijo
				break

	# Posicionar al jugador si encontramos la puerta
	if puerta is Node3D:
		var pos_puerta = puerta.global_position
		var distancia_seguridad: float = 2.5 
		var desfase = Vector3.ZERO
		
		match direccion_limpia:
			"norte": desfase.z = distancia_seguridad  
			"sur":   desfase.z = -distancia_seguridad 
			"este":  desfase.x = -distancia_seguridad 
			"oeste": desfase.x = distancia_seguridad  
				
		var posicion_final = pos_puerta + desfase
		jugador.set_deferred("global_position", Vector3(posicion_final.x, 0.1, posicion_final.z))
	else:
		print("⚠️ ERR: No se encontró '" + nombre_puerta + "' en " + cuarto_nodo.name + ". Revisa el nombre en el editor.")
		jugador.set_deferred("global_position", Vector3(0.0, 0.1, 0.0))

# ESCUCHA DE VIDA: Lee tus variables del jugador y las dibuja en pantalla
func _on_jugador_vida_cambiada() -> void:
	if barra_vida and jugador:
		barra_vida.max_value = jugador.vida_maxima
		barra_vida.value = jugador.vida_actual

# ESCUCHA DE DASHES: Muestra el texto simple "DASH: 3 / 3" arriba de la barra
func _on_jugador_cargas_cambiadas(cargas_actuales: int, max_cargas: int) -> void:
	if barra_dash:
		barra_dash.max_value = max_cargas
		barra_dash.value = cargas_actuales
		
		# Agregamos la propiedad para que pinte el texto plano con los números
		if "text" in barra_dash:
			barra_dash.text = "DASH: " + str(cargas_actuales) + " / " + str(max_cargas)
