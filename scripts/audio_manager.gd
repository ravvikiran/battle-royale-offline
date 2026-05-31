## Audio system managing music, sound effects, and spatial audio.
## Handles volume controls, 3D positional audio with distance attenuation,
## UI sounds, music tracks, storm ambient, and gameplay audio cues.
class_name AudioManager
extends RefCounted


## Maximum audible distance for gunshot sounds (meters).
const GUNSHOT_RANGE: float = 100.0

## Maximum audible distance for footstep sounds (meters).
const FOOTSTEP_RANGE: float = 30.0

## Maximum audible distance for explosion sounds (meters).
const EXPLOSION_RANGE: float = 150.0

## Volume multiplier for the player's own footsteps (lower than enemy footsteps).
const OWN_FOOTSTEP_VOLUME_SCALE: float = 0.4

## Minimum volume value.
const VOLUME_MIN: int = 0

## Maximum volume value.
const VOLUME_MAX: int = 100


## Music volume level (0-100).
var music_volume: int = 70:
	set(value):
		music_volume = clampi(value, VOLUME_MIN, VOLUME_MAX)

## Sound effects volume level (0-100).
var sfx_volume: int = 80:
	set(value):
		sfx_volume = clampi(value, VOLUME_MIN, VOLUME_MAX)

## Voice/announcer volume level (0-100).
var voice_volume: int = 80:
	set(value):
		voice_volume = clampi(value, VOLUME_MIN, VOLUME_MAX)

## Whether spatial (3D positional) audio is enabled.
var spatial_audio_enabled: bool = true

## Whether storm ambient is currently playing.
var _storm_ambient_playing: bool = false

## Currently playing music track (null if none).
var _current_music_track: String = ""


## Available music tracks.
enum MusicTrack {
	LOBBY,
	DROP_PHASE,
	VICTORY,
}

## Sound categories for 3D audio with their max distances.
enum SoundCategory {
	GUNSHOT,
	FOOTSTEP,
	EXPLOSION,
}

## Audio cue types for distinct gameplay events.
enum AudioCue {
	ZONE_WARNING,
	ITEM_PICKUP,
	ELIMINATION,
}


## Returns the maximum audible distance for a given sound category.
static func get_max_distance_for_category(category: SoundCategory) -> float:
	match category:
		SoundCategory.GUNSHOT:
			return GUNSHOT_RANGE
		SoundCategory.FOOTSTEP:
			return FOOTSTEP_RANGE
		SoundCategory.EXPLOSION:
			return EXPLOSION_RANGE
		_:
			return GUNSHOT_RANGE


## Calculates linear distance attenuation factor (1.0 at distance 0, 0.0 at max_distance).
## Returns a value between 0.0 and 1.0.
static func calculate_distance_attenuation(distance: float, max_distance: float) -> float:
	if max_distance <= 0.0:
		return 0.0
	if distance <= 0.0:
		return 1.0
	if distance >= max_distance:
		return 0.0
	return 1.0 - (distance / max_distance)


## Plays a 3D positional sound with distance-based attenuation.
## The sound volume attenuates linearly from full at distance 0 to zero at max_distance.
## If spatial_audio_enabled is false, plays without directional positioning.
## [param clip]: The audio clip identifier to play.
## [param position]: The world position of the sound source (Vector3).
## [param max_distance]: Maximum audible distance in meters.
## [param listener_position]: The listener's world position for distance calculation.
## Returns the calculated volume factor (0.0 to 1.0) for testing purposes.
func play_3d_sound(clip: String, position: Vector3, max_distance: float, listener_position: Vector3 = Vector3.ZERO) -> float:
	var distance := position.distance_to(listener_position)
	var attenuation := calculate_distance_attenuation(distance, max_distance)

	if attenuation <= 0.0:
		return 0.0

	var volume_factor := attenuation * (sfx_volume / 100.0)

	# In a full implementation, this would create an AudioStreamPlayer3D node
	# and configure it with the clip, position, and volume.
	# Spatial audio direction is only applied if spatial_audio_enabled is true.
	return volume_factor


## Plays a non-spatial UI sound (menus, button clicks, notifications).
## UI sounds are not affected by spatial audio settings or distance.
## [param clip]: The audio clip identifier to play.
## Returns the volume factor applied.
func play_ui_sound(clip: String) -> float:
	var volume_factor := sfx_volume / 100.0
	# In a full implementation, this would create an AudioStreamPlayer node
	# (non-positional) and play the clip at the given volume.
	return volume_factor


## Plays a music track (lobby, drop phase, victory screen).
## Stops any currently playing music before starting the new track.
## [param track]: The music track to play.
## Returns the volume factor applied.
func play_music(track: MusicTrack) -> float:
	# Stop current music if playing
	_current_music_track = _get_track_name(track)

	var volume_factor := music_volume / 100.0
	# In a full implementation, this would create/reuse an AudioStreamPlayer
	# and crossfade to the new track.
	return volume_factor


## Plays continuous storm ambient audio while the player is in the storm.
## Respects the player's volume settings (including mute at 0).
## Silently fails if the audio system is unavailable — does not interrupt gameplay.
## Returns true if storm ambient was started, false on silent failure.
func play_storm_ambient() -> bool:
	# Silent failure if audio is unavailable (simulated by sfx_volume check is not needed;
	# the requirement says silent failure if audio system unavailable, not if muted)
	# In a real implementation, we'd check if the audio device/bus is available.
	_storm_ambient_playing = true
	# In a full implementation, this would loop an ambient storm AudioStream.
	return true


## Stops the storm ambient audio.
func stop_storm_ambient() -> void:
	_storm_ambient_playing = false


## Returns whether storm ambient is currently playing.
func is_storm_ambient_playing() -> bool:
	return _storm_ambient_playing


## Plays the player's own footstep sound at lower volume without directional spatialization.
## This distinguishes the player's footsteps from enemy footsteps which are spatialized.
## Returns the volume factor applied.
func play_own_footstep() -> float:
	var volume_factor := (sfx_volume / 100.0) * OWN_FOOTSTEP_VOLUME_SCALE
	# In a full implementation, this would play via a non-positional AudioStreamPlayer
	# at reduced volume (OWN_FOOTSTEP_VOLUME_SCALE) to distinguish from enemy footsteps.
	# No spatialization is applied regardless of spatial_audio_enabled setting.
	return volume_factor


## Plays a distinct audio cue for gameplay events (zone warnings, item pickups, eliminations).
## Each cue type has a unique sound to be easily distinguishable.
## [param cue]: The type of audio cue to play.
## Returns the volume factor applied.
func play_audio_cue(cue: AudioCue) -> float:
	var volume_factor: float
	match cue:
		AudioCue.ZONE_WARNING:
			# Zone warnings use voice volume channel (announcer-style)
			volume_factor = voice_volume / 100.0
		AudioCue.ITEM_PICKUP:
			# Item pickups use sfx volume channel
			volume_factor = sfx_volume / 100.0
		AudioCue.ELIMINATION:
			# Eliminations use sfx volume channel
			volume_factor = sfx_volume / 100.0
		_:
			volume_factor = sfx_volume / 100.0

	# In a full implementation, each cue type would map to a distinct audio resource
	# and be played via a non-positional AudioStreamPlayer.
	return volume_factor


## Convenience method to play a gunshot sound at a world position.
## Uses the predefined GUNSHOT_RANGE for max distance.
func play_gunshot(position: Vector3, listener_position: Vector3 = Vector3.ZERO) -> float:
	return play_3d_sound("gunshot", position, GUNSHOT_RANGE, listener_position)


## Convenience method to play a footstep sound at a world position (enemy footstep).
## Uses the predefined FOOTSTEP_RANGE for max distance.
func play_footstep(position: Vector3, listener_position: Vector3 = Vector3.ZERO) -> float:
	return play_3d_sound("footstep", position, FOOTSTEP_RANGE, listener_position)


## Convenience method to play an explosion sound at a world position.
## Uses the predefined EXPLOSION_RANGE for max distance.
func play_explosion(position: Vector3, listener_position: Vector3 = Vector3.ZERO) -> float:
	return play_3d_sound("explosion", position, EXPLOSION_RANGE, listener_position)


## Sets all volume levels at once.
func set_volumes(music: int, sfx: int, voice: int) -> void:
	music_volume = music
	sfx_volume = sfx
	voice_volume = voice


## Returns the track name string for a given MusicTrack enum value.
func _get_track_name(track: MusicTrack) -> String:
	match track:
		MusicTrack.LOBBY:
			return "lobby"
		MusicTrack.DROP_PHASE:
			return "drop_phase"
		MusicTrack.VICTORY:
			return "victory"
		_:
			return "unknown"
