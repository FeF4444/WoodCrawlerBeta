extends Node3D

@onready var room_container: Node3D = $RoomContainer
var jugador: CharacterBody3D = null

func _enter_tree() -> void:
	# Buscador inteligente del personaje al arrancar
	for hijo in get_children():
		if hijo is CharacterBody3D:
			jugador = hijo
			break

func _ready() -> void:
	# Instanciamos el cuarto base de forma limpia
	var nueva_escena = load("res://rooms/cuarto_base.tscn")
	if nueva_escena:
		var nueva_room = nueva_escena.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		room_container.add_child(nueva_room)
		conectar_puertas_del_cuarto(nueva_room)
	
	if jugador != null:
		jugador.global_position = Vector3(0, 0.1, 0)
	else:
		print("⚠️ ADVERTENCIA: No se encontró al jugador en la raíz de Mundo.")

func conectar_puertas_del_cuarto(cuarto_nodo: Node) -> void:
	# Buscamos el nodo usando el nombre exacto con espacio que tienes en tu escena
	var puerta = cuarto_nodo.find_child("salida este", true, false)
	
	if puerta == null:
		print("❌ ERROR CRÍTICO: No se encontró el nodo 'salida este' en la habitación.")
		return
		
	print("✅ ¡ENCONTRADO!: El nodo 'salida este' existe en la escena.")
	
	# Conectamos la señal física de Godot por código de forma segura
	if puerta.body_entered.is_connected(_on_body_puerta_tocada):
		puerta.body_entered.disconnect(_on_body_puerta_tocada)
	puerta.body_entered.connect(_on_body_puerta_tocada)
	print("🚀 SENSOR CONECTADO CON ÉXITO. Camina hacia la salida.")

func _on_body_puerta_tocada(body: Node3D) -> void:
	# Verificamos si el cuerpo que cruza la puerta es nuestro jugador
	if jugador != null and body == jugador:
		print("🚀 ¡PORTAL ENGANCHADO! Teletransportando al títere...")
		jugador.velocity = Vector3.ZERO # Frenamos su inercia física para evitar tirones
		jugador.set_deferred("global_position", Vector3(-8, 0.1, 0))
