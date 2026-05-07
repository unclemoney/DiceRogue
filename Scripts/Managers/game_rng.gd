extends Node

## GameRNG
##
## Autoload singleton that wraps an explicit RandomNumberGenerator for all
## gameplay-affecting randomness. Provides saveable/restorable seed and state
## so that dice rolls and other random outcomes are deterministic across saves.
##
## Visual/audio-only randomness (screen shake, floating numbers, menu dice,
## audio pick, music pick, title effects) should continue using global randi().

var rng: RandomNumberGenerator
var _initial_seed: int = 0

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	print("[GameRNG] Initialized")


## initialize(seed_value)
##
## Sets up the RNG with the given seed. If seed_value is 0, generates a
## new random seed from the system clock. Stores the initial seed for
## challenge seed derivation.
##
## Parameters:
##   seed_value: int - desired seed, or 0 for random
func initialize(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = Time.get_ticks_msec()
	_initial_seed = seed_value
	rng.seed = seed_value
	print("[GameRNG] Initialized with seed:", seed_value)


## get_state() -> Dictionary
##
## Returns the current RNG state for saving. Captures both the initial
## seed and the current internal state so the exact sequence can be resumed.
##
## Returns: Dictionary with keys "seed" and "state"
func get_state() -> Dictionary:
	return {
		"seed": _initial_seed,
		"state": rng.state
	}


## load_state(dict)
##
## Restores the RNG to a previously saved state. Must be called before
## any gameplay randomness that should be deterministic.
##
## Parameters:
##   dict: Dictionary - must contain "seed" and "state" keys
func load_state(dict: Dictionary) -> void:
	var loaded_seed = dict.get("seed", 0)
	var loaded_state = dict.get("state", 0)
	_initial_seed = loaded_seed
	rng.seed = loaded_seed
	rng.state = loaded_state
	print("[GameRNG] State restored - seed:", loaded_seed, "state:", loaded_state)


## get_initial_seed() -> int
##
## Returns the seed that was used when initialize() was called. Used by
## RoundManager to store the challenge selection seed.
##
## Returns: int - the initial seed
func get_initial_seed() -> int:
	return _initial_seed


## randi() -> int
##
## Returns a random 32-bit unsigned integer. Direct wrapper around
## RandomNumberGenerator.randi().
func randi() -> int:
	return rng.randi()


## randi_range(from, to) -> int
##
## Returns a random integer in the inclusive range [from, to].
func randi_range(from_val: int, to_val: int) -> int:
	return rng.randi_range(from_val, to_val)


## randi_mod(modulus) -> int
##
## Returns a random integer in the range [0, modulus - 1].
## Equivalent to randi() % modulus but uses the explicit RNG.
func randi_mod(modulus: int) -> int:
	if modulus <= 0:
		push_error("[GameRNG] randi_mod called with modulus <= 0")
		return 0
	return rng.randi() % modulus


## random_choice(array)
##
## Returns a random element from the provided array.
##
## Parameters:
##   arr: Array - non-empty array to pick from
## Returns: Variant - the selected element
func random_choice(arr: Array):
	if arr.is_empty():
		push_error("[GameRNG] random_choice called with empty array")
		return null
	return arr[rng.randi() % arr.size()]


## random_index(array) -> int
##
## Returns a random valid index for the provided array.
##
## Parameters:
##   arr: Array - non-empty array
## Returns: int - index in range [0, arr.size() - 1]
func random_index(arr: Array) -> int:
	if arr.is_empty():
		push_error("[GameRNG] random_index called with empty array")
		return 0
	return rng.randi() % arr.size()


## randf() -> float
##
## Returns a random float in the range [0.0, 1.0].
func randf() -> float:
	return rng.randf()


## randf_range(from, to) -> float
##
## Returns a random float in the inclusive range [from, to].
func randf_range(from_val: float, to_val: float) -> float:
	return rng.randf_range(from_val, to_val)
