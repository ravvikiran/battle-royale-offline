## Plug-and-play asset loading system.
## Loads models, audio, textures, and VFX from res://assets/ with caching.
## Returns null when an asset doesn't exist so callers can fall back to placeholders.
extends Node

var _cache: Dictionary = {}

func load_model(relative_path: String) -> PackedScene:
	var full_path := "res://assets/" + relative_path
	if _cache.has(full_path):
		return _cache[full_path]
	if not ResourceLoader.exists(full_path):
		push_warning("Asset not found: %s — using placeholder" % full_path)
		return null
	var resource := load(full_path) as PackedScene
	_cache[full_path] = resource
	return resource

func load_audio(relative_path: String) -> AudioStream:
	var full_path := "res://assets/" + relative_path
	if _cache.has(full_path):
		return _cache[full_path]
	if not ResourceLoader.exists(full_path):
		return null
	var resource := load(full_path) as AudioStream
	_cache[full_path] = resource
	return resource

func load_texture(relative_path: String) -> Texture2D:
	var full_path := "res://assets/" + relative_path
	if _cache.has(full_path):
		return _cache[full_path]
	if not ResourceLoader.exists(full_path):
		return null
	var resource := load(full_path) as Texture2D
	_cache[full_path] = resource
	return resource

func load_vfx(relative_path: String) -> PackedScene:
	var full_path := "res://assets/" + relative_path
	if _cache.has(full_path):
		return _cache[full_path]
	if not ResourceLoader.exists(full_path):
		return null
	var resource := load(full_path) as PackedScene
	_cache[full_path] = resource
	return resource

func clear_cache() -> void:
	_cache.clear()
