## Property-based test for audio distance attenuation.
## **Validates: Requirements 12.1**
##
## Property 29: Audio distance attenuation
## *For any* sound source at distance D from the player, the audio volume SHALL
## attenuate with distance and SHALL be zero when D exceeds the source type's
## maximum range (gunshots: 100m, footsteps: 30m, explosions: 150m).
extends GutTest


## Number of random test iterations per property test.
const NUM_ITERATIONS := 100

## Tolerance for floating point comparisons.
const EPSILON := 0.001

## Sound categories with their maximum audible distances.
const SOUND_CATEGORIES := [
	{"category": AudioManager.SoundCategory.GUNSHOT, "max_distance": 100.0, "name": "gunshot"},
	{"category": AudioManager.SoundCategory.FOOTSTEP, "max_distance": 30.0, "name": "footstep"},
	{"category": AudioManager.SoundCategory.EXPLOSION, "max_distance": 150.0, "name": "explosion"},
]


var _rng: RandomNumberGenerator
var _audio_manager: AudioManager


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_audio_manager = AudioManager.new()
	# Set sfx_volume to 100 so attenuation is purely distance-based
	_audio_manager.sfx_volume = 100


## Generates a random 3D position at a specific distance from the listener.
func _position_at_distance(listener: Vector3, distance: float) -> Vector3:
	# Generate a random direction in 3D space
	var theta := _rng.randf_range(0.0, TAU)
	var phi := _rng.randf_range(-PI / 2.0, PI / 2.0)
	var direction := Vector3(
		cos(phi) * cos(theta),
		sin(phi),
		cos(phi) * sin(theta)
	).normalized()
	return listener + direction * distance


## Returns a random sound category configuration.
func _random_sound_category() -> Dictionary:
	return SOUND_CATEGORIES[_rng.randi_range(0, SOUND_CATEGORIES.size() - 1)]


## Returns a random listener position.
func _random_listener_position() -> Vector3:
	return Vector3(
		_rng.randf_range(-500.0, 500.0),
		_rng.randf_range(0.0, 50.0),
		_rng.randf_range(-500.0, 500.0)
	)


# --- Property 29: Audio distance attenuation ---

## Property test: Volume SHALL be zero when distance exceeds the source type's
## maximum range.
func test_property_zero_volume_beyond_max_range() -> void:
	gut.p("Property 29: Audio distance attenuation - zero beyond max range")
	gut.p("For any sound at distance > max range, volume SHALL be zero.")

	for i in range(NUM_ITERATIONS):
		var category_config := _random_sound_category()
		var max_distance: float = category_config["max_distance"]
		var category_name: String = category_config["name"]

		# Generate a distance beyond the max range
		var distance := _rng.randf_range(max_distance + 0.01, max_distance * 3.0)

		var listener := _random_listener_position()
		var source := _position_at_distance(listener, distance)

		# Use the convenience methods that apply the correct max_distance per category
		var volume: float
		match category_config["category"]:
			AudioManager.SoundCategory.GUNSHOT:
				volume = _audio_manager.play_gunshot(source, listener)
			AudioManager.SoundCategory.FOOTSTEP:
				volume = _audio_manager.play_footstep(source, listener)
			AudioManager.SoundCategory.EXPLOSION:
				volume = _audio_manager.play_explosion(source, listener)

		assert_almost_eq(volume, 0.0, EPSILON,
			"[Iter %d] %s at distance %.2f (max %.2f) should have zero volume, got %.4f" % [
				i, category_name, distance, max_distance, volume])


## Property test: Volume SHALL attenuate with distance (monotonically decreasing).
## For any two distances d1 < d2 within max range, volume(d1) >= volume(d2).
func test_property_volume_attenuates_with_distance() -> void:
	gut.p("Property 29: Audio distance attenuation - monotonic decrease")
	gut.p("For any d1 < d2, volume at d1 SHALL be >= volume at d2.")

	for i in range(NUM_ITERATIONS):
		var category_config := _random_sound_category()
		var max_distance: float = category_config["max_distance"]
		var category_name: String = category_config["name"]

		# Generate two distances where d1 < d2
		var d1 := _rng.randf_range(0.0, max_distance * 1.5)
		var d2 := _rng.randf_range(d1, max_distance * 2.0)

		var listener := _random_listener_position()
		var source1 := _position_at_distance(listener, d1)
		var source2 := _position_at_distance(listener, d2)

		var volume1: float
		var volume2: float
		match category_config["category"]:
			AudioManager.SoundCategory.GUNSHOT:
				volume1 = _audio_manager.play_gunshot(source1, listener)
				volume2 = _audio_manager.play_gunshot(source2, listener)
			AudioManager.SoundCategory.FOOTSTEP:
				volume1 = _audio_manager.play_footstep(source1, listener)
				volume2 = _audio_manager.play_footstep(source2, listener)
			AudioManager.SoundCategory.EXPLOSION:
				volume1 = _audio_manager.play_explosion(source1, listener)
				volume2 = _audio_manager.play_explosion(source2, listener)

		assert_true(volume1 >= volume2 - EPSILON,
			"[Iter %d] %s: volume at d=%.2f (%.4f) should be >= volume at d=%.2f (%.4f)" % [
				i, category_name, d1, volume1, d2, volume2])


## Property test: Volume at distance zero SHALL be maximum (1.0 when sfx_volume is 100).
func test_property_full_volume_at_zero_distance() -> void:
	gut.p("Property 29: Audio distance attenuation - full volume at zero distance")
	gut.p("For any sound at distance 0, volume SHALL be maximum.")

	for i in range(NUM_ITERATIONS):
		var category_config := _random_sound_category()
		var category_name: String = category_config["name"]

		var listener := _random_listener_position()
		# Source at same position as listener (distance = 0)
		var source := listener

		var volume: float
		match category_config["category"]:
			AudioManager.SoundCategory.GUNSHOT:
				volume = _audio_manager.play_gunshot(source, listener)
			AudioManager.SoundCategory.FOOTSTEP:
				volume = _audio_manager.play_footstep(source, listener)
			AudioManager.SoundCategory.EXPLOSION:
				volume = _audio_manager.play_explosion(source, listener)

		assert_almost_eq(volume, 1.0, EPSILON,
			"[Iter %d] %s at distance 0 should have full volume (1.0), got %.4f" % [
				i, category_name, volume])


## Property test: Volume at exactly the max range boundary SHALL be zero.
func test_property_zero_volume_at_exact_max_range() -> void:
	gut.p("Property 29: Audio distance attenuation - zero at exact max range")
	gut.p("For any sound at exactly max range, volume SHALL be zero.")

	for i in range(NUM_ITERATIONS):
		var category_config := _random_sound_category()
		var max_distance: float = category_config["max_distance"]
		var category_name: String = category_config["name"]

		var listener := _random_listener_position()
		var source := _position_at_distance(listener, max_distance)

		var volume: float
		match category_config["category"]:
			AudioManager.SoundCategory.GUNSHOT:
				volume = _audio_manager.play_gunshot(source, listener)
			AudioManager.SoundCategory.FOOTSTEP:
				volume = _audio_manager.play_footstep(source, listener)
			AudioManager.SoundCategory.EXPLOSION:
				volume = _audio_manager.play_explosion(source, listener)

		assert_almost_eq(volume, 0.0, EPSILON,
			"[Iter %d] %s at exactly max range %.2f should have zero volume, got %.4f" % [
				i, category_name, max_distance, volume])


## Property test: The static calculate_distance_attenuation function correctly
## maps distance to attenuation factor for all sound categories.
func test_property_attenuation_factor_within_range() -> void:
	gut.p("Property 29: Audio distance attenuation - attenuation factor correctness")
	gut.p("For any distance within range, attenuation = 1.0 - (distance / max_distance).")

	for i in range(NUM_ITERATIONS):
		var category_config := _random_sound_category()
		var max_distance: float = category_config["max_distance"]
		var category_name: String = category_config["name"]

		# Generate a distance within the valid range (0, max_distance)
		var distance := _rng.randf_range(0.01, max_distance - 0.01)

		var attenuation := AudioManager.calculate_distance_attenuation(distance, max_distance)
		var expected := 1.0 - (distance / max_distance)

		# Attenuation should be between 0 and 1
		assert_true(attenuation >= 0.0 and attenuation <= 1.0,
			"[Iter %d] %s: attenuation %.4f at distance %.2f should be in [0, 1]" % [
				i, category_name, attenuation, distance])

		# Attenuation should match the linear formula
		assert_almost_eq(attenuation, expected, EPSILON,
			"[Iter %d] %s: attenuation at distance %.2f should be %.4f, got %.4f" % [
				i, category_name, distance, expected, attenuation])


## Property test: Each sound category uses the correct max distance constant.
## Gunshots: 100m, Footsteps: 30m, Explosions: 150m.
func test_property_correct_max_distance_per_category() -> void:
	gut.p("Property 29: Audio distance attenuation - correct max distances")
	gut.p("Each category uses its specified max distance.")

	for i in range(NUM_ITERATIONS):
		# Verify the max distance constants match the specification
		var gunshot_max := AudioManager.get_max_distance_for_category(AudioManager.SoundCategory.GUNSHOT)
		var footstep_max := AudioManager.get_max_distance_for_category(AudioManager.SoundCategory.FOOTSTEP)
		var explosion_max := AudioManager.get_max_distance_for_category(AudioManager.SoundCategory.EXPLOSION)

		assert_almost_eq(gunshot_max, 100.0, EPSILON,
			"[Iter %d] Gunshot max distance should be 100m, got %.2f" % [i, gunshot_max])
		assert_almost_eq(footstep_max, 30.0, EPSILON,
			"[Iter %d] Footstep max distance should be 30m, got %.2f" % [i, footstep_max])
		assert_almost_eq(explosion_max, 150.0, EPSILON,
			"[Iter %d] Explosion max distance should be 150m, got %.2f" % [i, explosion_max])

		# Verify that a sound just inside max range is audible, just outside is not
		var category_config := _random_sound_category()
		var max_dist: float = category_config["max_distance"]

		var just_inside := max_dist - 0.1
		var just_outside := max_dist + 0.1

		var atten_inside := AudioManager.calculate_distance_attenuation(just_inside, max_dist)
		var atten_outside := AudioManager.calculate_distance_attenuation(just_outside, max_dist)

		assert_true(atten_inside > 0.0,
			"[Iter %d] %s: just inside max range (%.2f) should be audible" % [
				i, category_config["name"], just_inside])
		assert_almost_eq(atten_outside, 0.0, EPSILON,
			"[Iter %d] %s: just outside max range (%.2f) should be silent" % [
				i, category_config["name"], just_outside])
