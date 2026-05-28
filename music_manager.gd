extends Node

@onready var player1 = $Player1
@onready var player2 = $Player2

const BPM : float = 118.0

# El punto de salida real es el Beat 96 (Segundo 48.813)
const LOOP_OUT_TIME : float = 96.0 * (60.0 / BPM) 

# Los 8 beats de silencio/reverb que le quedan al archivo (4.067 segundos)
const REVERB_TAIL : float = 8.0 * (60.0 / BPM) 

var current_player : AudioStreamPlayer
var next_player : AudioStreamPlayer
var loop_triggered : bool = false

func _ready():
	current_player = player1
	next_player = player2
	
	current_player.volume_db = -15
	current_player.play()

func _process(_delta):
	if not current_player.playing:
		return
		
	# Le preguntamos a la tarjeta de sonido la posición exacta del audio
	var playback_pos = current_player.get_playback_position()
	
	# En cuanto toque el segundo 48.81 (Beat 96), disparamos la nueva vuelta
	if playback_pos >= LOOP_OUT_TIME and not loop_triggered:
		loop_triggered = true
		trigger_loop()

func trigger_loop():
	# 1. El siguiente reproductor empieza desde el puro inicio (segundo 0)
	next_player.volume_db = -15
	next_player.play(0.0) 
	
	var old_player = current_player
	
	# 2. El reproductor viejo sigue reproduciendo el silencio con reverb que viene después del beat 96.
	# Le bajamos el volumen con un Tween durante esos 4.06 segundos para que muera de forma natural.
	var tween = create_tween()
	tween.tween_property(old_player, "volume_db", -80.0, REVERB_TAIL)
	tween.tween_callback(func(): 
		old_player.stop() # Apagamos el reproductor cuando la reverb ya no se escuche
	)
	
	# 3. Intercambiamos los reproductores para el siguiente ciclo
	current_player = next_player
	next_player = old_player
	
	# Reseteamos el candado para la próxima vuelta
	loop_triggered = false
