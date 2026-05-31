## Manages user authentication state, guest ID generation, and login/logout.
## Supports guest play (UUID v4), Google, Facebook, and email/password authentication.
class_name AuthManager
extends RefCounted


## Current authentication state (GUEST or AUTHENTICATED)
var auth_state: Enums.AuthState = Enums.AuthState.GUEST

## Current user identifier (UUID v4 for guests, provider-specific ID for authenticated users)
var user_id: String = ""

## Authentication provider used for login (null equivalent when guest)
var provider: Enums.AuthProvider = Enums.AuthProvider.EMAIL

## Whether a provider has been set (false for guest users)
var _has_provider: bool = false


## Generates a UUID v4 compliant guest identifier.
## Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx (36 characters)
## where x is any hex digit and y is one of 8, 9, a, b.
func generate_guest_id() -> String:
	var hex_chars := "0123456789abcdef"
	var uuid := ""

	for i in range(36):
		if i == 8 or i == 13 or i == 18 or i == 23:
			uuid += "-"
		elif i == 14:
			# Version nibble: always 4
			uuid += "4"
		elif i == 19:
			# Variant nibble: must be 8, 9, a, or b
			var variant_chars := "89ab"
			uuid += variant_chars[randi() % 4]
		else:
			uuid += hex_chars[randi() % 16]

	return uuid


## Attempts to log in with the specified provider and credentials.
## Returns a dictionary with "success" (bool) and either "user_id" or "error".
## Credentials dictionary should contain:
##   - For EMAIL: {"email": String, "password": String}
##   - For GOOGLE/FACEBOOK: {"token": String}
func login(p_provider: Enums.AuthProvider, credentials: Dictionary) -> Dictionary:
	match p_provider:
		Enums.AuthProvider.EMAIL:
			return _login_email(credentials)
		Enums.AuthProvider.GOOGLE:
			return _login_social(p_provider, credentials)
		Enums.AuthProvider.FACEBOOK:
			return _login_social(p_provider, credentials)
		_:
			return {"success": false, "error": "unsupported_provider"}


## Logs out the current user, reverting to guest state with a new guest ID.
func logout() -> void:
	auth_state = Enums.AuthState.GUEST
	user_id = generate_guest_id()
	_has_provider = false


## Returns the current user's identifier.
## For guests, this is a UUID v4. For authenticated users, this is their provider-specific ID.
func get_current_user_id() -> String:
	return user_id


## Initializes the auth manager with a guest ID if no user_id is set.
func initialize() -> void:
	if user_id.is_empty():
		user_id = generate_guest_id()
		auth_state = Enums.AuthState.GUEST
		_has_provider = false


## Validates an email address against RFC 5322 basic rules.
## Returns true if the email is valid.
func validate_email(email: String) -> bool:
	if email.is_empty():
		return false

	# Must contain exactly one @ symbol
	var at_index := email.find("@")
	if at_index == -1:
		return false
	# Check there's no second @
	if email.find("@", at_index + 1) != -1:
		return false

	var local_part := email.substr(0, at_index)
	var domain_part := email.substr(at_index + 1)

	# Local part validation
	if local_part.is_empty() or local_part.length() > 64:
		return false

	# Local part cannot start or end with a dot
	if local_part.begins_with(".") or local_part.ends_with("."):
		return false

	# Local part cannot have consecutive dots
	if local_part.find("..") != -1:
		return false

	# Validate local part characters (simplified RFC 5322)
	for c in local_part:
		if not _is_valid_local_char(c):
			return false

	# Domain part validation
	if domain_part.is_empty() or domain_part.length() > 255:
		return false

	# Domain must contain at least one dot
	if domain_part.find(".") == -1:
		return false

	# Domain cannot start or end with a dot or hyphen
	if domain_part.begins_with(".") or domain_part.ends_with("."):
		return false
	if domain_part.begins_with("-") or domain_part.ends_with("-"):
		return false

	# Validate domain labels
	var labels := domain_part.split(".")
	for label in labels:
		if label.is_empty() or label.length() > 63:
			return false
		if label.begins_with("-") or label.ends_with("-"):
			return false
		for c in label:
			if not _is_valid_domain_char(c):
				return false

	# TLD must have at least 2 characters
	if labels[labels.size() - 1].length() < 2:
		return false

	return true


## Validates a password meets length requirements (8-64 characters).
## Returns true if the password is valid.
func validate_password(password: String) -> bool:
	return password.length() >= 8 and password.length() <= 64


## Returns whether the user is currently authenticated (not a guest).
func is_authenticated() -> bool:
	return auth_state == Enums.AuthState.AUTHENTICATED


## Returns the current provider if authenticated, or null-equivalent if guest.
func get_provider() -> Enums.AuthProvider:
	return provider


## Returns whether a provider has been set (i.e., user is authenticated).
func has_provider() -> bool:
	return _has_provider


# --- Private methods ---

func _login_email(credentials: Dictionary) -> Dictionary:
	if not credentials.has("email") or not credentials.has("password"):
		return {"success": false, "error": "missing_credentials"}

	var email: String = credentials["email"]
	var password: String = credentials["password"]

	if not validate_email(email):
		return {"success": false, "error": "invalid_email"}

	if not validate_password(password):
		return {"success": false, "error": "invalid_password"}

	# Simulate successful email login
	auth_state = Enums.AuthState.AUTHENTICATED
	user_id = email
	provider = Enums.AuthProvider.EMAIL
	_has_provider = true

	return {"success": true, "user_id": user_id}


func _login_social(p_provider: Enums.AuthProvider, credentials: Dictionary) -> Dictionary:
	if not credentials.has("token"):
		return {"success": false, "error": "missing_token"}

	var token: String = credentials["token"]
	if token.is_empty():
		return {"success": false, "error": "invalid_token"}

	# Simulate successful social login — in a real app this would verify with the provider
	auth_state = Enums.AuthState.AUTHENTICATED
	provider = p_provider
	_has_provider = true

	# Generate a provider-specific user ID from the token
	match p_provider:
		Enums.AuthProvider.GOOGLE:
			user_id = "google_" + token.md5_text().substr(0, 16)
		Enums.AuthProvider.FACEBOOK:
			user_id = "fb_" + token.md5_text().substr(0, 16)

	return {"success": true, "user_id": user_id}


func _is_valid_local_char(c: String) -> bool:
	# Alphanumeric
	if c >= "a" and c <= "z":
		return true
	if c >= "A" and c <= "Z":
		return true
	if c >= "0" and c <= "9":
		return true
	# Special characters allowed in local part (RFC 5322 subset)
	if c in [".", "!", "#", "$", "%", "&", "'", "*", "+", "-", "/", "=", "?", "^", "_", "`", "{", "|", "}", "~"]:
		return true
	return false


func _is_valid_domain_char(c: String) -> bool:
	if c >= "a" and c <= "z":
		return true
	if c >= "A" and c <= "Z":
		return true
	if c >= "0" and c <= "9":
		return true
	if c == "-":
		return true
	return false
