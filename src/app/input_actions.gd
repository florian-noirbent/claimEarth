## Centralizes input action names expected by gameplay and tests.
class_name InputActions
extends RefCounted


const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const JUMP := "jump"
const ROPE_UP := "rope_up"
const ROPE_DOWN := "rope_down"
const SELECT_SMALL_BOMB := "select_small_bomb"
const SELECT_LARGE_BOMB := "select_large_bomb"
const SELECT_FLAG := "select_flag"
const THROW_SELECTED := "throw_selected"
const HOOK := "hook"
const PAUSE := "pause"
const CYCLE_ITEM_PREVIOUS := "cycle_item_previous"
const CYCLE_ITEM_NEXT := "cycle_item_next"
const AIM_LEFT := "aim_left"
const AIM_RIGHT := "aim_right"
const AIM_UP := "aim_up"
const AIM_DOWN := "aim_down"
const MENU_BACK := "menu_back"

const ALL: PackedStringArray = [
	MOVE_LEFT,
	MOVE_RIGHT,
	JUMP,
	ROPE_UP,
	ROPE_DOWN,
	SELECT_SMALL_BOMB,
	SELECT_LARGE_BOMB,
	SELECT_FLAG,
	THROW_SELECTED,
	HOOK,
	PAUSE,
	CYCLE_ITEM_PREVIOUS,
	CYCLE_ITEM_NEXT,
	AIM_LEFT,
	AIM_RIGHT,
	AIM_UP,
	AIM_DOWN,
	MENU_BACK,
]
