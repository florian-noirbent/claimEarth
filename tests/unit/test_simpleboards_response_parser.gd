extends GutTest


const ParserScript = preload("res://src/leaderboard/simpleboards_response_parser.gd")


func test_parse_entries_accepts_valid_array() -> void:
	var parsed = ParserScript.parse_entries('[{"playerDisplayName":"Alice","score":"42","metadata":"{\\"seed\\":1}"}]')

	assert_true(parsed.ok)
	assert_eq(parsed.entries.size(), 1)
	assert_eq(parsed.entries[0].player_name, "Alice")
	assert_eq(parsed.entries[0].score_depth, 42)


func test_parse_entries_rejects_malformed_body() -> void:
	var parsed = ParserScript.parse_entries('{"bad":true}')

	assert_false(parsed.ok)
	assert_eq(parsed.entries.size(), 0)


func test_parse_entry_rejects_missing_fields() -> void:
	var parsed = ParserScript.parse_entry('{"score":"12"}')

	assert_false(parsed.ok)
	assert_null(parsed.entry)
