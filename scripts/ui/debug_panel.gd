extends PanelContainer
## Developer tools for exercising the core systems before real gameplay
## (contracts, hardware...) exists. Shown in debug builds only; every button
## calls the same manager API that gameplay will use.

const XP_AMOUNT: int = 250
const MONEY_AMOUNT: int = 500
const SPEND_AMOUNT: int = 200
const REPUTATION_AMOUNT: int = 5
const HEAT_AMOUNT: float = 10.0

@onready var _button_list: VBoxContainer = %ButtonList


func _ready() -> void:
	_add_action("+%d XP" % XP_AMOUNT, func() -> void:
		ProgressionManager.add_xp(XP_AMOUNT, "dev_tools"))
	_add_action("+%s" % FormatUtils.money(MONEY_AMOUNT), func() -> void:
		EconomyManager.add_money(MONEY_AMOUNT, TransactionCategory.DEBUG, "Dev grant"))
	_add_action("Spend %s" % FormatUtils.money(SPEND_AMOUNT), func() -> void:
		EconomyManager.spend_money(SPEND_AMOUNT, TransactionCategory.DEBUG, "Dev expense"))
	_add_action("+%d White Rep" % REPUTATION_AMOUNT, func() -> void:
		ReputationManager.add_reputation(ReputationManager.Kind.WHITE, REPUTATION_AMOUNT))
	_add_action("+%d Underground Rep" % REPUTATION_AMOUNT, func() -> void:
		ReputationManager.add_reputation(ReputationManager.Kind.UNDERGROUND, REPUTATION_AMOUNT))
	_add_action("+%d Heat" % int(HEAT_AMOUNT), func() -> void:
		ReputationManager.add_heat(HEAT_AMOUNT))
	_add_action("-%d Heat" % int(HEAT_AMOUNT), func() -> void:
		ReputationManager.add_heat(-HEAT_AMOUNT))


func _add_action(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	_button_list.add_child(button)
