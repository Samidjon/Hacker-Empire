# Scene Reference

## Top-level scenes

Switched by `GameManager`; paths are listed in `scripts/core/scene_paths.gd`.

| Scene | Script | Purpose |
|---|---|---|
| `scenes/menu/MainMenu.tscn` | `scripts/menu/main_menu.gd` | Main scene. Continue / New Game / Load Game / Quit, slot list, alias form |
| `scenes/main/GameSession.tscn` | `scripts/core/game_session.gd` | Root of a play session. Hosts the world and the session UI and connects them. Returns to the menu if opened without a session |

## World (`scenes/world/`, `scenes/player/`, `scenes/interaction/`)

| Scene | Script / class | Purpose |
|---|---|---|
| `world/GameWorld.tscn` | `GameWorld` | The player and the current room. `travel_to(room_id)`, `can_enter(room_id)`, `get_room()`, `get_room_id()`; restores room and position; turns interactions into signals |
| `world/OfficeRoom.tscn` | `OfficeRoom` (extends `HackerRoom`) | The company office, sized by office tier, with a desk and figure per employee. `get_desk_count()`, `get_staff_names()`, `get_desk_approach_position(index)` |
| `world/HackerRoom.tscn` | `HackerRoom` | The starting apartment: shell, furniture, interactables. API: `get_actor_parent()`, `get_spawn_position()`, `is_position_walkable()` |
| `world/Computer.tscn` | `IsoNode` root | Desk, monitor, tower, keyboard and the computer `Interactable` |
| `player/Player.tscn` | `Player` | CharacterBody2D with `PlayerVisual`, `InteractionDetector`, follow camera. `input_enabled`, `teleport()` |
| `interaction/Interactable.tscn` | `Interactable` | Reach zone + floating marker. Exports: `kind`, `prompt_text`, `message`, `travel_target`, `grid_position`, `marker_elevation`, `marker_color` |
| `interaction/InteractionPrompt.tscn` | `InteractionPrompt` | "E  Use Computer" hint. `set_prompt(text)` (empty hides it) |

Furniture inside `HackerRoom` (`Door`, `Chair`, `Storage`, `Bed`, `Lamp`) are `IsoBlock` nodes under
`Props`. Interactables in the room: computer (in `Computer.tscn`), `BedInteractable`,
`StorageInteractable`, `DoorInteractable` (to the office), `WindowInteractable`.
`OfficeRoom.tscn` holds a `Door`, a `Computer` and a `DoorInteractable` (home); desks are built in code.

## Desktop and applications

| Scene | Script / class | Purpose |
|---|---|---|
| `scenes/desktop/ComputerScreen.tscn` | `ComputerScreen` | Full-screen view at the computer. `open()`, `close()`, `get_desktop()`, signals `opened` / `closed` |
| `scenes/desktop/HackerDesktop.tscn` | `HackerDesktop` | Launcher, window area, taskbar. `open_app(id)`, `close_app(id)`, `minimize_app(id)`, `focus_app(id)`, `is_app_open(id)`, `get_app_content(id)`, `get_app_window(id)`, `get_icon(id)`; signals `app_opened`, `app_closed`, `log_off_requested` |
| `scenes/desktop/AppWindow.tscn` | `AppWindow` | Window frame. `set_title()`, `set_content()`, `set_maximized()`, `place()`; signals `close_requested`, `minimize_requested` |
| `scenes/desktop/AppIcon.tscn` | `AppIcon` | Launcher button. `setup(definition)`, `set_badge(count)`; signal `activated(app_id)` |
| `scenes/applications/Dashboard.tscn` | `scripts/applications/dashboard.gd` | Overview of profile, XP, money, reputation, heat, playtime, recent transactions |
| `scenes/applications/Terminal.tscn` | `scripts/applications/terminal/terminal.gd` | Command line. `submit_command(line)`, `get_output_text()`, `get_interpreter()` |
| `scenes/applications/FileManager.tscn` | `scripts/applications/file_manager.gd` | Folder list + file preview. `navigate_to(path)`, `open_entry(index)`, `go_up()` |
| `scenes/applications/Mail.tscn` | `scripts/applications/mail_app.gd` | Inbox + reading pane. `select_message(index)` |
| `scenes/applications/FinanceApp.tscn` | `scripts/applications/finance_app.gd` | Totals, category breakdown, transaction history. `refresh()` |
| `scenes/applications/NetworkMap.tscn` | `scripts/applications/network/network_map.gd` | Node graph + details. `select_node(id)` |
| `scenes/applications/Marketplace.tscn` | `scripts/applications/marketplace_app.gd` | Category filter, item list, details, Buy. `select_category(index)`, `select_item_id(id)`, `buy_selected()` |
| `scenes/applications/HardwareApp.tscn` | `scripts/applications/hardware_app.gd` | Performance totals, installed slots, owned parts, Install. `select_slot(index)`, `select_owned(index)`, `install_selected()` |
| `scenes/applications/SkillsApp.tscn` | `scripts/applications/skills_app.gd` + `SkillTreeView` | Skill tree and details, Learn / Upgrade. `select_skill(id)`, `upgrade_selected()`, `get_tree_view()` |
| `scenes/applications/OrganizationApp.tscn` | `scripts/applications/organization_app.gd` | Founding form, then company overview: level, cards, office and expansion, daily report. `set_company_name_text(text)`, `found_company()`, `refresh()` |
| `scenes/applications/EmployeesApp.tscn` | `scripts/applications/employees_app.gd` | Staff and Recruit views. `show_view(view)`, `select_employee(index)`, `assign_selected(index)`, `select_candidate(index)`, `hire_selected()`, `dismiss_selected()` |
| `scenes/applications/ResearchApp.tscn` | `scripts/applications/research_app.gd` | Research and Products views. `show_view(view)`, `select_project_id(id)`, `start_selected_research()`, `select_product_id(id)`, `develop_selected_product()` |
| `scenes/applications/ContractsApp.tscn` | `scripts/applications/contracts_app.gd` | Board / Active / History views. `show_view(view)`, `select_offer(index)`, `accept_selected()`, `get_runner()` |

## Contracts (`scenes/contracts/`)

| Scene | Script / class | Purpose |
|---|---|---|
| `MissionRunner.tscn` | `MissionRunner` | Plays the contract in progress: header, mistakes, clock, puzzle holder, result screen. `get_puzzle()`, `dismiss_result()`; signal `result_dismissed` |
| `puzzles/SequencePuzzle.tscn` | `sequence_puzzle.gd` | Click entries in ascending order. `pick(index)` |
| `puzzles/CipherPuzzle.tscn` | `cipher_puzzle.gd` | Step through letter shifts. `set_shift(n)`, `submit()` |
| `puzzles/SpotPuzzle.tscn` | `spot_puzzle.gd` | Toggle problem lines. `toggle(index)`, `get_selected()`, `submit()` |
| `puzzles/MatchPuzzle.tscn` | `match_puzzle.gd` | Pick the identical code. `pick(index)` |

All four puzzle scripts extend `MissionPuzzle` (`setup(logic)`, `get_logic()`, signals `solved`,
`mistake_made(message)`).

## Reusable UI components (`scenes/ui/`)

| Scene | Script / class | API |
|---|---|---|
| `NeonBackground.tscn` | `neon_background.gd` | Animated grid backdrop |
| `WorldHud.tscn` | `WorldHud` | Alias, level, money, Save / Menu buttons, story objectives. `get_objectives_text()`; signals `save_pressed`, `menu_pressed` |
| `StatCard.tscn` | `StatCard` | `@export title`, `set_value(text, color)`, `get_value_text()` |
| `SaveSlotCard.tscn` | `SaveSlotCard` | `setup(info, for_new_game)`; signals `selected(slot)`, `delete_requested(slot)` |
| `ConfirmPopup.tscn` | `ConfirmPopup` | `ask(message, confirm_text, on_confirm)`; signals `confirmed`, `cancelled` |
| `ToastNotifier.tscn` | `ToastNotifier` | `show_toast(message, color, display_seconds)`; shows at most 4 at a time |
| `../events/EventPopup.tscn` | `EventPopup` | World event dialog; pauses the tree. `show_pending_event()`, `get_choice_buttons()`, `close()`; signal `closed` |
| `EndingPopup.tscn` | `EndingPopup` | Story ending with run statistics; pauses the tree. `open()`, `close()`; signal `closed` |
| `PauseMenu.tscn` | `PauseMenu` | `open()`, `close()`, `can_open`; toggles on `ui_cancel`; pauses the tree |
| `DebugPanel.tscn` | `debug_panel.gd` | Dev tools, visible only when `OS.is_debug_build()` |

## Unique node names used by scripts

**MainMenu**: `MainPanel`, `ContinueButton`, `NewGameButton`, `LoadGameButton`, `QuitButton`,
`SlotPanel`, `SlotTitleLabel`, `SlotList`, `StatusLabel`, `SlotBackButton`, `NewGamePanel`,
`NewGameSlotLabel`, `AliasEdit`, `AliasErrorLabel`, `NewGameBackButton`, `StartButton`,
`VersionLabel`, `ConfirmPopup`

**GameSession**: `GameWorld`, `Hud`, `InteractionPrompt`, `ComputerScreen`, `EventPopup`, `EndingPopup`, `Toasts`, `PauseMenu`

**HackerRoom / OfficeRoom**: `Shell`, `Props` (the office script also uses the plain paths `Shell` and `Props/Computer`) - **Player**: `Visual`, `InteractionDetector`, `Camera`

**WorldHud**: `HudAliasLabel`, `HudLevelLabel`, `HudMoneyLabel`, `SaveButton`, `MenuButton`, `ObjectivesLabel`

**EndingPopup**: `EndingSummary`, `EndingStats`, `EndingContinueButton`

**ComputerScreen**: `Desktop`

**HackerDesktop**: `IconGrid`, `WindowArea`, `TaskList`, `TaskbarMoneyLabel`, `ClockLabel`, `LogOffButton`, `ClockTimer`

**AppWindow**: `TitleBar`, `WindowTitleLabel`, `MinimizeButton`, `MaximizeButton`, `CloseButton`, `ContentHolder` - **AppIcon**: `BadgeLabel`

**Terminal**: `Output`, `PromptLabel`, `CommandInput` - **FileManager**: `UpButton`, `HomeButton`, `PathLabel`, `EntryList`, `PreviewTitle`, `PreviewText`

**Mail**: `MessageList`, `SubjectLabel`, `MetaLabel`, `BodyText` - **NetworkMap**: `MapView`, `MapSummaryLabel`, `NodeNameLabel`, `NodeStatusLabel`, `NodeDescriptionLabel`

**FinanceApp**: `FinanceBalanceCard`, `FinanceIncomeCard`, `FinanceExpenseCard`, `FinanceNetCard`, `IncomeTable`, `ExpenseTable`, `HistoryTitle`, `HistoryTable`

**DebugPanel**: `ButtonList`

**ResearchApp**: `ResearchTabButton`, `ProductsTabButton`, `ResearchPowerLabel`, `ResearchView`, `ActiveResearchLabel`, `ActiveResearchBar`, `ProjectList`, `ProjectTitle`, `ProjectMeta`, `ProjectDescription`, `ProjectFacts`, `ProjectBlockerLabel`, `StartResearchButton`, `ProductsView`, `ProductList`, `ProductTitle`, `ProductMeta`, `ProductDescription`, `ProductFacts`, `ProductBlockerLabel`, `DevelopButton`

**EventPopup**: `EventTitle`, `EventDescription`, `EventChoices`, `EventOutcome`, `EventContinueButton`

**OrganizationApp**: `FoundingView`, `CompanyNameEdit`, `FoundingFactsLabel`, `FoundingBlockerLabel`, `FoundButton`, `CompanyView`, `CompanyNameLabel`, `CompanyLevelLabel`, `CompanyXpBar`, `CompanyXpLabel`, `CompanyReputationCard`, `CompanyStaffCard`, `CompanyCostsCard`, `CompanyDayCard`, `OfficeFacts`, `ExpansionBlockerLabel`, `ExpandButton`, `DayProgressBar`, `ReportTitle`, `ReportTable`

**EmployeesApp**: `StaffTabButton`, `RecruitTabButton`, `StaffSummaryLabel`, `NoCompanyLabel`, `StaffView`, `StaffList`, `EmployeeNameLabel`, `EmployeeMetaLabel`, `EmployeeFacts`, `AssignmentList`, `AssignmentDescription`, `DismissButton`, `RecruitView`, `CandidateList`, `CandidateNameLabel`, `CandidateMetaLabel`, `CandidateFacts`, `HireBlockerLabel`, `HireButton`

**Marketplace**: `MarketCategoryList`, `MarketItemList`, `MarketBalanceLabel`, `MarketItemTitle`, `MarketItemMeta`, `MarketItemDescription`, `MarketItemFacts`, `MarketBlockerLabel`, `BuyButton`

**HardwareApp**: `HardwareTotals`, `SlotList`, `OwnedTitle`, `OwnedList`, `OwnedDetails`, `InstallButton`

**SkillsApp**: `SkillTree`, `SkillPointsLabel`, `SkillNameLabel`, `SkillMetaLabel`, `SkillDescriptionLabel`, `SkillEffectsLabel`, `SkillBlockerLabel`, `UpgradeButton`

**ContractsApp**: `BoardTabButton`, `ActiveTabButton`, `HistoryTabButton`, `ContractStatsLabel`, `BoardView`, `ActiveView`, `HistoryView`, `OfferList`, `RefreshBoardButton`, `OfferTitle`, `OfferMeta`, `OfferDescription`, `OfferFacts`, `RequirementLabel`, `AcceptButton`, `NoActiveLabel`, `MissionRunner`, `ContractHistoryTable`

**MissionRunner**: `MissionPanel`, `MissionTitle`, `MistakesLabel`, `TimeLabel`, `AbandonButton`, `StageLabel`, `InstructionLabel`, `PuzzleHolder`, `FeedbackLabel`, `ResultPanel`, `ResultTitle`, `ResultText`, `ResultCloseButton`

**Puzzles**: `SequenceProgress`, `SequenceItems` - `CipherText`, `DecodedText`, `ShiftDownButton`, `ShiftLabel`, `ShiftUpButton`, `CipherSubmitButton` - `SpotLines`, `SpotCounter`, `SpotSubmitButton` - `MatchRound`, `MatchTarget`, `MatchOptions`

**Dashboard**: `AliasLabel`, `RankLabel`, `LevelLabel`, `XpBar`, `XpLabel`, `BalanceCard`,
`EarnedCard`, `SpentCard`, `PlaytimeCard`, `WhiteRepCard`, `UndergroundRepCard`, `HeatCard`,
`TotalXpCard`, `TransactionLog`, `PlaytimeTimer`

Renaming any of these requires updating the matching script (and `tests/flow_test_driver.gd`).

## Test scenes (`tests/`)

| Scene | Purpose |
|---|---|
| `TestRunner.tscn` | Headless unit tests |
| `FlowTest.tscn` | Headless end-to-end flow with real input |
| `ScreenshotTour.tscn` | Windowed visual capture to `user://screenshots` |
