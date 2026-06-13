extends GutTest


func test_seed_from_text_is_deterministic() -> void:
	assert_eq(SeedUtils.seed_from_text("claim-earth"), SeedUtils.seed_from_text("claim-earth"))
	assert_ne(SeedUtils.seed_from_text("claim-earth"), SeedUtils.seed_from_text("claim earth"))


func test_derive_seed_changes_with_salt() -> void:
	var base_seed := SeedUtils.seed_from_text("jam-seed")
	assert_ne(SeedUtils.derive_seed(base_seed, "terrain"), SeedUtils.derive_seed(base_seed, "items"))
