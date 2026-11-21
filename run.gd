extends Node2D

const PAD_WIDTH := 58.0
const PLAYER_HALF_WIDTH := 11.0
const PLAYER_HALF_HEIGHT := 15.0

@onready var player = $Player
@onready var decks: Array[StaticBody2D] = [
	$Route/Start, $Route/Landing1, $Route/Landing2, $Route/Exit
]
@onready var pits: Array[StaticBody2D] = [
	$Route/Catch1, $Route/Catch2, $Route/Catch3
]

var checkpoint := 0
var falls := 0
var pad_live := false
var finished := false


func _ready() -> void:
	player.landed.connect(_on_landed)
	player.fell_out.connect(_recover)
	$HUD/Finish/Again.pressed.connect(_restart)
	_install_art()
	_restart()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_sound"):
		var muted := not AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, muted)
		$HUD/Audio.text = "M · Sound off" if muted else "M · Sound on"
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart") or (finished and event.is_action_pressed("jump")):
		_restart()
		get_viewport().set_input_as_handled()


func _restart() -> void:
	checkpoint = 0
	falls = 0
	finished = false
	_clear_pad()
	$HUD/Finish.hide()
	$HUD/Help.show()
	player.respawn(_spawn_point())
	player.set_physics_process(true)
	_update_score()
	$HUD/Hint.text = "Drop into the first well to make a spring."


func _on_landed(surface: StaticBody2D) -> void:
	var deck := decks.find(surface)
	if deck == checkpoint + 1:
		checkpoint = deck
		_clear_pad()
		_update_score()
		if checkpoint == pits.size():
			_win()
		else:
			$HUD/Hint.text = "Checkpoint saved. Make a spring in the next well."
		return

	var pit := pits.find(surface)
	if pit == -1:
		return
	if pit != checkpoint:
		_recover()
		return

	if pad_live and absf(player.position.x - $Spring.position.x) < PAD_WIDTH / 2.0 + PLAYER_HALF_WIDTH:
		player.spring_up()
		$Sounds/Spring.play()
		$HUD/Hint.text = "Steer right in the air to reach the next ledge."
		return

	if not pad_live:
		var shape := surface.get_node("CollisionShape2D") as CollisionShape2D
		var size := (shape.shape as RectangleShape2D).size
		var free_space := (size.x - PAD_WIDTH) / 2.0
		$Spring.position.x = clampf(
			player.position.x, surface.position.x - free_space, surface.position.x + free_space
		)
		$Spring.position.y = surface.position.y - size.y / 2.0
		pad_live = true
		$Spring.show()
	_recover()


func _recover() -> void:
	falls += 1
	$Sounds/Fall.play()
	player.respawn(_spawn_point())
	_update_score()
	if pad_live:
		$HUD/Hint.text = "Your spring is ready. Land on it and steer toward the ledge."
	else:
		$HUD/Hint.text = "Try dropping into the well directly ahead."


func _spawn_point() -> Vector2:
	var deck := decks[checkpoint]
	var collider := deck.get_node("CollisionShape2D") as CollisionShape2D
	var size := (collider.shape as RectangleShape2D).size
	return deck.position + Vector2(0, -size.y / 2.0 - PLAYER_HALF_HEIGHT - 2.0)


func _clear_pad() -> void:
	pad_live = false
	$Spring.hide()


func _update_score() -> void:
	var fall_label := "fall" if falls == 1 else "falls"
	$HUD/Progress.text = "%d / %d ledges    |    %d %s" % [checkpoint, pits.size(), falls, fall_label]


func _win() -> void:
	finished = true
	player.set_physics_process(false)
	$Sounds/Win.play()
	$HUD/Hint.text = "You reached the top."
	$HUD/Help.hide()
	$HUD/Finish/Result.text = "Every fall helped you climb."
	$HUD/Finish/Stats.text = "Finished with %d falls" % falls
	$HUD/Finish.show()
	$HUD/Finish/Again.grab_focus()


func _install_art() -> void:
	_set_texture($Field, "res://art/backdrop.png", Vector2(886, 434))
	_set_texture($Player, "res://art/player.png", Vector2(24, 30), Vector2.ZERO, true)
	for surface in decks:
		_skin_surface(surface, "res://art/ledge.png")
	for surface in pits:
		_skin_surface(surface, "res://art/well.png")
	_set_texture($Spring, "res://art/spring.png", Vector2(46, 23), Vector2(0, -11.5))
	_set_texture($ExitSign, "res://art/exit.png", Vector2(32, 34), Vector2(0, -17))
	_set_audio($Player/JumpSound, "res://audio/jump.wav")
	_set_audio($Sounds/Fall, "res://audio/fall.wav")
	_set_audio($Sounds/Spring, "res://audio/spring.wav")
	_set_audio($Sounds/Win, "res://audio/win.wav")
	if _set_audio($Sounds/Music, "res://audio/music.ogg"):
		var track := $Sounds/Music.stream as AudioStreamOggVorbis
		track.loop = true
		$Sounds/Music.play()


func _skin_surface(surface: StaticBody2D, path: String) -> void:
	var collider := surface.get_node("CollisionShape2D") as CollisionShape2D
	var size := (collider.shape as RectangleShape2D).size
	_set_texture(surface, path, size)
	var sprite := surface.get_node("Art") as Sprite2D
	if sprite.texture != null:
		var tile_size := sprite.texture.get_size()
		if tile_size.x == tile_size.y:
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, size.x * tile_size.y / size.y, tile_size.y)
			sprite.scale = Vector2.ONE * size.y / tile_size.y


func _set_texture(
	node: Node2D, path: String, size: Vector2, offset := Vector2.ZERO, trim_padding := false
) -> void:
	if not ResourceLoader.exists(path, "Texture2D"):
		return
	var texture := load(path) as Texture2D
	var sprite := node.get_node("Art") as Sprite2D
	sprite.texture = texture
	sprite.position = offset
	var source_size := texture.get_size()
	if trim_padding:
		var bounds := texture.get_image().get_used_rect()
		if bounds.has_area():
			sprite.region_enabled = true
			sprite.region_rect = Rect2(bounds)
			source_size = Vector2(bounds.size)
	sprite.scale = size / source_size
	node.get_node("Preview").hide()


func _set_audio(sound: AudioStreamPlayer, path: String) -> bool:
	if not ResourceLoader.exists(path, "AudioStream"):
		return false
	sound.stream = load(path) as AudioStream
	return true
