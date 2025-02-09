extends StaticBody2D

signal health_changed

@export var bullet_scene : PackedScene
@export var maxHealth = 35
@export var currentHealth:float
@export var healthRegen = 1
@export var collectable_scn: PackedScene
@export var drop_type: String
@export var drop_count = 1
@export var durability = 5 #secs to mine
@export var max_drops = 10
@export var DMG = 10  #damage the bullet deals
@export var AtkSpeed = 1
@export var drop_throw_distance = 0
@export var is_attacking:bool = true
@export var attack_able:bool = true
@export var bulletcolor:Color

@export var tut:bool =false

var mined_drops = 0 #num resources mined so fat
var miners = []

var player = null

enum RESOURCE_STATE { AGGESSIVE , PASSIVE , MINED , DEAD }

@export var state : RESOURCE_STATE

@export var shoot_state = 0

func mine(miner):
	
	if state == RESOURCE_STATE.DEAD or state == RESOURCE_STATE.AGGESSIVE:
		return [0, null]
	elif state == RESOURCE_STATE.PASSIVE:
		state = RESOURCE_STATE.MINED
		name = "resource"
		$AnimatedSprite2D.play("mined")
		
	#resource should be mineable now
	mined_drops += 1
	
	# if resource already at max
	if mined_drops >= max_drops:
		state = RESOURCE_STATE.DEAD
		name = "deadresource"
		$AnimatedSprite2D.play("depleted")
		if str(miner).left(9) != "Harvester":
			return  [0, null]
	
	#otherwise add miner to list of subscribers
	if !miners.has(miner):
		miners.push_back(miner)
	var drop = collectable_scn.instantiate()
	drop.type = drop_type
	return [durability, drop]

# Called when the node enters the scene tree for the first time.
func _ready():
	
	$Timer.wait_time = 1/AtkSpeed + randf_range(-.01,.01)
	$Area2D/CollisionShape2D.disabled = !attack_able
	$Timer.autostart = is_attacking
	if is_attacking:
		$Timer.start()
	currentHealth = maxHealth
	$HealthBar.max_value = maxHealth
	$HealthBar.value = currentHealth
	$AnimatedSprite2D.play("default")
	state = RESOURCE_STATE.AGGESSIVE
	name = "aggressiveresource"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if state == RESOURCE_STATE.AGGESSIVE and currentHealth <=0:
		Save.set_value(1, "BRDEF", Save.get_value(1, "BRDEF", 0)+1)
		name = "resource"
		$AnimatedSprite2D.play("tamed")
		state = RESOURCE_STATE.PASSIVE
		$HealthBar.queue_free()
		$Timer.stop()
		$Area2D.set_collision_layer_value(3, false)
		#$Area2D.queue_free()
	
func attack():
	if !tut:
		var shoot_angle = randf_range(0,TAU)
		#var shoot_angle = deg_to_rad((shoot_state * 90) % 360)
		shoot_bullet(shoot_angle, 1, 10, 1)
		shoot_state += 1
	else:
		var shoot_angle = deg_to_rad((shoot_state * 90) % 360)
		shoot_bullet(shoot_angle, 1, 10, 1)

func shoot_bullet(angle, expiration, damage, size):
	var bullet = bullet_scene.instantiate()
	var velocity = Vector2(150.0, 0.0)
	bullet.damage = DMG
	bullet.direction = Vector2.RIGHT.rotated(angle)
	bullet.modulate = bulletcolor
	add_child(bullet)

func _on_area_2d_area_entered(area: Area2D) -> void:
	if state == RESOURCE_STATE.AGGESSIVE and "damage" in area:
		take_damage(area.damage)

func take_damage(damage):
	currentHealth += -damage
	#print(area.damage)
	$HealthBar.value = currentHealth
	$AnimatedSprite2D.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.modulate = Color.WHITE
# demo func based on harvester

signal getting_gathered
var test = "I'm gathering"

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event.get_class() == "InputEventMouseButton" and event.pressed:
		if state != RESOURCE_STATE.AGGESSIVE and state != RESOURCE_STATE.DEAD:
			spawn_collectable()
			
func spawn_collectable():
	var mine_ref = mine(null)
	var new_drop= collectable_scn.instantiate()
	new_drop.type = drop_type
	
	getting_gathered.emit(test)
	
	# drop in a random dir along resource
	var drop_dest = Vector2.RIGHT.rotated(randf_range(0, 2*PI)).normalized() * 32
	new_drop.drift(drop_dest)
	#new_drop.set_collision_layer_value(4, false)
	add_child(new_drop)
	#print("Mining this, durab\t", mine_ref[0], "\tRef\t",mine_ref[1])

func _on_area_2d_2_body_entered(body: Node2D) -> void:
	if "player_tag" in body && player == null:
		player = body
		player._link_resource(self)
