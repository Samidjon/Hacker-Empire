extends VBoxContainer
## Dashboard application: a live, read-only overview of the player's profile,
## progression, finances and reputation. It only listens to manager signals.

const MAX_VISIBLE_TRANSACTIONS: int = 14
const HEAT_WARNING_RATIO: float = 0.34
const HEAT_DANGER_RATIO: float = 0.67
## Left, top, right, bottom padding of a transaction table cell.
const LOG_CELL_PADDING: Rect2 = Rect2(0.0, 2.0, 28.0, 2.0)

@onready var _alias_label: Label = %AliasLabel
@onready var _rank_label: Label = %RankLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _xp_label: Label = %XpLabel
@onready var _balance_card: StatCard = %BalanceCard
@onready var _earned_card: StatCard = %EarnedCard
@onready var _spent_card: StatCard = %SpentCard
@onready var _playtime_card: StatCard = %PlaytimeCard
@onready var _white_rep_card: StatCard = %WhiteRepCard
@onready var _underground_rep_card: StatCard = %UndergroundRepCard
@onready var _heat_card: StatCard = %HeatCard
@onready var _total_xp_card: StatCard = %TotalXpCard
@onready var _transaction_log: RichTextLabel = %TransactionLog
@onready var _playtime_timer: Timer = %PlaytimeTimer


func _ready() -> void:
	PlayerManager.profile_changed.connect(_refresh_profile)
	ProgressionManager.xp_changed.connect(func(_xp: int, _required: int) -> void: _refresh_progression())
	ProgressionManager.level_changed.connect(func(_new: int, _old: int) -> void: _refresh_progression())
	EconomyManager.money_changed.connect(func(_balance: int, _delta: int) -> void: _refresh_economy())
	ReputationManager.reputation_changed.connect(
		func(_kind: ReputationManager.Kind, _value: int) -> void: _refresh_reputation()
	)
	ReputationManager.heat_changed.connect(func(_value: float) -> void: _refresh_reputation())
	_playtime_timer.timeout.connect(_refresh_playtime)
	refresh_all()


func refresh_all() -> void:
	_refresh_profile()
	_refresh_progression()
	_refresh_economy()
	_refresh_reputation()
	_refresh_playtime()


func _refresh_profile() -> void:
	_alias_label.text = PlayerManager.hacker_alias


func _refresh_progression() -> void:
	_rank_label.text = ProgressionManager.get_rank_name().to_upper()
	_level_label.text = "LEVEL %d / %d" % [ProgressionManager.level, ProgressionManager.get_max_level()]
	_xp_bar.value = ProgressionManager.get_level_progress() * _xp_bar.max_value
	if ProgressionManager.is_max_level():
		_xp_label.text = "MAX LEVEL"
	else:
		_xp_label.text = "%d / %d XP" % [ProgressionManager.current_xp, ProgressionManager.get_xp_required()]
	_total_xp_card.set_value("%d" % ProgressionManager.total_xp, UIPalette.SECONDARY)


func _refresh_economy() -> void:
	_balance_card.set_value(FormatUtils.money(EconomyManager.money), UIPalette.ACCENT)
	_earned_card.set_value(FormatUtils.money(EconomyManager.total_earned))
	_spent_card.set_value(FormatUtils.money(EconomyManager.total_spent))
	_refresh_transactions()


func _refresh_reputation() -> void:
	_white_rep_card.set_value("%d" % ReputationManager.white_reputation, UIPalette.PRIMARY)
	_underground_rep_card.set_value("%d" % ReputationManager.underground_reputation, UIPalette.SECONDARY)

	var heat_ratio: float = ReputationManager.get_heat_ratio()
	var heat_color: Color = UIPalette.ACCENT
	if heat_ratio >= HEAT_DANGER_RATIO:
		heat_color = UIPalette.DANGER
	elif heat_ratio >= HEAT_WARNING_RATIO:
		heat_color = UIPalette.WARNING
	_heat_card.set_value(
		"%d / %d" % [roundi(ReputationManager.heat), roundi(ReputationManager.CONFIG.max_heat)],
		heat_color
	)


func _refresh_playtime() -> void:
	_playtime_card.set_value(FormatUtils.duration(PlayerManager.playtime_seconds))


func _refresh_transactions() -> void:
	var transactions: Array[Dictionary] = EconomyManager.get_recent_transactions(MAX_VISIBLE_TRANSACTIONS)
	_transaction_log.clear()
	if transactions.is_empty():
		_transaction_log.push_color(UIPalette.TEXT_DIM)
		_transaction_log.add_text("No transactions yet.")
		_transaction_log.pop()
		return
	# Three aligned columns: amount | category | description.
	_transaction_log.push_table(3)
	for transaction: Dictionary in transactions:
		var amount: int = SaveDataReader.get_int(transaction, "amount")
		_add_log_cell(
			FormatUtils.signed_money(amount),
			UIPalette.ACCENT if amount >= 0 else UIPalette.DANGER
		)
		_add_log_cell(
			TransactionCategory.get_display_name(SaveDataReader.get_string(transaction, "category")),
			UIPalette.TEXT
		)
		_add_log_cell(SaveDataReader.get_string(transaction, "description"), UIPalette.TEXT_DIM)
	_transaction_log.pop()


func _add_log_cell(text: String, color: Color) -> void:
	_transaction_log.push_cell()
	_transaction_log.set_cell_padding(LOG_CELL_PADDING)
	_transaction_log.push_color(color)
	_transaction_log.add_text(text)
	_transaction_log.pop()
	_transaction_log.pop()
