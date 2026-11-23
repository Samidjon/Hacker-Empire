class_name PuzzleFactory
extends RefCounted
## The list of puzzle types. To add one: write a PuzzleLogic subclass and a
## MissionPuzzle scene, then register both here. Contract data refers to a
## puzzle by its type id.

const TYPE_SEQUENCE: String = "sequence"
const TYPE_CIPHER: String = "cipher"
const TYPE_SPOT: String = "spot"
const TYPE_MATCH: String = "match"

const VIEW_SCENES: Dictionary = {
	TYPE_SEQUENCE: "res://scenes/contracts/puzzles/SequencePuzzle.tscn",
	TYPE_CIPHER: "res://scenes/contracts/puzzles/CipherPuzzle.tscn",
	TYPE_SPOT: "res://scenes/contracts/puzzles/SpotPuzzle.tscn",
	TYPE_MATCH: "res://scenes/contracts/puzzles/MatchPuzzle.tscn",
}


static func is_known_type(puzzle_type: String) -> bool:
	return VIEW_SCENES.has(puzzle_type)


static func get_types() -> PackedStringArray:
	return PackedStringArray(VIEW_SCENES.keys())


## A generated puzzle, or null when the type is unknown or generation fails.
static func create_logic(
	puzzle_type: String, config: Dictionary, pools: Dictionary, rng: RandomNumberGenerator
) -> PuzzleLogic:
	var logic: PuzzleLogic = null
	match puzzle_type:
		TYPE_SEQUENCE:
			logic = SequencePuzzleLogic.new()
		TYPE_CIPHER:
			logic = CipherPuzzleLogic.new()
		TYPE_SPOT:
			logic = SpotPuzzleLogic.new()
		TYPE_MATCH:
			logic = MatchPuzzleLogic.new()
	if logic == null:
		push_error("PuzzleFactory: unknown puzzle type '%s'." % puzzle_type)
		return null
	if not logic.generate(config, pools, rng):
		push_error("PuzzleFactory: could not generate a '%s' puzzle from %s." % [puzzle_type, config])
		return null
	return logic


## A new instance of the scene that displays `logic`. The caller adds it to
## the tree and then calls its setup(logic).
static func create_view(logic: PuzzleLogic) -> MissionPuzzle:
	if logic == null or not VIEW_SCENES.has(logic.puzzle_type):
		return null
	var scene := load(VIEW_SCENES[logic.puzzle_type]) as PackedScene
	if scene == null:
		push_error("PuzzleFactory: cannot load the view for '%s'." % logic.puzzle_type)
		return null
	return scene.instantiate() as MissionPuzzle
