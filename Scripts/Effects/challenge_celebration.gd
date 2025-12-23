extends Node
class_name ChallengeCelebration

## ChallengeCelebration
##
## Manages celebratory firework particle effects when challenges are completed.
## Spawns multiple staggered GPU particle bursts around a target position.

const EXPLOSION_SCENE := preload("res://Scenes/Effects/ChallengeCelebration.tscn")

# Configuration
const NUM_BURSTS: int = 4
const BURST_DELAY: float = 0.15
const SPREAD_RADIUS: float = 60.0

var _active_particles: Array[GPUParticles2D] = []


## trigger_celebration(target_position)
##
## Spawns multiple particle burst explosions around the target position.
## Each burst is staggered by BURST_DELAY seconds for a firework effect.
##
## Parameters:
##   target_position: Vector2 - the center point for the celebration
##   viewport: Node - the viewport/scene to add particles to
func trigger_celebration(target_position: Vector2, viewport: Node) -> void:
	print("[ChallengeCelebration] Triggering celebration at position: %s" % str(target_position))
	
	for i in range(NUM_BURSTS):
		var delay = i * BURST_DELAY
		_spawn_burst_delayed(target_position, viewport, delay, i)


## _spawn_burst_delayed(center, viewport, delay, burst_index)
##
## Spawns a single particle burst after a delay.
func _spawn_burst_delayed(center: Vector2, viewport: Node, delay: float, burst_index: int) -> void:
	if delay > 0:
		await viewport.get_tree().create_timer(delay).timeout
	
	if not is_instance_valid(viewport):
		return
	
	# Calculate offset position for this burst
	var angle = (burst_index * TAU / NUM_BURSTS) + randf_range(-0.3, 0.3)
	var radius = randf_range(SPREAD_RADIUS * 0.5, SPREAD_RADIUS)
	var offset = Vector2(cos(angle), sin(angle)) * radius
	var burst_position = center + offset
	
	# Instantiate and configure the particle effect
	var explosion = EXPLOSION_SCENE.instantiate() as GPUParticles2D
	if not explosion:
		push_error("[ChallengeCelebration] Failed to instantiate explosion scene")
		return
	
	viewport.add_child(explosion)
	explosion.global_position = burst_position
	explosion.z_index = 100
	explosion.emitting = true
	
	_active_particles.append(explosion)
	print("[ChallengeCelebration] Spawned burst %d at %s" % [burst_index, str(burst_position)])
	
	# Schedule cleanup after particles finish
	var cleanup_delay = explosion.lifetime + 0.5
	viewport.get_tree().create_timer(cleanup_delay).timeout.connect(
		func(): _cleanup_particle(explosion)
	)


## _cleanup_particle(particle)
##
## Removes a particle instance from tracking and frees it.
func _cleanup_particle(particle: GPUParticles2D) -> void:
	if is_instance_valid(particle):
		_active_particles.erase(particle)
		particle.queue_free()


## cleanup_all()
##
## Immediately cleans up all active particle effects.
func cleanup_all() -> void:
	for particle in _active_particles:
		if is_instance_valid(particle):
			particle.queue_free()
	_active_particles.clear()
