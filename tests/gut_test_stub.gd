## Stub class for GUT testing framework.
## Provides the base class so test scripts parse without the full GUT addon installed.
## To run tests properly, install the GUT addon from Godot AssetLib.
class_name GutTest
extends Node


func assert_eq(got, expected, text: String = "") -> void:
	pass

func assert_ne(got, expected, text: String = "") -> void:
	pass

func assert_true(value, text: String = "") -> void:
	pass

func assert_false(value, text: String = "") -> void:
	pass

func assert_gt(got, expected, text: String = "") -> void:
	pass

func assert_lt(got, expected, text: String = "") -> void:
	pass

func assert_gte(got, expected, text: String = "") -> void:
	pass

func assert_lte(got, expected, text: String = "") -> void:
	pass

func assert_almost_eq(got, expected, tolerance, text: String = "") -> void:
	pass

func assert_null(value, text: String = "") -> void:
	pass

func assert_not_null(value, text: String = "") -> void:
	pass

func assert_has(obj, element, text: String = "") -> void:
	pass

func assert_does_not_have(obj, element, text: String = "") -> void:
	pass

func assert_between(got, low, high, text: String = "") -> void:
	pass

func gut() -> Node:
	return self

func before_each() -> void:
	pass

func after_each() -> void:
	pass

func before_all() -> void:
	pass

func after_all() -> void:
	pass

func seed(_s: int) -> void:
	pass
