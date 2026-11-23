# Architecture

Engine: Godot 4.7, GDScript only. Target 1920x1080, `canvas_items` stretch, GL Compatibility renderer.

## Layers

```
UI scenes (menu, dashboard, pause...)     read state, call manager methods, listen to signals
        |
Managers (autoloads)                      own state and rules, emit signals, know nothing about UI
        |
Config Resources (.tres) + SaveManager    tunable data, persistence
```

Rules:

- UI never changes game state directly; it calls a manager method.
- Managers never reference UI nodes; they emit signals.
- Gameplay numbers live in `resources/configurations/*.tres`, not in scripts.
- A manager owns exactly one concern. Do not add unrelated state to an existing manager.

## Autoloads

Load order matters: `SaveManager` is first so the others can register with it in `_ready()`.

| Autoload | Script | Owns |
|---|---|---|
| `SaveManager` | `scripts/save/save_manager.gd` | Slot files, versioning, validation, backups, autosave timer |
| `PlayerManager` | `scripts/player/player_manager.gd` | Alias, player id, creation time, playtime, world position |
| `EconomyManager` | `scripts/economy/economy_manager.gd` | Money, transactions, totals |
| `ProgressionManager` | `scripts/progression/progression_manager.gd` | XP, level, rank |
| `ReputationManager` | `scripts/reputation/reputation_manager.gd` | White / underground reputation, heat |
| `HardwareManager` | `scripts/hardware/hardware_manager.gd` | Owned and installed hardware, purchases, hardware bonuses |
| `SkillManager` | `scripts/skills/skill_manager.gd` | Learned skills, skill points, skill bonuses |
| `ContractManager` | `scripts/contracts/contract_manager.gd` | Contract board, contract in progress, rewards, failures, history |
| `OrganizationManager` | `scripts/organization/organization_manager.gd` | Company, office, rent, business days, daily reports |
| `EmployeeManager` | `scripts/employees/employee_manager.gd` | Candidates, staff, assignments, salaries, daily work |
| `ResearchManager` | `scripts/research/research_manager.gd` | Research projects, progress, unlocked technology |
| `ProductManager` | `scripts/research/product_manager.gd` | Software products: development, sales, subscriptions |
| `EventManager` | `scripts/events/event_manager.gd` | Random events, the waiting decision, applying choices |
| `StoryManager` | `scripts/story/story_manager.gd` | Chapters, objectives, chapter rewards, story completion |
| `MailManager` | `scripts/desktop/mail_manager.gd` | Inbox, message delivery triggers |
| `GameManager` | `scripts/core/game_manager.gd` | Game state, new/load/save/exit flow, scene transitions |

Every manager named in the master prompt now exists. `MailManager`, `ProductManager` and `StoryManager` are additions.

### Dependencies

- `GameManager` -> all others (it orchestrates the session).
- Every stateful manager -> `SaveManager.register_section()` only.
- `SaveManager` -> nothing. It discovers systems through registration.
- Managers do not call each other otherwise. Cross-system reactions use signals.

## Signals

| Manager | Signals |
|---|---|
| GameManager | `state_changed(state)`, `scene_transition_finished(path)` |
| SaveManager | `save_completed(slot, is_autosave)`, `save_failed(slot, reason)`, `load_completed(slot, recovered_from_backup)`, `load_failed(slot, reason)`, `slot_deleted(slot)` |
| PlayerManager | `profile_changed` |
| EconomyManager | `money_changed(balance, delta)`, `transaction_recorded(tx)`, `transaction_failed(amount, category, reason)` |
| ProgressionManager | `xp_gained(amount, source)`, `xp_changed(xp, required)`, `level_changed(new, old)`, `rank_changed(rank)` |
| ReputationManager | `reputation_changed(kind, value)`, `heat_changed(value)` |
| MailManager | `mail_received(message)`, `unread_count_changed(count)`, `inbox_changed` |
| HardwareManager | `hardware_changed`, `item_purchased(id)`, `item_installed(id)` |
| SkillManager | `skill_upgraded(id, level)`, `points_changed(available)`, `skills_changed` |
| OrganizationManager | `company_founded`, `company_changed`, `company_level_changed(level)`, `office_expanded(id)`, `day_processing(report)`, `day_finished(report)` |
| EmployeeManager | `employees_changed`, `candidates_changed`, `employee_hired(employee)`, `employee_left(name, reason)` |
| ResearchManager | `research_started(id)`, `research_completed(id)`, `research_changed` |
| ProductManager | `development_started(id)`, `product_released(id)`, `products_changed` |
| EventManager | `event_triggered(id)`, `event_resolved(id, choice_index, outcome)` |
| StoryManager | `chapter_started(index)`, `chapter_completed(index)`, `objectives_changed`, `story_completed` |
| ContractManager | `board_changed`, `contract_accepted(offer)`, `stage_changed(index)`, `mistakes_changed(made, limit)`, `contract_completed(result)`, `contract_failed(result)` |

On load and reset, managers re-emit their change signals so open UI refreshes itself.

## Session structure

```
GameSession (Node)                  wires world events to UI and GameManager
├─ BackdropLayer (CanvasLayer -10)  NeonBackground
├─ GameWorld (Node2D)               no UI knowledge; emits signals
│   └─ <current room>               HackerRoom.tscn or OfficeRoom.tscn, loaded at runtime
│       ├─ Shell (RoomShell)        floor, walls, window, neon; wall colliders
│       ├─ Props (IsoDepthSorter)   furniture + the Player (moved in at runtime)
│       └─ Interactables
└─ UILayer (CanvasLayer 10)         Hud, InteractionPrompt, ComputerScreen, EventPopup,
                                    EndingPopup, Toasts, PauseMenu
```

`GameWorld` signals: `interaction_prompt_changed(text)`, `computer_requested`, `rest_requested`,
`message_requested(text)`, `storage_requested`, `room_changed(room_id)`. `GameSession` is the only
place that knows both sides.

### Rooms and travel (MVP 8)

- `GameWorld.ROOM_SCENES` maps a room id to a scene. `travel_to(room_id)` frees the current room,
  loads the other one and moves the player to its entrance. `can_enter()` holds the rule for
  each room (the office needs `OrganizationManager.has_external_office()`).
- A door is an `Interactable` of kind `TRAVEL` with a `travel_target` room id.
- Every room is a `HackerRoom` (or a subclass): `get_actor_parent()`, `get_spawn_position()`,
  `is_position_walkable()`. **Adding a room**: build a scene with that script, a `Shell` and a
  `Props` node, add it to `ROOM_SCENES`, and put a door to it somewhere.
- `OfficeRoom` extends `HackerRoom` and is built from data: floor size and desk count follow the
  current `OfficeDefinition`; each employee gets a chair, a desk, a figure, a name label and an
  `INSPECT` interactable. It rebuilds its desks on `EmployeeManager.employees_changed`, and
  `GameWorld` reloads the whole room on `office_expanded`.
- The player's room id is saved next to their position (`PlayerManager.world_room`). A saved
  room that can no longer be entered falls back to the apartment.
- The player reports what they used (`Player.interacted`), so rooms can create interactables at
  any time without anything having to connect to them.

## Isometric world

- **Projection**: `IsoUtils` (2:1, 128x64 px tiles, 64 px per unit of height). Grid x runs
  down-right, grid y down-left. Everything in the world is placed in grid units.
- **`IsoNode`**: Node2D with `grid_position` + `footprint_size`. **`IsoBlock`** extends it and draws
  a neon box in code (placeholder art) and builds its own footprint collider when `solid`.
- **`RoomShell`**: draws the room and builds wall colliders from `room_size`.
- **Draw order**: `IsoDepthSorter` assigns `z_index`. Props are ordered back-to-front once; each
  frame an actor (group `iso_actor`) takes the slot just behind the first prop it stands behind.
  Plain Y-sort is not used because it fails for long furniture.
- **Movement**: `Player` is a `CharacterBody2D` in floating mode. Vertical speed is half the
  horizontal speed so diagonal input follows the grid lines.
- **Replacing placeholder art**: swap an `IsoBlock` for an `IsoNode` with a `Sprite2D` child and the
  same footprint; swap `PlayerVisual` for an `AnimatedSprite2D` script exposing `set_motion()`.
  `IsoUtils`, `IsoNode`, `IsoBlock` and `RoomShell` are `@tool` scripts, so rooms preview in the editor.

### Interaction

- `Interactable` (Area2D, physics layer 2) has a `kind` (`COMPUTER`, `REST`, `INSPECT`, `STORAGE`,
  `TRAVEL`), a `prompt_text`, an optional `message` or `travel_target`, and emits `interacted`.
  It does nothing itself.
- `InteractionDetector` on the player picks the nearest one in reach and marks it focused.
- `GameWorld` maps `kind` to one of its signals. To add a new kind of object: add an enum value
  and a signal there, then handle the signal in `GameSession`.
- Input actions: `move_left/right/up/down`, `interact` (see `[input]` in `project.godot`).

### Player position

`GameWorld` reports the player's position to `PlayerManager.set_world_position()`; it is saved in
the `player` section as an optional `world_position`. On load the room checks
`is_position_walkable()` and falls back to the spawn point, so older or damaged saves still work.
The save format version is unchanged (the field is optional).

## Hacker desktop (MVP 3)

```
ComputerScreen                      sit down / get up, Esc
└─ HackerDesktop                    launcher, window area, taskbar
    ├─ AppIcon (one per app)        from data/desktop/apps.json
    └─ AppWindow (one per open app) title bar, drag, minimise / maximise / close
        └─ <application scene>      any Control; knows nothing about the desktop
```

- **Data-driven app list**: `data/desktop/apps.json` -> `AppRegistry` -> `AppDefinition`
  (`id`, `title`, `glyph`, `scene`, `size`, `keep_state`, `debug_only`, `locked_note`).
  An entry without a `scene` is shown on the launcher as not installed.
- **Adding an application**: build a scene whose root is a `Control`, add an entry to
  `apps.json`. Nothing in the desktop code changes. If the app needs desktop services, give its
  root script `setup_app(context: DesktopContext, definition: AppDefinition)`.
- **`DesktopContext`** is the only link from an app to the desktop: the shared
  `VirtualFileSystem`, the app list, and `request_open_app()` / `request_close_app()`.
- **Window rules**: one window per app (launching again focuses it); clicking a window raises it;
  the taskbar button of the active window minimises it; windows cannot be dragged out of reach.
- **State**: windows stay as they are while the player walks around (the desktop lives for the
  whole session). Apps with `keep_state` (Terminal, File Manager) also survive being closed.
  None of this is written to the save file; a loaded game starts with a clean desktop.
- **Notifications**: toasts (new mail, level up, saves) plus the unread badge on the Mail icon.

### Applications

| App | Scene | Logic lives in |
|---|---|---|
| Dashboard | `applications/Dashboard.tscn` | reads managers |
| Terminal | `applications/Terminal.tscn` | `TerminalInterpreter` (no UI; returns text) |
| File Manager | `applications/FileManager.tscn` | `VirtualFileSystem` |
| Mail | `applications/Mail.tscn` | `MailManager` autoload |
| Finance | `applications/FinanceApp.tscn` | `EconomyManager` |
| Network Map | `applications/NetworkMap.tscn` | `NetworkNodeData`, drawn by `NetworkMapView` |
| Dev Tools | `ui/DebugPanel.tscn` | debug builds only |

- **Terminal safety**: `TerminalInterpreter` only reads game state and the virtual file system.
  It has no access to the OS, real files or any network. New commands are added with
  `_register()` in its `_init()`.
- **`VirtualFileSystem`**: read-only tree loaded from `data/desktop/filesystem.json`.
- **`MailManager`**: messages and their triggers (`new_game`, `level`, `contracts_completed`, `company_founded`, `story_chapter`) are defined in
  `data/mail/messages.json`; the inbox (arrived, read) is saved in the `mail` section.
  `{alias}` in a subject or body is replaced by the player's alias.
- **`NetworkNodeData`**: fictional story locations from `data/network/nodes.json`, discovered by
  player level. They are not real hosts.
- **`JsonDataLoader`** reads all data files and reports problems instead of crashing.

## Contracts and puzzles (MVP 4)

```
ContractsApp (desktop app)           board, active mission, history
└─ MissionRunner                     shows the current stage; knows no puzzle rules
    └─ MissionPuzzle (one of 4)      screen: turns clicks into moves
        └─ PuzzleLogic               rules: generates the instance, judges moves (no UI)

ContractManager (autoload)           board, active contract, mistakes, clock, rewards, history
```

- **Data**: `data/contracts/contracts.json` (contract templates) and
  `data/contracts/puzzle_pools.json` (the text puzzles are built from). Tuning values are in
  `resources/configurations/contract_config.tres`.
- **Contract fields** (`ContractDefinition`): id, name, client, description, category, alignment,
  difficulty, required level, required skills, required hardware, estimated duration, reward,
  XP reward, reputation (white / underground / heat), stages.
- **Stage**: `{title, instruction, puzzle, config}`. `puzzle` is a type id from `PuzzleFactory`.
- **Offers**: the board holds generated offers `{offer_id, template_id, reward, seed}`. The reward
  varies around the template's value; the seed fixes the puzzles.
- **Deterministic puzzles**: the puzzle for a stage is generated from `seed + stage index`, so a
  saved contract resumes on exactly the same puzzle.
- **Rules owned by `ContractManager`**: one contract at a time; `register_mistake()` fails the
  contract at `max_mistakes`; the clock (`estimated_duration x time_limit_factor`) fails it at
  zero; `abandon_contract()` fails it. Completion pays through `EconomyManager`, grants XP and
  reputation; failure costs reputation (and heat for underground work).
- **Requirements**: level is checked directly. Skill and hardware requirements are checked by
  `SkillManager` and `HardwareManager` through `GameEffects`. A requirement nobody can check
  counts as unmet.
- **Bonuses**: time limit, mistake limit, board size, refresh cooldown, pay, XP, heat and the
  flawless bonus all read `GameEffects` (see "Hardware, skills and bonuses").

| Puzzle type | Logic class | What the player does | Config |
|---|---|---|---|
| `sequence` | `SequencePuzzleLogic` | Click entries from lowest to highest key | `pool`, `count` |
| `cipher` | `CipherPuzzleLogic` | Find the Caesar shift that gives plain English | `pool` |
| `spot` | `SpotPuzzleLogic` | Select every problem line, then submit | `pool`, `normal`, `anomalies` |
| `match` | `MatchPuzzleLogic` | Pick the code identical to the target | `length`, `options`, `rounds` |

### Adding content

- **A contract**: add an entry to `contracts.json`. No code changes.
- **Puzzle text**: add a pool to `puzzle_pools.json` and reference it from a stage's `config`.
- **A puzzle type**: write a `PuzzleLogic` subclass (`generate()` plus its move methods) and a
  scene whose root script extends `MissionPuzzle` (emit `solved` / `mistake_made`), then register
  both in `PuzzleFactory`. `MissionRunner` and `ContractManager` need no changes.

## Hardware, skills and bonuses (MVP 5)

```
HardwareManager ─┐                        ┌─ ContractManager
SkillManager ────┼─ provide ─ GameEffects ─ ask ─┤
(later: employees)┘                        └─ (later: ResearchManager)
```

- **`GameEffects`** (`scripts/core/game_effects.gd`, static, not an autoload) is the only link
  between the systems that grant bonuses and the systems that use them.
  - A granting system calls `register_provider(Callable(effect_id) -> float)`.
  - A consuming system calls `get_total(effect_id)`.
  - Requirement checks work the same way: `register_requirement_checker(kind, callable)` and
    `check_requirement(kind, subject)`.
  - `notify_changed()` / `add_change_listener()` let consumers react when bonuses change.
  - `describe(effect_id, value)` gives the player-facing text, so every app words a bonus the same.
- Because nothing is wired by name, the managers do not depend on each other or on autoload
  order. Hardware and skills load before contracts, so a contract loaded from a save already
  sees the right bonuses.

| Effect id | Meaning | Granted by | Used by |
|---|---|---|---|
| `contract_time` | % extra time on contracts | hardware Speed, skills | ContractManager |
| `contract_reward`, `contract_reward:<category>` | % extra pay | skills, company level, supporting staff | ContractManager |
| `contract_xp` | % extra contract XP | skills | ContractManager |
| `extra_mistakes` | more mistakes allowed | skills | ContractManager |
| `board_size` | more offers on the board | hardware Capacity, skills | ContractManager |
| `refresh_cooldown` | % shorter wait for new offers (capped at 80) | hardware Network, skills | ContractManager |
| `heat_reduction` | % less heat from contracts | skills | ContractManager |
| `flawless_bonus` | percentage points on the flawless bonus | skills | ContractManager |
| `research_power` | research points per minute | hardware Research, skills, AI engineers, staff on Research | ResearchManager |
| `development_power` | development points per business day | staff on Product Development | ProductManager |
| `electricity_reduction` | % off the electricity bill | research | HardwareManager |

### Hardware

- Data: `data/items/hardware.json`. Each `HardwareItem` has id, category, name, description,
  price, tier, attributes (`speed`, `capacity`, `network`, `research`) and `required_level`.
  Items marked `starter` make up the stock machine and are never sold.
- `HardwareManager` keeps the owned items and one installed item per `HardwareCategory`.
  `purchase(id)` pays through `EconomyManager` and installs the part; the part it replaces stays
  owned (shown by the storage cabinet in the room) and can be put back with `install(id)`.
- Stats are summed over installed parts and converted to effects with the factors in
  `resources/configurations/hardware_config.tres`.
- Contract requirement syntax in `required_hardware`: an item id (`"gpu_spark"`) or a minimum
  tier for a slot (`"cpu:2"`).

### Skills

- Data: `data/skills/skills.json`. Each `SkillDefinition` has id, branch, name, description,
  max level, cost per level, required player level, prerequisite skills, effects per level and
  its row in the tree.
- `SkillManager` stores only the learned levels. Points earned follow from the player level
  (`skill_config.tres`) and points spent from the learned skills, so they cannot get out of step.
- Contract requirement syntax in `required_skills`: `{"skill_id": level}`.
- `SkillTreeView` draws the tree: a column per branch, a node per skill, lines to prerequisites.

### Adding content

- **A hardware part or a skill**: add an entry to the JSON file. No code changes.
- **A new kind of bonus**: add a constant and a `describe()` case to `GameEffects`, grant it from
  data, and read it with `get_total()` where it should apply.
- **A new system that grants bonuses** (for example employees): register a provider.

## Company and staff (MVP 6)

```
OrganizationManager                 company, office, rent, business-day clock
   │  day_processing(report)        "a day is ending; do your daily work and write it down"
   ▼
EmployeeManager                     candidates, staff, assignments, salaries, daily work
   │  provider
   ▼
GameEffects ── ContractManager      support bonuses reach the player's contracts
```

- **`OrganizationManager`** owns founding, the company name, company level and XP, company
  reputation, the office and its expansion, rent and overdue rent, and the business-day clock
  (`advance_time()`, `end_day()`). It does not know employees exist.
- **Business day**: when a day ends the manager builds a report
  `{day, income: {}, expenses: {}, notes: []}`, charges the rent, then emits
  `day_processing(report)`. Listeners do their daily work inside that signal and write into the
  same report. The manager then computes `net`, files the report and emits `day_finished(report)`.
  A later system (research, products) joins the day by connecting to the same signal.
- **`EmployeeManager`** owns everything about people. On `day_processing` it runs each
  assignment, books staff income, pays salaries, and removes anyone who resigns.
- **No negative balance**: rent that cannot be paid becomes `rent_arrears` (settled automatically,
  blocks hiring and expansion). Salaries that cannot be paid are simply not paid; the employee
  loses morale. Payroll is one payment when affordable, otherwise person by person in hiring order.
- **Money**: founding uses category `other`, moving in and rent `office_rent`, signing fees and
  salaries `salary`, staff income `maintenance_contract`. All through `EconomyManager`.
- **Data**: `data/organization/offices.json` (ordered office tiers),
  `data/employees/roles.json`, `assignments.json`, `names.json`. Tuning in
  `organization_config.tres` and `employee_config.tres`.

| Class | Holds |
|---|---|
| `OfficeDefinition` | id, name, description, capacity (desks), rent per day, moving cost, required company level |
| `EmployeeRole` | id, name, description, primary skill, salary and income rates, support effects |
| `EmployeeAssignment` | id, name, description, energy / morale change, XP gain, `produces_income`, `grants_support` |
| `Employee` | id, name, role, six skills, experience, level, salary, productivity, energy, morale, assignment, days employed, total earned |

- **Output**: daily income = role rate x role skill x productivity x efficiency, where efficiency
  falls with low energy and low morale (`Employee.get_efficiency()`).
- **Growth**: experience fills levels; each level raises the role skill by one and the salary.
- **Support**: an employee on a `grants_support` assignment contributes their role's
  `support_effects` (scaled by skill and efficiency) through `GameEffects`.
- **Company level** adds a small pay bonus on the player's contracts and attracts better
  candidates. The player's own completed contracts also give the company XP and reputation.

### Adding content

- **An office tier, a role, an assignment or names**: edit the JSON file. No code changes.
- **Something that happens every business day**: connect to
  `OrganizationManager.day_processing` and write into the report.

## Research, products, running costs and events (MVP 7)

### Research

- Data: `data/research/projects.json`. A `ResearchProject` has id, name, field, description,
  cost, points, required level, prerequisite projects, XP reward, optional grant, permanent
  `effects`, and the products it unlocks.
- `ResearchManager` runs one project at a time in real play time. Research power (points per
  minute) is `ResearchConfig.base_research_power` plus `GameEffects.get_total("research_power")`,
  which is where hardware, AI skills and staff on the Research assignment come in.
- Finished projects are a `GameEffects` provider: their effects apply for the rest of the game.
- Money: the cost is `research_cost`; a grant is `research_reward`.

### Products

- Data: `data/products/products.json`. A `ProductDefinition` is `one_time` or `subscription`,
  names the research that unlocks it, and has a development budget and amount of work.
- `ProductManager` works once per business day (`OrganizationManager.day_processing`): released
  products earn, then the product in development advances by the development power
  (`base_development_power` plus `GameEffects.get_total("development_power")`, which staff on
  Product Development provide).
- One-time products: `daily_revenue x decay ^ days`, never below `minimum_daily_revenue`
  (category `software_sales`). Subscriptions: subscribers grow by `subscriber_growth` to
  `subscriber_cap`, each paying `price_per_subscriber` (category `subscription`).

### Daily running costs

- `GameEffects.register_daily_cost(label, category, provider)` adds a cost that
  `OrganizationManager` charges with the rent at the end of every business day. Registered now:
  electricity (`HardwareManager.get_daily_power_cost()`, by installed tiers) and server
  maintenance (`ProductManager.get_daily_maintenance_cost()`, per running subscription).
- A cost that cannot be paid joins `rent_arrears`, like unpaid rent. The balance never goes
  negative.
- Running costs exist only once a company is founded, because business days do.

### Economy channels

| Income | Category | Source |
|---|---|---|
| Contracts | `contract` | ContractManager |
| Client maintenance contracts | `maintenance_contract` | EmployeeManager (staff on Client Work) |
| Software sales | `software_sales` | ProductManager |
| Subscriptions | `subscription` | ProductManager |
| Research rewards | `research_reward` | ResearchManager (grants) |

| Expense | Category | Source |
|---|---|---|
| Hardware | `hardware` | HardwareManager |
| Employee salaries | `salary` | EmployeeManager |
| Office rent | `office_rent` | OrganizationManager |
| Server maintenance | `server_maintenance` | ProductManager, via daily costs |
| Research costs | `research_cost` | ResearchManager, ProductManager (development budgets) |
| Electricity | `electricity` | HardwareManager, via daily costs |

### World events

- Data: `data/events/events.json`. An event has `conditions` (`min_level`, `min_employees`,
  `requires_company`, `requires_active_research`, `requires_released_product`,
  `requires_infrastructure`), a `weight`, and `choices`, each with a list of `effects`.
- Effect types: `money`, `xp`, `reputation`, `heat`, `company_reputation`, `company_xp`,
  `morale`, `employee_morale`, `employee_leaves`, `research_progress`.
- `EventManager` rolls for an event every `check_interval_seconds` of play (only in a session).
  One event waits at a time; `choose(index)` applies the effects through the other managers and
  records the outcome. A choice whose cost cannot be paid is disabled.
- `EventPopup` (in `GameSession`) shows the waiting event and pauses the tree until the player
  has chosen and read the outcome. A waiting event is saved and asked again after loading.
- **Adding an event** is a data edit. **A new effect type** is one `match` case in
  `EventManager._apply_effect()`.

## Story (MVP 8)

- Data: `data/story/chapters.json`. A chapter has a title, a summary, a reward (money, XP) and
  objectives `{text, type, target}`.
- Objective types (`StoryManager.KNOWN_TYPES`): `player_level`, `contracts_completed`,
  `hardware_bought`, `skill_points_spent`, `company_founded`, `employees`, `office_tier`,
  `company_level`, `research_completed`, `products_released`. `get_value(type)` reads the live
  number from the manager that owns it.
- `StoryManager.check_progress()` completes every chapter whose objectives all hold, pays the
  reward and starts the next. It runs whenever a relevant manager signals a change **during a
  session**; never while a save is loading, so a reward cannot be paid twice. `GameSession` runs
  it once when a session starts.
- Only the chapter number is saved. Objectives are always evaluated live.
- Presentation: `WorldHud` shows the chapter and its objectives; `GameSession` shows a toast on
  completion and the `EndingPopup` at the end; `MailManager` delivers a mail for each new chapter
  (trigger `story_chapter`).
- **Adding a chapter** is a data edit plus an optional mail. **A new objective type** is a
  constant, an entry in `KNOWN_TYPES` and a case in `get_value()`.

## Economy

All money moves through `EconomyManager.add_money()` / `spend_money()` with a
`TransactionCategory` constant. `spend_money()` returns `false` and changes nothing when the
balance is too low, so the balance can never go negative. History is capped by
`EconomyConfig.max_transaction_history`; lifetime totals per category
(`get_income_by_category()`, `get_expenses_by_category()`) are kept separately and never trimmed.

## Progression

`ProgressionConfig` (`resources/configurations/progression_config.tres`) defines `max_level` (50),
the curve `base_xp * level ^ xp_growth_exponent`, and the rank table (`RankDefinition` sub-resources).
Rebalancing means editing that file only.

## Save system

File: `user://saves/slot_N.json` (+ `.bak`, + `.tmp` while writing).

```json
{
  "format": "hacker_empire_save",
  "version": 1,
  "saved_at": 1795424580,
  "summary": { "alias": "...", "level": 2, "rank": "...", "money": 1800, "playtime_seconds": 12.5 },
  "sections": { "player": {}, "economy": {}, "progression": {}, "reputation": {} }
}
```

- **Atomic write**: write `.tmp`, read it back and validate, rotate the old file to `.bak`, rename.
- **Recovery**: an unreadable primary falls back to `.bak` automatically
  (`SaveSlotInfo.Status.RECOVERED_FROM_BACKUP`). A damaged primary never overwrites a good backup.
- **Validation before apply**: a file is parsed and checked completely before any manager is touched,
  so a failed load leaves the running game unchanged.
- **Field-level validation**: each manager reads its section through `SaveDataReader`, which returns
  a default for missing or wrongly typed values; managers then clamp to legal ranges.
- **Versioning**: `SAVE_VERSION` in `save_manager.gd`. Files from a newer version are refused.
  When the layout changes, bump the constant and add a step to `_migrate()`.
- **Forward compatibility**: a section missing from an older save keeps its defaults; unknown
  sections are ignored.
- **Autosave**: timer (interval in `SaveConfig`) while a session is active, plus on window close.

### Adding a new persistent system

1. Create `scripts/<area>/<name>_manager.gd` and add it to `[autoload]` after `SaveManager`.
2. Implement `get_save_data() -> Dictionary`, `load_save_data(data: Dictionary)`, `reset_to_defaults()`.
3. Call `SaveManager.register_section("<id>", self)` in `_ready()`.
4. Put tunable values in a `Resource` class + `.tres` under `resources/configurations/`.
5. Add tests to `tests/test_runner.gd`.

No change to `SaveManager` is needed, and old saves keep loading.

## UI

- Global theme: `resources/themes/cyberpunk_theme.tres` (set in Project Settings).
  Type variations: `TitleLabel`, `HeaderLabel`, `DimLabel`, `ValueLabel`, `DangerButton`.
- Colours for code: `UIPalette` (`scripts/ui/ui_palette.gd`). Keep it in sync with the theme.
- Text formatting: `FormatUtils`.
- Reusable components live in `scenes/ui/` (see SCENE_REFERENCE.md).
- Scripts find their nodes through scene-unique names (`%NodeName`), so layouts can be rearranged
  without touching code.
- No font or image assets are used yet; everything is theme styleboxes plus one shader
  (`assets/ui/shaders/neon_grid.gdshader`). Swap in real fonts through the theme.

## Folder layout

```
assets/        art, audio, fonts, shaders (assets/ui/shaders)
data/          JSON game content: desktop/ (apps, file system), mail/, network/; more from MVP 4
documentation/
resources/     themes/, configurations/ (.tres tuning data)
scenes/        one folder per system; ui/ holds reusable components
scripts/       mirrors scenes/; core/, save/, economy/, progression/, reputation/, player/,
               world/, interaction/, desktop/, ui/...
tests/         headless test scenes
```

Empty folders hold a `.gitkeep` and are reserved for later milestones.
