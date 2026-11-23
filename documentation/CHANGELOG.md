# Changelog

## 0.8.0 - 2026-11-23 - MVP 8: Expansion and Story

### Added

- `StoryManager` autoload; `data/story/chapters.json` (7 chapters); saved in the `story` section.
- Story objectives on the HUD, chapter-complete toasts, chapter mails (trigger `story_chapter`),
  `EndingPopup`, terminal command `story`.
- A second room: `OfficeRoom` (scene and script), built from the current office tier, with a
  desk, figure, name and conversation for every employee, and its own workstation.
- Travel: `Interactable.Kind.TRAVEL` and `travel_target`; doors in the apartment and the office;
  `GameWorld.travel_to()`, `can_enter()`, `get_room_id()`, signal `room_changed`.
- `PlayerManager.world_room` (saved with the position).
- `OrganizationManager.get_office_index()`, `has_external_office()`;
  `HardwareManager.get_purchased_count()`.
- `tests/story_tests.gd`; the flow test covers a chapter, the office trip and the ending screen.

### Changed

- `GameWorld` loads its room at runtime instead of containing the apartment.
- `Player` emits `interacted(target)`; `GameWorld` listens to the player instead of connecting
  to every interactable, so rooms can create interactables at any time.
- Project version 0.8.0. Save format version unchanged (new data is optional).

## 0.7.0 - 2026-11-23 - MVP 7: Economy, Research, and Events

### Added

- `ResearchManager` autoload, `ResearchProject`, `ResearchConfig`; `data/research/projects.json`
  (10 projects); saved in the `research` section.
- `ProductManager` autoload, `ProductDefinition`; `data/products/products.json` (5 products);
  saved in the `products` section.
- `EventManager` autoload, `EventConfig`, `EventPopup`; `data/events/events.json` (9 events);
  saved in the `events` section.
- Research desktop app with Research and Products views. All 13 applications are installed.
- `GameEffects`: `electricity_reduction`, `development_power`, and a registry of daily running
  costs. Electricity and server maintenance are charged with the rent.
- Staff assignments Research and Product Development; assignments can now grant effects.
- `EmployeeManager.change_morale()`, `change_morale_all()`, `resign()`.
- Terminal command `research`. Toasts for finished research and product releases. A mail hint.
- `tests/research_tests.gd`; the flow test covers research, a product release and an event.

### Changed

- `research_power` now sets research speed (it was only stored before).
- Project version 0.7.0. Save format version unchanged (new data is optional).

## 0.6.0 - 2026-11-23 - MVP 6: Organization and Employees

### Added

- `OrganizationManager` autoload, `OfficeDefinition`, `OrganizationConfig`;
  `data/organization/offices.json`; saved in the `organization` section.
- `EmployeeManager` autoload, `Employee`, `EmployeeRole`, `EmployeeAssignment`, `EmployeeConfig`;
  `data/employees/roles.json`, `assignments.json`, `names.json`; saved in the `employees` section.
- Business days with a shared daily report (`day_processing` / `day_finished`).
- Desktop apps: Organization, Employees.
- Company level pay bonus and staff support bonuses through `GameEffects`.
- Mail trigger `company_founded`, a registration mail and a hint at level 3.
- Terminal command `company`. Toasts for founding, company levels, day results and resignations.
- `tests/company_tests.gd`; the flow test founds a company and runs a business day.

### Changed

- Project version 0.6.0. Save format version unchanged (new data is optional).

## 0.5.0 - 2026-11-23 - MVP 5: Hardware and Skills

### Added

- `GameEffects`: shared bonus and requirement registry (static class).
- `HardwareManager` autoload, `HardwareItem`, `HardwareCategory`, `HardwareConfig`;
  `data/items/hardware.json` (38 items); saved in the `hardware` section.
- `SkillManager` autoload, `SkillDefinition`, `SkillBranch`, `SkillConfig`, `SkillTreeView`;
  `data/skills/skills.json` (18 skills); saved in the `skills` section.
- Desktop apps: Marketplace, Hardware, Skills.
- Terminal commands `hardware` and `skills`. Toasts for purchases and skill upgrades.
- Storage cabinet interaction lists spare parts (`Interactable.Kind.STORAGE`).
- Mail from Mara at level 3.
- `tests/upgrade_tests.gd`; the flow test buys, swaps and learns through the real apps.

### Changed

- `ContractManager` reads time, mistakes, board size, cooldown, pay, XP, heat and flawless bonus
  through `GameEffects`; new `get_board_size()`, `get_effective_reward()`, `get_effective_xp()`,
  `get_flawless_bonus_ratio()`, `get_refresh_cooldown()`. Requirement checkers moved to
  `GameEffects`.
- Five contracts gained hardware or skill requirements.
- The Contracts app shows pay and XP including bonuses.
- `ToastNotifier` shows at most four toasts; added `get_total_shown()`.
- Project version 0.5.0. Save format version unchanged (new data is optional).

## 0.4.0 - 2026-11-23 - MVP 4: Contracts and Mini-games

### Added

- `ContractManager` autoload, `ContractDefinition`, `ContractCategory`, `ContractConfig`
  (`contract_config.tres`), saved in the `contracts` section.
- Puzzle system: `PuzzleLogic`, `PuzzleFactory`, `MissionPuzzle`, and four puzzle types
  (sequence, cipher, spot, match), each a rules class plus a scene.
- `MissionRunner` scene and the Contracts desktop application.
- Data: `data/contracts/contracts.json` (14 contracts, 7 categories) and
  `data/contracts/puzzle_pools.json`.
- Mail trigger `contracts_completed` and a first-contract message.
- Terminal command `contracts`. Toasts for completed and failed contracts.
- `resources/themes/mono_font.tres`.
- `tests/contract_tests.gd`; the flow test plays, fails, abandons and reloads contracts.

### Changed

- Contracts is installed on the launcher. Welcome mail and `todo.txt` updated to match.
- `AppWindow` keeps its intended size and always opens fully inside the desktop.
- Project version 0.4.0. Save format version unchanged (new data is optional).

### Fixed

- Windows with word-wrapped text opened taller than intended.

## 0.3.0 - 2026-11-23 - MVP 3: Hacker Desktop

### Added

- Desktop shell: `HackerDesktop`, `AppWindow`, `AppIcon`, `AppRegistry`, `AppDefinition`,
  `DesktopContext`.
- Applications: Terminal (`TerminalInterpreter`), File Manager (`VirtualFileSystem`), Mail,
  Finance, Network Map (`NetworkNodeData`, `NetworkMapView`). Dashboard and Dev Tools became
  windowed apps.
- `MailManager` autoload with data-driven messages and a saved inbox (`mail` save section).
- Data files: `data/desktop/apps.json`, `data/desktop/filesystem.json`, `data/mail/messages.json`,
  `data/network/nodes.json`; `JsonDataLoader`.
- `EconomyManager`: lifetime income and expense totals per category (saved; rebuilt from the
  history for older saves).
- Theme: `SmallButton` variation, `ItemList` and tooltip styles.
- Tests for the registry, file system, terminal, mail, network data and category totals; the flow
  test now drives the whole desktop.

### Changed

- `ComputerScreen` hosts the desktop instead of the Dashboard; `get_desktop()` added.
- `GameManager.start_new_game()` delivers the new-game mail.
- Toasts moved up so they do not cover the taskbar.
- Project version 0.3.0. Save format version unchanged (new data is optional).

## 0.2.0 - 2026-11-23 - MVP 2: Isometric World and Player

### Added

- Isometric helpers: `IsoUtils`, `IsoNode`, `IsoBlock`, `RoomShell`, `IsoDepthSorter`.
- Scenes: `GameWorld`, `HackerRoom`, `Computer`, `Player`, `Interactable`, `InteractionPrompt`,
  `ComputerScreen`, `WorldHud`.
- Player movement with collision, follow camera, placeholder character art.
- Interaction system with computer, rest (save), and inspect interactions.
- Input actions `move_left`, `move_right`, `move_up`, `move_down`, `interact`; physics layer names.
- Player world position saved in the `player` section (optional field, no version bump).
- Tests: iso projection, position persistence, room walkable area; flow test now covers movement,
  walls, furniture collision, depth sorting, all interactions and position restore.

### Changed

- `GameSession` is now a plain `Node` hosting the world and a UI layer instead of showing the
  Dashboard directly. The Dashboard and Dev Tools moved into `ComputerScreen`.
- `PauseMenu`: added `can_open`; releases focus on close. Esc at the computer logs off.
- `ToastNotifier.show_toast()` takes an optional duration and wraps long text.
- Project version 0.2.0.

### Fixed

- Leaving a session no longer writes the player's position into the already-cleared profile.

## 0.1.0 - 2026-11-23 - MVP 1: Core Foundation

### Added

- Godot 4.7 project (`project.godot`), modular folder structure, `.gitignore`.
- Autoloads: `SaveManager`, `PlayerManager`, `EconomyManager`, `ProgressionManager`,
  `ReputationManager`, `GameManager`.
- Config resources: `SaveConfig`, `PlayerConfig`, `EconomyConfig`, `ProgressionConfig`
  (+ `RankDefinition`), `ReputationConfig`, with `.tres` files in `resources/configurations/`.
- Save system: 3 JSON slots, atomic writes, `.bak` recovery, format/version validation,
  field-level sanitising (`SaveDataReader`), migration hook, autosave timer, save on window close,
  slot deletion, slot summaries (`SaveSlotInfo`).
- Economy: `add_money` / `spend_money` gateway, `TransactionCategory`, capped history, totals.
- Progression: 50 levels, configurable XP curve, ranks Beginner to Legend.
- Reputation: white, underground, heat.
- Main menu with Continue, New Game (slot + alias), Load Game, Quit.
- `GameSession` scene with top bar, Dashboard application, pause menu, toasts.
- Dev Tools panel (debug builds only).
- Cyberpunk theme, animated neon grid shader, reusable UI components
  (`StatCard`, `SaveSlotCard`, `ConfirmPopup`, `ToastNotifier`, `PauseMenu`, `NeonBackground`).
- Fade transition between scenes.
- Tests: unit runner, end-to-end flow test, screenshot tour, `tests/run_tests.ps1`.
- Documentation: README, ARCHITECTURE, SCENE_REFERENCE, MVP_PROGRESS, CHANGELOG.
