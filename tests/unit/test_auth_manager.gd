## Unit tests for AuthManager: guest ID generation, login/logout, email/password validation.
extends GutTest


var _auth: AuthManager


func before_each() -> void:
	_auth = AuthManager.new()


# --- Guest ID generation tests ---

func test_generate_guest_id_length() -> void:
	var guest_id := _auth.generate_guest_id()
	assert_eq(guest_id.length(), 36, "UUID v4 should be 36 characters")


func test_generate_guest_id_hyphen_positions() -> void:
	var guest_id := _auth.generate_guest_id()
	assert_eq(guest_id[8], "-", "Hyphen at position 8")
	assert_eq(guest_id[13], "-", "Hyphen at position 13")
	assert_eq(guest_id[18], "-", "Hyphen at position 18")
	assert_eq(guest_id[23], "-", "Hyphen at position 23")


func test_generate_guest_id_version_nibble() -> void:
	var guest_id := _auth.generate_guest_id()
	assert_eq(guest_id[14], "4", "Version nibble at position 14 should be '4'")


func test_generate_guest_id_variant_nibble() -> void:
	var guest_id := _auth.generate_guest_id()
	var variant_char := guest_id[19]
	assert_true(
		variant_char == "8" or variant_char == "9" or variant_char == "a" or variant_char == "b",
		"Variant nibble at position 19 should be 8, 9, a, or b. Got: " + variant_char
	)


func test_generate_guest_id_only_hex_and_hyphens() -> void:
	var guest_id := _auth.generate_guest_id()
	var valid_chars := "0123456789abcdef-"
	for i in range(guest_id.length()):
		assert_true(
			valid_chars.find(guest_id[i]) != -1,
			"Character at position %d should be hex or hyphen, got: %s" % [i, guest_id[i]]
		)


func test_generate_guest_id_uniqueness() -> void:
	var id1 := _auth.generate_guest_id()
	var id2 := _auth.generate_guest_id()
	assert_ne(id1, id2, "Two generated IDs should be different")


# --- Initialize tests ---

func test_initialize_sets_guest_id() -> void:
	_auth.initialize()
	assert_false(_auth.user_id.is_empty(), "User ID should be set after initialize")
	assert_eq(_auth.auth_state, Enums.AuthState.GUEST)
	assert_eq(_auth.user_id.length(), 36)


func test_initialize_does_not_overwrite_existing_id() -> void:
	_auth.user_id = "existing-id"
	_auth.initialize()
	assert_eq(_auth.user_id, "existing-id")


# --- Email validation tests ---

func test_validate_email_valid_simple() -> void:
	assert_true(_auth.validate_email("user@example.com"))


func test_validate_email_valid_with_dots() -> void:
	assert_true(_auth.validate_email("first.last@example.com"))


func test_validate_email_valid_with_plus() -> void:
	assert_true(_auth.validate_email("user+tag@example.com"))


func test_validate_email_valid_subdomain() -> void:
	assert_true(_auth.validate_email("user@mail.example.co.uk"))


func test_validate_email_invalid_empty() -> void:
	assert_false(_auth.validate_email(""))


func test_validate_email_invalid_no_at() -> void:
	assert_false(_auth.validate_email("userexample.com"))


func test_validate_email_invalid_double_at() -> void:
	assert_false(_auth.validate_email("user@@example.com"))


func test_validate_email_invalid_no_domain_dot() -> void:
	assert_false(_auth.validate_email("user@example"))


func test_validate_email_invalid_leading_dot_local() -> void:
	assert_false(_auth.validate_email(".user@example.com"))


func test_validate_email_invalid_trailing_dot_local() -> void:
	assert_false(_auth.validate_email("user.@example.com"))


func test_validate_email_invalid_consecutive_dots() -> void:
	assert_false(_auth.validate_email("user..name@example.com"))


func test_validate_email_invalid_empty_local() -> void:
	assert_false(_auth.validate_email("@example.com"))


func test_validate_email_invalid_empty_domain() -> void:
	assert_false(_auth.validate_email("user@"))


func test_validate_email_invalid_domain_leading_hyphen() -> void:
	assert_false(_auth.validate_email("user@-example.com"))


func test_validate_email_invalid_domain_trailing_hyphen() -> void:
	assert_false(_auth.validate_email("user@example-.com"))


func test_validate_email_invalid_short_tld() -> void:
	assert_false(_auth.validate_email("user@example.c"))


# --- Password validation tests ---

func test_validate_password_valid_8_chars() -> void:
	assert_true(_auth.validate_password("12345678"))


func test_validate_password_valid_64_chars() -> void:
	var long_pass := "a".repeat(64)
	assert_true(_auth.validate_password(long_pass))


func test_validate_password_valid_middle_length() -> void:
	assert_true(_auth.validate_password("MyP@ssw0rd!"))


func test_validate_password_invalid_too_short() -> void:
	assert_false(_auth.validate_password("1234567"))


func test_validate_password_invalid_empty() -> void:
	assert_false(_auth.validate_password(""))


func test_validate_password_invalid_too_long() -> void:
	var too_long := "a".repeat(65)
	assert_false(_auth.validate_password(too_long))


# --- Login tests (email) ---

func test_login_email_success() -> void:
	var result := _auth.login(Enums.AuthProvider.EMAIL, {"email": "test@example.com", "password": "securepass1"})
	assert_true(result["success"])
	assert_eq(result["user_id"], "test@example.com")
	assert_eq(_auth.auth_state, Enums.AuthState.AUTHENTICATED)
	assert_eq(_auth.provider, Enums.AuthProvider.EMAIL)
	assert_true(_auth.is_authenticated())


func test_login_email_invalid_email() -> void:
	var result := _auth.login(Enums.AuthProvider.EMAIL, {"email": "invalid", "password": "securepass1"})
	assert_false(result["success"])
	assert_eq(result["error"], "invalid_email")
	assert_eq(_auth.auth_state, Enums.AuthState.GUEST)


func test_login_email_invalid_password() -> void:
	var result := _auth.login(Enums.AuthProvider.EMAIL, {"email": "test@example.com", "password": "short"})
	assert_false(result["success"])
	assert_eq(result["error"], "invalid_password")
	assert_eq(_auth.auth_state, Enums.AuthState.GUEST)


func test_login_email_missing_credentials() -> void:
	var result := _auth.login(Enums.AuthProvider.EMAIL, {})
	assert_false(result["success"])
	assert_eq(result["error"], "missing_credentials")


# --- Login tests (social) ---

func test_login_google_success() -> void:
	var result := _auth.login(Enums.AuthProvider.GOOGLE, {"token": "valid_google_token_123"})
	assert_true(result["success"])
	assert_true(result["user_id"].begins_with("google_"))
	assert_eq(_auth.auth_state, Enums.AuthState.AUTHENTICATED)
	assert_eq(_auth.provider, Enums.AuthProvider.GOOGLE)


func test_login_facebook_success() -> void:
	var result := _auth.login(Enums.AuthProvider.FACEBOOK, {"token": "valid_fb_token_456"})
	assert_true(result["success"])
	assert_true(result["user_id"].begins_with("fb_"))
	assert_eq(_auth.auth_state, Enums.AuthState.AUTHENTICATED)
	assert_eq(_auth.provider, Enums.AuthProvider.FACEBOOK)


func test_login_social_missing_token() -> void:
	var result := _auth.login(Enums.AuthProvider.GOOGLE, {})
	assert_false(result["success"])
	assert_eq(result["error"], "missing_token")


func test_login_social_empty_token() -> void:
	var result := _auth.login(Enums.AuthProvider.FACEBOOK, {"token": ""})
	assert_false(result["success"])
	assert_eq(result["error"], "invalid_token")


# --- Logout tests ---

func test_logout_reverts_to_guest() -> void:
	_auth.login(Enums.AuthProvider.EMAIL, {"email": "test@example.com", "password": "securepass1"})
	_auth.logout()
	assert_eq(_auth.auth_state, Enums.AuthState.GUEST)
	assert_false(_auth.is_authenticated())
	assert_false(_auth.has_provider())


func test_logout_generates_new_guest_id() -> void:
	_auth.login(Enums.AuthProvider.EMAIL, {"email": "test@example.com", "password": "securepass1"})
	_auth.logout()
	assert_eq(_auth.user_id.length(), 36, "Should have a new UUID v4 guest ID")
	assert_ne(_auth.user_id, "test@example.com", "Should not retain email as ID")


# --- get_current_user_id tests ---

func test_get_current_user_id_guest() -> void:
	_auth.initialize()
	var uid := _auth.get_current_user_id()
	assert_eq(uid.length(), 36)


func test_get_current_user_id_authenticated() -> void:
	_auth.login(Enums.AuthProvider.EMAIL, {"email": "player@game.com", "password": "password123"})
	assert_eq(_auth.get_current_user_id(), "player@game.com")
