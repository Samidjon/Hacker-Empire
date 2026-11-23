# MVP Progress

| # | Milestone | Status |
|---|---|---|
| 1 | Core Foundation | **Complete** (2026-11-23) |
| 2 | Isometric World and Player | **Complete** (2026-11-23) |
| 3 | Hacker Desktop | **Complete with noted gaps** (2026-11-23) |
| 4 | Contracts and Mini-games | **Complete** (2026-11-23) |
| 5 | Hardware and Skills | **Complete** (2026-11-23) |
| 6 | Organization and Employees | **Complete with noted gaps** (2026-11-23) |
| 7 | Economy, Research, and Events | **Complete** (2026-11-23) |
| 8 | Expansion and Story | **Complete** (2026-11-23) |
| 9 | Polish and Release | Not started |

## MVP 8 - Expansion and Story

The master prompt names this milestone without listing its features. It was scoped as: a story
that carries the player from the first contract to the "large technology organization" of the
game concept, and making the office expansion from MVP 6 a place in the world.

Validated on Godot 4.7.2 stable (Windows).

| Feature | Status | Notes |
|---|---|---|
| Story chapters | Done | Seven chapters with objectives and rewards, data-driven |
| Objectives on screen | Done | Current chapter and progress on the HUD; `story` terminal command |
| Chapter introductions | Done | A mail for each new chapter |
| Ending | Done | Ending screen with run statistics; play continues afterwards |
| Visitable office | Done | A second room reached by the apartment door |
| Office grows with the company | Done | Five floor sizes; one desk per place in the office tier |
| Visible staff | Done | Each employee sits at a desk under their name and can be talked to |
| Office workstation | Done | Opens the same desktop |
| Room saved | Done | The game resumes in the room you saved in |
| Earlier milestones preserved | Done | Older saves load at chapter 1 in the apartment |

### Test results (2026-11-23)

- `--headless --import`: no errors.
- `tests/TestRunner.tscn`: 796 passed, 0 failed. Includes playing the whole story to the end
  through the real systems, and travelling between rooms.
- `tests/FlowTest.tscn`: 283 passed, 0 failed. Completes the first chapter by finishing a
  contract, finds the door locked before there is an office, later walks to the office, talks to
  the hired employee, uses the office computer, walks home, and opens the ending screen.
- Main scene headless smoke run: no errors or warnings.
- Windowed run: objectives HUD, a two-desk office, an eight-desk office and the ending screen
  captured and reviewed.

### Known limitations

- **The story is a checklist, not a plot.** There are no characters on screen, no dialogue
  scenes and no branching; the narrative lives in the chapter summaries and the mail.
- **Reaching the ending by play is untested.** Automated tests reach it by granting money and
  XP. Given current balance, the last chapters (company level 8, ten staff, four products)
  would take a long time, and nobody has played that far.
- Staff sit still at their desks. They do not walk, animate or leave for the day.
- Travel is instant, with no transition, street or map.
- Only two rooms exist. The office has one look; tiers differ in size and desk count only.
- Objectives are measured live, so one can become unmet again (for example if an employee
  leaves) before the chapter completes.
- Office and character art is still placeholder, drawn in code.
- Not hand-played.

## MVP 7 - Economy, Research, and Events

Validated on Godot 4.7.2 stable (Windows).

| Requirement | Status | Notes |
|---|---|---|
| ResearchManager | Done | Research projects and technology unlocks |
| Research app | Done | The last of the 13 applications |
| EventManager | Done | Random events, configurable in data |
| Example events | Done | Server failure, employee resignation, new client opportunity, competitor recruitment, hardware malfunction, research breakthrough, plus three more |
| Meaningful consequences and choices | Done | Every event has at least two choices; every choice changes game state |
| Income: contracts | Done (MVP 4) | |
| Income: software sales | Done | One-time products |
| Income: subscriptions | Done | Subscription products |
| Income: research rewards | Done | Grants on sponsored projects |
| Income: client maintenance contracts | Done (MVP 6) | Staff on Client Work |
| Expense: hardware | Done (MVP 5) | |
| Expense: employee salaries | Done (MVP 6) | |
| Expense: office rent | Done (MVP 6) | |
| Expense: server maintenance | Done | Per running subscription |
| Expense: research costs | Done | Project costs and development budgets |
| Expense: electricity | Done | By installed hardware tiers |
| All transactions through EconomyManager | Done | No system changes money any other way |
| No negative balance | Done | Unpaid rent and bills become an overdue total; unpaid salaries cost morale |
| Carried over from MVP 6: research projects and product development | Done | Staff can be assigned to Research and to Product Development |
| Carried over from MVP 5: research power has a use | Done | It sets research speed |

### Test results (2026-11-23)

- `--headless --import`: no errors.
- `tests/TestRunner.tscn`: 739 passed, 0 failed.
- `tests/FlowTest.tscn`: 263 passed, 0 failed. Starts and finishes research in the app, develops
  and releases a product, checks sales in the daily report, and answers a world event in the
  dialog (including that Esc cannot dodge it).
- Main scene headless smoke run: no errors or warnings.
- Windowed run: Research tab, Products tab and the event dialog captured and reviewed.

### Known limitations

- **Running costs start with the company.** Electricity and server maintenance are charged at the
  end of a business day, and business days only exist once a company is founded. A solo player
  pays no electricity.
- **Balance is unjudged.** Research times, product revenue, bill sizes and event amounts are
  estimates. In the screenshot run a young company lost a little money most days.
- Research cannot be cancelled or queued; only one project runs at a time. The same holds for
  product development.
- Products cannot be improved, repriced or withdrawn after release.
- Event outcomes are fixed per choice; there is no chance element inside a choice.
- Events can interrupt a contract puzzle. The game pauses, so no contract time is lost, but the
  interruption is abrupt.
- The 13 applications share the desktop but there is no notification list; toasts are the only
  record besides Mail and the daily report.
- "Overdue rent" in the Organization app now also includes unpaid bills, but is still worded as
  rent.
- Not hand-played.

## MVP 6 - Organization and Employees

Validated on Godot 4.7.2 stable (Windows).

| Requirement | Status | Notes |
|---|---|---|
| OrganizationManager | Done | Company creation, company level, expansion |
| Company name | Done | Validated, chosen at founding |
| Company level | Done | XP from staff work and the player's contracts; 10 levels |
| Company reputation | Done | Grows with work, falls with unpaid rent |
| Employees | Done | See below |
| Office expansion | Done | Six office tiers; data only, see limitations |
| Income | Done | Staff on client work earn every business day |
| Expenses | Done | Rent, salaries, signing fees, moving costs |
| Research projects | Done in MVP 7 | |
| Product development | Done in MVP 7 | |
| EmployeeManager | Done | Recruitment, skills, salaries, assignments |
| Employee fields | Done | Unique id, name, role, skills, experience, salary, productivity, energy, morale |
| Six roles | Done | Programmer, Security Analyst, Network Engineer, Reverse Engineer, AI Engineer, System Administrator |
| Recruitment interface | Done | Recruit tab of the Employees app |
| Task assignment system | Done | Client work, support, training, time off |
| Earlier milestones preserved | Done | Older saves load with no company |

### Test results (2026-11-23)

- `--headless --import`: no errors.
- `tests/TestRunner.tscn`: 628 passed, 0 failed.
- `tests/FlowTest.tscn`: 243 passed, 0 failed. Founds a company through the app, hires, expands
  the office, changes an assignment, runs a business day, and checks the company and staff
  survive save and load.
- Main scene headless smoke run: no errors or warnings.
- Windowed run: founding form, company overview, staff and recruit views captured and reviewed.

### Known limitations

- **Research projects and product development are not part of the company yet.** The master
  prompt lists them under Organization; they need the research system (MVP 7).
- (Resolved in MVP 8) Offices can now be visited and staff are visible at their desks.
- **Balance is unjudged and thin at the start.** A first hire nets roughly $15-40 a day before
  rent, which is small next to contract income. Staff become worthwhile as they level up and as
  support for the player's contracts.
- Only an employee's role skill affects anything. Their five other skills are generated, shown
  and saved, and wait for research and products.
- Morale only changes through assignments and pay. There are no raises, bonuses or events.
- Staff cannot be given a salary other than the calculated one.
- Candidates are replaced every business day; there is no way to hold or search for one.
- A company cannot be renamed or closed.
- Not hand-played.

### Fixed during this milestone

- First balance pass on roles: as first written, a low-skill hire cost more than they earned.

## MVP 5 - Hardware and Skills

Validated on Godot 4.7.2 stable (Windows).

| Requirement | Status | Notes |
|---|---|---|
| HardwareManager | Done | Equipment, upgrades, hardware bonuses |
| Eight component types | Done | CPU, GPU, RAM, SSD, network adapter, cooling, monitors, servers; 38 items |
| Item fields | Done | Unique id, name, description, price, tier, performance attributes, unlock requirement (level) |
| Hardware affects operation speed | Done | Speed gives more time on contracts |
| Hardware affects task capacity | Done | Capacity adds offers to the contract board |
| Hardware affects research capabilities | Done in MVP 7 | Research power sets research speed |
| Functional hardware upgrades | Done | Marketplace to buy, Hardware app to view and swap parts |
| SkillManager | Done | Skill tree, unlocks, bonuses |
| Six branches | Done | Programming, Networking, Cybersecurity, Cryptography, Reverse Engineering, AI Research; 18 skills |
| Skill fields | Done | Level, maximum level, point cost, unlock conditions (player level, prerequisites), gameplay bonuses |
| Visual skill tree | Done | Columns per branch, prerequisite lines, colour by state |
| Contract requirements | Done | Five higher contracts now require a hardware tier or a skill level |
| Earlier milestones preserved | Done | Older saves get the stock machine and no skills |

### Test results (2026-11-23)

- `--headless --import`: no errors.
- `tests/TestRunner.tscn`: 498 passed, 0 failed.
- `tests/FlowTest.tscn`: 215 passed, 0 failed. Buys a CPU in the Marketplace, swaps parts in the
  Hardware app, learns a skill in the tree, and checks each bonus reaches the contract system and
  survives save and load.
- Main scene headless smoke run: no errors or warnings.
- Windowed run: Marketplace, Hardware and Skills captured and reviewed.

### Known limitations

- **Research power does nothing yet.** GPUs, servers and the first AI skill mainly add research
  power, so they are weak purchases until MVP 7. Their descriptions say so.
- **Balance is unjudged.** Prices, tier levels, bonus sizes and skill costs are estimates.
- Hardware cannot be sold. Replaced parts stay in storage.
- Skills cannot be reset or refunded.
- A save file edited to hold more skill levels than the player has points for is accepted
  (levels are clamped to each skill's maximum, but point totals are not enforced on load).
- Hardware unlocks only by player level; the Network Map does not gate the shop.
- The storage cabinet only lists spare parts; swapping is done in the Hardware app.
- The world does not change appearance when hardware is upgraded.
- Not hand-played.

### Fixed during this milestone

- Many notifications arriving at once could cover the screen; at most four toasts now show.

## MVP 4 - Contracts and Mini-games

Validated on Godot 4.7.2 stable (Windows).

| Requirement | Status | Notes |
|---|---|---|
| ContractManager | Done | Generation, requirements, difficulty, rewards, completion, failure, history |
| Data-driven contracts | Done | 14 templates in `data/contracts/contracts.json` |
| All contract fields | Done | id, name, description, category, difficulty, required level, required skills, required hardware, estimated duration, reward, XP reward, reputation reward, mission stages |
| Seven categories | Done | Each has two contracts |
| Real gameplay per contract | Done | Every stage is a puzzle; there is no "complete" button |
| Reusable mission scenes and puzzles | Done | `MissionRunner` + 4 puzzle types shared by all contracts |
| Contracts application | Done | Board, active mission, history |
| Failure | Done | Mistake limit, time limit, abandon; reputation and heat penalties |
| Contract history | Done | Saved, capped, shown in the app |
| Save/load | Done | Board, contract in progress (stage, mistakes, time), history; same puzzle after loading |
| Earlier milestones preserved | Done | Older saves without contract data load and get a fresh board |

### Test results (2026-11-23)

- `--headless --import`: no errors.
- `tests/TestRunner.tscn`: 374 passed, 0 failed. Includes generating and solving 144
  puzzle instances (all 36 stages of the 14 contracts, four seeds each).
- `tests/FlowTest.tscn`: 190 passed, 0 failed. Plays a contract to completion through the puzzle
  screens, fails one by mistakes, abandons one, and saves and reloads one in progress.
- Main scene headless smoke run: no errors or warnings.
- Windowed run: contract board and three puzzle types captured and reviewed.

### Known limitations

- (Resolved in MVP 5) Required skills and hardware are now checked, and five contracts use them.
- **Four puzzle types serve seven categories**, so categories share mechanics (for example
  audits, debugging and malware work all use "spot the problem lines" with different content).
- **Balance is untested by a human.** Rewards, XP, time limits and difficulty were set by
  estimate. The first level takes two or three contracts.
- Puzzle difficulty comes only from size (more lines, longer codes, more rounds).
- The puzzle text pools are small, so repeated contracts show familiar lines in new combinations.
- The same contract can reappear on the board right after it is finished or failed.
- Progress inside a single puzzle is not saved; loading restarts the current stage's puzzle
  (mistakes and time are kept).
- The Network Map does not yet show where a contract takes place.
- Puzzles are mouse-driven; there is no keyboard control for them.
- Dev Tools still exists in debug builds and can grant money and XP without playing.

### Fixed during this milestone

- Desktop windows containing word-wrapped text opened taller than intended, pushing buttons
  off screen. Windows now return to their intended size and always open fully visible.

## MVP 3 - Hacker Desktop

Validated on Godot 4.7.2 stable (Windows).

| Requirement | Status | Notes |
|---|---|---|
| Application launcher | Done | Data-driven from `data/desktop/apps.json` |
| Opening applications | Done | Launcher icon or terminal `open <app>` |
| Closing applications | Done | Window close button, terminal `exit` |
| Switching applications | Done | Taskbar, clicking a window, launching again |
| Window management | Done | Drag, minimise, maximise / restore, raise on click, kept on screen |
| Notifications | Done | Toasts for new mail, level up, saves; unread badge on the Mail icon |
| State preservation | Done | Windows persist while walking around; Terminal and File Manager survive closing |
| Terminal (fictional commands only) | Done | 18 commands over game state and a virtual file system |
| Dashboard | Done | Now a windowed app |
| File Manager | Done | Browse and read the virtual file system |
| Mail | Done | Data-driven messages delivered on new game and level milestones; saved |
| Finance | Done | Totals, per-category breakdown, transaction history |
| Network Map | Done | Fictional node graph, discovered by level |
| Contracts | Done in MVP 4 | |
| Marketplace, Hardware, Skills | Done in MVP 5 | |
| Organization, Employees | Done in MVP 6 | |
| Research | Done in MVP 7 | |

### Test results (2026-11-23)

- `--headless --import`: no errors.
- `tests/TestRunner.tscn`: 237 passed, 0 failed.
- `tests/FlowTest.tscn`: 163 passed, 0 failed.
- Main scene headless smoke run: no errors or warnings.
- Windowed run: empty desktop, overlapping windows, mail, terminal and taskbar captured and reviewed.

### Known limitations

- **7 of the 13 listed applications are not installed yet.** Their gameplay systems belong to
  MVP 4-7; building empty versions now would have meant fake screens. Each icon is disabled and
  its tooltip names the milestone.
- Windows cannot be resized by dragging an edge; they can be moved and maximised.
- The file system is read-only and fixed. Nothing in the game creates or changes files yet.
- Mail cannot be deleted or replied to; messages only arrive from new-game and level triggers.
- The Network Map is informational: nodes cannot be acted on until contracts exist.
- Open windows are not written to the save file; a loaded game starts with a clean desktop.
- The terminal has no tab completion, pipes or scripting.
- In the terminal, the first Esc leaves the text field and the second logs off (engine behaviour
  for text fields).
- Desktop icons are text glyphs, not images.
- Window dragging and typing were verified through automated events and screenshots, not by hand.

## MVP 2 - Isometric World and Player

Validated on Godot 4.7.2 stable (Windows).

| Requirement | Status | Notes |
|---|---|---|
| Isometric room | Done | 8x8 tile apartment: floor, two walls, window with city view, neon trim and sign |
| Required objects | Done | Player, desk, monitor, chair, bed, storage, neon lighting, window |
| Player movement | Done | WASD / arrows, grid-aligned diagonals, follow camera |
| Collision | Done | Walls and solid furniture; colliders generated from grid footprints |
| Depth sorting | Done | Custom sorter; player passes correctly behind and in front of furniture |
| Interaction system | Done | Reusable `Interactable` + `InteractionDetector`, prompt, highlighted target |
| Interactive computer | Done | Opens the workstation (Dashboard); Esc or Log Off returns to the room |
| Other interactions | Done | Bed rests and saves; storage and window show a description |
| Position persistence | Done | Saved with the profile; validated against the room on load |
| MVP 1 preserved | Done | All MVP 1 checks still pass; old saves without a position load at the spawn point |

### Test results (2026-11-23)

- `--headless --import`: no errors.
- `tests/TestRunner.tscn`: 154 passed, 0 failed.
- `tests/FlowTest.tscn`: 100 passed, 0 failed (real input actions for movement, interact and Esc).
- Main scene headless smoke run: no errors or warnings.
- Windowed run: world, depth sorting behind the cabinet, prompts, workstation and pause captured
  and reviewed.

### Known limitations

- **All world art is placeholder**, drawn in code (`IsoBlock`, `RoomShell`, `PlayerVisual`).
  No sprites, walk animation frames or audio yet.
- The player has a bob and a left/right facing only; there are no directional sprites.
- Depth sorting is exact for one actor against axis-aligned furniture that does not overlap on
  screen in conflicting ways. It is sufficient for this room; very dense layouts or tall
  free-standing objects in the middle of the room may need a per-object rule.
- Storage and window interactions only show text. Storage gets real contents with hardware (MVP 5).
- The chair is furniture only; the player does not sit in it.
- One room. Room transitions and the office arrive with the organization milestone.
- Keyboard only: no gamepad bindings, no click-to-move, no key rebinding screen.
- The camera has no limits, so empty space is visible around the room.
- Not hand-played: movement and interactions were driven by injected input in the automated test
  and screens were checked from screenshots. Movement speed and feel should be judged by hand.
- The Dev Tools panel is still the only source of XP and money (contracts arrive in MVP 4).

## MVP 1 - Core Foundation

Validated on Godot 4.7.2 stable (Windows).

| Requirement | Status | Notes |
|---|---|---|
| Project architecture | Done | Folder tree per the master prompt, plus `scripts/reputation`, `scripts/ui`, `scripts/menu`, `scripts/applications` |
| Godot project configuration | Done | 1920x1080, canvas_items stretch, GL Compatibility, global theme |
| Initial autoload systems | Done | Save, Player, Economy, Progression, Reputation, Game managers |
| Functional main menu | Done | Continue, New Game, Load Game, Quit |
| New-game flow | Done | Slot choice, overwrite confirmation, alias validation, starting funds |
| Player data | Done | Alias, id, creation time, playtime |
| Economy | Done | Single transaction gateway, no negative balance, capped history |
| XP and progression | Done | 50 levels, configurable curve, 6 ranks |
| Reputation and heat | Done | White, underground, heat with clamping |
| Save/load foundation | Done | 3 slots, autosave, versioning, validation, backup recovery, delete |
| Basic dashboard | Done | Live view of all core state |
| Validation and run docs | Done | 129 unit checks + 56 end-to-end checks pass; README |

### Test results (2026-11-23)

- `--headless --import`: no errors.
- `tests/TestRunner.tscn`: 129 passed, 0 failed.
- `tests/FlowTest.tscn`: 56 passed, 0 failed.
- Main scene headless smoke run (120 frames): no errors or warnings.
- Windowed run on NVIDIA / OpenGL 3.3: shader compiles, all six screens captured and reviewed.

### Known limitations

- **No gameplay income yet.** The only way to change XP, money, reputation and heat is the Dev
  Tools panel (debug builds only). This is intentional for MVP 1; contracts arrive in MVP 4.
- (Resolved in MVP 2) The dashboard was hosted directly by `GameSession`; it is now opened from
  the computer in the room. `Dashboard.tscn` itself was not changed.
- No settings screen (audio, resolution, key bindings). Not part of MVP 1.
- No custom fonts, icons or audio; Godot's default font is used.
- Not verified by a human playing with mouse and keyboard: buttons were driven by the automated
  flow test and screens were checked from screenshots. Hover/focus feel and keyboard navigation
  should be confirmed by hand.
- No exported Windows build yet (export templates and presets are an MVP 9 task). The game runs
  from the editor or the Godot executable.
- The heat level has no gameplay consequence yet; it is only stored and displayed.

### Deviation from the master prompt

- Top-level play scene is `scenes/main/GameSession.tscn` rather than `GameWorld.tscn`.
  `GameWorld.tscn` will be introduced in MVP 2 as the isometric world.
